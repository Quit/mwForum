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

# Check if access should be denied
$cfg->{subsInstant} || $cfg->{subsDigest} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $action = $m->paramStrId('act');
my $topicId = $m->paramInt('tid');
my $instant = $m->paramBool('instant');
my $submitted = $m->paramBool('subm');
$topicId or $m->error('errParamMiss');

# Get topic
my ($boardId, $subject) = $m->fetchArray("
	SELECT boardId, subject FROM topics WHERE id = ?", $topicId);
$boardId or $m->error('errTpcNotFnd');

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Check if user can see board
$m->boardVisible($board) or $m->error('errNoAccess');

# Check if user is already subscribed
my $subscribed = $m->fetchArray("
	SELECT 1 FROM topicSubscriptions WHERE userId = ? AND topicId = ?", $userId, $topicId);

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Process subscribe form
	if ($action eq 'subscribe' && !$subscribed) {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Add topic subscription
			$m->dbDo("
				INSERT INTO topicSubscriptions (userId, topicId, instant, unsubAuth) VALUES (?, ?, ?, ?)",
				$userId, $topicId, $instant, $m->randomId());
			
			# Log action and finish
			$m->logAction(1, 'topic', 'sub', $userId, $boardId, $topicId);
			$m->redirect('topic_show', tid => $topicId, msg => 'TpcSub');
		}
	}
	# Process unsubscribe form
	elsif ($action eq 'unsubscribe' && $subscribed) {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Remove topic subscription
			$m->dbDo("
				DELETE FROM topicSubscriptions WHERE userId = ? AND topicId = ?", $userId, $topicId);

			# Log action and finish
			$m->logAction(1, 'topic', 'unsub', $userId, $boardId, $topicId);
			$m->redirect('topic_show', tid => $topicId, msg => 'TpcUnsub');
		}
	}
	else {
		# Redirect back to topic if nothing to do
		$m->redirect('topic_show', tid => $topicId);
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('topic_show', tid => $topicId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{tsbTitle}, subTitle => $subject, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(['tsbSubT2']);
	$m->printFormErrors();

	if (!$subscribed) {
		# Print subscribe form
		my $instantDsb = !$cfg->{subsInstant} ? 'disabled' : "";
		my $digestDsb = !$cfg->{subsDigest} ? 'disabled' : "";
		my $instantChk = $cfg->{subsInstant} && !$cfg->{subsDigest} ? 'checked' : "";
		my $digestChk = $cfg->{subsDigest} ? 'checked' : "";
		print
			"<form action='topic_subscribe$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{tsbSubTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<div><label><input type='radio' name='instant' value='1' $instantChk $instantDsb>",
			" $lng->{tsbInstant}</label></div>\n",
			"<div><label><input type='radio' name='instant' value='0' $digestChk $digestDsb>",
			" $lng->{tsbDigest}</label></div>\n",
			$m->submitButton('tsbSubB', 'subscribe'),
			"<input type='hidden' name='tid' value='$topicId'>\n",
			"<input type='hidden' name='act' value='subscribe'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}
	else {
		# Print unsubscribe form
		print
			"<form action='topic_subscribe$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{tsbUnsubTtl}</span></div>\n",
			"<div class='ccl'>\n",
			$m->submitButton('tsbUnsubB', 'remove'),
			"<input type='hidden' name='tid' value='$topicId'>\n",
			"<input type='hidden' name='act' value='unsubscribe'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}

	# Log action and finish
	$m->logAction(3, 'topic', 'sub', $userId, $boardId, $topicId);
	$m->printFooter();
}
$m->finish();
