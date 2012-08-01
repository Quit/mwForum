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
my $action = $m->paramStrId('act');
my $boardId = $m->paramInt('bid') || 0;
my $time = $m->paramInt('time');

if ($userId) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->error('errSrcAuth');

	if ($action eq 'old') {
		# Mark messages as old by setting prevOnTime
		$m->{userUpdates}{prevOnTime} = $time;
		$m->setCookie('prevon', $time);
	
		# Log action and finish
		$m->logAction(1, 'user', 'markold', $userId);
		$m->redirect('forum_show', msg => 'MarkOld');
	}
	elsif ($action eq 'read') {
		if ($boardId) {
			# Mark all unread topics read
			my $lowestUnreadTime = $m->{now} - $cfg->{maxUnreadDays} * 86400;
			my $tmp = 'userMark' . int(rand(2147483647));
			$m->dbDo("
				CREATE TEMPORARY TABLE $tmp AS
				SELECT topics.id AS id
				FROM topics AS topics
					LEFT JOIN topicReadTimes AS topicReadTimes
						ON topicReadTimes.userId = :userId
						AND topicReadTimes.topicId = topics.id
				WHERE topics.boardId = :boardId
					AND topics.lastPostTime > :lowestUnreadTime
					AND (topics.lastPostTime > topicReadTimes.lastReadTime 
					OR topicReadTimes.topicId IS NULL)",
				{ userId => $userId, boardId => $boardId, lowestUnreadTime => $lowestUnreadTime });
			$m->dbDo("
				DELETE FROM topicReadTimes WHERE userId = ? AND topicId IN (SELECT id FROM $tmp)", 
				$userId);
			$m->dbDo("			
				INSERT INTO topicReadTimes SELECT ?, id, ? FROM $tmp", $userId, $m->{now});
			$m->dbDo("
				DROP TABLE $tmp");
		}
		else {
			# Mark everything read by setting fakeReadTime
			$m->{userUpdates}{fakeReadTime} = $time;
			$m->dbDo("
				DELETE FROM topicReadTimes WHERE userId = ?", $userId);
		}
	
		# Log action and finish
		$m->logAction(1, 'user', 'markread', $userId, $boardId);
		$m->redirect('forum_show', msg => 'MarkRead');
	}
}
else {
	if ($action eq 'old') {
		# Mark messages as old by setting prevOnTime in cookie
		$m->setCookie('prevon', $time);
	
		# Log action and finish
		$m->logAction(2, 'guest', 'markold');
		$m->redirect('forum_show', msg => 'MarkOld');
	}
	else {
		$m->error('errNoAccess');
	}
}
