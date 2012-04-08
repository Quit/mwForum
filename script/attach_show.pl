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
my $attachId = $m->paramInt('aid');

# Get attachment
my $attach = $m->fetchHash("
	SELECT * FROM attachments WHERE id = ?", $attachId);
$attach or $m->error('errAttNotFnd');
my $postId = $attach->{postId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = (SELECT boardId FROM posts WHERE id = ?)", $postId);

# Check if user can see board
$m->boardVisible($board) or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Print page bar
my @navLinks = ();
push @navLinks, { url => $m->url('prevnext', aid => $attachId, dir => 'prev'), 
	txt => 'atsPrev', ico => 'prev' };
push @navLinks, { url => $m->url('prevnext', aid => $attachId, dir => 'next'), 
	txt => 'atsNext', ico => 'next' };
push @navLinks, { url => $m->url('topic_show', pid => $postId), 
	txt => 'comUp', ico => 'up' };
$m->printPageBar(mainTitle => $lng->{atsTitle}, subTitle => $attach->{fileName}, 
	navLinks => \@navLinks);

# Print image
my $postIdMod = $postId % 100;
my $url = "$cfg->{attachUrlPath}/$postIdMod/$postId/$attach->{fileName}";
print "<p class='ims'><img src='$url' alt=''/></p>\n\n";
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
