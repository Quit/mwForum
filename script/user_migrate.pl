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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0], autocomplete => 1);

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Get CGI parameters
my $oldUserId = $m->paramInt('uid');
my $newUserId = $m->paramInt('newUserId');
my $userName = $m->paramStr('userName');
my $submitted = $m->paramBool('subm');
$oldUserId or $m->error('errParamMiss');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Check if old users exist
	$m->fetchArray("
		SELECT id FROM users WHERE id = ?", $oldUserId) 
		or $m->formError('errUsrNotFnd');

	# Check if user exists or get user id from name
	if ($newUserId) {
		$m->fetchArray("
			SELECT 1 FROM users WHERE id = ?", $newUserId) 
			or $m->formError('errUsrNotFnd');
	}
	else {	
		$newUserId = $m->fetchArray("
			SELECT id FROM users WHERE userName = ?", $userName);
		$newUserId or $m->formError('errUsrNotFnd');
	}
	
	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Change ownership of posts
		$m->dbDo("
			UPDATE posts SET userId = ?, userNameBak = ? WHERE userId = ?",
			$newUserId, $userName, $oldUserId);

		# Change ownership of messages
		$m->dbDo("
			UPDATE messages SET senderId = ? WHERE senderId = ?", $newUserId, $oldUserId);
		$m->dbDo("
			UPDATE messages SET receiverId = ? WHERE receiverId = ?", $newUserId, $oldUserId);
		
		# Log action and finish
		$m->logAction(1, 'user', 'migrate', $userId, 0, 0, 0, $newUserId);
		$m->redirect('user_info', uid => $oldUserId);
	}
}


# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Check if user exists
	my $oldUserName = $m->fetchArray("
		SELECT userName FROM users WHERE id = ?", $oldUserId);
	$oldUserName or $m->error('errUsrNotFnd');

	# Print page bar
	my @navLinks = ({ url => $m->url('user_info', uid => $oldUserId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "User", subTitle => $oldUserName, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(["Changes ownership of ${oldUserName}'s posts and messages to the specified user."]);
	$m->printFormErrors();

	# Print target user form
	print
		"<form action='user_migrate$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Migrate User</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>Username\n",
		"<input type='text' class='qwi acu acs' name='userName' autofocus required></label>\n",
		$m->submitButton("Migrate", 'merge'),
		"<input type='hidden' name='uid' value='$oldUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'user', 'migrate', $userId, 0, 0, 0, $oldUserId);
	$m->printFooter();
}
$m->finish();
