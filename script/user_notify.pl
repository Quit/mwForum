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
my $recvId = $m->paramInt('uid');
my $body = $m->paramStr('body');
my $submitted = $m->paramBool('subm');

# Get user
my $recvUser = $m->getUser($recvId);
$recvUser or $m->error('errUsrNotFnd');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Translate text
	my $note = { isNote => 1, body => $body };
	$m->editToDb({}, $note);
	
	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Insert notification message
		$m->addNote('admMsg', $recvId, $note->{body});
			
		# Log action and finish
		$m->logAction(1, 'note', 'add', $userId, 0, 0, 0, $recvId);
		$m->redirect('user_info', uid => $recvId);
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_info', uid => $recvId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "User", subTitle => $recvUser->{userName}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Prepare values
	my $bodyEsc = $m->escHtml($body, 1);

	# Print notification message form
	print
		"<form action='user_notify$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Send Notification Message</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>Text\n",
		"<textarea name='body' rows='4' autofocus required>$bodyEsc</textarea></label>\n",
		$m->submitButton("Send", 'write', 'add'),
		"<input type='hidden' name='uid' value='$recvId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'note', 'add', $userId, 0, 0, 0, $recvId);
	$m->printFooter();
}
$m->finish();
