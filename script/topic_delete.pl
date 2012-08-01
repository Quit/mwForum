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
my $topicId = $m->paramInt('tid');
my $notify = $m->paramBool('notify');
my $reason = $m->paramStr('reason');
$topicId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get topic
my $topic = $m->fetchHash("
	SELECT topics.boardId, topics.pollId, topics.lastPostTime, topics.subject,
		posts.userId
	FROM topics AS topics
		INNER JOIN posts AS posts
			ON posts.id = topics.basePostId
	WHERE topics.id = ?", $topicId);
$topic or $m->error('errTpcNotFnd');
my $boardId = $topic->{boardId};

# Get board
my $board = $m->fetchHash("
	SELECT topicAdmins FROM boards WHERE id = ?", $boardId);

# Check if user is admin or moderator
$user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId)
	or $m->error('errNoAccess');

# Get previous topic id for redirection to same page
my $prevTopicId = $m->fetchArray("
	SELECT id 
	FROM topics 
	WHERE boardId = :boardId
		AND lastPostTime > :lastPostTime
	ORDER BY lastPostTime
	LIMIT 1",
	{ boardId => $boardId, lastPostTime => $topic->{lastPostTime} });

# Delete topic
my $trash = $cfg->{trashBoardId} && $cfg->{trashBoardId} != $boardId;
$m->deleteTopic($topicId, $trash);
$m->recalcStats([ $boardId, $trash ? $cfg->{trashBoardId} : () ]);

# Add notification message
$m->addNote('tpcDel', $topic->{userId}, 'notTpcDel', tpcSbj => $topic->{subject}, reason => $reason) 
	if $notify && $topic->{userId} && $topic->{userId} != $userId;

# Log action and finish
$m->logAction(1, 'topic', 'delete', $userId, $boardId, $topicId);
$m->redirect('board_show', $prevTopicId ? (tid => $prevTopicId, tgt => "tid$prevTopicId") 
	: (bid => $boardId), msg => 'TpcDelete');
