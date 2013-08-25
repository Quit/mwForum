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

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		my $openStr = $user->{admin} ? "" : "WHERE open = 1";
		my $groups = $m->fetchAllArray("
			SELECT id FROM groups $openStr");
		for my $group (@$groups) {
			# Update group adminship
			my $set = $m->paramBool("admin_$group->[0]");
			$m->setRel($set, 'groupAdmins', 'userId', 'groupId', $optUserId, $group->[0])
				if $user->{admin};

			# Update group membership
			$set = $m->paramBool("member_$group->[0]");
			$m->setRel($set, 'groupMembers', 'userId', 'groupId', $optUserId, $group->[0]);
		}

		# Update user badges awarded by group membership
		if (@{$cfg->{badges}}) {
			$m->dbDo("
				DELETE FROM userBadges 
				WHERE userId = :optUserId
					AND badge IN (SELECT badge FROM groups WHERE badge <> '')",
				{ optUserId => $optUserId });
			$m->dbDo("
				INSERT INTO userBadges (userId, badge) 
				SELECT :optUserId, groups.badge 
				FROM groups AS groups
					INNER JOIN groupMembers AS groupMembers
						ON groupMembers.userId = :optUserId	
						AND groupMembers.groupId = groups.id
				WHERE groups.badge <> ''",
				{ optUserId => $optUserId });
		}
		
		# Log action and finish
		$m->logAction(1, 'user', 'groups', $userId, 0, 0, 0, $optUserId);
		$m->redirect('user_options', uid => $optUserId, msg => 'GrpChange');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_options', uid => $optUserId), 
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{ugrTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Get groups including status
	my $openStr = $user->{admin} ? "" : "WHERE groups.open = 1";
	my $groups = $m->fetchAllHash("
		SELECT groups.id, groups.title, groups.public,
			groupAdmins.userId IS NOT NULL AS admin,
			groupMembers.userId IS NOT NULL AS member
		FROM groups AS groups
			LEFT JOIN groupAdmins AS groupAdmins
				ON groupAdmins.userId = :optUserId
				AND groupAdmins.groupId = groups.id
			LEFT JOIN groupMembers AS groupMembers
				ON groupMembers.userId = :optUserId
				AND groupMembers.groupId = groups.id
		$openStr
		ORDER BY groups.title",
		{ optUserId => $optUserId });
	
	# Print group status table
	my $colspan = $user->{admin} ? 3 : 2;	
	print 
		"<form action='user_groups$m->{ext}' method='post'>\n",
		"<table class='tbl'>\n",
		"<tr class='hrw'><th colspan='$colspan'>$lng->{ugrGrpStTtl}</th></tr>\n";
		
	# Print group list
	for my $group (@$groups) {
		my $groupId = $group->{id};
		my $adminChk = $group->{admin} ? 'checked' : "";
		my $memberChk = $group->{member} ? 'checked' : "";
		my $url = $m->url('group_info', gid => $groupId);
		my $title = $group->{public} || $group->{admin} || $group->{member} || $user->{admin}
			? "<a href='$url'>$group->{title}</a>" : $group->{title};
		print
			"<tr class='crw'>\n",
			"<td>$title</td>\n";

		print			
			"<td class='shr'><label><input type='checkbox' name='admin_$groupId' $adminChk>",
			"$lng->{ugrGrpStAdm}</label></td>\n"
			if $user->{admin};

		print
			"<td class='shr'><label><input type='checkbox' name='member_$groupId' $memberChk>",
			"$lng->{ugrGrpStMbr}</label></td>\n",
			"</tr>\n";
	}
	
	print "</table>\n\n";

	# Print submit section
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{ugrSubmitTtl}</span></div>\n",
		"<div class='ccl'>\n",
		$m->submitButton('ugrChgB', 'group'),
		"<input type='hidden' name='uid' value='$optUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'user', 'groups', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
