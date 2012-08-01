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
my $postId = $m->paramInt('pid');
my $notify = $m->paramBool('notify');
my $reason = $m->paramStr('reason');
$postId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get post
my $post = $m->fetchHash("
	SELECT posts.*, 
		topics.pollId, topics.subject
	FROM posts AS posts
		INNER JOIN topics AS topics
			ON topics.id = posts.topicId
	WHERE posts.id = ?", $postId);
$post or $m->error('errPstNotFnd');
my $boardId = $post->{boardId};
my $topicId = $post->{topicId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);

# Check if user can see and write to board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId);
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');
$boardAdmin || $m->boardWritable($board, 1) or $m->error('errNoAccess');

# Check if user owns post or is moderator
$userId && $userId == $post->{userId} || $boardAdmin or $m->error('errNoAccess');
	
# Check editing time limitation
!$cfg->{postEditTime} || $m->{now} < $post->{postTime} + $cfg->{postEditTime}
	|| $boardAdmin || $m->boardMember($userId, $boardId)
	or $m->error('errPstEdtTme');

# Check if topic or post is locked
!$m->fetchArray("
	SELECT locked FROM topics WHERE id = ?", $topicId)
	|| $boardAdmin or $m->error('errTpcLocked');
!$post->{locked} || $boardAdmin or $m->error('errPstLocked');

# Check authorization
$m->checkAuthz($user, 'deletePost');

# Delete post
my $trash = $cfg->{trashBoardId} && $cfg->{trashBoardId} != $boardId;
my $topicDeleted = $m->deletePost($postId, $trash);
$m->recalcStats($boardId, $topicId);

# Add notification message
if ($notify && $post->{userId} && $post->{userId} != $userId) {
	if ($topicDeleted) {
		$m->addNote('tpcDel', $post->{userId}, 'notTpcDel', tpcSbj => $post->{subject}, reason => $reason);
	}
	else {
		my $url = "topic_show$m->{ext}?tid=$topicId";
		$m->addNote('pstDel', $post->{userId}, 'notPstDel', tpcUrl => $url, reason => $reason);
	}
}

# Log action and finish
$m->logAction(1, 'post', 'delete', $userId, $boardId, $topicId, $postId);
$m->redirect('board_show', bid => $boardId, msg => 'PstTpcDel') if $topicDeleted;
$m->redirect('topic_show', $post->{parentId} ? (pid => $post->{parentId}) : (tid => $topicId), 
	msg => 'PstDel');
