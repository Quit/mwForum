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
use MwfMain;

#------------------------------------------------------------------------------

# Init
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new(@_);

# Get CGI parameters
my $postId = $m->paramInt('pid');
my $url = $m->paramStr('url');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get post
my $post = $m->fetchHash("
	SELECT * FROM posts WHERE id = ?", $postId);
$post or $m->error('errPstNotFnd');
my $postIdMod = $postId % 100;
my $boardId = $post->{boardId};
my $topicId = $post->{topicId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Get topic
my $topic = $m->fetchHash("
	SELECT * FROM topics WHERE id = ?", $topicId);
$topic or $m->error('errTpcNotFnd');

# Check if user is admin or moderator
$user->{admin} || $m->boardAdmin($userId, $boardId) or $m->error('errNoAccess');

# Check if attachments are enabled
$cfg->{attachments} && $board->{attach} or $m->error("Attachments are disabled.");
$cfg->{attachImg} && $cfg->{attachImgThb} or $m->error("Thumbnails are disabled.");

# Fetch image with LWP or wget
my $wget = $cfg->{wgetBinary} || "/usr/bin/wget";
my $maxLen = $cfg->{maxAttXferLen} || $cfg->{maxAttachLen};
my $file = "$cfg->{attachFsPath}/transfer-" . int(rand(99999)) . ".tmp";
my $fileName = "";
if (!$cfg->{noLWP} && eval { require LWP::UserAgent }) {
	# Use LWP (better but bloaty)
	my $ua = LWP::UserAgent->new(agent => "mwForum/$MwfMain::VERSION; $cfg->{baseUrl}",
		timeout => 5, parse_head => 0, max_redirect => 2, max_size => $maxLen,
		default_headers => HTTP::Headers->new('Accept-Language' => "en", 'Accept-Encoding' => "identity"),
		ssl_opts => { verify_hostname => 0 });
	
	# Check file size with HEAD request
	my $rsp = $ua->head($url, ':content_file' => $file);
	$rsp->content_length() <= $maxLen
		or error($m, "Maximum file size exceeded. (" . $rsp->content_length() . " > $maxLen)", $file);
	$rsp->code() == 200 or error($m, "File size check failed. (" . $rsp->status_line() . ")", $file);
	
	# Transfer file from remote host to temp file
	$rsp = $ua->get($url, ':content_file' => $file);
	!$rsp->header('Client-Aborted')
		or error($m, "Maximum file size exceeded. (" . $rsp->content_length() . " > $maxLen)", $file);
	$rsp->code() == 200 or error($m, "Transfer failed. (" . $rsp->status_line() . ")", $file);
	$m->setMode($file, 'file');
	$fileName = $rsp->filename();
}
elsif (-x $wget) {
	# Use wget call
	my @args = ("--user-agent=mwForum/$MwfMain::VERSION; $cfg->{baseUrl}",
		"--no-check-certificate", "--no-verbose", "--header=Accept-Language: en",
		"--tries=1", "--timeout=5", "--max-redirect=2",
		"--output-file=$file.err", "--output-document=$file", $url);
	my $rv = system($wget, @args) >> 8;
	$rv == 0 or error($m, "Wget failed. ($rv)", $file);
	my $size = -s $file;
	$size or error($m, "Transfer failed.\n\n" . $m->slurpFile("$file.err"), $file);
	$size <= $maxLen or error($m, "Maximum file size exceeded. ($size > $maxLen)", $file);
	($fileName) = $url =~ m!([\w.-]+\.(?:jpg|png|gif))!i;
	unlink "$file.err";
}
else {
	$m->error("Neither LWP modules nor Wget are available.");
}

# Remove problematic stuff from filename and make sure it doesn't clash
$fileName =~ /\.(?:jpg|png|gif)\z/i or error($m, "No valid filename found.", $file);
$fileName =~ s![^A-Za-z_0-9.-]+!!g;
my ($name, $ext) = $fileName =~ /(.+?)(\.[^.]+)?\z/;
$name = substr($name, 0, $cfg->{attachNameLen} || 40);
$ext = substr($ext, 0, $cfg->{attachNameLen} || 40);
my $like = $m->{pgsql} ? 'ILIKE' : 'LIKE';
my $num = "";
for my $i (0 .. 100) {
	$num = $i ? "-$i" : "";
	my $nameExists = $m->fetchArray("
		SELECT 1 FROM attachments WHERE postId = ? AND LOWER(fileName) $like LOWER(?)",
		$postId, "$name$num%");
	last if !$nameExists;
	$i < 100 or error($m, "Too many filename collisions.", $file);
}
$fileName = "$name$num$ext";

# Create directories and move temp file
my $path = "$cfg->{attachFsPath}/$postIdMod";
$m->createDirectories($path, $postId);
rename $file, "$path/$postId/$fileName";

# Add attachments table entry
$m->dbDo("
	INSERT INTO attachments (postId, webImage, fileName) VALUES (?, 2, ?)", $postId, $fileName);
my $attachId = $m->dbInsertId("attachments");

# Resize image
$fileName = $m->resizeAttachment($attachId) || $fileName if $cfg->{attachImgRsz};

# Replace tag
my $body = \$post->{body};
my $urlRxEsc = quotemeta($m->escHtml($url));
$$body =~ s!<img class='emi' src='$urlRxEsc' alt=''/?>![img thb]${fileName}[/img]!;
$m->dbDo("
	UPDATE posts SET body = ? WHERE id = ?", $$body, $postId);

# Log action and finish
$m->logAction(1, 'attach', 'transfer', $userId, $boardId, $topicId, $postId, $attachId);
$m->redirect('topic_show', pid => $postId);

#------------------------------------------------------------------------------
# Delete temp file(s) before erroring

sub error
{
	my $m = shift();
	my $msg = shift();
	my $file = shift();

	unlink $file;
	unlink "$file.err";
	$m->error($msg);
}
