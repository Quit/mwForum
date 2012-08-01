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

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Get CGI parameters
my $mode = $m->paramStrId('mode') || "";
my $page = $m->paramInt('pg') || 1;
my $search = $m->paramStr('search') || "";
my $field = $m->paramStrId('field') || 'action';
my $sort = $m->paramStrId('sort') || 'id';
my $order = $m->paramStrId('order') || 'desc';

# Define values and names for selectable fields
my %fields = (
	level => "Level",
	entity => "Entity",
	action => "Action",
	userId => "User ID",
	boardId => "Board ID",
	topicId => "Topic ID",
	postId => "Post ID",
	extraId => "Other ID",
	ip => "IP Address",
	string => "String",
);

# Enforce valid options
$field = 'action' if !$fields{$field};
$sort = 'id' if $sort !~ /^(?:id|field)\z/;
$order = 'desc' if $order !~ /^(?:asc|desc)\z/;

# Preserve parameters in links
my @params = ( mode => $mode, search => $search, field => $field, sort => $sort, order => $order );

# Search for
my $fieldCast = $m->{pgsql} ? "CAST($field AS VARCHAR)" : $field;
my $searchEsc = $m->escHtml($search);
my $searchLike = $m->dbEscLike($searchEsc);
my $searchStr = $search ? "WHERE $fieldCast = :search" : "";

# Sort list by
my $orderStr = "";
if ($sort eq 'field') { $orderStr = "$field $order, id DESC" }
else { $orderStr = "id $order" }

# Get ids of log lines
my $lines = [];
if ($mode eq 'searches') {
	$lines = $m->fetchAllArray("
		SELECT id 
		FROM log
		WHERE entity = 'forum'
			AND action = 'search'
			AND string <> ''
		ORDER BY $orderStr
		LIMIT 2000");
}
else {
	$lines = $m->fetchAllArray("
		SELECT id FROM log $searchStr ORDER BY $orderStr LIMIT 2000", { search => $search });
}

# Print page bar
my $linesPP = 100;
my $pageNum = int(@$lines / $linesPP) + (@$lines % $linesPP != 0);
my @pageLinks = $pageNum < 2 ? () : $m->pageLinks('log_admin', \@params, $page, $pageNum);
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
my @adminLinks = ();
push @adminLinks, { url => $m->url('log_admin', mode => 'searches'),
	txt => "Searches", ico => 'search' };
push @adminLinks, { url => $m->url('log_delete'),
	txt => "Delete", ico => 'delete' };
$m->printPageBar(mainTitle => "Log", navLinks => \@navLinks, pageLinks => \@pageLinks,
	adminLinks => \@adminLinks);

# Get lines on page
my @pageLines = @$lines[($page - 1) * $linesPP .. $m->min($page * $linesPP, scalar @$lines) - 1];
my @pageLineIds = map($_->[0], @pageLines);
$lines = $m->fetchAllArray("
	SELECT id, level, entity, action, userId, boardId, topicId, postId, extraId, logTime, ip, string
	FROM log 
	WHERE id IN (:pageLineIds) 
	ORDER BY $orderStr",
	{ pageLineIds => \@pageLineIds });

# Determine checkbox, radiobutton and listbox states
my %state = ( $sort => 'selected', $order => 'selected', "field$field" => 'selected' );

# Print log list form
print
	"<form action='log_admin$m->{ext}' method='get'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>List Log Entries</span></div>\n",
	"<div class='ccl'>\n",
	"<div class='cli'>\n",
	"<label>Field\n",
	"<select name='field' size='1'>\n",
	map("<option value='$_' $state{\"field$_\"}>$fields{$_}</option>\n",
		sort({$fields{$a} cmp $fields{$b}} keys(%fields))),
	"</select></label>\n",
	"<label>Sort\n",
	"<select name='sort' size='1'>\n",
	"<option value='id' $state{id}>ID</option>\n",
	"<option value='field' $state{field}>Field</option>\n",
	"</select></label>\n",
	"<label>Order\n",
	"<select name='order' size='1'>\n",
	"<option value='desc' $state{desc}>Desc</option>\n",
	"<option value='asc' $state{asc}>Asc</option>\n",
	"</select></label>\n",
	"<label>Search\n",
	"<input type='text' name='search' style='width: 150px' value='$searchEsc'></label>\n",
	$m->submitButton('List', 'search'),
	"</div>\n",
	"</div>\n",
	"</div>\n",
	"</form>\n\n";

# Print log list header
print
	"<table class='tbl btb'>\n",
	"<tr class='hrw'>\n",
	"<th>ID</th>\n",
	"<th>Time</th>\n",
	"<th>Lvl</th>\n",
	"<th>Entity</th>\n",
	"<th>Action</th>\n",
	"<th>IP Address</th>\n",
	"<th>User</th>\n",
	"<th>Board</th>\n",
	"<th>Topic</th>\n",
	"<th>Post</th>\n",
	"<th>Other</th>\n",
	"<th>String</th>\n",
	"</tr>\n";

# Print log list
for my $line (@$lines) {
	my ($id, $level, $entity, $action, $logUserId, $boardId, $topicId, $postId, $extraId, $logTime, 
		$ip, $string) = @$line;
	$logTime = $m->formatTime($logTime, $user->{timezone}, "%Y-%m-%d %H:%M:%S");
	$logUserId = $logUserId
		? "<a href='" . $m->url('user_info', uid => $logUserId) . "'>$logUserId</a>" : "";
	$boardId = $boardId
		? "<a href='" . $m->url('board_show', bid => $boardId) . "'>$boardId</a>" : "";
	$topicId = $topicId
		? "<a href='" . $m->url('topic_show', tid => $topicId) . "'>$topicId</a>" : "";
	$postId = $postId
		? "<a href='" . $m->url('topic_show', pid => $postId) . "'>$postId</a>" : "";
	$extraId = $extraId ? $extraId : "";
	$string = $string && $entity eq 'forum' && $action eq 'search'
		? "<a href='" . $m->url('forum_search', words => $m->deescHtml($string), pg => 1)
		. "'>$string</a>" : $string;
	print
		"<tr class='crw'>\n",
		"<td>$id</td>\n",
		"<td>$logTime</td>\n",
		"<td>$level</td>\n",
		"<td>$entity</td>\n",
		"<td>$action</td>\n",
		"<td>$ip</td>\n",
		"<td>$logUserId</td>\n",
		"<td>$boardId</td>\n",
		"<td>$topicId</td>\n",
		"<td>$postId</td>\n",
		"<td>$extraId</td>\n",
		"<td>$string</td>\n",
		"</tr>\n";
}

print "</table>\n\n";

# Log action and finish
$m->printFooter();
$m->finish();
