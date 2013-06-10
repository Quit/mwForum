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

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Get CGI parameters
my $main = $m->paramBool('main');
my $subs = $m->paramBool('subs');
my $bounce = $m->paramBool('bounce');
my $rss = $m->paramBool('rss');
my $submitted = $m->paramBool('subm');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Spawn script
		if ($main) { $m->spawnScript('cron_jobs') }
		elsif ($subs) { $m->spawnScript('cron_subscriptions') }
		elsif ($bounce) { $m->spawnScript('cron_bounce') }
		elsif ($rss) { $m->spawnScript('cron_rss') }
		
		# Redirect to cronjob admin page
		$m->redirect('cron_admin');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Cronjob Administration", navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(["This method of manually starting cronjobs requires the"
		. " <code>\$cfg-&gt;{scriptFsPath}</code> and <code>\$cfg-&gt;{perlBinary}</code>"
		. " options to be set up."]);
	$m->printFormErrors();

	# Print execution form
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Execute Cronjobs</span></div>\n",
		"<div class='ccl'>\n",
		"<form action='cron_admin$m->{ext}' method='post'>\n",
		"<div>\n",
		$m->submitButton("Main Cronjob (cron_jobs)", 'cron', 'main'), "<br>\n",
		$m->submitButton("Digest Subscriptions (cron_subscriptions)", 'subscribe', 'subs'), "<br>\n",
		$m->submitButton("Bounce Handler (cron_bounce)", 'subscribe', 'bounce'), "<br>\n",
		$m->submitButton("Feed Writer (cron_rss)", 'feed', 'rss'),
		$m->stdFormFields(),
		"</div>\n",
		"</form>\n",
		"</div>\n",
		"</div>\n\n";

	# Log action and finish
	$m->logAction(3, 'cron', 'admin', $userId);
	$m->printFooter();
}
$m->finish();
