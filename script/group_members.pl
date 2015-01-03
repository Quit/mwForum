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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0], autocomplete => 1);

# Get CGI parameters
my $groupId = $m->paramInt('gid');
my @userIds = $m->paramInt('uid');
my $userNames = $m->paramStr('userNames');
my $action = $m->paramStrId('act');
my $submitted = $m->paramBool('subm');
$groupId or $m->error('errParamMiss');

# Get group
my ($title, $badge) = $m->fetchArray("
	SELECT title, badge FROM groups WHERE id = ?", $groupId);
length($title) or $m->error('errGrpNotFnd');

# Check if user is admin or group admin
my $groupAdmin = $m->fetchArray("
	SELECT 1 FROM groupAdmins WHERE userId = ? AND groupId = ?", $userId, $groupId);
$user->{admin} || $groupAdmin or $m->error('errNoAccess');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Process add member form
	if ($action eq 'add') {
		# Split/expand user/group names
		if ($userNames) {
			my @userNames = split(/\s*[;,]\s*/, $userNames);
			@userNames or $m->formError('errUsrNotFnd');
			$userNames = join("; ", @userNames);
			for my $name (@userNames) {
				if (substr($name, 0, 1) eq '!') {
					my @ids = $m->getMemberIds($name);
					@ids or $m->formError(substr($name, 1) . ": $lng->{errGrpNotFnd}");
					push @userIds, @ids;
				}
				else {
					my $id = $m->fetchArray("
						SELECT id FROM users WHERE userName = ?", $name);
					if ($id) { push @userIds, $id }
					else { $m->formError("$name: $lng->{errUsrNotFnd}") }
				}
			}
		}

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Add membership and badge
			for my $id (@userIds) {
				$m->setRel(1, 'groupMembers', 'userId', 'groupId', $id, $groupId);
				$m->setRel(1, 'userBadges', 'userId', 'badge', $id, $badge) if $badge;
			}

			# Log action and finish
			my $memberId = @userIds == 1 ? $userIds[0] : -1;
			$m->logAction(1, 'group', 'addmembr', $userId, 0, 0, 0, $memberId);
			$m->redirect('group_members', gid => $groupId, msg => 'MemberAdd');
		}
	}
	# Process remove member form
	elsif ($action eq 'remove') {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Remove membership and badge
			for my $id (@userIds) {
				$m->setRel(0, 'groupMembers', 'userId', 'groupId', $id, $groupId);
				$m->setRel(0, 'userBadges', 'userId', 'badge', $id, $badge) if $badge;
			}

			# Log action and finish
			my $memberId = @userIds == 1 ? $userIds[0] : -1;
			$m->logAction(1, 'group', 'remmembr', $userId, 0, 0, 0, $memberId);
			$m->redirect('group_members', gid => $groupId, msg => 'MemberRem');
		}
	}
	else { $m->error('errParamMiss') }
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('group_info', gid => $groupId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{grmTitle}, subTitle => $title, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Prepare values
	my $userNamesEsc = $m->escHtml($userNames);

	# Print add form
	print
		"<form action='group_members$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{grmAddTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>$lng->{grmAddUser}\n",
		"<input type='text' class='hwi acu acm' name='userNames' value='$userNamesEsc'",
		" autofocus required></label>\n",
		$m->submitButton('grmAddB', 'user'),
		"<input type='hidden' name='gid' value='$groupId'>\n",
		"<input type='hidden' name='act' value='add'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Get members
	my $members = $m->fetchAllArray("
		SELECT users.id, users.userName
		FROM users AS users
			INNER JOIN groupMembers AS groupMembers
				ON groupMembers.userId = users.id
				AND groupMembers.groupId = :groupId
			LEFT JOIN groupAdmins AS groupAdmins
				ON groupAdmins.userId = users.id
				AND groupAdmins.groupId = :groupId
		WHERE groupAdmins.userId IS NULL
		ORDER BY users.userName",
		{ groupId => $groupId });
	
	if (@$members) {
		# Print remove form
		print
			"<form action='group_members$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{grmRemTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<label class='lbw'>$lng->{grmRemUser}\n",
			"<select name='uid' size='10' multiple='multiple'>\n",
			map("<option value='$_->[0]'>$_->[1]</option>\n", @$members),
			"</select></label>\n",
			$m->submitButton('grmRemB', 'remove'),
			"<input type='hidden' name='gid' value='$groupId'>\n",
			"<input type='hidden' name='act' value='remove'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}
	
	# Log action and finish
	$m->logAction(3, 'group', 'members', $userId, 0, 0, 0, $groupId);
	$m->printFooter();
}
$m->finish();
