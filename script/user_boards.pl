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
$m->cacheUserStatus() if $userId;

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Get boards
		my $boards = $m->fetchAllHash("
			SELECT * FROM boards");

		for my $board (@$boards) {
			# Update subscriptions
			my $boardId = $board->{id};
			my $subscribe = $m->paramInt("subscribe_$boardId");
			$subscribe = 0 if !$m->boardVisible($board) || !$optUser->{email} || $optUser->{dontEmail}
				|| ($subscribe == 2 && !$cfg->{subsInstant}) || ($subscribe == 1 && !$cfg->{subsDigest});
			my $instant = $subscribe == 2 ? 1 : 0;
			my ($subscribed, $isInstant) = $m->fetchArray("
				SELECT 1, instant FROM boardSubscriptions WHERE userId = ? AND boardId = ?", 
				$optUserId, $boardId);
			if ($subscribe && !$subscribed) {
				$m->dbDo("
					INSERT INTO boardSubscriptions (userId, boardId, instant, unsubAuth) VALUES (?, ?, ?, ?)",
					$optUserId, $boardId, $instant, $m->randomId());
			}
			elsif (!$subscribe && $subscribed) {
				$m->dbDo("
					DELETE FROM boardSubscriptions WHERE userId = ? AND boardId = ?", $optUserId, $boardId);
			}
			elsif ($subscribe && ($instant && !$isInstant || !$instant && $isInstant)) {
				$m->dbDo("
					UPDATE boardSubscriptions SET instant = ? WHERE userId = ? AND boardId = ?", 
					$instant, $optUserId, $boardId);
			}

			# Update hidden boards
			my $hide = $m->paramBool("hide_$boardId");
			my $hidden = $m->fetchArray("
				SELECT 1 FROM boardHiddenFlags WHERE userId = ? AND boardId = ?", $optUserId, $boardId);
			if ($hide && !$hidden) {
				$m->dbDo("
					INSERT INTO boardHiddenFlags (userId, boardId, manual) VALUES (?, ?, 1)",
					$optUserId, $boardId);
			}
			elsif (!$hide && $hidden) {
				$m->dbDo("
					DELETE FROM boardHiddenFlags WHERE userId = ? AND boardId = ?", $optUserId, $boardId);
			}
		}
		
		# Log action and finish
		$m->logAction(1, 'user', 'boards', $userId, 0, 0, 0, $optUserId);
		$m->redirect('user_options', uid => $optUserId, msg => 'BrdChange');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_options', uid => $optUserId), 
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{ubdTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(['ubdSubsT2']) if $cfg->{subsDigest} || $cfg->{subsInstant};
	$m->printFormErrors();

	# Get boards including status
	my $boards = $m->fetchAllHash("
		SELECT boards.*, 
			categories.title AS categTitle,
			boardSubscriptions.userId IS NOT NULL AS subscribed, boardSubscriptions.instant,
			boardHiddenFlags.userId IS NOT NULL AS hidden
		FROM boards AS boards
			INNER JOIN categories AS categories
				ON categories.id = boards.categoryId
			LEFT JOIN boardSubscriptions AS boardSubscriptions
				ON boardSubscriptions.userId = :optUserId
				AND boardSubscriptions.boardId = boards.id
			LEFT JOIN boardHiddenFlags AS boardHiddenFlags
				ON boardHiddenFlags.userId = :optUserId
				AND boardHiddenFlags.boardId = boards.id
		ORDER BY categories.pos, boards.pos",
		{ optUserId => $optUserId });
	@$boards = grep($m->boardVisible($_), @$boards);
		
	# Print board option table
	print 
		"<form action='user_boards$m->{ext}' method='post'>\n",
		"<table class='tbl'>\n",
		"<tr class='hrw'>\n",
		"<th>$lng->{ubdBrdStTtl}</th>\n",
		"<th>$lng->{ubdBrdStSubs}</th>\n",
		"<th>$lng->{ubdBrdStHide}</th>\n",
		"</tr>\n";
		
	# Print board list
	for my $board (@$boards) {
		my $boardId = $board->{id};
		my $subsDsb = !$optUser->{email} || $optUser->{dontEmail};
		my $instantDsb = !$cfg->{subsInstant} || $subsDsb ? 'disabled' : "";
		my $digestDsb = !$cfg->{subsDigest} || $subsDsb ? 'disabled' : "";
		my $instantChk = $board->{subscribed} && $board->{instant} ? 'checked' : "";
		my $digestChk = $board->{subscribed} && !$board->{instant} ? 'checked' : "";
		my $unsubChk = $instantChk || $digestChk ? "" : 'checked';
		my $hiddenChk = $board->{hidden} ? 'checked' : "";
		print
			"<tr class='crw'>\n",
			"<td>$board->{categTitle} / $board->{title}</td>\n",
			"<td>\n",
			"<label><input type='radio' name='subscribe_$boardId' value='2'",
			" $instantChk $instantDsb> $lng->{ubdBrdStInst}</label>\n",
			"<label><input type='radio' name='subscribe_$boardId' value='1'",
			" $digestChk $digestDsb> $lng->{ubdBrdStDig}</label>\n",
			"<label><input type='radio' name='subscribe_$boardId' value='0'",
			" $unsubChk> $lng->{ubdBrdStOff}</label>\n",
			"</td>\n",
			"<td><label><input type='checkbox' name='hide_$boardId' $hiddenChk>",
			" $lng->{ubdBrdStHide}</label></td>\n",
			"</tr>\n";
	}
	
	print "</table>\n\n";

	# Print submit section
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{ubdSubmitTtl}</span></div>\n",
		"<div class='ccl'>\n",
		$m->submitButton('ubdChgB', 'board'),
		"<input type='hidden' name='uid' value='$optUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'user', 'boards', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
