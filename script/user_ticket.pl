#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2012 Markus Wichitill
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
no warnings qw(uninitialized redefine);

# Imports
use MwfMain;

#------------------------------------------------------------------------------

# Init
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new(@_);

# Get CGI parameters
my $ticketId = $m->paramStrId('t');

# Get ticket
my $ticket = $m->fetchHash("
	SELECT * FROM tickets WHERE id = ? AND issueTime > ? - 2 * 86400", $ticketId, $m->{now});
$ticket or $m->error('errTktNotFnd');

# Get user
my $dbUser = $m->getUser($ticket->{userId});
$dbUser or $m->error('errUsrNotFnd');

# Login ticket (freshly registered)
if ($ticket->{type} eq 'usrReg') {
	# Set cookie
	$m->setCookie('login', "$dbUser->{id}-$dbUser->{password}", $dbUser->{tempLogin});

	# Delete old sessions
	$m->dbDo("
		DELETE FROM sessions WHERE lastOnTime < ? - ? * 60", $m->{now}, $cfg->{sessionTimeout});

	# Insert session
	if ($cfg->{urlSessions}) {
		$m->{sessionId} = $m->randomId();
		$m->dbDo("
			INSERT INTO sessions (id, userId, lastOnTime, ip) VALUES (?, ?, ?, ?)",
			$m->{sessionId}, $dbUser->{id}, $m->{now}, $m->{env}{userIp});
	}

	# Delete user's login tickets
	$m->dbDo("
		DELETE FROM tickets WHERE userId = ? AND type = ?", $dbUser->{id}, 'usrReg');

	# Log action and finish
	$m->logAction(1, 'user', 'tkusrreg', $dbUser->{id});
	$m->redirect('forum');
}
# Login ticket (forgot password)
elsif ($ticket->{type} eq 'fgtPwd') {
	# Set cookies
	$m->setCookie('login', "$dbUser->{id}-$dbUser->{password}", $dbUser->{tempLogin});

	# Delete old sessions
	$m->dbDo("
		DELETE FROM sessions WHERE lastOnTime < ? - ? * 60", $m->{now}, $cfg->{sessionTimeout});

	# Insert session
	if ($cfg->{urlSessions}) {
		$m->{sessionId} = $m->randomId();
		$m->dbDo("
			INSERT INTO sessions (id, userId, lastOnTime, ip) VALUES (?, ?, ?, ?)",
			$m->{sessionId}, $dbUser->{id}, $m->{now}, $m->{env}{userIp});
	}

	# Delete user's login tickets
	$m->dbDo("
		DELETE FROM tickets WHERE userId = ? AND type = ?", $dbUser->{id}, 'fgtPwd');

	# Log action and finish
	$m->logAction(1, 'user', 'tkfgtpwd', $dbUser->{id});
	$m->redirect('user_password', msg => 'TkaFgtPwd');
}
# Email change ticket
elsif ($ticket->{type} eq 'emlChg') {
	# Change email address
	$m->dbDo("
		UPDATE users SET email = ? WHERE id = ?", $ticket->{data}, $dbUser->{id});
	
	# Delete all email change tickets
	$m->dbDo("
		DELETE FROM tickets WHERE userId = ? AND type = ?", $dbUser->{id}, 'emlChg');

	# Log action and finish
	$m->logAction(1, 'user', 'tkemlchg', $dbUser->{id});
	$m->redirect('forum_show', msg => 'TkaEmlChg');
}
