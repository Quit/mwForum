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
my $wipeUserId = $m->paramInt('uid');
my $submitted = $m->paramBool('subm');
$wipeUserId or $m->error('errParamMiss');

# Get user
my $wipeUser = $m->getUser($wipeUserId);
$wipeUser or $m->error('errUsrNotFnd');
!$wipeUser->{admin} or $m->error("Wiping admins is not allowed for security reasons.");

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Wipe user
		$m->deleteUser($wipeUserId, 1);

		# Log action and finish
		$m->logAction(1, 'user', 'wipe', $userId, 0, 0, 0, $wipeUserId);
		$m->redirect('user_info', uid => $wipeUserId);
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_info', uid => $wipeUserId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "User", subTitle => $wipeUser->{userName}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints([
		"Wiping a user account means clearing all profile fields, resetting Email, Password and OpenID".
		" (making login impossible), and deleting various related entries from other database tables.".
		" The account itself remains, and the Real Name, Email and OpenID fields will be copied into".
		" the Comments field (only visible to admins). Useful when a user wants to be deleted, but".
		" when that is undesirable for accountability reasons."]);
	$m->printFormErrors();

	# Print notification message form
	print
		"<form action='user_wipe$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Wipe User</span></div>\n",
		"<div class='ccl'>\n",
		$m->submitButton("Wipe", 'wipe'),
		"<input type='hidden' name='uid' value='$wipeUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'user', 'wipe', $userId, 0, 0, 0, $wipeUserId);
	$m->printFooter();
}
$m->finish();
