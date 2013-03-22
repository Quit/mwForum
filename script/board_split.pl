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

# Get CGI parameters
my @topicIds = $m->paramInt('tid');
my $oldBoardId = $m->paramInt('bid');
my $newBoardId = $m->paramInt('newBoardId');
my $page = $m->paramInt('pg') || 1;
my $submitted = $m->paramBool('subm');
$oldBoardId or $m->error('errParamMiss');

# Get board
my $oldBoard = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $oldBoardId);
$oldBoard or $m->error('errBrdNotFnd');

# Check if user is admin or moderator
$user->{admin} || $m->boardAdmin($userId, $oldBoardId) or $m->error('errNoAccess');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Check if new board and topics selected
	$newBoardId or $m->error('errParamMiss');
	@topicIds or $m->error('errParamMiss');

	# Check if user has write access to destination board
	my $newBoard = $m->fetchHash("
		SELECT * FROM boards WHERE id = ?", $newBoardId);
	$newBoard or $m->error('errBrdNotFnd');
	$m->boardVisible($newBoard) or $m->error('errNoAccess');
	$m->boardWritable($newBoard) or $m->error('errNoAccess');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update posts, topics and boards
		$m->dbDo("
			UPDATE posts SET boardId = :newBoardId 
			WHERE topicId IN (:topicIds)
				AND boardId = :oldBoardId", 
			{ newBoardId => $newBoardId, topicIds => \@topicIds, oldBoardId => $oldBoardId });
		$m->dbDo("
			UPDATE topics SET boardId = :newBoardId 
			WHERE id IN (:topicIds)
				AND boardId = :oldBoardId",
			{ newBoardId => $newBoardId, topicIds => \@topicIds, oldBoardId => $oldBoardId });
		$m->recalcStats([ $oldBoardId, $newBoardId ]);

		# Log action and finish
		$m->logAction(1, 'board', 'split', $userId, $oldBoardId, 0, 0, $newBoardId);
		$m->redirect('board_split', bid => $oldBoardId, pg => $page);
	}
}

# Print forms
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Get boards
	my $boards = $m->fetchAllHash("
		SELECT boards.id, boards.title,
			categories.title AS categTitle
		FROM boards AS boards
			INNER JOIN categories AS categories
				ON categories.id = boards.categoryId
		ORDER BY categories.pos, boards.pos");
	@$boards = grep($_->{id} != $oldBoardId 
		&& $m->boardVisible($_) && $m->boardWritable($_), @$boards);

	# Get topics on page
	my $topicsPP = 100;
	my $offset = ($page - 1) * $topicsPP;
	my $topics = $m->fetchAllArray("
		SELECT id, subject 
		FROM topics 
		WHERE boardId = :oldBoardId
		ORDER BY lastPostTime DESC
		LIMIT :topicsPP OFFSET :offset",
		{ oldBoardId => $oldBoardId, topicsPP => $topicsPP, offset => $offset });

	# Print page bar
	my $topicNum = $m->fetchArray("
		SELECT COUNT(*) FROM topics WHERE boardId = ?", $oldBoardId);
	my $pageNum = int($topicNum / $topicsPP) + ($topicNum % $topicsPP != 0);
	my @pageLinks = $pageNum < 2 ? ()
		: $m->pageLinks('board_split', [ bid => $oldBoardId ], $page, $pageNum);
	my @navLinks = ({ url => $m->url('board_show', bid => $oldBoardId), txt =>'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{bspTitle}, subTitle => $oldBoard->{title}, 
		navLinks => \@navLinks, pageLinks => \@pageLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Print form
	print
		"<form action='board_split$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{bspSplitTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{bspSplitDest}\n",
		"<select name='newBoardId' size='1' autofocus>\n",
		map("<option value='$_->{id}'>$_->{categTitle} / $_->{title}</option>\n", @$boards),
		"</select></label>\n",
		"</fieldset>\n",
		"<fieldset>\n";

	# Print topic list		
	for my $topic	(@$topics) {
		my $url = $m->url('topic_show', tid => $topic->[0]);
		print 
			"<div><label><input type='checkbox' name='tid' value='$topic->[0]'> ",
			"<a href='$url'>$topic->[1]</a></label></div>\n";
	}

	# Print submit section	
	print
		"</fieldset>\n",
		$m->submitButton('bspSplitB', 'split'),
		"<input type='hidden' name='bid' value='$oldBoardId'>\n",
		"<input type='hidden' name='pg' value='$page'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'board', 'split', $userId, $oldBoardId);
	$m->printFooter();
}
$m->finish();
