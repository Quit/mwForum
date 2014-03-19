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
my $maxAge = $m->paramInt('maxAge');
my $submitted = $m->paramBool('subm');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Delete log lines older than maxAge days
		if (!$maxAge) {
			$m->dbDo("
				DELETE FROM log");
		}
		else {
			$m->dbDo("
				DELETE FROM log WHERE logTime < ? - ? * 86400", $m->{now}, $maxAge);
		}

		# Log action and finish
		$m->logAction(1, 'log', 'delete', $userId);
		$m->redirect('log_admin');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('log_admin'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Log", navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Print notification message form
	print
		"<form action='log_delete$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Delete Log Entries</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>Delete entries older than x days (0 = all)\n",
		"<input type='number' name='maxAge' value='7'></label>\n",
		"</fieldset>\n",
		$m->submitButton("Delete", 'delete'),
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'log', 'delete', $userId);
	$m->printFooter();
}
$m->finish();
