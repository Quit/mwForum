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

# Check if access should be denied
$cfg->{reports} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $boardId = $m->paramInt('bid');

# Print header
$m->printHeader();

# Print page bar
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{repTitle}, navLinks => \@navLinks);

# Determine which boards user can and wants to see
my @boardIds = ();
my $boardStr = ""; 
if ($user->{admin} && $boardId) {
	$boardStr = "WHERE posts.boardId = :boardId";
}
elsif (!$user->{admin}) {
	if ($boardId) {
		$m->boardAdmin($userId, $boardId) or $m->error('errNoAccess');
		$boardStr = "WHERE posts.boardId = :boardId";
	}
	else {
		my $boards = $m->fetchAllArray("
			SELECT id FROM boards");
		@$boards = grep($m->boardAdmin($userId, $_->[0]), @$boards);
		@$boards or $m->error('errNoAccess');
		@boardIds = map($_->[0], @$boards);
		$boardStr = "WHERE posts.boardId IN (:boardIds)";
	}
}

# Get reported posts
my $posts = $m->fetchAllHash("
	SELECT postReports.userId AS reporterId, postReports.reason,
		posts.id, posts.userId, posts.userNameBak, posts.topicId, posts.postTime, posts.body,
		topics.subject,
		users.userName,
		reporters.id AS reporterId, reporters.userName AS reporterName
	FROM postReports AS postReports
		INNER JOIN posts AS posts
			ON posts.id = postReports.postId
		INNER JOIN topics AS topics
			ON topics.id = posts.topicId
		LEFT JOIN users AS users
			ON users.id = posts.userId
		LEFT JOIN users AS reporters 
			ON reporters.id = postReports.userId
	$boardStr
	ORDER BY posts.postTime DESC",
	{ boardId => $boardId, boardIds => \@boardIds });

# Print reports
for my $post (@$posts) {
	# Shortcuts
	my $postId = $post->{id};

	# Format output
	my $userNameStr = $post->{userName} || $post->{userNameBak} || " - ";
	my $infUrl = $m->url('user_info', uid => $post->{userId});
	$userNameStr = "<a href='$infUrl'>$userNameStr</a>" if $post->{userId} > 0;
	my $reporterNameStr = $post->{reporterName} || " - ";
	$infUrl = $m->url('user_info', uid => $post->{reporterId});
	$reporterNameStr = "<a href='$infUrl'>$reporterNameStr</a>";
	my $report = { isReport => 1, body => $post->{reason} };
	$m->dbToDisplay({}, $report);
	$m->dbToDisplay({}, $post);
	my $shwUrl = $m->url('topic_show', pid => $postId);

	# Print post
	print
		"<form action='report_delete$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{repBy}</span> $reporterNameStr</div>\n",
		"<div class='ccl'>\n",
		"$report->{body}\n",
		"</div>\n",
		"<div class='ccl'>\n",
		"<div>$lng->{repTopic}: <a href='$shwUrl'>$post->{subject}</a></div>\n",
		"<div>$lng->{repPoster}: $userNameStr</div>\n",
		"<div>$post->{body}</div>\n",
		$m->submitButton('repDeleteB', 'remove'),
		"<input type='hidden' name='uid' value='$post->{reporterId}'/>\n",
		"<input type='hidden' name='pid' value='$postId'/>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
}

# If list is empty, display notification
print "<div class='frm'><div class='ccl'>$lng->{repEmpty}</div></div>\n\n" if !@$posts;

# Log action and finish
$m->logAction(2, 'report', 'list', $userId);
$m->printFooter();
$m->finish();
