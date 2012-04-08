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

# Get CGI parameters
my $groupId = $m->paramInt('gid');
my $submitted = $m->paramBool('subm');

# Get group name
my $groupTitle = $m->fetchArray("
	SELECT title FROM groups WHERE id = ?", $groupId);
$groupTitle or $m->error('errGrpNotFnd');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		my $boards = $m->fetchAllHash("
			SELECT id FROM boards");
		for my $board (@$boards) {
			# Update group moderator status
			my $set = $m->paramBool("admin_$board->{id}");
			$m->setRel($set, 'boardAdminGroups', 'groupId', 'boardId', $groupId, $board->{id});
				
			# Update group membership
			$set = $m->paramBool("member_$board->{id}");
			$m->setRel($set, 'boardMemberGroups', 'groupId', 'boardId', $groupId, $board->{id});
		}
		
		# Log action and finish
		$m->logAction(1, 'group', 'boards', $userId, 0, 0, 0, $groupId);
		$m->redirect('group_admin');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('group_admin'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Group", subTitle => $groupTitle, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Print board permissions table
	print 
		"<form action='group_boards$m->{ext}' method='post'>\n",
		"<table class='tbl'>\n",
		"<tr class='hrw'>\n",
		"<th colspan='3'>Board Permissions</th>\n",
		"</tr>\n";
		
	# Get boards including group status
	my $boards = $m->fetchAllHash("
		SELECT boards.id, boards.title,
			categories.title AS categTitle,
			boardAdminGroups.groupId IS NOT NULL AS admin,
			boardMemberGroups.groupId IS NOT NULL AS member
		FROM boards AS boards
			INNER JOIN categories AS categories
				ON categories.id = boards.categoryId
			LEFT JOIN boardAdminGroups AS boardAdminGroups
				ON boardAdminGroups.groupId = :groupId
				AND boardAdminGroups.boardId = boards.id
			LEFT JOIN boardMemberGroups AS boardMemberGroups
				ON boardMemberGroups.groupId = :groupId
				AND boardMemberGroups.boardId = boards.id
		ORDER BY categories.pos, boards.pos",
		{ groupId => $groupId });

	# Print board list
	for my $board (@$boards) {
		my $boardId = $board->{id};
		my $admin = $board->{admin} ? "checked='checked'" : '';
		my $member = $board->{member} ? "checked='checked'" : '';
		my $url = $m->url('board_info', bid => $boardId);
		print
			"<tr class='crw'>\n",
			"<td>$board->{categTitle} / <a href='$url'>$board->{title}</a></td>\n",
			"<td class='shr'><label>",
			"<input type='checkbox' class='fcs' name='admin_$boardId'",
			" autofocus='autofocus' $admin/>Moderator</label></td>\n",
			"<td class='shr'><label>",
			"<input type='checkbox' name='member_$boardId' $member/>Member</label></td>\n",
			"</tr>\n";
	}
	
	print "</table>\n\n";

	# Print submit section
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Change Permissions</span></div>\n",
		"<div class='ccl'>\n",
		$m->submitButton("Change", 'admopt'),
		"<input type='hidden' name='gid' value='$groupId'/>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'group', 'boards', $userId, 0, 0, 0, $groupId);
	$m->printFooter();
}
$m->finish();
