#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2014 Markus Wichitill
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#------------------------------------------------------------------------------

# This script fills a forum with 5000 users, 50000 topics and 1000000 posts 
# for testing and benchmarking purposes.
# 
# Create a database, set up MwfConfig.pm for it and call install.pl to create 
# its schema. Then call this script with an -x parameter.
#
# Also required is a lines.txt file that should contain lines of real text,
# five of which are randomly chosen to form each post body. Cobble something
# together from ebooks or whatever.
#
# User login will be admin/admin.

use strict;
use warnings;
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
use Locale::Country ();
require MwfMain;

# Get arguments
my %opts = ();
Getopt::Std::getopts('xf:', \%opts);
my $execute = $opts{x};
my $forumId = $opts{f};
$execute or die "-x not specified, refusing to run for safety reasons.";

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId);
my $startTime = time();
srand 42;

# Shortcuts
my $dbh = $m->{dbh};
my $baseTime = $m->{now} - 123003600;
my $ua = "'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:16.0) Gecko/16.0 Firefox/16.0'";
my $ip = "'127.0.0.1'";
my @countries = Locale::Country::all_country_names();

# Load text
print "Loading text...\n";
open my $fh, "lines.txt" or die "Open text file failed";
my @lines = <$fh>;
chomp @lines;

# Drop indexes
print "Dropping indexes...\n";
if ($m->{mysql}) {
	$dbh->do("DROP INDEX topics_lastPostTime ON topics");
	$dbh->do("DROP INDEX posts_userId ON posts");
	$dbh->do("DROP INDEX posts_topicId ON posts");
	$dbh->do("DROP INDEX posts_postTime ON posts");
}
else {
	$dbh->do("DROP INDEX topics_lastPostTime");
	$dbh->do("DROP INDEX posts_userId");
	$dbh->do("DROP INDEX posts_topicId");
	$dbh->do("DROP INDEX posts_postTime");
}

