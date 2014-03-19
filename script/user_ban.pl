#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2014 Markus Wichitill
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

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Get CGI parameters
my $action = $m->paramStrId('act');
my $banUserId = $m->paramInt('uid');
my $reason = $m->paramStr('reason');
my $intReason = $m->paramStr('intReason');
my $duration = $m->paramInt('duration');
my $resetEmail = $m->paramDefined('resetEmail') ? $m->paramBool('resetEmail') : 1;
my $deleteMsgs = $m->paramBool('deleteMsgs');
my $submitted = $m->paramBool('subm');
$banUserId or $m->error('errParamMiss');

# Check if user exists
my $banUser = $m->getUser($banUserId);
$banUser or $m->error('errUsrNotFnd');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Process ban form
	if ($action eq 'ban') {
		# Check if user isn't already banned
		!$m->fetchArray("
			SELECT userId FROM userBans WHERE userId = ?", $banUserId) 
			or $m->error("User is already banned.");
			
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Insert ban
			$duration = $m->min($m->max(0, $duration), 999);
			$duration ||= 0;
			my $reasonEsc = $m->escHtml($reason);
			my $intReasonEsc = $m->escHtml($intReason);
			$m->dbDo("
				INSERT INTO userBans (userId, banTime, duration, reason, intReason)
				VALUES (?, ?, ?, ?, ?)",
				$banUserId, $m->{now}, $duration, $reasonEsc, $intReasonEsc);

			# Remove all admin permissions
			$m->dbDo("
				UPDATE users SET admin = 0 WHERE id = ?", $banUserId)
				if $banUser->{admin};
			$m->dbDo("
				DELETE FROM groupMembers 
				WHERE userId = :banUserId
					AND groupId IN (SELECT DISTINCT groupId FROM boardAdminGroups)",
				{ banUserId => $banUserId });
			$m->dbDo("
				DELETE FROM groupAdmins WHERE userId = ?", $banUserId);

			# Reset email subscriptions and notifications
			if ($resetEmail) {
				$m->dbDo("
					DELETE FROM boardSubscriptions WHERE userId = ?", $banUserId);
				$m->dbDo("
					UPDATE users SET msgNotify = 0 WHERE id = ?", $banUserId);
			}

			# Delete outgoing messages
			$m->dbDo("
				DELETE FROM messages WHERE senderId = ?", $banUserId) 
				if $deleteMsgs;

			# Log action and finish
			$m->logAction(1, 'user', 'ban', $userId, 0, 0, 0, $banUserId);
			$m->redirect('user_info', uid => $banUserId);
		}
	}
	# Process unban form
	elsif ($action eq 'unban') {
		# Check if user is already banned
		$m->fetchArray("
			SELECT userId FROM userBans WHERE userId = ?", $banUserId) 
			or $m->error("User is not banned.");
		
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Delete ban
			$m->dbDo("
				DELETE FROM userBans WHERE userId = ?", $banUserId);

			# Log action and finish
			$m->logAction(1, 'user', 'unban', $userId, 0, 0, 0, $banUserId);
			$m->redirect('user_info', uid => $banUserId);
		}
	}	
	else { $m->error('errParamMiss') }
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();
	
	# Get user
	my $banUser = $m->getUser($banUserId);
	$banUser or $m->error('errUsrNotFnd');
	
	# Print page bar
	my @navLinks = ({ url => $m->url('user_info', uid => $banUserId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "User", subTitle => $banUser->{userName}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Check if user is already banned
	my $ban = $m->fetchHash("
		SELECT * FROM userBans WHERE userId = ?", $banUserId);

	if ($ban) {
		# Print unban form
		print
			"<form action='user_ban$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>Unban User</span></div>\n",
			"<div class='ccl'>\n",
			"<p>User is currently banned. Duration: $ban->{duration} days.</p>\n",
			"<p>Public reason: $ban->{reason}</p>\n",
			"<p>Internal reason: $ban->{intReason}</p>\n",
			$m->submitButton("Unban", 'remove'),
			"<input type='hidden' name='uid' value='$banUserId'>\n",
			"<input type='hidden' name='act' value='unban'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}
	else {
		# Escape submitted values
		my $reasonEsc = $m->escHtml($reason);
		my $intReasonEsc = $m->escHtml($intReason);

		# Determine checkbox, radiobutton and listbox states
		my $resetEmailChk = $resetEmail ? 'checked' : "";
		my $deleteMsgsChk = $deleteMsgs ? 'checked' : "";

		# Print ban form
		print
			"<form action='user_ban$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>Ban User</span></div>\n",
			"<div class='ccl'>\n",
			"<p>Banned users are locked out from any functionality except logging out.</p>\n",
			"<fieldset>\n",
			"<datalist id='reasons'>\n",
			map("<option value='$_'>\n", @{$cfg->{banReasons}}),
			"</datalist>\n",
			"<label class='lbw'>Reason (shown to banned user)\n",
			"<input type='text' class='fwi' name='reason' list='reasons'",
			" value='$reasonEsc' autofocus></label>\n",
			"<label class='lbw'>Internal Reason (shown to admins only)\n",
			"<input type='text' class='fwi' name='intReason' list='reasons'",
			" value='$intReasonEsc'></label>\n",
			"<label class='lbw'>Duration (in days, 0 = unlimited)\n",
			"<input type='number' name='duration' value='$duration'></label>\n",
			"</fieldset>\n",
			"<fieldset>\n",
			"<div><label><input type='checkbox' name='resetEmail' $resetEmailChk>",
			" Reset email subscriptions and notifications</label></div>\n",
			"<div><label><input type='checkbox' name='deleteMsgs' $deleteMsgsChk>",
			" Delete sent private messages</label></div>\n",
			"</fieldset>\n",
			$m->submitButton("Ban", 'ban'),
			"<input type='hidden' name='uid' value='$banUserId'>\n",
			"<input type='hidden' name='act' value='ban'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}
	
	# Log action and finish
	$m->logAction(3, 'user', 'ban', $userId, 0, 0, 0, $banUserId);
	$m->printFooter();
}
$m->finish();
