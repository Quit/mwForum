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
my $newParentId = $m->paramInt('parent') || 0;
$postId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get branch base post
my ($oldBoardId, $oldTopicId, $oldParentId) = $m->fetchArray("
	SELECT boardId, topicId, parentId FROM posts WHERE id = ?", $postId);
$oldBoardId or $m->error('errPstNotFnd');

# Get source topic
my ($basePostId, $oldLastPostTime) = $m->fetchArray("
	SELECT basePostId, lastPostTime FROM topics WHERE id = ?", $oldTopicId);
$basePostId != $postId or $m->error('errPromoTpc');

# Check if user is admin or moderator in source board
$user->{admin} || $m->boardAdmin($userId, $oldBoardId) or $m->error('errNoAccess');

# Get new parent post
my $newBoardId = $oldBoardId;
my $newTopicId = $oldTopicId;
if ($newParentId) {
	($newBoardId, $newTopicId) = $m->fetchArray("
		SELECT boardId, topicId FROM posts WHERE id = ?", $newParentId);
	$newBoardId or $m->error('errPstNotFnd');
}

# Get IDs of posts that belong to branch and check for illegal moves
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

# Move inside topic or to other topic and maybe board
if ($oldTopicId == $newTopicId) {
	# Only update post
	$m->dbDo("
		UPDATE posts SET parentId = ? WHERE id = ?", $newParentId, $postId);
}
else {
	# Check if user is admin or moderator in destination board
	$user->{admin} || $m->boardAdmin($userId, $newBoardId) or $m->error('errNoAccess')
		if $oldBoardId != $newBoardId;

	# Update posts, topics and boards
	$m->dbDo("
		UPDATE posts SET parentId = ? WHERE id = ?", $newParentId, $postId);
	$m->dbDo("
		UPDATE posts SET boardId = :newBoardId, topicId = :newTopicId WHERE id IN (:branchPostIds)",
		{ newBoardId => $newBoardId, newTopicId => $newTopicId, branchPostIds => \@branchPostIds });

	# Handle read times
	my $newLastPostTime = $m->fetchArray("
		SELECT lastPostTime FROM topics WHERE id = ?", $newTopicId);
	if ($m->{mysql}) {
		# Special treatment for users who have both topics completely read
		$m->dbDo("
			UPDATE topicReadTimes AS topicReadTimes
			INNER JOIN (
				SELECT oldTimes.userId
				FROM topicReadTimes AS oldTimes 
					INNER JOIN topicReadTimes AS newTimes
						ON newTimes.userId = oldTimes.userId
				WHERE oldTimes.topicId = :oldTopicId
					AND oldTimes.lastReadTime >= :oldLastPostTime
					AND newTimes.topicId = :newTopicId
					AND newTimes.lastReadTime >= :newLastPostTime
			) AS updates
			SET lastReadTime = :now
			WHERE topicReadTimes.userId = updates.userId
				AND (topicId = :oldTopicId OR topicId = :newTopicId)",
			{ now => $m->{now}, oldTopicId => $oldTopicId, newTopicId => $newTopicId,
				oldLastPostTime => $oldLastPostTime, newLastPostTime => $newLastPostTime });

		# Set read times to older of the two
		$m->dbDo("
			UPDATE topicReadTimes AS o
				LEFT JOIN topicReadTimes AS i 
					ON i.userId = o.userId 
					AND i.topicId = :oldTopicId
			SET o.lastReadTime = LEAST(o.lastReadTime, COALESCE(i.lastReadTime, 0))
			WHERE o.topicId = :newTopicId",
			{ oldTopicId => $oldTopicId, newTopicId => $newTopicId });
	}
	else {
		# Special treatment for users who have both topics completely read
		$m->dbDo("
			UPDATE topicReadTimes SET lastReadTime = :now 
			FROM (
				SELECT oldTimes.userId
				FROM topicReadTimes AS oldTimes 
					INNER JOIN topicReadTimes AS newTimes
						ON newTimes.userId = oldTimes.userId
				WHERE oldTimes.topicId = :oldTopicId
					AND oldTimes.lastReadTime >= :oldLastPostTime
					AND newTimes.topicId = :newTopicId
					AND newTimes.lastReadTime >= :newLastPostTime
				) AS updates
			WHERE topicReadTimes.userId = updates.userId
				AND (topicId = :oldTopicId OR topicId = :newTopicId)",
			{ now => $m->{now}, oldTopicId => $oldTopicId, newTopicId => $newTopicId,
				oldLastPostTime => $oldLastPostTime, newLastPostTime => $newLastPostTime })
			if $m->{pgsql};

		# Set read times to older of the two
		my $least = $m->{sqlite} ? 'MIN' : 'LEAST';
		$m->dbDo("
			UPDATE topicReadTimes SET 
				lastReadTime = $least(lastReadTime, COALESCE((
					SELECT lastReadTime
					FROM topicReadTimes AS i 
					WHERE i.userId = topicReadTimes.userId 
						AND i.topicId = :oldTopicId
				), 0))
			WHERE topicId = :newTopicId",
			{ oldTopicId => $oldTopicId, newTopicId => $newTopicId });
	}

	# Update statistics
	$m->recalcStats(undef, [ $oldTopicId, $newTopicId ]) if $oldTopicId != $newTopicId;
	$m->recalcStats([ $oldBoardId, $newBoardId ]) if $oldBoardId != $newBoardId;
}

# Log action and finish
$m->logAction(1, 'branch', 'move', $userId, $oldBoardId, $oldTopicId, $postId, $newParentId);
$m->redirect('topic_show', pid => $postId, msg => 'BrnMove');
