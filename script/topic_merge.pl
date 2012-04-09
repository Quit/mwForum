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

# Get CGI parameters
my $oldTopicId = $m->paramInt('tid');
my $newTopicId1 = $m->paramInt('newTopic1');
my $newTopicId2 = $m->paramInt('newTopic2');
my $notify = $m->paramBool('notify');
my $reason = $m->paramStr('reason');
my $submitted = $m->paramBool('subm');
my $newTopicId = $newTopicId2 || $newTopicId1;
$oldTopicId or $m->error('errParamMiss');

# Get topic
my $topic = $m->fetchHash("
	SELECT topics.boardId, topics.lastPostTime,
		posts.userId
	FROM topics AS topics
		INNER JOIN posts AS posts
			ON posts.id = topics.basePostId
	WHERE topics.id = ?", $oldTopicId);
$topic or $m->error('errTpcNotFnd');
my $oldBoardId = $topic->{boardId};

# Check if user is admin or moderator in source board
$user->{admin} || $m->boardAdmin($userId, $oldBoardId) or $m->error('errNoAccess');

# Destination topic must not be source topic
$newTopicId != $oldTopicId or $m->error('errTpcNotFnd');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Get destination board
	my $newBoardId = $m->fetchArray("
		SELECT boardId FROM topics WHERE id = ?", $newTopicId);
	$newBoardId or $m->formError('errTpcNotFnd');

	# Check if user is admin or moderator in destination board
	$user->{admin} || $m->boardAdmin($userId, $newBoardId) or $m->error('errNoAccess')
		if $oldBoardId != $newBoardId;
	
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
		
		# Update posts
		$m->dbDo("
			UPDATE posts SET topicId = ?, boardId = ? WHERE topicId = ?",
			$newTopicId, $newBoardId, $oldTopicId);
		
		# Delete old topic
		$m->deleteTopic($oldTopicId);
		
		# Delete topicReadTimes, otherwise too many posts might be marked as read
		$m->dbDo("
			DELETE FROM topicReadTimes WHERE topicId = ?", $newTopicId);
		
		# Update statistics
		$m->recalcStats(undef, $newTopicId);
		if ($oldBoardId != $newBoardId) {
			$m->recalcStats($oldBoardId);
			$m->recalcStats($newBoardId);
		}

		# Add notification message
		if ($notify && $topic->{userId} && $topic->{userId} != $userId) {
			my $url = "topic_show$m->{ext}?tid=$newTopicId";
			$m->addNote('tpcMrg', $topic->{userId}, 'notTpcMrg', tpcUrl => $url, reason => $reason);
		}
		
		# Log action and finish
		$m->logAction(1, 'topic', 'merge', $userId, $oldBoardId, $oldTopicId, 0, $newTopicId);
		$m->redirect('board_show', 	$prevTopicId ? (tid => $prevTopicId, tgt => "tid$prevTopicId") 
			: (bid => $oldBoardId), msg => 'TpcMerge');
	}
}

# Print forms
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Get subject
	my $subject = $m->fetchArray("
		SELECT subject FROM topics WHERE id = ?", $oldTopicId);
	$subject or $m->error('errTpcNotFnd');

	# Print page bar
	my @navLinks = ({ url => $m->url('topic_show', tid => $oldTopicId), 
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{mgtTitle}, subTitle => $subject, navLinks => \@navLinks);
	
	# Get other topics
	my $topics = $m->fetchAllHash("
		SELECT id, subject
		FROM topics
		WHERE boardId = :oldBoardId
			AND id <> :oldTopicId
		ORDER BY lastPostTime DESC
		LIMIT 200", 
		{ oldBoardId => $oldBoardId, oldTopicId => $oldTopicId });

	# Print hints and form errors
	$m->printFormErrors();
	
	# Print destination topic form
	print
		"<form action='topic_merge$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{mgtMrgTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{mgtMrgDest}\n",
		"<select class='fcs' name='newTopic1' size='10' autofocus='autofocus'>\n",
		map("<option value='$_->{id}'>$_->{subject}</option>\n", @$topics),
		"</select></label>\n",
		"<label class='lbw'>$lng->{mgtMrgDest2}\n",
		"<input type='text' class='qwi' name='newTopic2' maxlength='8'/></label>\n",
		"</fieldset>\n";

	# Print notification checkbox
	my $checked = $cfg->{noteDefMod} ? "checked='checked'" : "";
	print
		"<fieldset>\n",
		"<div><label><input type='checkbox' name='notify' $checked/>$lng->{notNotify}</label></div>\n",
		"<input type='text' class='fwi' name='reason'/>\n",
		"</fieldset>\n"
		if $topic->{userId} > 0 && $topic->{userId} != $userId;

	print
		$m->submitButton('mgtMrgB', 'merge'),
		"<input type='hidden' name='tid' value='$oldTopicId'/>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'topic', 'merge', $userId, 0, $oldTopicId);
	$m->printFooter();
}
$m->finish();
