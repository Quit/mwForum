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
my $action = $m->paramStrId('act');
$postId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get post
my ($boardId, $topicId) = $m->fetchArray("
	SELECT boardId, topicId FROM posts WHERE id = ?", $postId);
$boardId or $m->error('errPstNotFnd');

# Get board
my $board = $m->fetchHash("
	SELECT topicAdmins FROM boards WHERE id = ?", $boardId);

# Check if user is admin or moderator
$user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId)
	or $m->error('errNoAccess');

# Update post
my $locked = $action eq 'lock' ? 1 : 0;
$m->dbDo("
	UPDATE posts SET locked = ? WHERE id = ?", $locked, $postId);

# Log action and finish
$m->logAction(1, 'post', $locked ? 'lock' : 'unlock', $userId, $boardId, $topicId, $postId);
$m->redirect('topic_show', pid => $postId, msg => $locked ? 'PstLock' : 'PstUnlock');
