#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2013 Markus Wichitill
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#------------------------------------------------------------------------------

use strict;
use warnings;
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
use Mail::POP3Client ();
use MwfMain;

#------------------------------------------------------------------------------

# Get arguments
my %opts = ();
Getopt::Std::getopts('sf:', \%opts);
my $spawned = $opts{s};
my $forumId = $opts{f};

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId, spawned => $spawned);

# Connect to POP3 account
my $pop = Mail::POP3Client->new(
	USER      => $cfg->{bouncePopUser},
	PASSWORD  => $cfg->{bouncePopPwd},
	HOST      => $cfg->{bouncePopHost} || 'localhost',
	AUTH_MODE => $cfg->{bouncePopAuth} || 'BEST',
	PORT      => $cfg->{bouncePopPort} || 110,
	TIMEOUT   => $cfg->{bouncePopTout} || 20,
	USESSL    => $cfg->{bouncePopSsl}  || 0,
	DEBUG     => $cfg->{bouncePopDbg}  || 0,
);
$pop->Alive() or $m->error("POP3 connection failed.");

# Retrieve messages
my @emails = ();
my $emailNum = $pop->Count();
defined($emailNum) && $emailNum != -1 or $m->error("POP3 connection failed. ($!)");
for my $i (1 .. $emailNum) {
	push @emails, scalar $pop->Body($i);
	$pop->Delete($i);
}

# Close connection
$pop->Close();

# For each email
for my $email (@emails) {
	# Get auth value from email
	my ($auth) = $email =~ /X-mwForum-BounceAuth: ([A-Za-z_0-9-]+)/;
	$auth or $m->logAction(3, 'bounce', 'noauth'), next;

	# Get user with auth value
	my $cs = 'BINARY';
	if ($m->{pgsql}) { $cs = 'TEXT' }
	elsif ($m->{sqlite}) { $cs = 'BLOB' }
	my $authUser = $m->fetchHash("
		SELECT id, bounceNum, dontEmail, regTime, lastOnTime 
		FROM users 
		WHERE bounceAuth = CAST(? AS $cs)", 
		$auth);
	$authUser or $m->logAction(2, 'bounce', 'nouser'), next;
	my $authUserId = $authUser->{id};
	$m->logAction(1, 'bounce', 'auth', $authUserId);

	# Delete users that never logged in (registered with invalid email)
	if ($authUser->{regTime} == $authUser->{lastOnTime}) {
		$m->logAction(1, 'bounce', 'delnew', $authUserId);
		$m->deleteUser($authUserId);
		next;
	}

	# Update user's bounceNum
	my $bounceFactor = $cfg->{bounceFactor} || 3;
	my $oldBounceNum = $authUser->{bounceNum};
	my $newBounceNum = $oldBounceNum + $bounceFactor;
	$m->dbDo("
		UPDATE users SET bounceNum = ? WHERE id = ?", $newBounceNum, $authUserId);
	
	# Take action depending on configured policy
	my $warnTrsh = $cfg->{bounceTrshWarn} * $bounceFactor;
	my $cnclTrsh = $cfg->{bounceTrshCncl} * $bounceFactor;
	my $dsblTrsh = $cfg->{bounceTrshDsbl} * $bounceFactor;
	
	if ($warnTrsh && $oldBounceNum < $warnTrsh && $newBounceNum >= $warnTrsh) {
		# Add notification if there isn't already one
		my $warned = $m->fetchArray("
			SELECT 1 FROM notes WHERE type = ? AND userId = ?", 'bncWrn', $authUserId);
		$m->addNote('bncWrn', $authUserId, 'bncWarning') if !$warned;
	}
	elsif ($cnclTrsh && $oldBounceNum < $cnclTrsh && $newBounceNum >= $cnclTrsh) {
		# Cancel subscriptions and clear email notification options
		$m->dbDo("
			DELETE FROM boardSubscriptions WHERE userId = ?", $authUserId);
		$m->dbDo("
			DELETE FROM topicSubscriptions WHERE userId = ?", $authUserId);
		$m->dbDo("
			UPDATE users SET msgNotify = 0 WHERE id = ?", $authUserId);
	}
	elsif ($dsblTrsh && $oldBounceNum < $dsblTrsh && $newBounceNum >= $dsblTrsh) {
		# Set dontEmail flag unless it's already set
		$m->dbDo("
			UPDATE users SET dontEmail = 1 WHERE id = ?", $authUserId) 
			if !$authUser->{dontEmail};
	}
}
