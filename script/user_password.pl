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
$userId or $m->error('errNoAccess');

# Don't change password when auth plugin is used
!$cfg->{authenPlg}{login} && !$cfg->{authenPlg}{request}
	or $m->error("Password change n/a when auth plugin is used.");

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $password = $m->paramStr('password') || "";
my $passwordV = $m->paramStr('passwordV') || "";
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Check password for validity
	$password eq $passwordV or $m->formError('errPwdDiffer');
	length($password) >= 8 or $m->formError('errPwdSize');
	
	# Get new salt, loginAuth and password hash
	my $salt = $m->randomId();
	my $loginAuth = $m->randomId();
	my $passwordHash = $m->hashPassword($password, $salt);
	
	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update user
		$m->dbDo("
			UPDATE users SET password = ?, salt = ?, loginAuth = ? WHERE id = ?", 
			$passwordHash, $salt, $loginAuth, $optUserId);
		
		# Update cookies if password changed
		$m->setCookie('login', "$optUserId:$loginAuth", $optUser->{tempLogin})
			if $optUserId == $userId;
		
		# Log action and finish
		$m->logAction(1, 'user', 'passwd', $userId, 0, 0, 0, $optUserId);
		$m->redirect('user_options', uid => $optUserId, msg => 'PwdChange');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_options', uid => $optUserId), 
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{pwdTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(['pwdChgT']);
	$m->printFormErrors();

	# Print password form
	print
		"<form action='user_password$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{pwdChgTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>$lng->{pwdChgPwd} ($lng->{pwdChgPwdFmt})\n",
		"<input type='password' class='qwi' name='password' pattern='.{8,}'",
		" title='$lng->{pwdChgPwdFmt}' autocomplete='off' required autofocus></label>\n",
		"<label class='lbw'>$lng->{pwdChgPwdV}\n",
		"<input type='password' class='qwi' name='passwordV' pattern='.{8,}'",
		" title='$lng->{pwdChgPwdFmt}' autocomplete='off' required>",
		"</label>\n",
		$m->submitButton('pwdChgB', 'password'),
		"<input type='hidden' name='uid' value='$optUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'user', 'passwd', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
