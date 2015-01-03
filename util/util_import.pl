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

# Import a board or topic exported from another mwForum.
# Assigns posts to users having the same email address.

use strict;
use warnings;
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
require MwfMain;

# Get arguments
my %opts = ();
Getopt::Std::getopts('?hf:c:b:', \%opts);
my $help = $opts{'?'} || $opts{h};
my $forumId = $opts{f};
my $impCategId = $opts{c} || 0;
my $impBoardId = $opts{b} || 0;
usage() if $help;
$impBoardId xor $impCategId or usage();

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId);
$m->dbBegin();
binmode STDIN, ':utf8';

# Map old to new ids, resp. email addresses to user ids
my $newBoardId = undef;
my %topicMap = ();
my %postMap = ();
my %userMap = ();

# Read lines
my $currSection = undef;
my $currId = undef;
my %entry = ();
while (my $line = <STDIN>) {
	chomp $line;
	next if !$line;

	# Parse line
	my ($startSection, $startId) = $line =~ /^\[(\w+) ?(\d+)?\]/;
	my ($key, $value) = $line =~ /^([A-Za-z_0-9]+)=(.*)/;
	if ($startSection) {
		if ($currSection) {
			if ($currSection eq 'global') {
				# Check version
				$entry{version} eq $m->getVar('version') or $m->error("Schema version mismatch.");
			}
			elsif ($currSection eq 'board') {
				# Insert board
				$impCategId or $m->error("Category ID not specified.");
				my $pos = $m->fetchArray("
					SELECT COALESCE(MAX(pos), 0) + 1 FROM boards WHERE categoryId = ?", $impCategId);
				$m->dbDo("
					INSERT INTO boards (categoryId, pos, title, shortDesc, longDesc, expiration, locking,
						topicAdmins, approve, private, list, unregistered, announce, flat, attach,
						lastPostTime, postNum)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
					$impCategId, $pos, $entry{title}, $entry{shortDesc} || "", $entry{longDesc} || "",
					$entry{expiration} || 0, $entry{locking} || 0, $entry{topicAdmins} || 0,
					$entry{approve} || 0, $entry{private} || 0, $entry{list} || 0,
					$entry{unregistered} || 0, $entry{announce} || 0, $entry{flat} || 0,
					$entry{attach} || 0, $entry{lastPostTime}, $entry{postNum});
				$newBoardId = $m->dbInsertId('boards');
			}
			elsif ($currSection eq 'topic') {
				# Insert topic
				$m->dbDo("
					INSERT INTO topics (boardId, basePostId, subject, locked, lastPostTime, postNum)
					VALUES (?, ?, ?, ?, ?, ?)",
					0, $entry{basePostId}, $entry{subject}, $entry{locked} || 0,
					$entry{lastPostTime}, $entry{postNum});
				$topicMap{$currId} = $m->dbInsertId('topics');
			}
			elsif ($currSection eq 'post') {
				# Try to map user by email
				my $userId = 0;
				my $email = $entry{userEmail};
				if (defined($entry{userId}) && $entry{userId} <= 0) {
					$userId = $entry{userId};
				}
				elsif ($email) {
					$userId = $userMap{$email};
					if (!defined($userId)) {
						$userId = $m->fetchArray("
							SELECT COALESCE(id, 0) FROM users WHERE email = ?", $email);
						$userMap{$email} = $userId;
					}
				}

				# Insert post
				$m->dbDo("
					INSERT INTO posts (boardId, topicId, parentId, userId, userNameBak, ip,
						approved, locked, postTime, editTime, body, rawBody)
					VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
					0, $entry{topicId}, $entry{parentId} || 0, $userId,
					$entry{userNameBak} || "", $entry{ip} || "",
					$entry{approved} || 0, $entry{locked} || 0,
					$entry{postTime}, $entry{editTime} || 0,
					$entry{body} || "", $entry{rawBody} || "");
				$postMap{$currId} = $m->dbInsertId('posts');
			}
			else {
				# Ignore lines before first section
			}
		}

		# Start new section
		$currSection = $startSection;
		$currId = $startId;
		%entry = ();
	}
	elsif ($key) {
		# Copy field
		$entry{$key} = $value;
	}
	else {
		# Ignore illegal lines
	}
}

# Update topics with new IDs
my $boardId = $impBoardId || $newBoardId;
for my $topicId (sort { $a <=> $b } values %topicMap) {
	my $basePostId = $m->fetchArray("
		SELECT basePostId FROM topics WHERE id = ?", $topicId);
	$basePostId = $postMap{$basePostId} || 0;
	$m->dbDo("
		UPDATE topics SET boardId = ?, basePostId = ? WHERE id = ?",
		$boardId, $basePostId, $topicId);
}

# Update posts with new IDs
for my $postId (sort { $a <=> $b } values %postMap) {
	my ($topicId, $parentId) = $m->fetchArray("
		SELECT topicId, parentId FROM posts WHERE id = ?", $postId);
	$topicId = $topicMap{$topicId};
	$parentId = $postMap{$parentId} || 0;
	$m->dbDo("
		UPDATE posts SET boardId = ?, topicId = ?, parentId = ? WHERE id = ?",
		$boardId, $topicId, $parentId, $postId);
}

# Update board statistics
$m->recalcStats($impBoardId) if $impBoardId;

# Log action and finish
$m->logAction(1, 'util', 'import', 0, $boardId);
$m->dbCommit();
print	"Finished with $m->{queryNum} database queries.\n";

#------------------------------------------------------------------------------

sub usage
{
	print
		"Import a board or topic exported from another mwForum.\n\n",
		"Usage: util_import.pl [-f forum] -c categId < board.dat\n",
		"       util_import.pl [-f forum] -b boardId < topic.dat\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
		"  -c   ID of a category to import an exported board into.\n",
		"  -b   ID of a board to import an exported topic into.\n",
	;

	exit 1;
}
