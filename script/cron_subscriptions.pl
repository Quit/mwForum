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
Getopt::Std::getopts('sf:', \%opts);
my $spawned = $opts{s};
my $forumId = $opts{f};

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId, spawned => $spawned);
exit if !$cfg->{subsDigest};
$m->dbBegin();

# Shortcuts
my $baseUrl = $cfg->{baseUrl} . $cfg->{scriptUrlPath};

# Get boards
my $lastSentTime = $m->max($m->getVar('crnSubLst') || 0, $m->{now} - 86400 * 5);
my $boards = $m->fetchAllHash("
	SELECT * FROM boards WHERE lastPostTime > ?", $lastSentTime);
	
# Board subscriptions
for my $board (@$boards) {
	# Get posts
	my $posts = $m->fetchAllHash("
		SELECT posts.*, topics.subject
		FROM posts AS posts
			INNER JOIN topics AS topics
				ON topics.id = posts.topicId
		WHERE posts.postTime > :lastSentTime
			AND posts.boardId = :boardId
			AND posts.approved = 1
		ORDER BY posts.topicId, posts.postTime",
		{ lastSentTime => $lastSentTime, boardId => $board->{id} });
	next if !@$posts;
	$m->dbToEmail({}, $_) for @$posts;
	my $boardTitleDeesc = $m->deescHtml($board->{title});

	# Get subscribers
	my $subscribers = $m->fetchAllHash("
		SELECT boardSubscriptions.unsubAuth, users.*
		FROM boardSubscriptions AS boardSubscriptions
			INNER JOIN users AS users
				ON users.id = boardSubscriptions.userId
		WHERE boardSubscriptions.boardId = :boardId
			AND boardSubscriptions.instant = 0
			AND users.email <> ''
			AND users.dontEmail = 0",
		{ boardId => $board->{id} });
	next if !@$subscribers;
	
	# Send to subscribers if they still have board access
	for my $subscriber (@$subscribers) { 
		next if !$m->boardVisible($board, $subscriber);
		$lng = $m->setLanguage($subscriber->{language});
		my $subject = "$lng->{subSubjBrdDg}: $boardTitleDeesc";
		my $body = $lng->{subNoReply} . "\n\n" . "-" x 70 . "\n\n";
		for my $post (@$posts) {
			$body = $body
				. $lng->{subLink} . "$baseUrl/topic_show$m->{ext}?pid=$post->{id}\n"
				. $lng->{subBoard} . $boardTitleDeesc . "\n"
				. $lng->{subTopic} . $post->{subject} . "\n"
				. $lng->{subBy} . $post->{userNameBak} . "\n"
				. $lng->{subOn} . $m->formatTime($post->{postTime}, $subscriber->{timezone}) . "\n\n"
				. $post->{body} . "\n\n" 
				. ($post->{rawBody} ? $post->{rawBody} . "\n\n" : "")
				. "-" x 70 . "\n\n";
		}
		$body .= $lng->{subUnsubBrd} . "\n"
			. "$baseUrl/user_unsubscribe$m->{ext}?t=$subscriber->{unsubAuth}\n\n";
		$m->sendEmail(user => $subscriber, subject => $subject, body => $body);
	}
}

# Topic subscriptions
for my $board (@$boards) {
	# Get topics
	my $topics = $m->fetchAllHash("
		SELECT id, subject FROM topics WHERE lastPostTime > ? AND boardId = ?",
		$lastSentTime, $board->{id});
	
	# For each topic
	for my $topic (@$topics) {
		# Get posts
		my $posts = $m->fetchAllHash("
			SELECT *
			FROM posts
			WHERE postTime > :lastSentTime
				AND topicId = :topicId
				AND approved = 1
			ORDER BY postTime",
			{ lastSentTime => $lastSentTime, topicId => $topic->{id} });
		next if !@$posts;
		$m->dbToEmail({}, $_) for @$posts;
		my $boardTitleDeesc = $m->deescHtml($board->{title});
	
		# Get recipients
		my $subscribers = $m->fetchAllHash("
			SELECT topicSubscriptions.unsubAuth, users.*
			FROM topicSubscriptions AS topicSubscriptions
				INNER JOIN users AS users
					ON users.id = topicSubscriptions.userId
			WHERE topicSubscriptions.topicId = :topicId
				AND topicSubscriptions.instant = 0
				AND users.email <> ''
				AND users.dontEmail = 0",
			{ topicId => $topic->{id} });
		next if !@$subscribers;
	
		# Send to subscribers if they still have board access	
		for my $subscriber (@$subscribers) { 
			next if !$m->boardVisible($board, $subscriber);
			$lng = $m->setLanguage($subscriber->{language});
			my $subject = "$lng->{subSubjTpcDg}: $topic->{subject}";
			my $body = $lng->{subNoReply} . "\n\n" . "-" x 70 . "\n\n";
			for my $post (@$posts) {
				$body = $body
					. $lng->{subLink} . "$baseUrl/topic_show$m->{ext}?pid=$post->{id}\n"
					. $lng->{subBoard} . $boardTitleDeesc . "\n"
					. $lng->{subTopic} . $topic->{subject} . "\n"
					. $lng->{subBy} . $post->{userNameBak} . "\n"
					. $lng->{subOn} . $m->formatTime($post->{postTime}, $subscriber->{timezone}) . "\n\n"
					. $post->{body} . "\n\n" 
					. ($post->{rawBody} ? $post->{rawBody} . "\n\n" : "")
					. "-" x 70 . "\n\n";
			}
			$body .= $lng->{subUnsubTpc} . "\n"
				. "$baseUrl/user_unsubscribe$m->{ext}?t=$subscriber->{unsubAuth}\n\n";
			$m->sendEmail(user => $subscriber, subject => $subject, body => $body);
		}
	}
}

# Set last sent time
$m->setVar('crnSubLst', $m->{now}, 0);

# Log action and commit
$m->logAction(1, 'cron', 'subscr');
$m->dbCommit();
