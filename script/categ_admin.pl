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
no warnings qw(uninitialized redefine);

# Imports
use MwfMain;

#------------------------------------------------------------------------------

# Init
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0]);

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Print page bar
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => "Category Administration", navLinks => \@navLinks);
     
# Print create category form
print
	"<form action='categ_add$m->{ext}' method='post'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Create Category</span></div>\n",
	"<div class='ccl'>\n",
	$m->submitButton("Create", 'category'),
	$m->stdFormFields(),
	"</div>\n",
	"</div>\n",
	"</form>\n\n";

# Get categories
my $categs = $m->fetchAllHash("
	SELECT * FROM categories ORDER BY pos");

# Print category list
print
	"<table class='tbl'>\n",
	"<tr class='hrw'><th>Title</th><th>Position</th><th>Commands</th>\n",
	"</tr>\n";

for my $categ (@$categs) {
	my $optUrl = $m->url('categ_options', cid => $categ->{id});
	my $delUrl = $m->url('user_confirm', cid => $categ->{id}, script => 'categ_delete', 
		name => $categ->{title});
	print
		"<tr class='crw'>\n",
		"<td>$categ->{title}</td>\n",
		"<td class='shr'>$categ->{pos}</td>\n",
		"<td class='shr'>\n",
		"<a class='btl' href='$optUrl'>Options</a>\n",
		"<a class='btl' href='$delUrl'>Delete</a>\n",
		"</td>\n",
		"</tr>\n";
}

print "</table>\n\n";

# Log action and finish
$m->logAction(3, 'categ', 'admin', $userId);
$m->printFooter();
$m->finish();
