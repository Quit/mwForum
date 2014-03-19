#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright © 1999-2014 Markus Wichitill
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

package MwfPlgEvent;
use utf8;
use strict;
use warnings;
no warnings qw(uninitialized redefine);
our $VERSION = "2.27.0";

#------------------------------------------------------------------------------
# Hide a specific board for newly registered users

sub userRegisterHideBoard
{
	my %params = @_;
	my $m = $params{m};
	my $level = $params{level};
	my $entity = $params{entity};
	my $action = $params{action};
	my $userId = $params{userId};

	if ($level == 1 && $entity eq 'user' && $action eq 'register') {
		$m->dbDo("
			INSERT INTO boardHiddenFlags (userId, boardId) VALUES (?, ?)", $userId, 9);
	}
}

#------------------------------------------------------------------------------
# Auto-ban newly registered users to emulate a queue from which admins have to
# manually approve users before they can post (e.g. to hinder spambots)

sub userRegisterQueue
{
	my %params = @_;
	my $m = $params{m};
	my $level = $params{level};
	my $entity = $params{entity};
	my $action = $params{action};
	my $userId = $params{userId};

	if ($level == 1 && $entity eq 'user' && $action eq 'register') {
		my $reason = "Awaiting manual approval by an admin for spam protection reasons.";
		$m->dbDo("
			INSERT INTO userBans (userId, banTime, duration, reason, intReason)
			VALUES (?, ?, ?, ?, ?)",
			$userId, $m->{now}, 0, $reason, '[queued]');

		# Add notification message for admin with userId 1
		my $link = "<a href='user_ban$m->{ext}?uid=$userId'>user</a>";
		$m->addNote('usrReg', 1, "A $link registered and requires un-banning.");
	}
}

#-----------------------------------------------------------------------------
# Make a backup copy of all new posts

sub postAddBackup
{
	my %params = @_;
	my $m = $params{m};
	my $level = $params{level};
	my $entity = $params{entity};
	my $action = $params{action};
	my $postId = $params{postId};
	
	if ($level == 1 && ($entity eq 'post' || $entity eq 'topic') && $action eq 'add') {
		$m->dbDo("
			INSERT INTO postBackups 
			SELECT * FROM posts WHERE id = ?", $postId);
	}
}

#-----------------------------------------------------------------------------
# Mark posts by certain users as unapproved in any board

sub postAddUnapprove
{
	my %params = @_;
	my $m = $params{m};
	my $level = $params{level};
	my $entity = $params{entity};
	my $action = $params{action};
	my $postId = $params{postId};
	
	if ($level == 1 && ($entity eq 'post' || $entity eq 'topic') && $action eq 'add'
		&& $m->{user}{comment} =~ /\[troll\]/i) {
		$m->dbDo("
			UPDATE posts SET approved = 0 WHERE id = ?", $postId);
	}
}

#-----------------------------------------------------------------------------
# Log events to file

sub logToFile
{
	my %params = @_;
	my $m = $params{m};

	open my $fh, ">>:utf8", $m->{cfg}{logFile} or return 0;
	flock $fh, 2;
	seek $fh, 0, 2;
	my $timeStr = $m->formatTime($params{logTime}, 0, "%Y-%m-%d %H:%M:%S");
	print $fh 
		"[$timeStr] [$m->{env}{userIp}] [$m->{env}{script}]",
		" $params{level} $params{entity} $params{action} $params{userId} $params{boardId}",
		" $params{topicId} $params{postId} $params{extraId} $params{string}\n";
	close $fh;
	return 1;
}

#-----------------------------------------------------------------------------
1;
