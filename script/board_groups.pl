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

# Get CGI parameters
my $boardId = $m->paramInt('bid');
my $submitted = $m->paramBool('subm');

# Check if user is admin or moderator
$user->{admin} || $m->boardAdmin($userId, $boardId) or $m->error('errNoAccess');

# Get board name
my $boardTitle = $m->fetchArray("
	SELECT title FROM boards WHERE id = ?", $boardId);
$boardTitle or $m->error('errBrdNotFnd');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		my $groups = $m->fetchAllHash("
			SELECT id FROM groups");
		for my $group (@$groups) {
			# Update group moderator status
			my $set = $m->paramBool("admin_$group->{id}");
			$m->setRel($set, 'boardAdminGroups', 'groupId', 'boardId', $group->{id}, $boardId)
				if $user->{admin};

			# Update group membership
			$set = $m->paramBool("member_$group->{id}");
			$m->setRel($set, 'boardMemberGroups', 'groupId', 'boardId', $group->{id}, $boardId);
		}
		
		# Log action and finish
		$m->logAction(1, 'board', 'groups', $userId, $boardId);
		$m->redirect('board_admin');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('board_show', bid => $boardId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{bgrTitle}, subTitle => $boardTitle, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Get groups including board status
	my $groups = $m->fetchAllHash("
		SELECT groups.id, groups.title,
			boardAdminGroups.groupId IS NOT NULL AS admin,
			boardMemberGroups.groupId IS NOT NULL AS member
		FROM groups AS groups
			LEFT JOIN boardAdminGroups AS boardAdminGroups
				ON boardAdminGroups.groupId = groups.id
				AND boardAdminGroups.boardId = :boardId
			LEFT JOIN boardMemberGroups AS boardMemberGroups
				ON boardMemberGroups.groupId = groups.id
				AND boardMemberGroups.boardId = :boardId
		ORDER BY groups.title",
		{ boardId => $boardId });

	# Print board status table
	print 
		"<form action='board_groups$m->{ext}' method='post'>\n",
		"<table class='tbl'>\n",
		"<tr class='hrw'><th colspan='3'>$lng->{bgrPermTtl}</th></tr>\n";
		
	# Print group list
	for my $group (@$groups) {
		my $adminChk = $group->{admin} ? 'checked' : "";
		my $memberChk = $group->{member} ? 'checked' : "";
		my $url = $m->url('group_info', gid => $group->{id});
		print
			"<tr class='crw'>\n",
			"<td><a href='$url'>$group->{title}</a></td>\n";

		print
			"<td class='shr'><label>",
			"<input type='checkbox' name='admin_$group->{id}' $adminChk>$lng->{bgrModerator}",
			"</label></td>\n"
			if $user->{admin};

		print
			"<td class='shr'><label>",
			"<input type='checkbox' name='member_$group->{id}' $memberChk>$lng->{bgrMember}",
			"</label></td>\n",
			"</tr>\n";
	}
	
	print "</table>\n\n";

	# Print submit section
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{bgrChangeTtl}</span></div>\n",
		"<div class='ccl'>\n",
		$m->submitButton('bgrChangeB', 'group'),
		"<input type='hidden' name='bid' value='$boardId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'board', 'groups', $userId, $boardId);
	$m->printFooter();
}
$m->finish();
