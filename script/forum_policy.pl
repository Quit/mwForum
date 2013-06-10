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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new(@_, allowBanned => 1);

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $accept = $m->paramBool('accept');
my $reject = $m->paramBool('reject');
my $read = $m->paramBool('read');
my $submitted = $m->paramBool('subm');

# Process form
if ($submitted) {
	if ($accept) {
		# Check request source authentication
		$m->checkSourceAuth() or $m->formError('errSrcAuth');
	
		# Check that policy was read
		$read or $m->formError('errPlcRead');
		
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Update user
			$m->dbDo("
				UPDATE users SET policyAccept = ? WHERE id = ?", $cfg->{policyVersion}, $userId);
	
			# Log action and finish
			$m->logAction(1, 'forum', 'policy', $userId);
			$m->redirect('forum_show');
		}
	}
	elsif ($reject) {
		$m->redirect('user_logout', auth => 1);
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	$m->printPageBar(mainTitle => $cfg->{policyTitle});

	# Print hints and form errors
	$m->printFormErrors();

	# Print policy
	my $policyEsc = $m->escHtml($cfg->{policy}, 2);
	print
		"<form action='forum_policy$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='ccl'>\n",
		"<div>$policyEsc</div>\n",
		$m->submitButton('plcRejectB', undef, 'reject'),
		$m->submitButton('plcAcceptB', undef, 'accept'),
		"<label><input type='checkbox' name='read'>$lng->{plcRead}</label>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
		
	# Log action and finish
	$m->logAction(3, 'forum', 'policy', $userId);
	$m->printFooter();
}
$m->finish();
