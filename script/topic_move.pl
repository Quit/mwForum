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
$m->cacheUserStatus() if $userId;

# Get CGI parameters
my $topicId = $m->paramInt('tid');
my $newBoardId = $m->paramInt('bid');
my $notify = $m->paramBool('notify');
my $reason = $m->paramStr('reason');
my $submitted = $m->paramBool('subm');
$topicId or $m->error('errParamMiss');

# Get topic and topic poster
my $topic = $m->fetchHash("
	SELECT topics.boardId, topics.lastPostTime, topics.basePostId,
		posts.userId AS userId
	FROM topics AS topics
		INNER JOIN posts AS posts
			ON posts.id = topics.basePostId
	WHERE topics.id = ?", $topicId);
$topic or $m->error('errTpcNotFnd');
my $oldBoardId = $topic->{boardId};

# Check if user is admin or moderator in source board
$user->{admin} || $m->boardAdmin($userId, $oldBoardId) or $m->error('errNoAccess');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Check if destination board exists
	$newBoardId or $m->error('errParamMiss');
	my $newBoard = $m->fetchHash("
		SELECT * FROM boards WHERE id = ?", $newBoardId);
	$newBoard or $m->error('errBrdNotFnd');

	# Check if user has write access to destination board
	$m->boardVisible($newBoard) or $m->error('errNoAccess');
	$m->boardWritable($newBoard) or $m->error('errNoAccess');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Get previous topic id for redirection to same page
		my $prevTopicId = $m->fetchArray("
			SELECT id 
			FROM topics 
			WHERE boardId = :oldBoardId
				AND lastPostTime > :lastPostTime
			ORDER BY lastPostTime
			LIMIT 1",
			{ oldBoardId => $oldBoardId, lastPostTime => $topic->{lastPostTime} });

		# Update posts, topic and board
		$m->dbDo("
			UPDATE posts SET boardId = ? WHERE topicId = ?", $newBoardId, $topicId);
		$m->dbDo("
			UPDATE topics SET boardId = ? WHERE id = ?", $newBoardId, $topicId);
		$m->recalcStats([ $oldBoardId, $newBoardId ]);

		# Add notification message
		if ($notify && $topic->{userId} && $topic->{userId} != $userId) {
			my $url = "topic_show$m->{ext}?tid=$topicId";
			$m->addNote('tpcMov', $topic->{userId}, 'notTpcMov', tpcUrl => $url, reason => $reason);
		}

		# Log action and finish
		$m->logAction(1, 'topic', 'move', $userId, $oldBoardId, $topicId, 0, $newBoardId);
		$m->redirect('board_show', $prevTopicId ? (tid => $prevTopicId, tgt => "tid$prevTopicId") 
			: (bid => $oldBoardId), msg => 'TpcMove');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Get subject
	my $subject = $m->fetchArray("
		SELECT subject FROM topics WHERE id = ?", $topicId);
	$subject or $m->error('errTpcNotFnd');

	# Print page bar
	my @navLinks = ({ url => $m->url('topic_show', tid => $topicId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{mvtTitle}, subTitle => $subject, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Get boards
	my $boards = $m->fetchAllHash("
		SELECT boards.*,
			categories.title AS categTitle
		FROM boards AS boards
			INNER JOIN categories AS categories
				ON categories.id = boards.categoryId
		ORDER BY categories.pos, boards.pos");
	@$boards = grep($_->{id} != $oldBoardId && $m->boardVisible($_) && $m->boardWritable($_), 
		@$boards);

	# Print destination board form
	print
		"<form action='topic_move$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{mvtMovTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{mvtMovDest}\n",
		"<select name='bid' size='10' autofocus>\n",
		map("<option value='$_->{id}'>$_->{categTitle} / $_->{title}</option>\n", @$boards),
		"</select></label>\n",
		"</fieldset>\n";

	# Print notification section
	my $noteChk = $cfg->{noteDefMod} ? 'checked' : "";
	print		
		"<fieldset>\n",
		"<div><label><input type='checkbox' name='notify' $noteChk>$lng->{notNotify}</label></div>\n",
		"<datalist id='reasons'>\n",
		map("<option value='$_'>\n", @{$cfg->{modReasons}}),
		"</datalist>\n",
		"<input type='text' class='fwi' name='reason' list='reasons'>\n",
		"</fieldset>\n",
		if $topic->{userId} > 0 && $topic->{userId} != $userId;
	
	# Print submit section
	print	
		$m->submitButton('mvtMovB', 'move'),
		"<input type='hidden' name='tid' value='$topicId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'topic', 'move', $userId, 0, $topicId);
	$m->printFooter();
}
$m->finish();
