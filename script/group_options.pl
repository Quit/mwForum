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
my $title = $m->paramStr('title');
my $badge = $m->paramStrId('badge');
my $public = $m->paramBool('public');
my $open = $m->paramBool('open');
my $submitted = $m->paramBool('subm');
$groupId or $m->error('errParamMiss');

# Get group
my $group = $m->fetchHash("
	SELECT * FROM groups WHERE id = ?", $groupId);
$group or $m->error('errGrpNotFnd');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Check title
	$title or $m->formError("Title is empty.");

	# Check badge
	if ($badge) {
		my $badgeExists = 0;
		for my $line (@{$cfg->{badges}}) {
			my ($id, $type) = $line =~ /(\w+)\s+(\w+)/;
			$badgeExists = 1 if $id eq $badge && $type eq 'group';
		}
		$badgeExists or $m->formError("Badge doesn't exist or isn't meant for groups.");
		my $badgeUsed = $m->fetchArray("
			SELECT 1 FROM groups WHERE badge = ? AND id <> ?", $badge, $groupId);
		!$badgeUsed or $m->formError("Badge is already used by a different group.");
	}

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update group
		my $titleEsc = $m->escHtml($title);
		$m->dbDo("
			UPDATE groups SET title = ?, badge = ?, public = ?, open = ? WHERE id = ?",
			$titleEsc, $badge, $public, $open, $groupId);

		# Handle user badges			
		if (@{$cfg->{badges}}) {
			# Remove old badges
			$m->dbDo("
				DELETE FROM userBadges 
				WHERE userId IN (SELECT userId FROM groupMembers WHERE groupId = :groupId)
					AND badge = :badge",
				{ groupId => $groupId, badge => $group->{badge} })
				if $group->{badge};

			# Award badges to members
			$m->dbDo("
				INSERT INTO userBadges (userId, badge) 
				SELECT userId, :badge FROM groupMembers WHERE groupId = :groupId",
				{ badge => $badge, groupId => $groupId })
				if $badge;
		}
		
		# Log action and finish
		$m->logAction(1, 'group', 'options', $userId, 0, 0, 0, $groupId);
		$m->redirect('group_admin');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('group_admin'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Group", subTitle => $group->{title}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Get badges
	my @badges = ();
	for my $line (@{$cfg->{badges}}) {
		my ($id, $type) = $line =~ /(\w+)\s+(\w+)/;
		push @badges, $id if $type eq 'group';
	}
	
	# Set submitted or database values
	my $titleEsc = $submitted ? $m->escHtml($title) : $group->{title};
	$badge = $submitted ? $badge : $group->{badge};
	$public = $submitted ? $public : $group->{public};
	$open = $submitted ? $open : $group->{open};

	# Determine checkbox, radiobutton and listbox states
	my $publicChk = $public ? 'checked' : "";
	my $openChk = $open ? 'checked' : "";
	my %state = ( "badge$badge" => 'selected' );

	# Print options form
	print
		"<form action='group_options$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Options</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>Title (50 chars)\n",
		"<input type='text' class='hwi' name='title' maxlength='50' value='$titleEsc'",
		" autofocus required></label>\n",
		"<label class='lbw'>Badge\n",
		"<select name='badge' size='1'>\n",
		"<option value=''>(none)</option>\n",
		map("<option value='$_' $state{\"badge$_\"}>$_</option>\n", @badges),
		"</select></label>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<div><label><input type='checkbox' name='public' $publicChk>",
		" Public (non-members can see group info page)</label></div>\n",
		"<div><label><input type='checkbox' name='open' $openChk>",
		" Open (users can join themselves)</label></div>\n",
		"</fieldset>\n",
		$m->submitButton("Change", 'admopt'),
		"<input type='hidden' name='gid' value='$groupId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'group', 'options', $userId, 0, 0, 0, $groupId);
	$m->printFooter();
}
$m->finish();
