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
$m->cacheUserStatus() if $userId;

# Print header
$m->printHeader();

# Get CGI parameters
my $postId = $m->paramInt('pid');
$postId or $m->error('errParamMiss');

# Get branch base post
my ($boardId, $topicId, $parentId) = $m->fetchArray("
	SELECT boardId, topicId, parentId FROM posts WHERE id = ?", $postId);
$boardId or $m->error('errPstNotFnd');

# Get topic base post
my $basePostId = $m->fetchArray("
	SELECT basePostId FROM topics WHERE id = ?", $topicId);
$basePostId or $m->error('errTpcNotFnd');
$basePostId != $postId or $m->error('errPromoTpc');
my $newParentId = $parentId ? 0 : $basePostId;

# Get board
my $board = $m->fetchHash("
	SELECT flat, topicAdmins FROM boards WHERE id = ?", $boardId);

# Check if user is admin or moderator
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId);
my $topicAdmin = $board->{topicAdmins} && $m->topicAdmin($userId, $topicId);
$user->{admin} || $boardAdmin || $topicAdmin or $m->error('errNoAccess');

# Print page bar
my @navLinks = ({ url => $m->url('topic_show', pid => $postId), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{brnTitle}, navLinks => \@navLinks);

# Get boards
my $boards = $m->fetchAllHash("
	SELECT boards.*,
		categories.title AS categTitle
	FROM boards AS boards
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
	ORDER BY categories.pos, boards.pos");
@$boards = grep($m->boardVisible($_) && $m->boardWritable($_), @$boards);

# Print promotion form
if ($boardAdmin) {
	my %state = ( $boardId => 'selected' );
	print
		"<form action='branch_promote$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{brnPromoTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{brnPromoSbj}\n",
		"<input type='text' class='fwi' name='subject' maxlength='$cfg->{maxSubjectLen}'",
		" autofocus required></label>\n",
		"<label class='lbw'>$lng->{brnPromoBrd}\n",
		"<select name='bid' size='1'>\n",
		map("<option value='$_->{id}' $state{$_->{id}}>$_->{categTitle} / $_->{title}</option>\n", @$boards),
		"</select></label>\n",
		"</fieldset>\n";
		
	print
		"<fieldset>\n",
		"<label><input type='checkbox' name='link' checked>$lng->{brnPromoLink}</label>\n",
		"</fieldset>\n"
		if !$board->{flat};
			
	print
		$m->submitButton('brnPromoB', 'topic'),
		"<input type='hidden' name='pid' value='$postId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
}

# Print move branch form
print
	"<form action='branch_move$m->{ext}' method='post'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{brnMoveTtl}</span></div>\n",
	"<div class='ccl'>\n",
	"<label class='lbw'>$lng->{brnMovePrnt}\n",
	"<input type='number' name='parent' value='$newParentId'></label>",
	$m->submitButton('brnMoveB', 'move'),
	"<input type='hidden' name='pid' value='$postId'>\n",
	$m->stdFormFields(),
	"</div>\n",
	"</div>\n",
	"</form>\n\n"
	if $boardAdmin;

# Print lock form
print
	"<form action='branch_lock$m->{ext}' method='post'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{brnLockTtl}</span></div>\n",
	"<div class='ccl'>\n",
	"<div>\n",
	$m->submitButton('brnLockLckB', 'lock', 'lock'),
	$m->submitButton('brnLockUnlB', 'lock', 'unlock'),
	"</div>\n",
	"<input type='hidden' name='pid' value='$postId'>\n",
	$m->stdFormFields(),
	"</div>\n",
	"</div>\n",
	"</form>\n\n"
	if !$board->{flat};

# Print delete form
print
	"<form action='branch_delete$m->{ext}' method='post'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{brnDeleteTtl}</span></div>\n",
	"<div class='ccl'>\n",
	$m->submitButton('brnDeleteB', 'delete'),
	"<input type='hidden' name='pid' value='$postId'>\n",
	$m->stdFormFields(),
	"</div>\n",
	"</div>\n",
	"</form>\n\n"
	if !$board->{flat};

# Log action and finish
$m->logAction(3, 'branch', 'admin', $userId, $boardId, $topicId, $postId);
$m->printFooter();
$m->finish();
