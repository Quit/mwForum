#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2015 Markus Wichitill
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

# Check if access should be denied
$userId or $m->error('errNoAccess');
$cfg->{postLikes} or $m->error('errNoAccess');

# Get CGI parameters
my $postId = $m->paramInt('pid');
my $action = $m->paramStrId('act');
$postId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get post
my ($boardId, $topicId, $postUserId) = $m->fetchArray("
	SELECT boardId, topicId, userId FROM posts WHERE id = ?", $postId);
$boardId or $m->error('errPstNotFnd');

# No liking own posts
$userId != $postUserId or $m->error('errNoAccess');

# Check if already liked
my $liked = $m->fetchArray("
	SELECT 1 FROM postLikes WHERE postId = ? AND userId = ?", $postId, $userId);

# Add like or revoke like
my $like = $action eq 'like' ? 1 : 0;
if ($like && !$liked) {
	# Insert like
	$m->dbDo("
		INSERT INTO postLikes (postId, userId) VALUES (?, ?)", $postId, $userId);
}
elsif (!$like && $liked) {
	# Remove like
	$m->dbDo("
		DELETE FROM postLikes WHERE postId = ? AND userId = ?", $postId, $userId);
}

# Log action and finish
$m->logAction(1, 'post', $like ? 'like' : 'unlike', $userId, $boardId, $topicId, $postId);
$m->redirect('topic_show', pid => $postId, msg => $like ? 'PstLike' : 'PstUnlike');
