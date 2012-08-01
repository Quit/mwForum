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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new(@_, autocomplete => 1);

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $ignUserId = $m->paramInt('userId');
my $userName = $m->paramStr('userName');
my $action = $m->paramStrId('act');
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Get username from id or vice versa
if ($ignUserId) {
	$userName = $m->fetchArray("
		SELECT userName FROM users WHERE id = ?", $ignUserId);
	$userName or $m->formError('errUsrNotFnd');
}
elsif ($userName) {	
	$ignUserId = $m->fetchArray("
		SELECT id FROM users WHERE userName = ?", $userName);
	$ignUserId or $m->formError('errUsrNotFnd');
}

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Process add ignore form
	if ($action eq 'add') {
		# Don't accept 0 as userId
		$ignUserId > 0 or $m->formError('errUsrNotFnd');

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Add ignored user
			$m->setRel(1, 'userIgnores', 'userId', 'ignoredId', $optUserId, $ignUserId);
		
			# Log action and finish
			$m->logAction(1, 'user', 'ignadd', $userId, 0, 0, 0, $ignUserId);
			$m->redirect('user_ignore', uid => $optUserId, msg => 'IgnoreAdd');
		}
	}
	# Process remove ignore form
	elsif ($action eq 'remove') {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Remove ignored user
			$m->setRel(0, 'userIgnores', 'userId', 'ignoredId', $optUserId, $ignUserId);
		
			# Log action and finish
			$m->logAction(1, 'user', 'ignrem', $userId, 0, 0, 0, $ignUserId);
			$m->redirect('user_ignore', uid => $optUserId, msg => 'IgnoreRem');
		}
	}
	else { $m->error('errParamMiss') }
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_options', uid => $optUserId),
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{uigTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(['uigAddT']);
	$m->printFormErrors();

	# Prepare values
	my $userNameEsc = $m->escHtml($userName);

	# Print add form
	print
		"<form action='user_ignore$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{uigAddTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>$lng->{uigAddUser}\n",
		"<input type='text' class='qwi acu acs' name='userName' value='$userNameEsc'",
		" autofocus required></label>\n",
		$m->submitButton('uigAddB', 'ignore'),
		"<input type='hidden' name='act' value='add'>\n",
		"<input type='hidden' name='uid' value='$optUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Get ignored users
	my $users = $m->fetchAllArray("
		SELECT users.id, users.userName
		FROM userIgnores AS userIgnores
			INNER JOIN users AS users
				ON users.id = userIgnores.ignoredId
		WHERE userIgnores.userId = :optUserId
		ORDER BY users.userName",
		{ optUserId => $optUserId });
	
	if (@$users) {
		# Print remove form
		my %state = ( $ignUserId => 'selected' );
		print
			"<form action='user_ignore$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{uigRemTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<label class='lbw'>$lng->{uigRemUser}\n",
			"<select name='userId' size='10'>\n",
			map("<option value='$_->[0]' $state{$_->[0]}>$_->[1]</option>\n", @$users),
			"</select></label>\n",
			$m->submitButton('uigRemB', 'remove'),
			"<input type='hidden' name='act' value='remove'>\n",
			"<input type='hidden' name='uid' value='$optUserId'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}
	
	# Log action and finish
	$m->logAction(3, 'user', 'ignore', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
