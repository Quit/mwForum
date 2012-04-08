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
my $newBoardId = $m->paramInt('bid');
my $subject = $m->paramStr('subject');
my $link = $m->paramBool('link');
$postId or $m->error('errParamMiss');
$subject or $m->error('errSubEmpty');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get branch base post
my ($oldBoardId, $oldTopicId, $oldParentId, $oldPostTime) = $m->fetchArray("
	SELECT boardId, topicId, parentId, postTime FROM posts WHERE id = ?", $postId);
$oldBoardId or $m->error('errPstNotFnd');
$newBoardId ||= $oldBoardId;

# Get topic base post
my $basePostId = $m->fetchArray("
	SELECT basePostId FROM topics WHERE id = ?", $oldTopicId);
$basePostId != $postId or $m->error('errPromoTpc');

# Get destination board
my $newBoard = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $newBoardId);
$newBoard or $m->error('errBrdNotFnd');

# Check if user is admin or moderator in source board
$user->{admin} || $m->boardAdmin($userId, $oldBoardId) or $m->error('errNoAccess');

# Check if user has write access to destination board
$m->boardVisible($newBoard) or $m->error('errNoAccess');
$m->boardWritable($newBoard) or $m->error('errNoAccess');

# Get IDs of posts that belong to branch
my $posts = $m->fetchAllHash("
	SELECT id, parentId FROM posts WHERE topicId = ?", $oldTopicId);
my %postsByParent = ();
push @{$postsByParent{$_->{parentId}}}, $_ for @$posts;
my @branchPostIds = ();
my $getBranchPostIds = sub {
	my $self = shift();
	my $pid = shift();
	push @branchPostIds, $pid;
	for my $child (@{$postsByParent{$pid}}) { 
		$child->{id} != $pid or error("Integrity Error", "Post is its own parent?!");
		$self->($self, $child->{id});
	}
};
$getBranchPostIds->($getBranchPostIds, $postId);

# Get last post time from branch posts
my $branchLastPostTime = $m->fetchArray("
	SELECT MAX(postTime) FROM posts WHERE id IN (:branchPostIds)",
	{ branchPostIds => \@branchPostIds });

my $newTopicId = undef;
my $oldMarkerId = undef;
if ($link) {
	# Insert new topic
	my $subjectEsc = $m->escHtml($subject);
	$m->dbDo("
		INSERT INTO topics (subject, boardId, lastPostTime)	VALUES (?, ?, ?)",
		$subjectEsc, $newBoardId, $branchLastPostTime);
	$newTopicId = $m->dbInsertId("topics");

	# Insert marker post in old topic
	$m->setLanguage($cfg->{language});
	my $linkText = $m->{lng}{brnProLnkBdy};
	$m->setLanguage();
	my $url = "topic_show$m->{ext}?pid=$postId";
	my $body = "[<a class='irl' href='$url'>$linkText</a>]";
	$m->dbDo("
		INSERT INTO posts (userId, boardId, topicId, parentId, approved, postTime, body) 
		VALUES (?, ?, ?, ?, ?, ?, ?)",
		-2, $oldBoardId, $oldTopicId, $oldParentId, 1, $oldPostTime, $body);
	$oldMarkerId = $m->dbInsertId("posts");

	# Insert marker post in new topic
	$url = "topic_show$m->{ext}?pid=$oldMarkerId";
	$body = "[<a class='irl' href='$url'>$linkText</a>]";
	$m->dbDo("
		INSERT INTO posts (userId, boardId, topicId, parentId, approved, postTime, body) 
		VALUES (?, ?, ?, ?, ?, ?, ?)",
		-2, $newBoardId, $newTopicId, 0, 1, $branchLastPostTime, $body);
	my $newMarkerId = $m->dbInsertId("posts");

	# Update new topic's base post id
	$m->dbDo("
		UPDATE topics SET basePostId = ? WHERE id = ?", $newMarkerId, $newTopicId);

	# Update base post's parentId
	$m->dbDo("
		UPDATE posts SET parentId = ? WHERE id = ?", $newMarkerId, $postId);
}
else {
	# Insert topic
	my $subjectEsc = $m->escHtml($subject);
	$m->dbDo("
		INSERT INTO topics (subject, boardId, basePostId, lastPostTime)	VALUES (?, ?, ?, ?)",
		$subjectEsc, $newBoardId, $postId, $m->{now});
	$newTopicId = $m->dbInsertId("topics");
	
	# Update base post's parentId
	$m->dbDo("
		UPDATE posts SET parentId = 0 WHERE id = ?", $postId);
}		

# Update posts
$m->dbDo("
	UPDATE posts SET
		boardId = :newBoardId,
		topicId = :newTopicId
	WHERE id IN (:branchPostIds)",
	{ newBoardId => $newBoardId, newTopicId => $newTopicId, branchPostIds => \@branchPostIds });

# Update statistics
if ($oldBoardId != $newBoardId) {
	# Update board stats
	$m->recalcStats($oldBoardId, $oldTopicId);
	$m->recalcStats($newBoardId, $newTopicId);
}
else {
	# Only update topic stats
	$m->recalcStats(undef, $oldTopicId);
	$m->recalcStats(undef, $newTopicId);
}

# Duplicate topicReadTimes for new topic
$m->dbDo("
	INSERT INTO topicReadTimes (userId, topicId, lastReadTime)
	SELECT userId, :newTopicId, lastReadTime 
	FROM topicReadTimes 
	WHERE topicId = :oldTopicId", 
	{ newTopicId => $newTopicId, oldTopicId => $oldTopicId });

# Log action and finish
$m->logAction(1, 'branch', 'promote', $userId, $oldBoardId, $oldTopicId, $postId, $newTopicId);
$m->redirect('topic_show', pid => $postId, msg => 'BrnPromo');