# Insert admin, categories, boards and config
print "Inserting admin, categories, boards and some options...\n";
my $salt = 'lh0ojBonHYdxU4c47ktEVw';
my $password = $m->hashPassword('admin', $salt);
$dbh->begin_work();
$dbh->do("
	INSERT INTO users (admin, userName, password, salt, lastOnTime, prevOnTime, topicsPP, postsPP, indent) 
	VALUES (1, 'admin', $password, $salt, $m->{now}, $m->{now}, 25, 50, 3)") 
	or die $dbh->errstr;
$dbh->do("INSERT INTO categories (title, pos) VALUES ('Category 1', 1)") or die $dbh->errstr;
$dbh->do("INSERT INTO categories (title, pos) VALUES ('Category 2', 2)") or die $dbh->errstr;
$dbh->do("INSERT INTO boards (title, pos, categoryId) VALUES ('Board 1', 1, 1)") or die $dbh->errstr;
$dbh->do("INSERT INTO boards (title, pos, categoryId) VALUES ('Board 2', 2, 1)") or die $dbh->errstr;
$dbh->do("INSERT INTO boards (title, pos, categoryId) VALUES ('Board 3', 3, 1)") or die $dbh->errstr;
$dbh->do("INSERT INTO boards (title, pos, categoryId) VALUES ('Board 4', 1, 2)") or die $dbh->errstr;
$dbh->do("INSERT INTO boards (title, pos, categoryId) VALUES ('Board 5', 2, 2)") or die $dbh->errstr;
$dbh->do("INSERT INTO boards (title, pos, categoryId) VALUES ('Board 6', 3, 2)") or die $dbh->errstr;
$dbh->do("INSERT INTO config (name, value) VALUES ('advForumOpt', '1')") or die $dbh->errstr;
$dbh->do("INSERT INTO config (name, value) VALUES ('skipStickySort', '1')") or die $dbh->errstr;

# Prepare statements
my $usrInsSth = $dbh->prepare("
	INSERT INTO users (userName, realName, email, location, userAgent, lastIp) 
	VALUES (?,?,?,?,$ua,$ip)");
my $tpcInsSth = $dbh->prepare("
	INSERT INTO topics (subject, boardId, basePostId, postNum, lastPostTime) 
	VALUES (?,?,?,?,?)");
my $pstInsSth = $dbh->prepare("
	INSERT INTO posts (userId, userNameBak, boardId, topicId, parentId, approved, postTime, body, ip) 
	VALUES (?,?,?,?,?,?,?,?,$ip)");

# Insert
print "Inserting 5000 users...\n";
for (my $u = 2; $u <= 5000; $u++) {
	$usrInsSth->execute("user_$u", "User Number $u", "$u\@example.org", 
		$countries[int(rand(@countries))]) or die $dbh->errstr;
}
print "Inserting 50000 topics...\n";
for (my $t = 1; $t <= 50000; $t++) {
	print "  Inserting topic $t...\n" if $t % 10000 == 0;
	my $subject = substr($lines[int(rand(@lines))], 0, 50);
	my $boardId = $t % 2 ? 1 : 2;
	my $basePostId = ($t - 1) * 20 + 1;
	my $lastPostTime = $baseTime + ($basePostId + 20) * 100;
	$tpcInsSth->execute($subject, $boardId, $basePostId, 20, $lastPostTime) or die $dbh->errstr;
}
print "Inserting 1000000 posts...\n";
for (my $t = 1; $t <= 50000; $t++) {
	print "  Inserting posts for topic $t...\n" if $t % 500 == 0;
	my $boardId = $t % 2 ? 1 : 2;
	for (my $p = 1; $p <= 20; $p++) {
		my $postId = ($t - 1) * 20 + $p;
		my $parentId;
		if ($p == 1) { $parentId = 0 }
		elsif ($p == 11) { $parentId = $postId - 10 }
		else { $parentId = $postId - 1 }
		my $userId = int(rand(5000)) + 1;
		my $postTime = $baseTime + $postId * 100;
		my $body = join(" ", @lines[int(rand(@lines)), int(rand(@lines)), int(rand(@lines)), 
			int(rand(@lines)), int(rand(@lines))]);
		$pstInsSth->execute(
			$userId, "user_$userId", $boardId, $t, $parentId,	1, $postTime, $body) 
			or die $dbh->errstr;
	}
}
$dbh->commit();

# Create indexes
print "Creating topics_lastPostTime index...\n";
$dbh->do("CREATE INDEX topics_lastPostTime ON topics (lastPostTime)") or die $dbh->errstr;
print "Creating posts_userId index...\n";
$dbh->do("CREATE INDEX posts_userId ON posts (userId)") or die $dbh->errstr;
print "Creating posts_topicId index...\n";
$dbh->do("CREATE INDEX posts_topicId ON posts (topicId)") or die $dbh->errstr;
print "Creating posts_postTime index...\n";
$dbh->do("CREATE INDEX posts_postTime ON posts (postTime)") or die $dbh->errstr;

# Update board stats
print "Updating board postNum and lastPostTime...\n";
$m->recalcStats([ 1, 2 ]);

# Update database stats
print "Updating database statistics...\n";
my @tables = qw(attachments boardAdminGroups boardHiddenFlags boardMemberGroups 
	boards boardSubscriptions categories chat config groupMembers groups messages 
	notes pollOptions polls pollVotes postLikes postReports posts tickets 
	topicReadTimes topics topicSubscriptions userBans userIgnores users 
	userVariables variables watchUsers watchWords);
if ($m->{mysql}) {
	for my $table (@tables) {
		$dbh->do("ANALYZE TABLE $table");
	}
}
elsif ($m->{pgsql}) {
	for my $table (@tables) {
		$dbh->do("VACUUM ANALYZE $table");
	}
}
elsif ($m->{sqlite}) {
	$dbh->do("ANALYZE");
}

print "Finished in " . (time() - $startTime) . "s.\n";
