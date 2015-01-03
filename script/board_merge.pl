#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2015 Markus Wichitill
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
my $oldBoardId = $m->paramInt('bid');
my $newBoardId = $m->paramInt('newBoardId');
my $submitted = $m->paramBool('subm');
$oldBoardId or $m->error('errParamMiss');

# Get board
my $boardTitle = $m->fetchArray("
	SELECT title FROM boards WHERE id = ?", $oldBoardId);
$boardTitle or $m->error('errBrdNotFnd');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Check if new board selected
	$newBoardId or $m->formError("No board selected.");

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update posts, topics and board
		$m->dbDo("
			UPDATE posts SET boardId = ? WHERE boardId = ?", $newBoardId, $oldBoardId);
		$m->dbDo("
			UPDATE topics SET boardId = ? WHERE boardId = ?", $newBoardId, $oldBoardId);
		$m->recalcStats([ $oldBoardId, $newBoardId ]);

		# Log action and finish
		$m->logAction(1, 'board', 'merge', $userId, $oldBoardId, 0, 0, $newBoardId);
		$m->redirect('board_show', bid => $oldBoardId);
	}
}

# Print forms
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('board_show', bid => $oldBoardId),
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Board", subTitle => $boardTitle, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Get boards
	my $boards = $m->fetchAllHash("
		SELECT boards.id, boards.title,
			categories.title AS categTitle
		FROM boards AS boards
			INNER JOIN categories AS categories
				ON categories.id = boards.categoryId
		ORDER BY categories.pos, boards.pos");

	# Print destination board form
	print
		"<form action='board_merge$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Merge Boards</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>Destination Board\n",
		"<select name='newBoardId' size='10' autofocus>\n",
		map("<option value='$_->{id}'>$_->{categTitle} / $_->{title}</option>\n", @$boards),
		"</select></label>\n",
		$m->submitButton("Merge", 'merge'),
		"<input type='hidden' name='bid' value='$oldBoardId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'board', 'merge', $userId, $oldBoardId);
	$m->printFooter();
}
$m->finish();
