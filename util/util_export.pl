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

# Export a board or topic for import in another mwForum.
# Doesn't export ancillary things like users, polls or attachments.

use strict;
use warnings;
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
require MwfMain;

# Get arguments
my %opts = ();
Getopt::Std::getopts('?hf:b:t:', \%opts);
my $help = $opts{'?'} || $opts{h};
my $forumId = $opts{f};
my $boardId = $opts{b} || 0;
my $topicId = $opts{t} || 0;
usage() if $help;
$boardId xor $topicId or usage();

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId);
$m->dbBegin();
binmode STDOUT, ':utf8';

# Print UTF-8 hint and version
my $schemaVersion = $m->getVar('version');
print
	"[global]\n",
	"utf8=\x{00E4}\x{00F6}\x{00FC}\n",
	"version=$schemaVersion\n",
	"\n";

if ($boardId) {
	# Get board
	my $board = $m->fetchHash("
		SELECT * FROM boards WHERE id = ?", $boardId);
	print
		"[board $boardId]\n",
		"title=$board->{title}\n",
		"shortDesc=$board->{shortDesc}\n",
		"longDesc=$board->{longDesc}\n",
		"expiration=$board->{expiration}\n",
		"locking=$board->{locking}\n",
		"topicAdmins=$board->{topicAdmins}\n",
		"approve=$board->{approve}\n",
		"private=$board->{private}\n",
		"list=$board->{list}\n",
		"unregistered=$board->{unregistered}\n",
		"announce=$board->{announce}\n",
		"flat=$board->{flat}\n",
		"attach=$board->{attach}\n",
		"lastPostTime=$board->{lastPostTime}\n",
		"postNum=$board->{postNum}\n",
		"\n";
}

# Print topics in batches
my $limit = 100;
my $offset = 0;
while (1) {
	my $where = $boardId ? "boardId = :boardId" : "id = :topicId";
	my $topics = $m->fetchAllHash("
		SELECT id, basePostId, subject, locked, lastPostTime, postNum
		FROM topics
		WHERE $where
		ORDER BY id
		LIMIT :limit OFFSET :offset",
		{ boardId => $boardId, topicId => $topicId, limit => $limit, offset => $offset });
	for my $topic (@$topics) {
		print
			"[topic $topic->{id}]\n",
			"basePostId=$topic->{basePostId}\n",
			"subject=$topic->{subject}\n",
			$topic->{locked} ? "locked=$topic->{locked}\n" : "",
			"lastPostTime=$topic->{lastPostTime}\n",
			"postNum=$topic->{postNum}\n",
			"\n";
	}
	last if @$topics < $limit;
	$offset += $limit;
}

# Print posts in batches
$offset = 0;
while (1) {
	my $where = $boardId ? "posts.boardId = :boardId" : "posts.topicId = :topicId";
	my $posts = $m->fetchAllHash("
		SELECT posts.*, users.email AS userEmail
		FROM posts
			LEFT JOIN users ON users.id = posts.userId
		WHERE $where
		ORDER BY posts.id
		LIMIT :limit OFFSET :offset",
		{ boardId => $boardId, topicId => $topicId, limit => $limit, offset => $offset });
	for my $post (@$posts) {
		my $body = \$post->{body};
		my $rawBody = \$post->{rawBody};
		$$body =~ s!<[^>]>!! if $post->{userId} == -2;
		$$rawBody =~ s!\n!<br>!g if $$rawBody;
		print
			"[post $post->{id}]\n",
			"topicId=$post->{topicId}\n",
			$post->{parentId} ? "parentId=$post->{parentId}\n" : "",
			$post->{userId} <= 0 ? "userId=$post->{userId}\n" : "",
			$post->{userNameBak} ? "userNameBak=$post->{userNameBak}\n" : "",
			$post->{userEmail} ? "userEmail=$post->{userEmail}\n" : "",
			$post->{ip} ? "ip=$post->{ip}\n" : "",
			$post->{approved} ? "approved=$post->{approved}\n" : "",
			$post->{locked} ? "locked=$post->{locked}\n" : "",
			"postTime=$post->{postTime}\n",
			$post->{editTime} ? "editTime=$post->{editTime}\n" : "",
			"body=$$body\n",
			$$rawBody ? "rawBody=$$rawBody\n" : "",
			"\n";
	}
	last if @$posts < $limit;
	$offset += $limit;
}

print "[end]\n";

# Log action and finish
$m->logAction(1, 'util', 'export', 0, $boardId, $topicId);
$m->dbCommit();
print STDERR "Finished with $m->{queryNum} database queries.\n";

#------------------------------------------------------------------------------

sub usage
{
	print
		"Export a board or topic for import in another mwForum.\n\n",
		"Usage: util_export.pl [-f forum] -b boardId > board.dat\n",
		"       util_export.pl [-f forum] -t topicId > topic.dat\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
		"  -b   ID of a single board to export with its contents.\n",
		"  -t   ID of a single topic to export with its contents.\n",
	;

	exit 1;
}
