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
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
use MwfMain;

#------------------------------------------------------------------------------

# Get arguments
my %opts = ();
Getopt::Std::getopts('sf:p:', \%opts);
my $spawned = $opts{s};
my $forumId = $opts{f};
my $postId = int($opts{p});

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId, spawned => $spawned);
exit if !$cfg->{subsInstant};
$m->dbBegin();

# Shortcuts
my $baseUrl = $cfg->{baseUrl} . $cfg->{scriptUrlPath};

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
$m->dbToEmail({}, $post);

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');
my $boardTitleDeesc = $m->deescHtml($board->{title});

# Get board subscribers
my $boardSubscribers = $m->fetchAllHash("
	SELECT boardSubscriptions.unsubAuth, users.*
	FROM boardSubscriptions AS boardSubscriptions
		INNER JOIN users AS users 
			ON users.id = boardSubscriptions.userId
	WHERE boardSubscriptions.boardId = :boardId
		AND boardSubscriptions.instant = 1
		AND users.email <> ''
		AND users.dontEmail = 0",
	{ boardId => $boardId });

# Send to board subscribers if they still have board access	
for my $subscriber (@$boardSubscribers) { 
	next if !$m->boardVisible($board, $subscriber);
	$lng = $m->setLanguage($subscriber->{language});
	my $subject = "$lng->{subSubjBrdIn}: $boardTitleDeesc";
	my $body = $lng->{subNoReply} . "\n\n" . "-" x 70 . "\n\n"
		. $lng->{subLink} . "$baseUrl/topic_show$m->{ext}?pid=$post->{id}\n"
		. $lng->{subBoard} . $boardTitleDeesc . "\n"
		. $lng->{subTopic} . $post->{subject} . "\n"
		. $lng->{subBy} . $post->{userNameBak} . "\n"
		. $lng->{subOn} . $m->formatTime($post->{postTime}, $subscriber->{timezone}) . "\n\n"
		. $post->{body} . "\n\n"
		. ($post->{rawBody} ? $post->{rawBody} . "\n\n" : "")
		. "-" x 70 . "\n\n"
		. $lng->{subUnsubBrd} . "\n"
		. "$baseUrl/user_unsubscribe$m->{ext}?t=$subscriber->{unsubAuth}\n\n";
	$m->sendEmail(user => $subscriber, subject => $subject, body => $body);
}

# Get topic subscribers
my $topicSubscribers = $m->fetchAllHash("
	SELECT topicSubscriptions.unsubAuth, users.*
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
	$lng = $m->setLanguage($subscriber->{language});
	my $subject = "$lng->{subSubjTpcIn}: $post->{subject}";
	my $body = $lng->{subNoReply} . "\n\n" . "-" x 70 . "\n\n"
		. $lng->{subLink} . "$baseUrl/topic_show$m->{ext}?pid=$post->{id}\n"
		. $lng->{subBoard} . $boardTitleDeesc . "\n"
		. $lng->{subTopic} . $post->{subject} . "\n"
		. $lng->{subBy} . $post->{userNameBak} . "\n"
		. $lng->{subOn} . $m->formatTime($post->{postTime}, $subscriber->{timezone}) . "\n\n"
		. $post->{body} . "\n\n"
		. ($post->{rawBody} ? $post->{rawBody} . "\n\n" : "")
		. "-" x 70 . "\n\n"
		. $lng->{subUnsubTpc} . "\n"
		. "$baseUrl/user_unsubscribe$m->{ext}?t=$subscriber->{unsubAuth}\n\n";
	$m->sendEmail(user => $subscriber, subject => $subject, body => $body);
}

# Log action and commit
$m->logAction(1, 'spawn', 'subscr');
$m->dbCommit();
