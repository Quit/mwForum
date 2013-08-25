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
	SELECT topics.boardId, topics.pollId, posts.userId
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

# Check if poll is already locked
my $poll = $m->fetchHash("
	SELECT locked FROM polls WHERE id = ?", $pollId);
$poll or $m->error('errPolNotFnd');
!$poll->{locked} or $m->error('errPolLocked');

# Mark poll as locked
$m->dbDo("
	UPDATE polls SET locked = 1 WHERE id = ?", $pollId);

# Consolidate votes
my $voteSums = $m->fetchAllArray("
	SELECT optionId, COUNT(*) FROM pollVotes WHERE pollId = ? GROUP BY optionId", $pollId);

# Set option sums
$m->dbDo("
	UPDATE pollOptions SET votes = ? WHERE id = ?", $_->[1], $_->[0])
	for @$voteSums;

# Delete individual votes
$m->dbDo("
	DELETE FROM pollVotes WHERE pollId = ?", $pollId);

# Log action and finish
$m->logAction(1, 'poll', 'lock', $userId, $boardId, $topicId, undef, $pollId);
$m->redirect('topic_show', tid => $topicId, msg => 'PollLock');
