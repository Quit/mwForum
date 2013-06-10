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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new(@_);

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Get CGI parameters
my $field = $m->paramStrId('field') || $m->getVar('brdAdmFld', $userId) || 'pos';;
my $sort = $m->paramStrId('sort') || $m->getVar('brdAdmSrt', $userId) || 'categPos';
my $order = $m->paramStrId('order') || $m->getVar('brdAdmOrd', $userId) || 'asc';

# Define values and names for selectable fields
my %fields = (
	pos => "Position",
	categoryId => "Category ID",
	shortDesc => "Short Description",
	longDesc => "Long Description",
	private => "Read Access",
	announce => "Write Access",
	unregistered => "Unregistered",
	approve => "Moderation",
	flat => "Non-Threaded",
	attach => "Attachments",
	locking => "Topic Locking",
	expiration => "Topic Expiration",
	list => "List If Inaccessible",
);

# Enforce valid options
$field = 'categoryId' if !$fields{$field};
$sort = 'categPos' if $sort !~ /^(?:categPos|title|id|field)\z/;
$order = 'desc' if $order !~ /^(?:asc|desc)\z/;

# Save options
$m->setVar('brdAdmFld', $field, $userId);
$m->setVar('brdAdmSrt', $sort, $userId);
$m->setVar('brdAdmOrd', $order, $userId);

# Print page bar
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => "Board Administration", navLinks => \@navLinks);

# Print create board form
print
	"<form action='board_add$m->{ext}' method='post'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Create Board</span></div>\n",
	"<div class='ccl'>\n",
	$m->submitButton("Create", 'board'),
	$m->stdFormFields(),
	"</div>\n",
	"</div>\n",
	"</form>\n\n";

# Determine checkbox, radiobutton and listbox states
my %state = ( $sort => 'selected', $order => 'selected', "field$field" => 'selected' );

# Print board list form
print
	"<form action='board_admin$m->{ext}' method='get'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>List Boards</span></div>\n",
	"<div class='ccl'>\n",
	"<div class='cli'>\n",
	"<label>Field\n",
	"<select name='field' size='1'>\n",
	map("<option value='$_' $state{\"field$_\"}>$fields{$_}</option>\n",
		sort({$fields{$a} cmp $fields{$b}} keys(%fields))),
	"</select></label>\n",
	"<label>Sort\n",
	"<select name='sort' size='1'>\n",
	"<option value='categPos' $state{categPos}>Categ/Pos</option>\n",
	"<option value='title' $state{title}>Title</option>\n",
	"<option value='id' $state{id}>ID</option>\n",
	"<option value='field' $state{field}>Field</option>\n",
	"</select></label>\n",
	"<label>Order\n",
	"<select name='order' size='1'>\n",
	"<option value='asc' $state{asc}>Ascending</option>\n",
	"<option value='desc' $state{desc}>Descending</option>\n",
	"</select></label>\n",
	$m->submitButton("List", 'search'),
	"</div>\n",
	"</div>\n",
	"</div>\n",
	"</form>\n\n";
	
# Sort list by
if ($sort eq 'field') { 
	$sort = $field;
}
elsif ($sort eq 'categPos') { 
	$sort = "categories.pos, boards.pos";
	$order = "";
}

# Get boards
my $boards = $m->fetchAllHash("
	SELECT boards.id, boards.title, boards.$field, 
		categories.title AS categTitle
	FROM boards AS boards
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
	ORDER BY $sort $order");

# Print board list
print
	"<table class='tbl'>\n",
	"<tr class='hrw'><th>Title</th><th>$field</th><th>Commands</th></tr>\n";

for my $board (@$boards) {
	my $boardId = $board->{id};
	my $nameStr = $m->abbr($board->{categTitle}, 30) . " / " . $m->abbr($board->{title}, 30);
	my $infUrl = $m->url('board_info', bid => $boardId);
	my $optUrl = $m->url('board_options', bid => $boardId, ori => 1);
	my $grpUrl = $m->url('board_groups', bid => $boardId, ori => 1);
	my $delUrl = $m->url('user_confirm', bid => $boardId, script => 'board_delete', 
		name => $board->{title}, ori => 1);
	print
		"<tr class='crw'>\n",
		"<td><a href='$infUrl'>$nameStr</a></td>\n",
		"<td>$board->{$field}</td>\n",
		"<td class='shr'>\n",
		"<a class='btl' href='$optUrl'>Opt</a>\n",
		"<a class='btl' href='$grpUrl'>Grp</a>\n",
		"<a class='btl' href='$delUrl'>Del</a>\n",
		"</td></tr>\n";
}

print "</table>\n\n";

# Log action and finish
$m->logAction(3, 'board', 'admin', $userId);
$m->printFooter();
$m->finish();
