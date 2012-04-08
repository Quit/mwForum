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

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $email = $m->paramStr('email') || "";
my $emailV = $m->paramStr('emailV') || "";
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Check email for validity
	$email eq $emailV or $m->formError('errEmlDiffer');
	$m->checkEmail($email);
	
	# Did email change or was is set after being empty?
	my $emailChanged = $optUser->{email} && $optUser->{email} ne $email;
	my $emailAdded = !$optUser->{email} && $email;
	$emailChanged || $emailAdded or $m->formError('errEmlGone');
	
	# Check if email is free
	if (!($user->{admin} && !length($email))) {
		!$m->fetchArray("
			SELECT id FROM users WHERE email = ? AND id <> ?", $email, $optUserId)
			or $m->formError('errEmlGone');
	}

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# If email changed by non-admin, send ticket
		if (!$user->{admin}) {
			# Delete previous tickets
			$m->dbDo("
				DELETE FROM tickets WHERE type = ? AND userId = ?", 'emlChg', $optUserId);
			
			# Create ticket
			my $ticketId = $m->randomId();
			$m->dbDo("
				INSERT INTO tickets (id, userId, issueTime, type, data) VALUES (?, ?, ?, ?, ?)",
				$ticketId, $optUserId, $m->{now}, 'emlChg', $email);
			
			# Email ticket to user
			$optUser->{email} = $email;
			$m->sendEmail($m->createEmail(
				type => 'emlChg', 
				user => $optUser, 
				url => "$cfg->{baseUrl}$m->{env}{scriptUrlPath}/user_ticket$m->{ext}?t=$ticketId",
			));
		}
		else {
			# Update email directly if changed by admin
			$m->dbDo("
				UPDATE users SET email = ? WHERE id = ?", $email, $optUserId);
		}
		
		# Log action and finish
		$m->logAction(1, 'user', 'email', $userId, 0, 0, 0, $optUserId);
		$m->redirect('user_profile', uid => $optUserId, !$user->{admin} ? (msg => 'EmlChange') : ());
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_profile', uid => $optUserId), 
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{emlTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks);
	
	# Set submitted or database values
	my $emailEsc = $submitted ? $m->escHtml($email) : $optUser->{email};
	my $emailVEsc = $submitted ? $m->escHtml($emailV) : $optUser->{email};

	# Print hints and form errors
	$m->printHints(['emlChgT']) if !$user->{admin};
	$m->printFormErrors();
	
	# Print email options
	my $required = !$user->{admin} ? "required='required'" : "";
	print
		"<form action='user_email$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{emlChgTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>$lng->{emlChgAddr}\n",
		"<input type='email' class='fcs hwi' name='email' maxlength='100'",
		" autofocus='autofocus' $required value='$emailEsc'/></label>\n",
		"<label class='lbw'>$lng->{emlChgAddrV}\n",
		"<input type='email' class='hwi' name='emailV' maxlength='100'",
		" $required value='$emailVEsc'/></label>\n",
		$m->submitButton('emlChgB', 'subscribe'),
		"<input type='hidden' name='uid' value='$optUserId'/>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'user', 'options', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
