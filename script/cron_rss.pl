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
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
use POSIX ();
use MwfMain;

#------------------------------------------------------------------------------

# Get arguments
my %opts = ();
Getopt::Std::getopts('sf:', \%opts);
my $spawned = $opts{s};
my $forumId = $opts{f};

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId, spawned => $spawned);

# Create xml directory
my $feedFsPath = "$cfg->{attachFsPath}/xml";
$m->createDirectories($feedFsPath);

#------------------------------------------------------------------------------
# Generate Atom/RSS feeds

# Generate separate files for boards
my $boards = $m->fetchAllHash("
	SELECT id, title FROM boards WHERE private = 0");

for my $board (@$boards) {
	my $boardId = $board->{id};
	my $rss200File = "$feedFsPath/board$boardId.rss200.xml";
	my $atom10File = "$feedFsPath/board$boardId.atom10.xml";
	my $rss200Time = (stat($rss200File))[9];
	my $atom10Time = (stat($atom10File))[9];

	# Get time of latest post
	my $lastPostTime = $m->fetchArray("
		SELECT MAX(postTime) 
		FROM posts 
		WHERE boardId = :boardId
			AND userId > -2
			AND approved = 1",
		{ boardId => $boardId });

	# Get latest edit time of posts
	my $lastEditTime = $m->fetchArray("
		SELECT MAX(editTime)
		FROM posts
		WHERE boardId = :boardId
			AND userId > -2
			AND approved = 1",
		{ boardId => $boardId });
	my $updateTime = $lastEditTime > $lastPostTime ? $lastEditTime : $lastPostTime;

	# Get latest posts
	my $posts = $m->fetchAllHash("
		SELECT posts.*,
			topics.subject, topics.postNum,
			boards.title AS boardTitle
		FROM posts AS posts
			INNER JOIN topics AS topics
				ON topics.id = posts.topicId
			INNER JOIN boards AS boards
				ON boards.id = posts.boardId
		WHERE posts.boardId = :boardId
			AND posts.userId > -2
			AND posts.approved = 1
		ORDER BY posts.postTime DESC
		LIMIT :rssItems",
		{ boardId => $boardId, rssItems => $cfg->{rssItems} });
	
	# Write file	
	writeRss200($rss200File, $posts, $board->{title}) 
		if $updateTime > $rss200Time || !-f $rss200File;
	writeAtom10($atom10File, $posts, $board->{title}) 
		if $updateTime > $atom10Time || !-f $atom10File;
}

# Generate single file for whole forum
my $rss200File = "$feedFsPath/forum.rss200.xml";
my $atom10File = "$feedFsPath/forum.atom10.xml";
my $rss200Time = (stat($rss200File))[9];
my $atom10Time = (stat($atom10File))[9];

# Get time of latest post
my @exclBoardIds = $cfg->{rssExclude} =~ /(\d+)/g || (0);
my $lastPostTime = $m->fetchArray("
	SELECT MAX(posts.postTime)
	FROM posts AS posts
		INNER JOIN boards AS boards
			ON boards.id = posts.boardId
	WHERE posts.userId > -2
		AND posts.approved = 1
		AND boards.private = 0
		AND boards.id NOT IN (:exclBoardIds)",
	{ exclBoardIds => \@exclBoardIds });

# Get latest edit time of posts
my $lastEditTime = $m->fetchArray("
	SELECT MAX(posts.editTime)
	FROM posts AS posts
		INNER JOIN boards AS boards
			ON boards.id = posts.boardId
	WHERE posts.userId > -2
		AND posts.approved = 1
		AND boards.private = 0
		AND boards.id NOT IN (:exclBoardIds)",
	{ exclBoardIds => \@exclBoardIds });
my $updateTime = $lastEditTime > $lastPostTime ? $lastEditTime : $lastPostTime;

# Get latest posts
my $posts = $m->fetchAllHash("
	SELECT posts.*,
		topics.subject, topics.postNum,
		boards.title AS boardTitle
	FROM posts AS posts
		INNER JOIN topics AS topics
			ON topics.id = posts.topicId
		INNER JOIN boards AS boards
			ON boards.id = posts.boardId
	WHERE posts.userId > -2
		AND posts.approved = 1
		AND boards.private = 0
		AND boards.id NOT IN (:exclBoardIds)
	ORDER BY posts.postTime DESC
	LIMIT :rssItems",
	{ exclBoardIds => \@exclBoardIds, rssItems => $cfg->{rssItems} });

# Write file	
writeRss200($rss200File, $posts) if $updateTime > $rss200Time || !-f $rss200File;
writeAtom10($atom10File, $posts) if $updateTime > $atom10Time || !-f $atom10File;

#------------------------------------------------------------------------------
# Write RSS 2.0 feed

sub writeRss200
{
	my $file = shift();
	my $posts = shift();
	my $boardTitle = shift();
	
	# Open file
	open my $fh, ">:utf8", $file or $m->error("Opening feed file failed. ($!)");

	# Set locale for stupid date format
	my $oldLocale = POSIX::setlocale(POSIX::LC_TIME(), 'C');

	# Format values
	my $title = $cfg->{forumName};
	$title .= " - $boardTitle" if $boardTitle;
	my $buildDate = $m->formatTime($m->{now}, 0, "%a, %d %b %Y %H:%M:%S GMT");
	my $descEsc = $m->escHtml($cfg->{rssDesc});
	
	# Print header
	print $fh
		"<?xml version='1.0' encoding='utf-8'?>\n",
		"<rss version='2.0'>\n",
		"  <channel>\n",
		"    <title>$title</title>\n",
		"    <link>$cfg->{baseUrl}$cfg->{scriptUrlPath}/forum$m->{ext}</link>\n",
		"    <description>$descEsc</description>\n",
		"    <lastBuildDate>$buildDate</lastBuildDate>\n",
		"    <ttl>120</ttl>\n",
		"    <generator>mwForum $MwfMain::VERSION</generator>\n";
	
	# Print items
	my $itemLink = "$cfg->{baseUrl}$cfg->{scriptUrlPath}/topic_show$m->{ext}?pid=";
	for my $post (@$posts) {
		# Format values
		my $postId = $post->{id};
		my $subject = $post->{subject};
		$subject =~ s!&#39;!'!g;
		$subject =~ s!&quot;!"!g;
		$subject =~ s!&lt;!!g;
		$subject =~ s!&gt;!!g;
		my $postCopy = { body => $post->{body} };
		$m->dbToDisplay({}, $postCopy);
		my $pubDate = $m->formatTime($post->{postTime}, 0, "%a, %d %b %Y %H:%M:%S GMT");

		# Print entry
		print $fh
			"    <item>\n",
			"      <guid isPermaLink='false'>$itemLink$postId</guid>\n",
			"      <link>$itemLink$postId</link>\n",
			"      <title>$subject</title>\n",
			"      <author>$post->{userNameBak}</author>\n",
			"      <pubDate>$pubDate</pubDate>\n",
			"      <category>$post->{boardTitle}</category>\n",
			"      <description>\n",
			"        <![CDATA[$postCopy->{body}]]>\n",
			"      </description>\n",
			"    </item>\n";
	}
	
	# End file
	print $fh 
		"  </channel>\n",
		"</rss>\n";

	close $fh;
	$m->setMode($file, 'file');
	POSIX::setlocale(POSIX::LC_TIME(), $oldLocale);
}

#------------------------------------------------------------------------------
# Write Atom 1.0 feed

sub writeAtom10
{
	my $file = shift();
	my $posts = shift();
	my $boardTitle = shift();
	
	# Open file
	open my $fh, ">:utf8", $file or $m->error("Opening feed file failed. ($!)");
	
	# Format values
	my $title = $cfg->{forumName};
	$title .= " - $boardTitle" if $boardTitle;
	my $updated = $m->formatTime($m->{now}, 0, "%Y-%m-%dT%TZ");
	my $fileName = $file;
	$fileName =~ s!.*[\\/:]!!;
	my $descEsc = $m->escHtml($cfg->{rssDesc});
	
	# Print header
	print $fh
		"<?xml version='1.0' encoding='utf-8'?>\n",
		"<feed xmlns='http://www.w3.org/2005/Atom'",
		" xmlns:slash='http://purl.org/rss/1.0/modules/slash/'",
		" xml:base='$cfg->{baseUrl}'>\n",
		"  <id>$cfg->{baseUrl}$cfg->{scriptUrlPath}/forum$m->{ext}</id>\n",
		"  <link rel='self' href='$cfg->{baseUrl}$cfg->{attachUrlPath}/xml/$fileName'/>\n",
		"  <link rel='alternate' href='$cfg->{baseUrl}$cfg->{scriptUrlPath}/forum$m->{ext}'/>\n",
		"  <title>$title</title>\n",
		"  <subtitle>$descEsc</subtitle>\n",
		"  <updated>$updated</updated>\n",
		"  <generator version='$MwfMain::VERSION' uri='http://www.mwforum.org/'>mwForum</generator>\n",
	;

	# Print entries
	my $itemLink = "$cfg->{baseUrl}$cfg->{scriptUrlPath}/topic_show$m->{ext}?pid=";
	my $authorLink = "$cfg->{baseUrl}$cfg->{scriptUrlPath}/user_info$m->{ext}?uid=";
	for my $post (@$posts) {
		# Format values
		my $postId = $post->{id};
		my $postCopy = { body => $post->{body} };
		$m->dbToDisplay({}, $postCopy);
		$post->{editTime} ||= $post->{postTime};
		my $published = $m->formatTime($post->{postTime}, 0, "%Y-%m-%dT%TZ");
		my $updated = $m->formatTime($post->{editTime}, 0, "%Y-%m-%dT%TZ");
		my $comments = $post->{postNum} - 1;

		# Print entry
		print $fh
			"  <entry>\n",
			"    <id>$itemLink$postId</id>\n",
			"    <link href='$itemLink$postId'/>\n",
			"    <title>$post->{subject}</title>\n",
			"    <author><name>$post->{userNameBak}</name></author>\n",
			"    <published>$published</published>\n",
			"    <updated>$updated</updated>\n",
			"    <category term='$post->{boardTitle}'/>\n",
			"    <slash:comments>$comments</slash:comments>\n",
			"    <content type='html'>\n",
			"      <![CDATA[$postCopy->{body}]]>\n",
			"    </content>\n",
			"  </entry>\n";
	}
	
	print	$fh "</feed>\n";
	close $fh;
	$m->setMode($file, 'file');
}
