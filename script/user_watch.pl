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

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $word = $m->paramStr('word');
my $userName = $m->paramStr('userName');
my $watchedId = $m->paramInt('userId');
my $action = $m->paramStrId('act');
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Get username from id or vice versa
if ($watchedId) {
	$userName = $m->fetchArray("
		SELECT userName FROM users WHERE id = ?", $watchedId);
	$userName or $m->formError('errUsrNotFnd');
}
elsif ($userName) {
	$watchedId = $m->fetchArray("
		SELECT id FROM users WHERE userName = ?", $userName);
	$watchedId or $m->formError('errUsrNotFnd');
}

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Process add watch word form
	if ($action eq 'addWord') {
		# Check if feature is enabled
		$cfg->{watchWords} or $m->error('errNoAccess');
		
		# Check word validity
		$word = lc($word);
		length($word) >= 4 && length($word) <= 30 or $m->formError('errWordSize');

		# Limit number of watch entries
		my $wordNum = $m->fetchArray("
			SELECT COUNT(*) FROM watchWords WHERE userId = ?", $optUserId);
		$wordNum <= 10 or $m->formError('errWatchNum');

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Add watch word
			$m->setRel(1, 'watchWords', 'userId', 'word', $optUserId, $m->escHtml($word));

			# Log action and finish
			$m->logAction(1, 'user', 'wwordadd', $userId, 0, 0, 0, $optUserId);
			$m->redirect('user_watch', uid => $optUserId, msg => 'WatWrdAdd');
		}
	}
	# Process remove watch word form
	elsif ($action eq 'removeWord') {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Remove watch word
			$m->setRel(0, 'watchWords', 'userId', 'word', $optUserId, $m->escHtml($word));

			# Log action and finish
			$m->logAction(1, 'user', 'wwordrem', $userId, 0, 0, 0, $optUserId);
			$m->redirect('user_watch', uid => $optUserId, msg => 'WatWrdRem');
		}
	}
	# Process add watch user form
	elsif ($action eq 'addUser') {
		# Check if feature is enabled
		$cfg->{watchUsers} or $m->error('errNoAccess');

		# Don't accept 0 as userId
		$watchedId > 0 or $m->formError('errUsrNotFnd');
		
		# Limit number of watch entries
		my $userNum = $m->fetchArray("
			SELECT COUNT(*) FROM watchUsers WHERE userId = ?", $optUserId);
		$userNum <= 10 or $m->formError('errWatchNum');

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Add watch user
			$m->setRel(1, 'watchUsers', 'userId', 'watchedId', $optUserId, $watchedId);

			# Log action and finish
			$m->logAction(1, 'user', 'wuseradd', $userId, 0, 0, 0, $watchedId);
			$m->redirect('user_watch', uid => $optUserId, msg => 'WatUsrAdd');
		}
	}
	# Process remove watch user form
	elsif ($action eq 'removeUser') {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Remove watch user
			$m->setRel(0, 'watchUsers', 'userId', 'watchedId', $optUserId, $watchedId);

			# Log action and finish
			$m->logAction(1, 'user', 'wuserrem', $userId, 0, 0, 0, $watchedId);
			$m->redirect('user_watch', uid => $optUserId, msg => 'WatUsrRem');
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
	$m->printPageBar(mainTitle => $lng->{watTitle}, subTitle => $optUser->{userName},
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(['watWrdAddT', 'watUsrAddT']);
	$m->printFormErrors();

	# Escape submitted values
	my $wordEsc = $m->escHtml($word);
	my $userNameEsc = $m->escHtml($userName);

	if ($cfg->{watchWords}) {
		# Print add word form
		print
			"<form action='user_watch$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{watWrdAddTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<label class='lbw'>$lng->{watWrdAddWrd}",
			"<input type='text' class='qwi' name='word' value='$wordEsc' autofocus required></label>\n",
			$m->submitButton('watWrdAddB', 'watch'),
			"<input type='hidden' name='act' value='addWord'>\n",
			"<input type='hidden' name='uid' value='$optUserId'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";

		# Get watch words
		my $words = $m->fetchAllArray("
			SELECT word FROM watchWords WHERE userId = ? ORDER BY word", $optUserId);

		if (@$words) {
			# Print remove word form
			print
				"<form action='user_watch$m->{ext}' method='post'>\n",
				"<div class='frm'>\n",
				"<div class='hcl'><span class='htt'>$lng->{watWrdRemTtl}</span></div>\n",
				"<div class='ccl'>\n",
				"<label class='lbw'>$lng->{watWrdRemWrd}",
				"<select name='word' size='5'>\n",
				map("<option value='$_->[0]'>$_->[0]</option>\n", @$words),
				"</select></label>\n",
				$m->submitButton('watWrdRemB', 'remove'),
				"<input type='hidden' name='act' value='removeWord'>\n",
				"<input type='hidden' name='uid' value='$optUserId'>\n",
				$m->stdFormFields(),
				"</div>\n",
				"</div>\n",
				"</form>\n\n";
		}
	}

	if ($cfg->{watchUsers}) {
		# Print add user form
		print
			"<form action='user_watch$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{watUsrAddTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<label class='lbw'>$lng->{watUsrAddUsr}",
			"<input type='text' class='qwi acu acs' name='userName' value='$userNameEsc'",
			" required></label>\n",
			$m->submitButton('watUsrAddB', 'watch'),
			"<input type='hidden' name='act' value='addUser'>\n",
			"<input type='hidden' name='uid' value='$optUserId'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";

		# Get watched users
		my $users = $m->fetchAllArray("
			SELECT users.id, users.userName
			FROM watchUsers AS watchUsers
				INNER JOIN users AS users
					ON users.id = watchUsers.watchedId
			WHERE watchUsers.userId = :optUserId
			ORDER BY users.userName",
			{ optUserId => $optUserId });

		if (@$users) {
			# Print remove user form
			my %state = ( $watchedId => 'selected' );
			print
				"<form action='user_watch$m->{ext}' method='post'>\n",
				"<div class='frm'>\n",
				"<div class='hcl'><span class='htt'>$lng->{watUsrRemTtl}</span></div>\n",
				"<div class='ccl'>\n",
				"<label class='lbw'>$lng->{watUsrRemUsr}",
				"<select name='userId' size='5'>\n",
				map("<option value='$_->[0]' $state{$_->[0]}>$_->[1]</option>\n", @$users),
				"</select></label>\n",
				$m->submitButton('watUsrRemB', 'remove'),
				"<input type='hidden' name='act' value='removeUser'>\n",
				"<input type='hidden' name='uid' value='$optUserId'>\n",
				$m->stdFormFields(),
				"</div>\n",
				"</div>\n",
				"</form>\n\n";
		}
	}

	# Log action and finish
	$m->logAction(3, 'user', 'watch', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
