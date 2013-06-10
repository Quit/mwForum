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

# Check if access should be denied
$cfg->{subsInstant} || $cfg->{subsDigest} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Get subscribed topics
my $topics = $m->fetchAllHash("
	SELECT topics.id, topics.subject,	
		topicSubscriptions.instant
	FROM topicSubscriptions AS topicSubscriptions
		INNER JOIN topics AS topics
			ON topics.id = topicSubscriptions.topicId
	WHERE topicSubscriptions.userId = :optUserId
	ORDER BY topics.lastPostTime",
	{ optUserId => $optUserId });

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		for my $topic (@$topics) {
			# Update subscriptions
			my $topicId = $topic->{id};
			my $subscribe = $m->paramInt("subscribe_$topicId");
			$subscribe = 0 if !$optUser->{email} || $optUser->{dontEmail}
				|| ($subscribe == 2 && !$cfg->{subsInstant}) || ($subscribe == 1 && !$cfg->{subsDigest});
			my $instant = $subscribe == 2 ? 1 : 0;
			my $subscribed = $m->fetchArray("
				SELECT 1 FROM topicSubscriptions WHERE userId = ? AND topicId = ?", $optUserId, $topicId);
			if ($subscribe && !$subscribed) {
				$m->dbDo("
					INSERT INTO topicSubscriptions (userId, topicId, instant, unsubAuth) VALUES (?, ?, ?, ?)",
					$optUserId, $topicId, $instant, $m->randomId());
			}
			elsif (!$subscribe && $subscribed) {
				$m->dbDo("
					DELETE FROM topicSubscriptions WHERE userId = ? AND topicId = ?", $optUserId, $topicId);
			}
		}
		
		# Log action and finish
		$m->logAction(1, 'user', 'topics', $userId, 0, 0, 0, $optUserId);
		$m->redirect('user_options', uid => $optUserId, msg => 'TpcChange');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_options', uid => $optUserId), 
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{utpTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Print topic option table
	print 
		"<form action='user_topics$m->{ext}' method='post'>\n",
		"<table class='tbl'>\n",
		"<tr class='hrw'>\n",
		"<th>$lng->{utpTpcStTtl}</th>\n",
		"<th>$lng->{utpTpcStSubs}</th>\n",
		"</tr>\n";

	# Print topic list		
	for my $topic (@$topics) {
		my $topicId = $topic->{id};
		my $instantDsb = !$cfg->{subsInstant} ? 'disabled' : "";
		my $digestDsb = !$cfg->{subsDigest} ? 'disabled' : "";
		my $instantChk = $topic->{instant} ? 'checked' : "";
		my $digestChk = !$topic->{instant} ? 'checked' : "";
		print
			"<tr class='crw'>\n",
			"<td>$topic->{subject}</td>\n",
			"<td class='shr'>",
			"<label><input type='radio' name='subscribe_$topicId' value='2' $instantChk $instantDsb>",
			" $lng->{ubdTpcStInst}</label>\n",
			"<label><input type='radio' name='subscribe_$topicId' value='1' $digestChk $digestDsb>",
			" $lng->{ubdTpcStDig}</label>\n",
			"<label><input type='radio' name='subscribe_$topicId' value='0'>",
			" $lng->{ubdTpcStOff}</label>\n",
			"</td>\n",
			"</tr>\n";
	}

	# If no subscribed topics, display notification
	print "<tr class='crw'><td colspan='2'>$lng->{utpEmpty}</td></tr>\n" if !@$topics;
	
	# Print submit section
	print
		"</table>\n\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{utpSubmitTtl}</span></div>\n",
		"<div class='ccl'>\n",
		$m->submitButton('utpChgB', 'topic'),
		"<input type='hidden' name='uid' value='$optUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'user', 'topics', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
