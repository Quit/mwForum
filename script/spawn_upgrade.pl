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
my $test = $m->paramBool('test');
my $upgrade = $m->paramBool('upgrade');
my $wipe = $m->paramBool('wipe');
my $submitted = $m->paramBool('subm');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		if ($upgrade) { $m->spawnScript('upgrade') }
		elsif ($test) { $m->spawnScript('spawn_test') }
		elsif ($wipe) {
			# Wipe last output
			$m->dbDo("
				DELETE FROM variables WHERE name = ?", 'upgOutput');
		}

		# Redirect to same page
		$m->redirect('spawn_upgrade');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Upgrade", navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints([
		"This method of starting upgrade.pl over the browser requires the"
		. " <code>\$cfg-&gt;{scriptFsPath}</code> and <code>\$cfg-&gt;{perlBinary}</code>"
		. " options to be set up. The output below may be from the previous upgrade."
		. " Execution may take a while."
		. " Only if the output ends with 'mwForum upgrade done' has upgrade.pl run to completion."
		. " As it is run in the background, it should not get interrupted by any webserver"
		. " timeouts, though some webhosters may kill any script that runs for too long."
		. " Use Test to check if a script can run for 20 minutes."
		. " Refresh occasionally to check if scripts are done."
	]);
	$m->printFormErrors();

	# Print execution form
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Execute</span></div>\n",
		"<div class='ccl'>\n",
		"<form action='spawn_upgrade$m->{ext}' method='post'>\n",
		"<div>\n",
		$m->submitButton("Test", 'admopt', 'test'),
		$m->submitButton("Upgrade", 'admopt', 'upgrade'),
		$m->submitButton("Wipe Output", 'delete', 'wipe'),
		$m->stdFormFields(),
		"</div>\n",
		"</form>\n",
		"</div>\n",
		"</div>\n\n";

	# Print last upgrade output
	my $output = $m->fetchArray("
		SELECT value FROM variables WHERE name = ?", 'upgOutput');
	my $outputEsc = $m->escHtml($output, 1);
	my $refreshUrl = $m->url('spawn_upgrade');
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Last Output</span>",
		" | <a href='$refreshUrl'>Refresh</a></div>\n",
		"<div class='ccl'>\n",
		"<pre><samp>$outputEsc</samp></pre>\n",
		"</div>\n",
		"</div>\n\n";

	# Log action and finish
	$m->logAction(3, 'spawn', 'upgrade', $userId);
	$m->printFooter();
}
$m->finish();
