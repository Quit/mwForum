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
my $newParentId = $m->paramInt('parent') || 0;
$postId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get branch base post
my ($oldBoardId, $oldTopicId, $oldParentId) = $m->fetchArray("
	SELECT boardId, topicId, parentId FROM posts WHERE id = ?", $postId);
$oldBoardId or $m->error('errPstNotFnd');

# Get topic base post
my $basePostId = $m->fetchArray("
	SELECT basePostId FROM topics WHERE id = ?", $oldTopicId);
$basePostId != $postId or $m->error('errPromoTpc');

# Check if user is admin or moderator in source board
$user->{admin} || $m->boardAdmin($userId, $oldBoardId) or $m->error('errNoAccess');

# If moving to other parent post
if ($newParentId) {
	# Get new parent post
	my ($newBoardId, $newTopicId) = $m->fetchArray("
		SELECT boardId, topicId FROM posts WHERE id = ?", $newParentId);
	$newTopicId or $m->error('errPstNotFnd');

	# Get IDs of posts that belong to branch
	my %postsByParent = ();
	my @branchPostIds = ();
	my $posts = $m->fetchAllHash("
		SELECT id, parentId FROM posts WHERE topicId = ?", $oldTopicId);
	push @{$postsByParent{$_->{parentId}}}, $_ for @$posts;
	my $getBranchPostIds = sub {
		my $self = shift();
		my $pid = shift();
		$pid != $newParentId or $m->error("Can't move branch into itself.");
		push @branchPostIds, $pid;
		for my $child (@{$postsByParent{$pid}}) { 
			$child->{id} != $pid or $m->error("Post is its own parent?!");
			$self->($self, $child->{id});
		}
	};
	$getBranchPostIds->($getBranchPostIds, $postId);
	
	# If moving to parent post in other topic and/or board
	if ($oldTopicId != $newTopicId || $oldBoardId != $newBoardId) {
		# Check if user is admin or moderator in destination board
		$user->{admin} || $m->boardAdmin($userId, $newBoardId) or $m->error('errNoAccess')
			if $oldBoardId != $newBoardId;

		# Update base post's parentId
		$m->dbDo("
			UPDATE posts SET parentId = ? WHERE id = ?", $newParentId, $postId);
		
		# Update posts
		$m->dbDo("
			UPDATE posts SET
				boardId = :newBoardId,
				topicId = :newTopicId
			WHERE id IN (:branchPostIds)",
			{ newBoardId => $newBoardId, newTopicId => $newTopicId, branchPostIds => \@branchPostIds });
	
		# Update statistics
		if ($oldBoardId != $newBoardId) {
			$m->recalcStats($oldBoardId, $oldTopicId);
			$m->recalcStats($newBoardId, $newTopicId);
		}
		elsif ($oldTopicId != $newTopicId) {
			$m->recalcStats(undef, $oldTopicId);
			$m->recalcStats(undef, $newTopicId);
		}
	}
	# If moving to other parent post in same topic
	else {
		# Update base post's parentId
		$m->dbDo("
			UPDATE posts SET parentId = ? WHERE id = ?", $newParentId, $postId);
	}
}
else {
	# Move post to topic level when parentId is 0
	$m->dbDo("
		UPDATE posts SET parentId = 0 WHERE id = ?", $postId);
}

# Log action and finish
$m->logAction(1, 'branch', 'move', $userId, $oldBoardId, $oldTopicId, $postId, $newParentId);
$m->redirect('topic_show', pid => $postId, msg => 'BrnMove');
