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

use strict;
use warnings;
no warnings qw(uninitialized redefine);

# Imports
use MwfMain;

#------------------------------------------------------------------------------

# Init
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0]);

# Print header
$m->printHeader();

# Print page bar
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{fedTitle}, navLinks => \@navLinks);

# Get boards
my $boards = $m->fetchAllHash("
	SELECT boards.id, boards.title,
		categories.title AS categTitle
	FROM boards AS boards
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
	WHERE boards.private = 0
	ORDER BY categories.pos, boards.pos");

# Print feed list
my $path = "$cfg->{attachUrlPath}/xml";
print
	"<table class='tbl'>\n",
	"<tr class='crw'>\n",
	"<td>$lng->{fedAllBoards}</td>\n",
	"<td class='shr'><a href='$path/forum.atom10.xml'>Atom 1.0</a></td>\n",
	"<td class='shr'><a href='$path/forum.rss200.xml'>RSS 2.0</a></td>\n",
	"</tr>\n";

for my $board (@$boards) {
	print
		"<tr class='crw'>\n",
		"<td>$board->{categTitle} / $board->{title}</td>\n",
		"<td class='shr'><a href='$path/board$board->{id}.atom10.xml'>Atom 1.0</a></td>\n",
		"<td class='shr'><a href='$path/board$board->{id}.rss200.xml'>RSS 2.0</a></td>\n",
		"</tr>\n";
}

print
	"</table>\n";

# Log action and finish
$m->logAction(3, 'forum', 'feeds', $userId);
$m->printFooter();
$m->finish();
