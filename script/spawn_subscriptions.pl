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
use Getopt::Std ();
use MwfMain;

#------------------------------------------------------------------------------

# Get arguments
my %opts = ();
Getopt::Std::getopts('f:p:', \%opts);
my $forumId = $opts{f};
my $postId = int($opts{p});

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId, spawn => 1);
exit if !$cfg->{subsInstant};
$m->dbBegin();

# Get post
my $post = $m->fetchHash("
	SELECT posts.*, topics.subject
	FROM posts AS posts
		INNER JOIN topics AS topics
			ON topics.id = posts.topicId
	WHERE posts.id = ?", 
	$postId);
$post or $m->error('errPstNotFnd');
my $topicId = $post->{topicId};
my $boardId = $post->{boardId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Compose email
$m->dbToEmail($board, $post);
my $timeStr = $m->formatTime($post->{postTime});
my $subjectBoard = "$cfg->{forumName} - \"$board->{title}\" $lng->{subSubjBrdIn}";
my $subjectTopic = "$cfg->{forumName} - \"$post->{subject}\" $lng->{subSubjTpcIn}";
my $body = $lng->{subNoReply} . "\n\n" 
	. "-" x 70 . "\n\n"
	. $lng->{subTopic} . $post->{subject} . "\n"
	. $lng->{subBy} . $post->{userNameBak} . "\n"
	. $lng->{subOn} . $timeStr . "\n\n"
	. $post->{body} . "\n\n"
	. ($post->{rawBody} ? $post->{rawBody} . "\n\n" : "")
	. "-" x 70 . "\n\n";

# Get board subscribers
my $boardSubscribers = $m->fetchAllHash("
	SELECT users.*
	FROM boardSubscriptions AS boardSubscriptions
		INNER JOIN users AS users 
			ON users.id = boardSubscriptions.userId
	WHERE boardSubscriptions.boardId = :boardId
		AND boardSubscriptions.instant = 1
		AND users.email <> ''
		AND users.dontEmail = 0",
	{ boardId => $boardId });

# Send to subscribers if they still have board access	
for my $subscriber (@$boardSubscribers) { 
	next if !$m->boardVisible($board, $subscriber);
	$m->sendEmail(user => $subscriber, subject => $subjectBoard, body => $body);
}

# Get topic subscribers
my $topicSubscribers = $m->fetchAllHash("
	SELECT users.*
	FROM topicSubscriptions AS topicSubscriptions
		INNER JOIN users AS users 
			ON users.id = topicSubscriptions.userId
	WHERE topicSubscriptions.topicId = :topicId
		AND topicSubscriptions.instant = 1
		AND users.email <> ''
		AND users.dontEmail = 0",
	{ topicId => $topicId });

# Send to topic subscribers if they still have board access	
for my $subscriber (@$topicSubscribers) { 
	next if !$m->boardVisible($board, $subscriber);
	$m->sendEmail(user => $subscriber, subject => $subjectTopic, body => $body);
}

# Log action and commit
$m->logAction(1, 'spawn', 'subscr');
$m->dbCommit();
