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

# Print header
$m->printHeader();

# Get CGI parameters
my $topicId = $m->paramInt('tid');
$topicId or $m->error('errParamMiss');

# Get topic
my $topic = $m->fetchHash("
	SELECT * FROM topics WHERE id = ?", $topicId);
$topic or $m->error('errTpcNotFnd');
my $boardId = $topic->{boardId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $topic->{boardId});
$board or $m->error('errBrdNotFnd');

# Is board visible to user?
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId);
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');

# Print page bar
my @navLinks = ({ url => $m->url('topic_show', tid => $topicId), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => "Topic Info", subTitle => $topic->{subject},
	navLinks => \@navLinks);

# Print topic tag
if ($topic->{tag}) {
	my ($title) = $cfg->{topicTags}{$topic->{tag}} =~ /[\w.]+\s*(.*)?/;
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Tag</span></div>\n",
		"<div class='ccl'>\n",
		$m->formatTopicTag($topic->{tag}), " $title\n",
		"</div>\n",
		"</div>\n\n";
}

if ($user->{admin}) {
	# Get subscribers
	my $maxUserListNum = $cfg->{maxUserListNum} || 500;
	my $subscribers = $m->fetchAllArray("
		SELECT users.id, users.userName, topicSubscriptions.instant
		FROM topicSubscriptions AS topicSubscriptions
			INNER JOIN users AS users
				ON users.id = topicSubscriptions.userId
		WHERE topicSubscriptions.topicId = :topicId
		ORDER BY users.userName
		LIMIT :maxUserListNum",
		{ topicId => $topicId, maxUserListNum => $maxUserListNum });

	# Print subscribers
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Subscribers</span></div>\n",
		"<div class='ccl'>\n",
		join(",\n", map("<a href='" . $m->url('user_info', uid => $_->[0]) 
			. "' title='Instant: $_->[2]'>$_->[1]</a>", @$subscribers)) || " - ", "\n",
		"</div>\n",
		"</div>\n\n";
}

# Log action and finish
$m->logAction(3, 'topic', 'info', $userId, $boardId, $topicId);
$m->printFooter();
$m->finish();
