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

# Export the public parts of the forum into minimalistic HTML files for basic 
# archival purposes or for browsing by smallscreen devices and screen readers.
# Not meant as a backup tool. Does not export complete data.

use strict;
use warnings;
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
require MwfMain;

# Get arguments
my %opts = ();
Getopt::Std::getopts('?hf:p:', \%opts);
my $help = $opts{'?'} || $opts{h};
my $forumId = $opts{f};
my $path = $opts{p};
usage() if $help;
$path or usage();

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId);
my $dbh = $m->{dbh};

#------------------------------------------------------------------------------
# Put CSS file into path

if (!-f "$path/minimal.css") {
	open my $fh, ">:utf8", "$path/minimal.css" or $m->error("Opening CSS file failed.");

	print $fh <<'EOCSS';
body {
	font-size: 13px;
	font-family: verdana, sans-serif;
}

a {
	text-decoration: none;
}

blockquote {
	margin: 0;
	color: gray;
}
blockquote p {
	margin: 0;
}

code {
	font-size: 90%;
}
EOCSS
}

#------------------------------------------------------------------------------
# Generate forum file

{
	# Open file
	open my $fh, ">:utf8", "$path/forum.html" or $m->error("Opening index HTML file failed.");

	# Get boards
	my $boardSth = $m->fetchSth("
		SELECT boards.id, boards.title
		FROM boards AS boards
			INNER JOIN categories AS categories
				ON categories.id = boards.categoryId
		WHERE boards.private = 0
		ORDER BY categories.pos, boards.pos");
	my ($boardId, $boardTitle);
	$boardSth->bind_columns(\($boardId, $boardTitle));

	# Print header
	print $fh header($cfg->{forumName}), "<ul>\n";

	# Print boards
	print $fh "<li><a href='board_$boardId.html'>$boardTitle</a></li>\n"
		while $boardSth->fetch();

	# Print footer
	print $fh	"</ul>\n\n</body>\n</html>\n";
}

#------------------------------------------------------------------------------
# Generate board files

{
	# Get boards
	my $boardSth = $m->fetchSth("
		SELECT id, title FROM boards WHERE private = 0");
	my ($boardId, $boardTitle);
	$boardSth->bind_columns(\($boardId, $boardTitle));

	# Iterate boards
	while ($boardSth->fetch()) {
		my $file = "$path/board_$boardId.html";
		my $fileTime = (stat($file))[9];

		# Get time of latest post
		my $lastPostTime = $m->fetchArray("
			SELECT MAX(postTime) FROM posts WHERE boardId = ? AND userId > -2 AND approved = 1",
			$boardId);

		# Get latest edit time of posts
		my $lastEditTime = $m->fetchArray("
			SELECT MAX(editTime) FROM posts WHERE boardId = ? AND userId > -2 AND approved = 1", 
			$boardId);
		my $updateTime = $lastEditTime > $lastPostTime ? $lastEditTime : $lastPostTime;

		if ($updateTime > $fileTime) {
			# Open file
			open my $fh, ">:utf8", $file or $m->error("Opening board HTML file failed.");

			# Get topics
			my $topicSth = $m->fetchSth("
				SELECT id, subject FROM topics WHERE boardId = ? ORDER BY id DESC", $boardId);
			my ($topicId, $topicSubject);
			$topicSth->bind_columns(\($topicId, $topicSubject));

			# Print header
			print $fh header($boardTitle), "<ul>\n";

			# Print topics
			print $fh "<li><a href='topic_$topicId.html'>$topicSubject</a></li>\n"
				while $topicSth->fetch();

			# Print footer
			print $fh	"</ul>\n\n</body>\n</html>\n";
		}
	}
}

#------------------------------------------------------------------------------
# Generate topic files

{
	# Get topics
	my ($topicId, $topicSubject);
	my $topicSth = $m->fetchSth("
		SELECT topics.id, topics.subject
		FROM topics AS topics
			INNER JOIN boards AS boards
				ON boards.id = topics.boardId
		WHERE boards.private = 0");
	$topicSth->bind_columns(\($topicId, $topicSubject));

	# Iterate topics
	while ($topicSth->fetch()) {
		my $file = "$path/topic_$topicId.html";
		my $fileTime = (stat($file))[9];

		# Get time of latest post
		my $lastPostTime = $m->fetchArray("
			SELECT MAX(postTime) FROM posts WHERE topicId = ? AND userId > -2 AND approved = 1",
			$topicId);

		# Get latest edit time of posts
		my $lastEditTime = $m->fetchArray("
			SELECT MAX(editTime) FROM posts WHERE topicId = ? AND userId > -2 AND approved = 1",
			$topicId);
		my $updateTime = $lastEditTime > $lastPostTime ? $lastEditTime : $lastPostTime;

		if ($updateTime > $fileTime) {
			# Open file
			open my $fh, ">:utf8", $file or $m->error("Opening topic HTML file failed.");

			# Get posts
			my $postSth = $m->fetchSth("
				SELECT userNameBak, body, postTime
				FROM posts
				WHERE topicId = :topicId
					AND userId > -2
					AND approved = 1
				ORDER BY id",
				{ topicId => $topicId });
			my ($postUser, $postBody, $postTime);
			$postSth->bind_columns(\($postUser, $postBody, $postTime));

			# Print header
			print $fh header($topicSubject);

			# Print posts
			while ($postSth->fetch()) {
				next if !$postUser || !$postBody;
				my $postTimeStr = $m->formatTime($postTime, 0, "%Y-%m-%d %H:%M");
				print $fh
					"<h4>$postUser, $postTimeStr</h4>\n",
					"<div>$postBody</div>\n\n";
			}

			# Print footer
			print $fh "</body>\n</html>\n";
		}
	}
}

#------------------------------------------------------------------------------

sub header
{
	my $title = shift();

	return
		"<!DOCTYPE html>\n",
		"<html>\n",
		"<head>\n",
		"<meta http-equiv='content-type' content='text/html; charset=ut","f-8'>\n",
		"<title>$title</title>\n",
		"<link rel='stylesheet' href='minimal.css' type='text/css'>\n",
		"</head>\n",
		"<body>\n\n",
		"<h2>$title</h2>\n\n";
}

#------------------------------------------------------------------------------

sub usage
{
	print
		"Export the public part of the forum into basic HTML files.\n\n",
		"Usage: util_exporthtml.pl [-f forum] -p path\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
		"  -p   Filesystem path to save files to.\n",
	;

	exit 1;
}
