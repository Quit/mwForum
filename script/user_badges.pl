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

# Check if access should be denied
@{$cfg->{badges}} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Check if there are user-selectable badges
my $selfBadge = 0;
for my $line (@{$cfg->{badges}}) {
	my ($type) = $line =~ /\w+\s+(\w+)/;
	if ($type eq 'user') { $selfBadge = 1; last }
}
$selfBadge || $user->{admin} or $m->error('errNoAccess');

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
		# Update badges
		for my $line (@{$cfg->{badges}}) {
			my ($id, $type) = $line =~ /(\w+)\s+(\w+)/;
			next if !($type eq 'user' || $type eq 'admin' && $user->{admin});
			my $set = $m->paramBool("badge_$id");
			$m->setRel($set, 'userBadges', 'userId', 'badge', $optUserId, $id);
		}

		# Log action and finish
		$m->logAction(1, 'user', 'badges', $userId, 0, 0, 0, $optUserId);
		$m->redirect('user_profile', uid => $optUserId, msg => 'BdgChange');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_profile', uid => $optUserId), 
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{bdgTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Get badges
	my $userBadges = $m->fetchAllArray("
		SELECT badge FROM userBadges WHERE userId = ?", $optUserId);

	# Print badge table
	print
		"<form action='user_badges$m->{ext}' method='post'>\n",
		"<table class='tbl'>\n",
		"<tr class='hrw'>\n",
		"<th colspan='2'>$lng->{bdgSelTtl}</th>\n",
		"</tr>\n";

	# Print badge list
	for my $line (@{$cfg->{badges}}) {
		my ($id, $type, $smallIcon, $bigIcon, $title, $description) = 
			$line =~ /(\w+)\s+(\w+)\s+(\S+)\s+(\S+)\s+"([^"]+)"\s+"([^"]+)"/;
		next if !($type eq 'user' || $type eq 'admin' && $user->{admin});
		my $chk = grep($_->[0] eq $id, @$userBadges) ? 'checked' : "";
		my $icon = $smallIcon ne '-' ? $smallIcon : $bigIcon;
		print
			"<tr class='crw'>\n",
			"<td class='hco'><label>\n",
			"<input type='checkbox' name='badge_$id' $chk>\n",
			"<img class='ubs' src='$cfg->{dataPath}/$icon' alt=''> $title</label></td>\n",
			"<td>$description</td>\n",
			"</tr>\n";
	}

	print "</table>\n\n";

	# Print submit section
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{bdgSubmitTtl}</span></div>\n",
		"<div class='ccl'>\n",
		$m->submitButton('bdgSubmitB', 'tag'),
		"<input type='hidden' name='uid' value='$optUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'user', 'badges', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
