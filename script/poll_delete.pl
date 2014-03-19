#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2014 Markus Wichitill
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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0]);

# Get CGI parameters
my $topicId = $m->paramInt('tid');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get topic
my ($boardId, $pollId, $topicUserId) = $m->fetchArray("
	SELECT topics.boardId, topics.pollId,	posts.userId
	FROM topics AS topics
		INNER JOIN posts AS posts
			ON posts.id = topics.basePostId
	WHERE topics.id = ?", $topicId);
$boardId or $m->error('errTpcNotFnd');

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Check if user can see and write to board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId);
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');
$boardAdmin || $m->boardWritable($board, 1) or $m->error('errNoAccess');

# Check if user owns topic or is moderator
$userId == $topicUserId || $boardAdmin or $m->error('errNoAccess');

# Normal topic creator may only delete if there have been no votes so far
if (!$boardAdmin) {
	!$m->fetchArray("
		SELECT pollId FROM pollVotes WHERE pollId = ?", $pollId) 
		or $m->error('errPolNoDel');
}

# Delete poll
$m->dbDo("
	DELETE FROM pollVotes WHERE pollId = ?", $pollId);
$m->dbDo("
	DELETE FROM pollOptions WHERE pollId = ?", $pollId);
$m->dbDo("
	DELETE FROM polls WHERE id = ?", $pollId);
$m->dbDo("
	UPDATE topics SET pollId = 0 WHERE id = ?", $topicId);

# Log action and finish
$m->logAction(1, 'poll', 'delete', $userId, $boardId, $topicId, undef, $pollId);
$m->redirect('topic_show', tid => $topicId, msg => 'PollDel');
