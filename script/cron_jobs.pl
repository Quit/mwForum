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
no warnings qw(uninitialized redefine once);

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
my $pfx = $cfg->{dbPrefix};

#------------------------------------------------------------------------------
# Begin one big transaction

$m->dbBegin();

#------------------------------------------------------------------------------
# Expire old topics

# Get boards	
my $boards = $m->fetchAllHash("
	SELECT id, expiration FROM boards WHERE expiration > 0");

# For each board
for my $board (@$boards) {
	# Get topics
	my $tmp = 'topicExpiration' . int(rand(2147483647));
	my $time = $m->{now} - $board->{expiration} * 86400;
	$m->dbDo("
		CREATE TEMPORARY TABLE $tmp AS
		SELECT id
		FROM topics 
		WHERE boardId = :boardId
			AND lastPostTime > 0
			AND lastPostTime < :time
			AND sticky = 0",
		{ boardId => $board->{id}, time => $time });
	my $topics = $m->fetchAllArray("
		SELECT id FROM $tmp");
		
	# Copy board, topics and posts to archive
	if ($cfg->{archiveExpired} && @$topics && !$m->{sqlite}) {
		# Delete old arc boards and insert current copies
		$m->dbDo("
			DELETE FROM arc_boards WHERE id = ?", $board->{id});
		$m->dbDo("
			INSERT INTO arc_boards 
			SELECT * FROM boards WHERE id = ?", $board->{id});
		
		# Deleting arc topics does nothing normally, but useful if job croaked in post query 
		# below because of inconsistent post table schemas
		$m->dbDo("
			DELETE FROM arc_topics WHERE id IN (SELECT id FROM $tmp)");
		$m->dbDo("
			INSERT INTO arc_topics
			SELECT * FROM topics WHERE id IN (SELECT id FROM $tmp)");

		# Copy posts to archive
		$m->dbDo("
			INSERT INTO arc_posts
			SELECT * FROM posts WHERE topicId IN (SELECT id FROM $tmp)");

		# Update stats in archive
		$m->dbDo("
			UPDATE arc_boards SET
				postNum = (
					SELECT SUM(postNum) 
					FROM arc_topics
					WHERE boardId = ${pfx}arc_boards.id),
				lastPostTime = (
					SELECT MAX(lastPostTime) 
					FROM arc_topics 
					WHERE boardId = ${pfx}arc_boards.id)");
	}

	$m->dbDo("
		DROP TABLE $tmp");

	# Delete topics
	$m->deleteTopic($_->[0]) for @$topics;
}

#------------------------------------------------------------------------------
# Lock old topics

# Get boards	
$boards = $m->fetchAllArray("
	SELECT id, locking FROM boards WHERE locking > 0");

# Lock topics
for my $board (@$boards) {
	my $time = $m->{now} - $board->[1] * 86400;
	$m->dbDo("
		UPDATE topics SET 
			locked = 1 
		WHERE boardId = :boardId
			AND lastPostTime < :time
			AND locked = 0
			AND sticky = 0",
		{ boardId => $board->[0], time => $time });
}

#------------------------------------------------------------------------------
# Lock huge, performance-killing topics

if ($cfg->{hugeTpcLocking}) {
	$m->dbDo("
		UPDATE topics SET locked = 1 WHERE locked = 0 AND postNum >= ?", $cfg->{hugeTpcLocking});
}

#------------------------------------------------------------------------------
# Lock polls in locked topics

if ($cfg->{polls} && $cfg->{pollLocking}) {
	# Get locked topics with unlocked polls
	my $topics = $m->fetchAllArray("
		SELECT pollId
		FROM topics AS topics
			INNER JOIN polls AS polls
				ON polls.id = topics.pollId
		WHERE topics.locked = 1
			AND polls.locked = 0");

	# For each topic
	for my $topic (@$topics) {
		# Consolidate votes
		my $voteSums = $m->fetchAllArray("
			SELECT optionId, COUNT(*) FROM pollVotes WHERE pollId = ? GROUP BY optionId", $topic->[0]);
		
		# Set option sums
		$m->dbDo("
			UPDATE pollOptions SET votes = ? WHERE id = ?", $_->[1], $_->[0])
			for @$voteSums;
		
		# Mark poll as locked
		$m->dbDo("
			UPDATE polls SET locked = 1 WHERE id = ?", $topic->[0]);
	
		# Delete individual votes
		$m->dbDo("
			DELETE FROM pollVotes WHERE pollId = ?", $topic->[0]);
	}
}

#------------------------------------------------------------------------------
# Lock polls after x days

if ($cfg->{polls} && $cfg->{pollLockTime}) {
	# Get topics with unlocked polls
	my $time = $m->{now} - $cfg->{pollLockTime} * 86400;
	my $topics = $m->fetchAllArray("
		SELECT pollId
		FROM topics AS topics
			INNER JOIN polls AS polls
				ON polls.id = topics.pollId
		WHERE polls.locked = 0
			AND topics.lastPostTime < ?",	$time);

	# For each topic
	for my $topic (@$topics) {
		# Consolidate votes
		my $voteSums = $m->fetchAllArray("
			SELECT optionId, COUNT(*) FROM pollVotes WHERE pollId = ? GROUP BY optionId", $topic->[0]);
		
		# Set option sums
		$m->dbDo("
			UPDATE pollOptions SET votes = ? WHERE id = ?", $_->[1], $_->[0])
			for @$voteSums;
		
		# Mark poll as locked
		$m->dbDo("
			UPDATE polls SET locked = 1 WHERE id = ?", $topic->[0]);
	
		# Delete individual votes
		$m->dbDo("
			DELETE FROM pollVotes WHERE pollId = ?", $topic->[0]);
	}
}

#------------------------------------------------------------------------------
# Recalc cached statistics

# Recalculate boards stats
$m->dbDo("
	UPDATE boards SET
		postNum = (
			SELECT COUNT(*) FROM posts WHERE boardId = ${pfx}boards.id),
		lastPostTime = COALESCE((
			SELECT MAX(postTime) FROM posts WHERE boardId = ${pfx}boards.id), 0)");

# Recalculate topics stats
$m->dbDo("
	UPDATE topics SET
		postNum = (
			SELECT COUNT(*) FROM posts WHERE topicId = ${pfx}topics.id),
		lastPostTime = COALESCE((
			SELECT MAX(postTime) FROM posts WHERE topicId = ${pfx}topics.id), 0)");

#------------------------------------------------------------------------------
# Expire users that haven't logged in for a while

if ($cfg->{userExpiration}) {
	my $havingStr = $cfg->{noUserPostsExp} ? "HAVING COUNT(posts.id) = 0" : "";
	my $time = $m->{now} - $cfg->{userExpiration} * 86400;
	my $users = $m->fetchAllArray("
		SELECT users.id
		FROM users AS users
			LEFT JOIN posts AS posts
				ON posts.userId = users.id
		WHERE users.admin = 0
			AND users.lastOnTime < :time
			AND users.regTime < :time
		GROUP BY users.id
		$havingStr", 
		{ time => $time });
	$m->deleteUser($_->[0]) for @$users;
}

#------------------------------------------------------------------------------
# Expire users that have never logged in

if ($cfg->{acctExpiration}) {
	my $time = $m->{now} - $cfg->{acctExpiration} * 86400;
	my $users = $m->fetchAllArray("
		SELECT id FROM users WHERE regTime = lastOnTime AND regTime < ?", $time);
	$m->deleteUser($_->[0]) for @$users;
}

#------------------------------------------------------------------------------
# Expire non-vital user data

if ($cfg->{userDataExp}) {
	my $time = $m->{now} - $cfg->{userDataExp} * 86400;
	my $tmp = 'userDataExpiration' . int(rand(2147483647));
	$m->dbDo("
		CREATE TEMPORARY TABLE $tmp AS
		SELECT id FROM users WHERE lastOnTime < ?", $time);
	$m->dbDo("
		UPDATE users SET birthyear = 0, birthday = '' WHERE id IN (SELECT id FROM $tmp)");
	$m->dbDo("
		DELETE FROM boardSubscriptions WHERE userId IN (SELECT id FROM $tmp)");
	$m->dbDo("
		DELETE FROM topicSubscriptions WHERE userId IN (SELECT id FROM $tmp)");
	$m->dbDo("
		DELETE FROM userIgnores WHERE userId IN (SELECT id FROM $tmp)");
	$m->dbDo("
		DELETE FROM userIgnores WHERE ignoredId IN (SELECT id FROM $tmp)");
	$m->dbDo("
		DELETE FROM watchWords WHERE userId IN (SELECT id FROM $tmp)");
	$m->dbDo("
		DELETE FROM watchUsers WHERE userId IN (SELECT id FROM $tmp)");
	$m->dbDo("
		DELETE FROM userVariables WHERE userId IN (SELECT id FROM $tmp)");
	$m->dbDo("
		DROP TABLE $tmp");
}

#------------------------------------------------------------------------------
# Expire IP addresses

if ($cfg->{ipExpiration}) {
	my $time = $m->{now} - $cfg->{ipExpiration} * 86400;
	$m->dbDo("
		UPDATE users SET lastIp = '' WHERE lastIp <> '' AND lastOnTime < ? AND regTime < ?",
		$time, $time);
	$m->dbDo("
		UPDATE posts SET ip = '' WHERE ip <> '' AND postTime < ? AND editTime < ?",
		$time, $time);
}

#------------------------------------------------------------------------------
# Expire user bans

$m->dbDo("
	DELETE FROM userBans WHERE duration > 0 AND banTime < ? - duration * 86400", $m->{now});

#------------------------------------------------------------------------------
# Expire topic read times

if ($cfg->{maxUnreadDays}) {
	my $time = $m->{now} - $cfg->{maxUnreadDays} * 86400;
	$m->dbDo("
		DELETE FROM topicReadTimes WHERE lastReadTime < ?", $time);
}

#------------------------------------------------------------------------------
# Expire chat messages (also happens in chat_add)

if ($cfg->{chatMaxAge}) {
	my $time = $m->{now} - $cfg->{chatMaxAge} * 86400;
	$m->dbDo("
		DELETE FROM chat WHERE postTime < ?",	$time);
}

#------------------------------------------------------------------------------
# Expire private messages

if ($cfg->{msgExpiration}) {
	my $time = $m->{now} - $cfg->{msgExpiration} * 86400;
	$m->dbDo("
		DELETE FROM messages WHERE sendTime < ?", $time);
}

#------------------------------------------------------------------------------
# Expire notification messages

$m->dbDo("
	DELETE FROM notes WHERE sendTime < ? - 21 * 86400", $m->{now});

#------------------------------------------------------------------------------
# Expire tickets

$m->dbDo("
	DELETE FROM tickets WHERE issueTime < ? - 3 * 86400", $m->{now});

#------------------------------------------------------------------------------
# Change request source authentication values

my $rndStr = undef;
if ($m->{mysql}) { $rndStr = "FLOOR(RAND() * 2147483647)" }
elsif ($m->{pgsql}) { $rndStr = "FLOOR(RANDOM() * 2147483647)" }
elsif ($m->{sqlite}) { $rndStr = "RANDOM() & 2147483647" }
$m->dbDo("
	UPDATE users SET sourceAuth2 = sourceAuth");
$m->dbDo("
	UPDATE users SET sourceAuth = $rndStr");

#------------------------------------------------------------------------------
# Decrease users.bounceNum and reset countermeasures

if ($cfg->{bounceTrshWarn} || $cfg->{bounceTrshCncl} || $cfg->{bounceTrshDsbl}) {
	my $bounceFactor = $cfg->{bounceFactor} || 3;
	my $dsblTrsh = $cfg->{bounceTrshDsbl} * $bounceFactor;

	# Decrease bounceNum	
	$m->dbDo("
		UPDATE users SET bounceNum = bounceNum - 1 WHERE bounceNum > 0");

	# Reset users.dontEmail if disable threshold is used
	$m->dbDo("
		UPDATE users SET dontEmail = 0 WHERE bounceNum < ?", $dsblTrsh) 
		if $dsblTrsh;
}

#------------------------------------------------------------------------------
# Store finish time and duration

$m->setVar('crnJobLst', $m->{now});
$m->setVar('crnJobDur', time() - $m->{now});

#------------------------------------------------------------------------------
# End big transaction

$m->dbCommit();

#------------------------------------------------------------------------------
# Call local script

system $^X, "cron_jobs_local$m->{ext}", $m->{forumId} ? ("-f" => $m->{forumId}) : ()
	if -f "cron_jobs_local$m->{ext}";

#------------------------------------------------------------------------------
# Optimize tables (except logs)

my @tables = grep(!/^log/, @MwfDefaults::tables);

if ($m->{mysql}) {
	$m->dbDo("OPTIMIZE TABLE $pfx$_") for @tables;
}
elsif ($m->{pgsql}) {
	$m->dbDo("VACUUM ANALYZE $pfx$_") for @tables;
}	
elsif ($m->{sqlite}) {
	$m->dbDo("VACUUM");
	$m->dbDo("ANALYZE");
}	

#------------------------------------------------------------------------------
# Log action

$m->logAction(1, 'cron', 'exec');
