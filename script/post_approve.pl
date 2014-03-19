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
my $postId = $m->paramInt('pid');
$postId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get post
my $post = $m->fetchHash("
	SELECT * FROM posts WHERE id = ?", $postId);
$post or $m->error('errPstNotFnd');
my $boardId = $post->{boardId};
my $topicId = $post->{topicId};

# Get parent post
my $parent = undef;
$parent = $m->fetchHash("
	SELECT * FROM posts WHERE id = ?", $post->{parentId})
	if $post->{parentId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Get topic
my $topic = $m->fetchHash("
	SELECT * FROM topics WHERE id = ?", $topicId);
$topic or $m->error('errTpcNotFnd');

# Check if user is admin or moderator
$user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId)
	or $m->error('errNoAccess');

# Update post
$m->dbDo("
	UPDATE posts SET approved = 1 WHERE id = ?", $postId);

# Send delayed notifications
$m->notifyPost(board => $board, topic => $topic, post => $post, parent => $parent);

# Log action and finish
$m->logAction(1, 'post', 'approve', $userId, $boardId, $topicId, $postId);
$m->redirect('topic_show', pid => $postId, msg => 'PstApprv');
