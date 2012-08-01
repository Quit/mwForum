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

# Check if access should be denied
$cfg->{polls} or $m->error('errNoAccess');

# Get CGI parameters
my $topicId = $m->paramInt('tid');
my $title = $m->paramStr('title');
my $optionText = $m->paramStr('options');
my $multi = $m->paramBool('multi');
my $submitted = $m->paramBool('subm');
$topicId or $m->error('errParamMiss');

# Get topic
my $topic = $m->fetchHash("
	SELECT topics.id, topics.boardId, topics.pollId, topics.subject, topics.locked,
		posts.userId
	FROM topics AS topics
		INNER JOIN posts AS posts
			ON posts.id = topics.basePostId
	WHERE topics.id = ?", $topicId);
$topic or $m->error('errTpcNotFnd');
!$topic->{pollId} or $m->error('errPolExist');
my $boardId = $topic->{boardId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Check if user can see and write to board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId);
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');
$boardAdmin || $m->boardWritable($board, 1) or $m->error('errNoAccess');

# Check if user owns topic or is moderator
$userId == $topic->{userId} || $boardAdmin or $m->error('errNoAccess');

# Check if polls are enabled
$cfg->{polls} == 1 || $cfg->{polls} == 2 && $boardAdmin	or $m->error('errNoAccess');

# Check if topic is locked
!$topic->{locked} || $boardAdmin or $m->error('errTpcLocked');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');
	
	# Split options text into options
	my @options = grep(/\S/, split(/[\r\n]+/, $optionText));
	
	# Check option limits
	@options >= 2 && @options <= 20 or $m->formError('errPolOptNum');
	for my $option (@options) { 
		if (length($option) > 60) { $m->formError('errOptLen'); last; }
	}

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Insert poll
		my $titleEsc = $m->escHtml(substr($title, 0, 200));
		$m->dbDo("
			INSERT INTO polls (title, multi) VALUES (?, ?)",
			$titleEsc, $multi);
		my $pollId = $m->dbInsertId("polls");

		# Insert poll options
		for my $i (0..19) {
			last if !defined($options[$i]);
			my $optionEsc = $m->escHtml($options[$i]);
			$m->dbDo("
				INSERT INTO pollOptions (pollId, title) VALUES (?, ?)",
				$pollId, $optionEsc);
		}
		
		# Update topic
		$m->dbDo("
			UPDATE topics SET pollId = ? WHERE id = ?", $pollId, $topicId);
		
		# Log action and finish
		$m->logAction(1, 'poll', 'add', $userId, $boardId, $topicId, undef, $pollId);
		$m->redirect('topic_show', tid => $topicId, msg => 'PollAdd');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('topic_show', tid => $topicId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{tpcTitle}, subTitle => $topic->{subject}, 
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(['aplPollNote']);
	$m->printFormErrors();

	# Escape submitted values
	my $titleEsc = $m->escHtml($title);
	my $optionTextEsc = $m->escHtml($optionText, 1);

	# Prepare values
	my $multiChk = $multi ? 'checked' : "";

	# Print add poll form
	print
		"<form action='poll_add$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{aplTitle}</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{aplPollTitle}\n",
		"<input type='text' class='fwi' name='title' maxlength='200' value='$titleEsc'",
		" autofocus required></label>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{aplPollOpts}\n",
		"<textarea name='options' rows='14' required>$optionTextEsc</textarea></label>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<label><input type='checkbox' name='multi' $multiChk>$lng->{aplPollMulti}</label>\n",
		"</fieldset>\n",
		$m->submitButton('aplPollAddB', 'poll'),
		"<input type='hidden' name='tid' value='$topicId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'poll', 'add', $userId, $boardId, $topicId);
	$m->printFooter();
}
$m->finish();
