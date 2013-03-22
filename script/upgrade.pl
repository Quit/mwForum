#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2013 Markus Wichitill
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
no warnings qw(uninitialized once);

# Imports
use Getopt::Std ();
require MwfMain;

#------------------------------------------------------------------------------

# Get arguments
my %opts = ();
Getopt::Std::getopts('isf:o:', \%opts);
my $spawned = $opts{s};
my $forumId = $opts{f};
my $citext = $opts{i};
my $oldVersionParam = $opts{o};

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId, spawned => $spawned, upgrade => 1);
my $dbh = $m->{dbh};
my $pfx = $cfg->{dbPrefix};
my $output = "";
$| = 1;
output("mwForum upgrade running...\n");

# Don't try to wrap whole script in transaction for PgSQL/SQLite,
# as some DROP stuff will normally fail, and would rollback everything.

# Determine old version 
my $newVersion = undef;
my $oldVersionDb = $m->fetchArray("
	SELECT value FROM variables WHERE name = ?", 'version');
my $oldVersion = $oldVersionParam || $oldVersionDb;
if (!$oldVersion) {
	output( 
		"\nError: no database entry containing previous version number found.\n",
		"This is normal if you are upgrading from before 2.3.2.\n",
		"It can also be the result of a bug in 2.17.3 to 2.20.0.\n",
		"Please specify your previous version manually by starting this script\n",
		"again with an additional parameter of \"-o x.y.z\" (e.g.\n",
		"\"perl upgrade.pl -o 2.18.0\" if your old version was 2.18.0).\n\n",
		"mwForum upgrade cancelled.\n");
	exit 1;
}
my $oldVersionDec = tripletToDecimal($oldVersion);
output("Previous database schema version: $oldVersion\n");

#------------------------------------------------------------------------------
# Print and collect output

sub output
{
	my $text = shift();

	print $text;
	$output .= $text;
	$m->dbDo("
		DELETE FROM variables WHERE name = ?", 'upgOutput');
	$m->dbDo("
		INSERT INTO variables (name, value) VALUES (?, ?)", 'upgOutput', $output);
}

#------------------------------------------------------------------------------
# Convert "1.2.3" string into number

sub tripletToDecimal
{
	my $triplet = shift();

	my ($a,$b,$c) = split(/\./, $triplet);
	return $a*1000000 + $b*1000 + $c;
}

#------------------------------------------------------------------------------
# Modify SQL as necessary and execute as separate queries

sub upgradeSchema
{
	my $sql = shift();
	my $ignoreError = shift() || 0;

	# Add prefix to table names
	if ($pfx) {
		$sql =~ s! ON ! ON $pfx!g;
		$sql =~ s! FROM ! FROM $pfx!g;
		$sql =~ s! JOIN ! JOIN $pfx!g;
		$sql =~ s! INTO ! INTO $pfx!g;
		$sql =~ s! TABLE ! TABLE $pfx!g;
		$sql =~ s! RENAME TO ! RENAME TO $pfx!g;
		$sql =~ s!UPDATE !UPDATE $pfx!g;
	}
	
	# Make SQL compatible with chosen DBMS
	if ($m->{mysql}) {
		my $tableOpt = $cfg->{dbTableOpt} || "CHARSET=utf8";
		$sql =~ s! TABLEOPT! $tableOpt!g;
		$sql =~ s! TEXT ! MEDIUMTEXT !g;
	}
	elsif ($m->{pgsql} || $m->{sqlite}) {
		$sql =~ s! TABLEOPT! $cfg->{dbTableOpt}!g;
		$sql =~ s! FIRST;!;!g;
		$sql =~ s! AFTER \w+!!g;
		$sql =~ s!(DROP INDEX \w+) ON \w+!$1!g;

		if ($m->{pgsql}) {
			$citext ||= $cfg->{dbCitext};
			$sql =~ s! INT PRIMARY KEY AUTO_INCREMENT! SERIAL PRIMARY KEY!g;
			$sql =~ s! TINYINT! SMALLINT!g;
			$sql =~ s! VARCHAR\((\d+)\)| TEXT! citext!g if $citext && $1 != 22;
		}
		elsif ($m->{sqlite}) {
			$sql =~ s! AUTO_INCREMENT! AUTOINCREMENT!g;
			$sql =~ s! INT ! INTEGER !g;
			$sql =~ s!ALTER TABLE \w+ DROP \w+;!!g;
		}
	}

	# Execute separate queries
	for (grep(/\w/, split(";", $sql))) {
		my $rv = $dbh->do($_);
		output("Error: $DBI::errstr\n") if !$rv && !$ignoreError;
	}
}

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

$newVersion = "2.3.2";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE boards ADD attach TINYINT NOT NULL DEFAULT 0 AFTER flat;
		ALTER TABLE messages ADD inbox TINYINT NOT NULL DEFAULT 0 AFTER box;
		ALTER TABLE messages ADD sentbox TINYINT NOT NULL DEFAULT 0 AFTER inbox;
		UPDATE messages SET inbox = 1 WHERE box = 0;
		UPDATE messages SET sentbox = 1 WHERE box = 1;
		ALTER TABLE messages DROP box;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.5.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE posts DROP signature;
		ALTER TABLE boards DROP markup;
		ALTER TABLE posts DROP score;
		ALTER TABLE boards DROP score;
		ALTER TABLE users DROP votesLeft;
		ALTER TABLE users DROP votesDaily;
		ALTER TABLE users DROP threshold;
		ALTER TABLE users DROP baseScore;
		ALTER TABLE users ADD birthyear SMALLINT NOT NULL DEFAULT 0 AFTER extra3;
		ALTER TABLE users ADD birthday VARCHAR(5) NOT NULL DEFAULT '' AFTER birthyear;
		CREATE TABLE sessions (
			id           CHAR(32) PRIMARY KEY,
			userId       INT NOT NULL DEFAULT 0,
			lastOnTime   INT NOT NULL DEFAULT 0,
			ip           CHAR(15) NOT NULL DEFAULT ''
		) TABLEOPT;
	");
	output("$newVersion: done.\n");

	# Statically markup/highlight quotes
	output("$newVersion: statically highlighting quotes...\n");
	my $changeSum = 0;
	$m->dbBegin();
	my $selSth = $m->fetchSth("
		SELECT id, body FROM posts");
	my ($postId, $body);
	$selSth->bind_columns(\($postId, $body));
	my $updSth = $m->dbPrepare("
		UPDATE posts SET body = ? WHERE id = ?");
	while ($selSth->fetch()) {
		my $changeNum = $body =~
			s~(^|<br/>)((?:&gt;).*?)(?=(?:<br/>)+(?!&gt;)|$)~$1<blockquote>$2</blockquote>~g;
		$body =~ s~</blockquote>(?:<br/>){2,}~</blockquote><br/>~g;
		if ($changeNum) {
			$m->dbExecute($updSth, $body, $postId);
			$changeSum += $changeNum;
		}
	}
	$m->dbCommit();
	output("$newVersion: done ($changeSum).\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.5.1";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		CREATE TABLE groups (
			id           INT PRIMARY KEY AUTO_INCREMENT,
			title        VARCHAR(255) NOT NULL DEFAULT ''
		) TABLEOPT;
		CREATE TABLE groupMembers (
			userId       INT NOT NULL DEFAULT 0,
			groupId      INT NOT NULL DEFAULT 0,
			PRIMARY KEY (userId, groupId)
		) TABLEOPT;
		CREATE TABLE boardMemberGroups (
			groupId      INT NOT NULL DEFAULT 0,
			boardId      INT NOT NULL DEFAULT 0,
			PRIMARY KEY (groupId, boardId)
		) TABLEOPT;
		CREATE TABLE boardAdminGroups (
			groupId      INT NOT NULL DEFAULT 0,
			boardId      INT NOT NULL DEFAULT 0,
			PRIMARY KEY (groupId, boardId)
		) TABLEOPT;
		ALTER TABLE users ADD showImages TINYINT NOT NULL DEFAULT 0 AFTER showAvatars;
		UPDATE users SET showImages = 1;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.7.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		UPDATE users SET timezone = '0';
		UPDATE config SET value = '0' WHERE name = 'userTimezone';
	");
	output("$newVersion: done.\n");

	# Fix blockquotes to conform to standard, they need a block inside
	output("$newVersion: fixing blockquotes...\n");
	my $changeSum = 0;
	$m->dbBegin();
	my $selSth = $m->fetchSth("
		SELECT id, body FROM posts");
	my ($postId, $body);
	$selSth->bind_columns(\($postId, $body));
	my $updSth = $m->dbPrepare("
		UPDATE posts SET body = ? WHERE id = ?");
	while ($selSth->fetch()) {
		my $changeNum = $body =~
			s~<blockquote>(?!<p>)(.*?)</blockquote>~<blockquote><p>$1</p></blockquote>~g;
		if ($changeNum) {
			$m->dbExecute($updSth, $body, $postId);
			$changeSum += $changeNum;
		}
	}
	$m->dbCommit();
	output("$newVersion: done ($changeSum).\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.7.2";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE topics ADD tag      VARCHAR(20) NOT NULL DEFAULT '' AFTER subject;
		ALTER TABLE users  ADD showDeco TINYINT NOT NULL DEFAULT 0 AFTER boardDescs;
		UPDATE users SET showDeco = 1;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.9.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		CREATE TABLE topicSubscriptions (
			userId       INT NOT NULL DEFAULT 0,
			topicId      INT NOT NULL DEFAULT 0,
			PRIMARY KEY (userId, topicId)
		) TABLEOPT;
		CREATE TABLE notes (
			id           INT PRIMARY KEY AUTO_INCREMENT,
			userId       INT NOT NULL DEFAULT 0,
			sendTime     INT NOT NULL DEFAULT 0,
			body         TEXT NOT NULL DEFAULT ''
		) TABLEOPT;
		CREATE INDEX notes_userId ON notes (userId);
		ALTER TABLE users DROP adminMsg;
		ALTER TABLE posts DROP notify;
		UPDATE users SET notify = 1;
		UPDATE users SET msgNotify = 0;
		UPDATE config SET value = '1' WHERE name = 'notify';
		UPDATE config SET value = '0' WHERE name = 'msgNotify';
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.9.2";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		CREATE TABLE attachments (
			id           INT PRIMARY KEY AUTO_INCREMENT,
			postId       INT NOT NULL DEFAULT 0,
			webImage     TINYINT NOT NULL DEFAULT 0,
			fileName     VARCHAR(255) NOT NULL DEFAULT ''
		) TABLEOPT;
		DELETE FROM tickets WHERE type = 'cptcha';
	");
	output("$newVersion: done.\n");
	
	# Move attachments to their own table
	output("$newVersion: moving attachment entries to their own table...\n");
	my $changeSum = 0;
	$m->dbBegin();
	my $selSth = $m->fetchSth("
		SELECT id, attach, attachEmbed FROM posts WHERE attach <> '' ORDER BY id");
	my ($postId, $fileName, $embed);
	$selSth->bind_columns(\($postId, $fileName, $embed));
	my $insSth = $m->dbPrepare("
		INSERT INTO attachments (postId, webImage, fileName) VALUES (?, ?, ?)");
	while ($selSth->fetch()) {
		my $webImage = $fileName =~ /\.(?:jpg|png|gif)\z/i ? 1 : 0;
		$webImage = 2 if $embed && $webImage;
		$m->dbExecute($insSth, $postId, $webImage, $fileName);
		$changeSum++;
	}
	$m->dbCommit();
	output("$newVersion: done ($changeSum).\n");

	output("$newVersion: upgrading database schema, part 2...\n");
	upgradeSchema("
		ALTER TABLE posts DROP attach;
		ALTER TABLE posts DROP attachEmbed;
		CREATE INDEX attachments_postId ON attachments (postId);
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.11.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE boards ADD list TINYINT NOT NULL DEFAULT 0 AFTER private;
		CREATE INDEX messages_senderId ON messages (senderId);
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.11.1";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		DROP INDEX email ON users;
		DROP INDEX users_email ON users;
	", 1);
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.13.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE users ADD openId VARCHAR(255) NOT NULL DEFAULT '' AFTER email;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.13.1";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE users DROP manOldMark;
		DROP TABLE postTodos;
		ALTER TABLE boards ADD rate TINYINT NOT NULL DEFAULT 0 AFTER attach;
		ALTER TABLE posts ADD rating SMALLINT NOT NULL DEFAULT 0 AFTER approved;
		ALTER TABLE users ADD postRating SMALLINT NOT NULL DEFAULT 0 AFTER postNum;
		CREATE TABLE postRatings (
			postId       INT NOT NULL DEFAULT 0,
			userId       INT NOT NULL DEFAULT 0,
			rating       TINYINT NOT NULL DEFAULT 0,
			PRIMARY KEY (postId, userId)
		) TABLEOPT;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.13.2";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	# Get rid of useless indices that have only been removed from
	# install.pl (.sql) before, but not existing installations (I think).
	# Also parentId is mostly useless, even misleading, since mostly 0 is looked up.
	upgradeSchema("
		DROP INDEX boardId ON topics;
		DROP INDEX topics_boardId ON topics;
		DROP INDEX boardId ON posts;
		DROP INDEX posts_boardId ON posts;
		DROP INDEX parentId ON posts;
		DROP INDEX posts_parentId ON posts;
	", 1);
	upgradeSchema("
		CREATE TABLE watchWords (
			userId       INT NOT NULL DEFAULT 0,
			word         VARCHAR(30) NOT NULL DEFAULT ''
		) TABLEOPT;
		CREATE TABLE watchUsers (
			userId       INT NOT NULL DEFAULT 0,
			watchedId    INT NOT NULL DEFAULT 0
		) TABLEOPT;
		CREATE INDEX watchUsers_watchedId ON watchUsers (watchedId);
		ALTER TABLE groups ADD public TINYINT NOT NULL DEFAULT 0;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.15.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	if ($m->{mysql}) {
		my $stat = $m->fetchHash("
			SHOW TABLE STATUS LIKE '${pfx}posts'");
		if ($stat->{Collation} !~ /utf8/) {
			my $dupes = $m->fetchAllArray("
				SELECT DISTINCT u1.id, u1.userName
				FROM users AS u1
					INNER JOIN users AS u2
				WHERE u1.id <> u2.id 
					AND CONVERT(u1.userName USING utf8) = CONVERT(u2.userName USING utf8)");
			for my $dupe (@$dupes) {
				$m->dbDo("
					UPDATE users SET userName = CONCAT(userName, ?) WHERE id = ?",
					" ($dupe->[0])", $dupe->[0]);
				output("WARNING: renamed user '$dupe->[1]' to '$dupe->[1] ($dupe->[0])'\n");
			}
			upgradeSchema("
				ALTER TABLE log CONVERT TO CHARSET ascii;
				ALTER TABLE sessions CONVERT TO CHARSET ascii;
				ALTER TABLE attachments CONVERT TO CHARSET utf8;
				ALTER TABLE boardAdminGroups CONVERT TO CHARSET utf8;
				ALTER TABLE boardAdmins CONVERT TO CHARSET utf8;
				ALTER TABLE boardHiddenFlags CONVERT TO CHARSET utf8;
				ALTER TABLE boardMemberGroups CONVERT TO CHARSET utf8;
				ALTER TABLE boardMembers CONVERT TO CHARSET utf8;
				ALTER TABLE boards CONVERT TO CHARSET utf8;
				ALTER TABLE boardSubscriptions CONVERT TO CHARSET utf8;
				ALTER TABLE categories CONVERT TO CHARSET utf8;
				ALTER TABLE chat CONVERT TO CHARSET utf8;
				ALTER TABLE config CONVERT TO CHARSET utf8;
				ALTER TABLE groupMembers CONVERT TO CHARSET utf8;
				ALTER TABLE groups CONVERT TO CHARSET utf8;
				ALTER TABLE logStrings CONVERT TO CHARSET utf8;
				ALTER TABLE messages CONVERT TO CHARSET utf8;
				ALTER TABLE notes CONVERT TO CHARSET utf8;
				ALTER TABLE pollOptions CONVERT TO CHARSET utf8;
				ALTER TABLE polls CONVERT TO CHARSET utf8;
				ALTER TABLE pollVotes CONVERT TO CHARSET utf8;
				ALTER TABLE postReports CONVERT TO CHARSET utf8;
				ALTER TABLE postRatings CONVERT TO CHARSET utf8;
				ALTER TABLE posts CONVERT TO CHARSET utf8;
				ALTER TABLE tickets CONVERT TO CHARSET utf8;
				ALTER TABLE topicReadTimes CONVERT TO CHARSET utf8;
				ALTER TABLE topics CONVERT TO CHARSET utf8;
				ALTER TABLE topicSubscriptions CONVERT TO CHARSET utf8;
				ALTER TABLE userBans CONVERT TO CHARSET utf8;
				ALTER TABLE userIgnores CONVERT TO CHARSET utf8;
				ALTER TABLE users CONVERT TO CHARSET utf8;
				ALTER TABLE variables CONVERT TO CHARSET utf8;
				ALTER TABLE watchUsers CONVERT TO CHARSET utf8;
				ALTER TABLE watchWords CONVERT TO CHARSET utf8;
			");
		}
	}
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.15.1";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	if ($m->{mysql}) {
		upgradeSchema("
			CREATE TABLE arc_boards LIKE ${pfx}boards;
			CREATE TABLE arc_topics LIKE ${pfx}topics;
			CREATE TABLE arc_posts  LIKE ${pfx}posts;
		");
	}
	elsif ($m->{pgsql}) {
		my ($version) = $m->fetchArray("SELECT VERSION()") =~ /PostgreSQL (\d+\.\d+)/;
		my $indexes = $version >= 8.3 ? "INCLUDING INDEXES" : "";
		upgradeSchema("
			CREATE TABLE arc_boards (LIKE ${pfx}boards $indexes INCLUDING DEFAULTS);
			CREATE TABLE arc_topics (LIKE ${pfx}topics $indexes INCLUDING DEFAULTS);
			CREATE TABLE arc_posts  (LIKE ${pfx}posts  $indexes INCLUDING DEFAULTS);
		");
	}
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.16.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE users ADD renamesLeft TINYINT NOT NULL DEFAULT 0;
		ALTER TABLE users ADD oldNames TEXT NOT NULL DEFAULT '';
		ALTER TABLE notes ADD type VARCHAR(6) NOT NULL DEFAULT '' AFTER sendTime;
		ALTER TABLE boards DROP anonymous;
	");
	if ($m->{mysql} || $m->{pgsql}) {
		upgradeSchema("
			ALTER TABLE arc_boards DROP anonymous;
		");
	}
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.17.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE users ADD comment TEXT NOT NULL DEFAULT '';
		ALTER TABLE groups ADD badge VARCHAR(20) NOT NULL DEFAULT '' AFTER title;
		CREATE TABLE userBadges (
			userId       INT NOT NULL DEFAULT 0,
			badge        VARCHAR(20) NOT NULL DEFAULT 0,
			PRIMARY KEY (userId, badge)
		) TABLEOPT;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.17.1";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		DROP TABLE boardAdmins;
		DROP TABLE boardMembers;
		ALTER TABLE groups ADD open TINYINT NOT NULL DEFAULT 0;
		CREATE TABLE groupAdmins (
			userId       INT NOT NULL DEFAULT 0,
			groupId      INT NOT NULL DEFAULT 0,
			PRIMARY KEY (userId, groupId)
		) TABLEOPT;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.17.2";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE posts ADD locked TINYINT NOT NULL DEFAULT 0 AFTER approved;
		ALTER TABLE boards ADD topicAdmins TINYINT NOT NULL DEFAULT 0 AFTER locking;
	");
	if ($m->{mysql} || $m->{pgsql}) {
		upgradeSchema("
			ALTER TABLE arc_posts ADD locked TINYINT NOT NULL DEFAULT 0 AFTER approved;
			ALTER TABLE arc_boards ADD topicAdmins TINYINT NOT NULL DEFAULT 0 AFTER locking;
		");
	}

	# Move blog topics to new board
	my $blogsExist = $m->fetchArray("
		SELECT 1 FROM topics WHERE boardId < 0 LIMIT 1");
	if ($blogsExist) {
		$m->dbBegin();
		output("$newVersion: moving former blog topics to new board...\n");
		my $firstCatId = $m->fetchArray("
			SELECT MIN(id) FROM categories");
		my $pos = $m->fetchArray("
			SELECT MAX(pos) + 1 FROM boards WHERE categoryId = ?", $firstCatId);
		$pos ||= 1;
		my $private = $cfg->{blogs} == 2 ? 2 : 0;
		$m->dbDo("
			INSERT INTO boards (title, categoryId, pos, private, topicAdmins) 
			VALUES (?, ?, ?, ?, ?)", 
			'Blogs', $firstCatId, $pos, $private, 1);
		my $boardId = $m->dbInsertId('boards');
		$m->dbDo("
			UPDATE topics SET boardId = ? WHERE boardId < 0", $boardId);
		$m->dbDo("
			UPDATE posts SET boardId = ? WHERE boardId < 0", $boardId);
		$m->recalcStats($boardId);
		$m->dbCommit();
	}
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.19.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE users DROP gpgCompat;
		ALTER TABLE users ADD blurb TEXT NOT NULL DEFAULT '' AFTER signature;
		ALTER TABLE attachments ADD caption VARCHAR(255) NOT NULL DEFAULT '';
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.19.2";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE users DROP postRating;
		ALTER TABLE boards DROP rate;
		ALTER TABLE posts DROP rating;
		DROP TABLE postRatings;
	");
	if ($m->{mysql} || $m->{pgsql}) {
		upgradeSchema("
			ALTER TABLE arc_boards DROP rate;
			ALTER TABLE arc_posts DROP rating;
		");
	}
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.19.3";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE boardSubscriptions ADD instant TINYINT NOT NULL DEFAULT 0;
		ALTER TABLE topicSubscriptions ADD instant TINYINT NOT NULL DEFAULT 0;
	");
	output("$newVersion: updating includePlg forum option...\n");
	$m->dbDo("
		UPDATE config SET parse = 'arrayhash' WHERE name = 'includePlg'");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.21.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE users DROP secureLogin;
		CREATE TABLE userVariables (
			userId       INT NOT NULL DEFAULT 0,
			name         VARCHAR(10) NOT NULL DEFAULT '',
			value        TEXT NOT NULL DEFAULT '',
			PRIMARY KEY (userId, name)
		) TABLEOPT;
		ALTER TABLE variables RENAME TO variables_old;
		CREATE TABLE variables (
			name         VARCHAR(10) PRIMARY KEY,
			value        TEXT NOT NULL DEFAULT ''
		) TABLEOPT;
		INSERT INTO userVariables SELECT userId, name, value FROM variables_old WHERE userId <> 0;
		INSERT INTO variables SELECT name, value FROM variables_old WHERE userId = 0;
		DROP TABLE variables_old;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.21.1";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: updating msgDisplayPlg forum option...\n");
	$m->dbDo("
		UPDATE config SET parse = 'array' WHERE name = 'msgDisplayPlg'");

	# Replace <tt> with <code> for HTML5
	output("$newVersion: replacing <tt> with <code> for HTML5-compat...\n");
	my $changeSum = 0;
	my @fields = (
		['posts', 'body'], ['messages', 'body'], ['users', 'signature'], ['users', 'blurb']);
	for my $field (@fields) {
		$m->dbBegin();
		my $table = $field->[0];
		my $column = $field->[1];
		my $selSth = $m->fetchSth("
			SELECT id, $column FROM $table");
		my ($id, $text);
		$selSth->bind_columns(\($id, $text));
		my $updSth = $m->dbPrepare("
			UPDATE $table SET $column = ? WHERE id = ?");
		while ($selSth->fetch()) {
			my $changeNum = $text =~ s!<tt>!<code>!g;
			$changeNum += $text =~ s!</tt>!</code>!g;
			if ($changeNum) {
				$m->dbExecute($updSth, $text, $id);
				$changeSum += $changeNum;
			}
		}
		$m->dbCommit();
	}
	output("$newVersion: done ($changeSum).\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.21.2";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE posts ADD rawBody TEXT NOT NULL DEFAULT '';
	");
	if ($m->{mysql} || $m->{pgsql}) {
		upgradeSchema("
			ALTER TABLE arc_posts ADD rawBody TEXT NOT NULL DEFAULT '';
		");
	}
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.21.3";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE boardHiddenFlags ADD manual TINYINT NOT NULL DEFAULT 0;
		UPDATE boardHiddenFlags SET manual = 1;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.23.0";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	if ($m->{pgsql}) {
		upgradeSchema("
			ALTER TABLE users ALTER lastIp TYPE VARCHAR(39);
			ALTER TABLE posts ALTER ip TYPE VARCHAR(39);
			ALTER TABLE arc_posts ALTER ip TYPE VARCHAR(39);
			ALTER TABLE log ALTER ip TYPE VARCHAR(39);
			ALTER TABLE sessions ALTER ip TYPE VARCHAR(39);
		");
	}
	elsif ($m->{mysql}) {
		upgradeSchema("
			ALTER TABLE users MODIFY lastIp VARCHAR(39) NOT NULL DEFAULT '';
			ALTER TABLE posts MODIFY ip VARCHAR(39) NOT NULL DEFAULT '';
			ALTER TABLE arc_posts MODIFY ip VARCHAR(39) NOT NULL DEFAULT '';
			ALTER TABLE log MODIFY ip VARCHAR(39) NOT NULL DEFAULT '';
			ALTER TABLE sessions MODIFY ip VARCHAR(39) NOT NULL DEFAULT '';
		");
	}
	upgradeSchema("
		ALTER TABLE users ADD sourceAuth2 INT NOT NULL DEFAULT 0 AFTER sourceAuth;
	");
	output("$newVersion: duplicating source auth values...\n");
	$m->dbDo("
		UPDATE users SET sourceAuth2 = sourceAuth");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.25.1";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		ALTER TABLE topics DROP hitNum;
		DROP TABLE logStrings;
	");
	if ($m->{mysql}) {
		upgradeSchema("
			ALTER TABLE log CONVERT TO CHARSET utf8;
		");
	}
	if ($m->{mysql} || $m->{pgsql}) {
		upgradeSchema("
			ALTER TABLE log ADD id INT PRIMARY KEY AUTO_INCREMENT FIRST;
			ALTER TABLE log ADD string TEXT NOT NULL DEFAULT '';
		");
	}
	if ($m->{sqlite}) {
		upgradeSchema("
			DROP TABLE log;
			CREATE TABLE log (
				id           INT PRIMARY KEY AUTO_INCREMENT,
				level        TINYINT NOT NULL,
				entity       VARCHAR(6) NOT NULL,
				action       VARCHAR(8) NOT NULL,
				userId       INT NOT NULL DEFAULT 0,
				boardId      INT NOT NULL DEFAULT 0,
				topicId      INT NOT NULL DEFAULT 0,
				postId       INT NOT NULL DEFAULT 0,
				extraId      INT NOT NULL DEFAULT 0,
				logTime      INT NOT NULL,
				ip           VARCHAR(39) NOT NULL DEFAULT '',
				string       TEXT NOT NULL DEFAULT ''
			) TABLEOPT;
		");
	}
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.27.1";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		DROP TABLE sessions;
		ALTER TABLE users DROP hideEmail;
	");
	if ($m->{mysql} || $m->{pgsql}) {
		upgradeSchema("
			ALTER TABLE arc_topics DROP hitNum;
		");
	}
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.27.2";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	$m->dbDo("
		DELETE FROM tickets");
	if ($m->{mysql}) {
		upgradeSchema("
			ALTER TABLE users
				DROP   sourceAuth,
				DROP   sourceAuth2,
				MODIFY bounceAuth  VARCHAR(22) NOT NULL DEFAULT '',
				MODIFY salt        VARCHAR(22) NOT NULL DEFAULT '' AFTER bounceAuth,
				ADD    loginAuth   VARCHAR(22) NOT NULL DEFAULT '' AFTER salt,
				ADD    sourceAuth  VARCHAR(22) NOT NULL DEFAULT '' AFTER loginAuth,
				ADD    sourceAuth2 VARCHAR(22) NOT NULL DEFAULT '' AFTER sourceAuth;
			ALTER TABLE tickets MODIFY id VARCHAR(22) NOT NULL DEFAULT '';
		");
	}
	elsif ($m->{pgsql}) {
		upgradeSchema("
			ALTER TABLE users
				DROP   sourceAuth,
				DROP   sourceAuth2,
				ALTER  bounceAuth  TYPE VARCHAR(22),
				ALTER  salt        TYPE VARCHAR(22),
				ALTER  bounceAuth  SET DEFAULT '',
				ALTER  salt        SET DEFAULT '',
				ADD    loginAuth   VARCHAR(22) NOT NULL DEFAULT '',
				ADD    sourceAuth  VARCHAR(22) NOT NULL DEFAULT '',
				ADD    sourceAuth2 VARCHAR(22) NOT NULL DEFAULT '';
			ALTER TABLE tickets ALTER id VARCHAR(22);
		");
	}
	elsif ($m->{sqlite}) {
		upgradeSchema("
			ALTER TABLE users ADD loginAuth VARCHAR(22) NOT NULL DEFAULT '';
		");
	}
	upgradeSchema("
		ALTER TABLE boardSubscriptions ADD unsubAuth VARCHAR(22) NOT NULL DEFAULT '';
		ALTER TABLE topicSubscriptions ADD unsubAuth VARCHAR(22) NOT NULL DEFAULT '';
	");
	output("$newVersion: setting auth values...\n");
	$m->dbBegin();
	my $users = $m->fetchAllArray("
		SELECT id, password FROM users");
	for my $user (@$users) {
		my $password = $user->[1];
		$password =~ s/([a-fA-F0-9]{2})/pack("C", hex($1))/eg;
		$password = $m->md5($password, 99999, 1);
		my $sourceAuth = $m->randomId();
		$m->dbDo("
			UPDATE users SET 
				bounceAuth = ?, password = ?, loginAuth = ?, sourceAuth = ?, sourceAuth2 = ? 
			WHERE id = ?", 
			$m->randomId(), $password, $m->randomId(), $sourceAuth, $sourceAuth, $user->[0]);
	}
	my $boardSubscriptions = $m->fetchAllArray("
		SELECT userId, boardId FROM boardSubscriptions");
	for my $subscription (@$boardSubscriptions) {
		$m->dbDo("
			UPDATE boardSubscriptions SET unsubAuth = ? WHERE userId = ? AND boardId = ?",
			$m->randomId(), $subscription->[0], $subscription->[1]);
	}
	my $topicSubscriptions = $m->fetchAllArray("
		SELECT userId, topicId FROM topicSubscriptions");
	for my $subscription (@$topicSubscriptions) {
		$m->dbDo("
			UPDATE topicSubscriptions SET unsubAuth = ? WHERE userId = ? AND topicId = ?",
			$m->randomId(), $subscription->[0], $subscription->[1]);
	}
	$m->dbCommit();
	output("$newVersion: upgrading database schema some more...\n");
	if ($m->{mysql}) {
		upgradeSchema("
			ALTER TABLE users MODIFY password VARCHAR(22) NOT NULL DEFAULT '' AFTER bounceAuth;
		");
	}
	elsif ($m->{pgsql}) {
		upgradeSchema("
			ALTER TABLE users ALTER password TYPE VARCHAR(22);
		");
	}
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

$newVersion = "2.27.4";

if ($oldVersionDec < tripletToDecimal($newVersion)) {
	output("$newVersion: upgrading database schema...\n");
	upgradeSchema("
		CREATE TABLE postLikes (
			postId       INT NOT NULL,
			userId       INT NOT NULL,
			PRIMARY KEY (postId, userId)
		) TABLEOPT;
	");
	output("$newVersion: done.\n");
}

#------------------------------------------------------------------------------

# Update dataVersion serial
my $dataVersion = $m->fetchArray("
	SELECT value FROM config WHERE name = ?", 'dataVersion');
if ($dataVersion) {
	$m->dbDo("
		UPDATE config SET value = ? WHERE name = ?", $dataVersion + 1, 'dataVersion');
	$m->dbDo("
		UPDATE config SET value = ? WHERE name = ?", $m->{now}, 'lastUpdate');
}

# Insert new version variable
$m->dbDo("
	DELETE FROM variables WHERE name = ?", 'version');
$m->dbDo("
	INSERT INTO variables (name, value) VALUES ('version', ?)", $newVersion);
output("Current database schema version: $newVersion\n");
output("mwForum upgrade done.\n");
