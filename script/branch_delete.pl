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

# Get CGI parameters
my $postId = $m->paramInt('pid');
$postId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get branch base post
my ($boardId, $topicId, $parentId) = $m->fetchArray("
	SELECT boardId, topicId, parentId FROM posts WHERE id = ?", $postId);
$boardId or $m->error('errPstNotFnd');

# Get board
my $board = $m->fetchHash("
	SELECT topicAdmins FROM boards WHERE id = ?", $boardId);

# Get topic base post
my $basePostId = $m->fetchArray("
	SELECT basePostId FROM topics WHERE id = ?", $topicId);
$basePostId != $postId or $m->error('errPromoTpc');

# Check if user is admin or moderator
$user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId)
	or $m->error('errNoAccess');

# Get posts
my $posts = $m->fetchAllHash("
	SELECT id, parentId	FROM posts WHERE topicId = ?", $topicId);

# Put posts in by-parent lookup table
my %postsByParent = ();
push @{$postsByParent{$_->{parentId}}}, $_ for @$posts;

# Delete posts
my $deleteBranch = sub {
	my $self = shift();
	my $pid = shift();

	# Recurse through children
	for my $child (@{$postsByParent{$pid}}) { 
		$child->{id} != $pid or $m->error("Post is its own parent?!");
		$self->($self, $child->{id});
	}

	# Delete post
	$m->deletePost($pid, 0, 0, 0);
};
$deleteBranch->($deleteBranch, $postId);
$m->recalcStats($boardId, $topicId);

# Log action and finish
$m->logAction(1, 'branch', 'delete', $userId, $boardId, $topicId, $postId);
$m->redirect('topic_show', tid => $topicId, msg => 'BrnDelete');
