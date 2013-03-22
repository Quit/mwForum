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

# Check if access should be denied
$userId or $m->error('errNoAccess');
$user->{renamesLeft} or $m->error('errNoAccess');

# Get CGI parameters
my $userName = $m->paramStr('name') || "";
my $submitted = $m->paramBool('subm');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');
	
	# Check username for validity
	length($userName) or $m->formError('errNamEmpty');
	if (length($userName)) {
		length($userName) >= 2 && length($userName) <= $cfg->{maxUserNameLen} 
			or $m->formError('errNamSize');
		$userName =~ /$cfg->{userNameRegExp}/ or $m->formError('errNamChar');
		$userName !~ /  / or $m->formError('errNamChar');
		$userName !~ /https?:/ or $m->formError('errNamResrvd');
		index(lc($userName), lc($_)) < 0 or $m->formError('errNamResrvd')
			for @{$cfg->{reservedNames}};
	}
	
	# Check if username is free
	!$m->fetchArray("
		SELECT id FROM users WHERE userName = ?", $userName)
		or $m->formError('errNamGone');

	# Track old usernames
	my $oldNames = length($user->{userName}) > 20 && $user->{openId} =~ /$user->{userName}/
		? "" : join(", ", $user->{userName}, $user->{oldNames} || ());
	
	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update user
		$m->dbDo("
			UPDATE users SET userName = ?, oldNames = ?, renamesLeft = renamesLeft - 1 WHERE id = ?",
			$userName, $oldNames, $userId);

		# Update posts.userNameBak
		$m->dbDo("
			UPDATE posts SET userNameBak = ? WHERE userId = ?", $userName, $userId);

		# Log action and finish
		$m->logAction(1, 'user', 'name', $userId);
		$m->redirect('user_profile', msg => 'NamChange');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_profile', uid => $userId), 
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{namTitle}, subTitle => $user->{userName}, 
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(['namChgT']);
	$m->printFormErrors();

	# Prepare values
	my $userNameEsc = $submitted ? $m->escHtml($userName) : $user->{userName};

	# Print profile options
	print
		"<form action='user_name$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{namChgTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<p>", $m->formatStr($lng->{namChgT2}, { times => $user->{renamesLeft} }), "</p>\n",
		"<label class='lbw'>$lng->{namChgName}\n",
		"<input type='text' class='qwi' name='name' maxlength='$cfg->{maxUserNameLen}'",
		" value='$userNameEsc' autofocus required></label>\n",
		$m->submitButton('namChgB', 'name'),
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'user', 'name', $userId, 0, 0, 0, $userId);
	$m->printFooter();
}
$m->finish();
