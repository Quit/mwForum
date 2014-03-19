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
no warnings qw(uninitialized redefine);

# Imports
use MwfMain;

#------------------------------------------------------------------------------

# Init
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0]);

# Get CGI parameters
my $attachId = $m->paramInt('aid');

# Get attachment
my $attach = $m->fetchHash("
	SELECT * FROM attachments WHERE id = ?", $attachId);
$attach or $m->error('errAttNotFnd');
my $postId = $attach->{postId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = (SELECT boardId FROM posts WHERE id = ?)", $postId);

# Get prev/next image attachment id
my $prevAttachId = $m->fetchArray("
	SELECT id 
	FROM attachments 
	WHERE postId = :postId
		AND webImage > 0
		AND id < :id
	ORDER BY id DESC
	LIMIT 1",
	{ postId => $postId, id => $attachId });
my $nextAttachId = $m->fetchArray("
	SELECT id 
	FROM attachments 
	WHERE postId = :postId
		AND webImage > 0
		AND id > :id
	ORDER BY id ASC
	LIMIT 1",
	{ postId => $postId, id => $attachId });

# Check if user can see board
$m->boardVisible($board) or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Print page bar
my @navLinks = ();
push @navLinks, { url => $m->url('attach_show', aid => $prevAttachId), 
	txt => 'atsPrev', ico => 'prev', dsb => $prevAttachId ? 0 : 1 };
push @navLinks, { url => $m->url('attach_show', aid => $nextAttachId), 
	txt => 'atsNext', ico => 'next', dsb => $nextAttachId ? 0 : 1 };
push @navLinks, { url => $m->url('topic_show', pid => $postId), 
	txt => 'comUp', ico => 'up' };
$m->printPageBar(mainTitle => $lng->{atsTitle}, subTitle => $attach->{fileName}, 
	navLinks => \@navLinks);

# Print image
my $postIdMod = $postId % 100;
my $url = "$cfg->{attachUrlPath}/$postIdMod/$postId/$attach->{fileName}";
print "<p class='ims'><img src='$url' alt=''></p>\n\n";

# Print caption
print
	"<div class='frm'>\n",
	"<div class='ccl'>\n",
	"<p class='imc'>$attach->{caption}</p>\n",
	"</div>\n",
	"</div>\n\n"
	if $attach->{caption};
	
# Log action and finish
$m->logAction(2, 'attach', 'show', $userId, $board->{id}, 0, $postId, $attachId);
$m->printFooter(1);
$m->finish();
