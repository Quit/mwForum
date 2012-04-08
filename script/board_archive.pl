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
my $boardId = $m->paramInt('bid');
my $submitted = $m->paramBool('subm');
$boardId or $m->error('errParamMiss');

# Get board
my $boardTitle = $m->fetchArray("
	SELECT title FROM boards WHERE id = ?", $boardId);
$boardTitle or $m->error('errBrdNotFnd');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Delete old archive contents
		$m->dbDo("
			DELETE FROM arc_boards WHERE id = ?", $boardId);
		$m->dbDo("
			DELETE FROM arc_topics WHERE boardId = ?", $boardId);
		$m->dbDo("
			DELETE FROM arc_posts WHERE boardId = ?", $boardId);
		
		# Copy boards, topics and posts
		$m->dbDo("
			INSERT INTO arc_boards
			SELECT * FROM boards WHERE id = ?", $boardId);
		$m->dbDo("
			INSERT INTO arc_topics
			SELECT * FROM topics WHERE boardId = ?", $boardId);
		$m->dbDo("
			INSERT INTO arc_posts
			SELECT * FROM posts WHERE boardId = ?", $boardId);

		# Log action and finish
		$m->logAction(1, 'board', 'archive', $userId, $boardId);
		$m->redirect('board_show', bid => $boardId);
	}
}

# Print forms
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('board_show', bid => $boardId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Board", subTitle => $boardTitle, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(["Archiving a board copies the board and its topics and posts into separate".
		" archive tables. Archiving a board that has been archived before will delete the old".
		" archive contents. See FAQ.html for details."]);
	$m->printFormErrors();

	# Print form
	print
		"<form action='board_archive$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Archive Board</span></div>\n",
		"<div class='ccl'>\n",
		$m->submitButton("Archive", 'archive'),
		"<input type='hidden' name='bid' value='$boardId'/>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'board', 'archive', $userId, $boardId);
	$m->printFooter();
}
$m->finish();
