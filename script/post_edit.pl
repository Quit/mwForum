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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0]);

# Get CGI parameters
my $postId = $m->paramInt('pid');
my $subject = $m->paramStr('subject');
my $body = $m->paramStr('body');
my $rawBody = $m->paramStr('raw', 0);
my $notify = $m->paramBool('notify');
my $edit = $m->paramBool('edit');
my $preview = $m->paramBool('preview');
my $reason = $m->paramStr('reason');
$postId or $m->error('errParamMiss');

# Get post
my $post = $m->fetchHash("
	SELECT * FROM posts WHERE id = ?", $postId);
$post or $m->error('errPstNotFnd');
my $boardId = $post->{boardId};
my $topicId = $post->{topicId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Get topic
my $topic = $m->fetchHash("
	SELECT * FROM topics WHERE id = ?", $topicId);
$topic or $m->error('errTpcNotFnd');

# Check if user can see and write to board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId);
my $boardMember = $m->boardMember($userId, $boardId);
$boardAdmin || $boardMember || $m->boardVisible($board) or $m->error('errNoAccess');
$boardAdmin || $boardMember || $m->boardWritable($board, 1) or $m->error('errNoAccess');

# Check if user owns post or is moderator
$userId && $userId == $post->{userId} || $boardAdmin or $m->error('errNoAccess');

# Don't allow editing of approved posts in moderated boards
!$board->{approve} || !$post->{approved} || $boardAdmin || ($boardMember && $board->{private} != 1)
	or $m->error('errEditAppr');

# Check editing time limitation
!$cfg->{postEditTime} || $m->{now} < $post->{postTime} + $cfg->{postEditTime} 
	|| $boardAdmin || $boardMember
	or $m->error('errPstEdtTme');

# Check if topic or post is locked
!$topic->{locked} || $boardAdmin or $m->error('errTpcLocked');
!$post->{locked} || $boardAdmin or $m->error('errPstLocked');

# Check authorization
$m->checkAuthz($user, 'editPost');

# Process form
if ($edit) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Check subject/body length
	if ($postId == $topic->{basePostId}) {
		length($subject) or $m->formError('errSubEmpty');
		length($subject) <= $cfg->{maxSubjectLen} or $m->formError('errSubLen');
		$subject =~ /\S/ or $m->formError('errSubNoText') if length($subject);
	}
	length($body) || $post->{userId} == -2 or $m->formError('errBdyEmpty');
	length($body) <= $cfg->{maxBodyLen} or $m->formError('errBdyLen');
	length($rawBody) <= $cfg->{maxBodyLen} or $m->formError('errBdyLen');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Process text
		my $oldBody = $post->{body};
		$post->{subject} = $subject;
		$post->{body} = $body;
		$post->{rawBody} = $rawBody;
		$m->editToDb({}, $post);

		# Only change editTime if there's some time between post and edit, and body changed
		my $postEditStTime = defined($cfg->{postEditStTime}) ? $cfg->{postEditStTime} : 120;
		my $editTime = ($m->{now} - $post->{postTime} > $postEditStTime) && ($oldBody ne $post->{body})
			? $m->{now} : $post->{editTime};
		
		# Update post
		$m->dbDo("
			UPDATE posts SET editTime = ?, body = ?, rawBody = ? WHERE id = ?", 
			$editTime, $post->{body}, $post->{rawBody}, $postId)
			if $post->{userId} != -2;
		
		# Update topic subject if first post
		$m->dbDo("
			UPDATE topics SET subject = ? WHERE id = ?", $post->{subject}, $topicId)
			if $postId == $topic->{basePostId};

		# Add notification message
		if ($notify && $post->{userId} && $post->{userId} != $userId) {
			my $url = "topic_show$m->{ext}?pid=$postId";
			$m->addNote('pstEdt', $post->{userId}, 'notPstEdt', pstUrl => $url, reason => $reason);
		}

		# Log action and finish
		$m->logAction(1, 'post', 'edit', $userId, $boardId, $topicId, $postId);
		$m->redirect('topic_show', pid => $postId, msg => 'PstChange');
	}
}

# Print form
if (!$edit || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader(undef, { tagButtons => 1, lng_tbbInsSnip => $lng->{tbbInsSnip} });

	# Print page bar
	my @navLinks = ({ url => $m->url('topic_show', pid => $postId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{eptTitle}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Prepare subject and body
	my ($subjectEsc, $bodyEsc, $rawBodyEsc);
	if ($edit || $preview) { 
		$subjectEsc = $m->escHtml($subject);
		$bodyEsc = $m->escHtml($body, 1);
		$rawBodyEsc = $m->escHtml($rawBody, 1);
	}
	else {
		$subjectEsc = $topic->{subject};
		$m->dbToEdit({}, $post);
		$bodyEsc = $post->{body};
		$rawBodyEsc = $post->{rawBody};
	}

	# Prepare preview body
	if ($preview) {
		$preview = { body => $body, rawBody => $rawBody };
		$m->editToDb({}, $preview);
		$m->dbToDisplay($board, $preview);
	}

	# Print edit post form
	print
		"<form action='post_edit$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{eptEditTtl}</span></div>\n",
		"<div class='ccl'>\n";

	# Print subject input
	print	
		"<fieldset>\n",
		"<label class='lbw'>$lng->{eptEditSbj}\n",
		"<input type='text' class='fwi' name='subject' maxlength='$cfg->{maxSubjectLen}'",
		" value='$subjectEsc' autofocus required></label>\n",
		"</fieldset>\n"
		if $postId == $topic->{basePostId};

	# Print body textarea
	print
		"<fieldset>\n",
		$m->tagButtons($board),
		"<textarea class='tgi' name='body' rows='14' required>$bodyEsc</textarea>\n",
		"</fieldset>\n"
		if $post->{userId} != -2;

	# Print raw body textarea
	print
		$rawBodyEsc ? "<fieldset>\n" : 
			"<div><a class='clk rvl' data-rvlid='#rawtxt' href='#'>$lng->{eptEditIRaw} &#187;"
			. "</a></div>\n<fieldset id='rawtxt' style='display: none'>\n",
		"<label class='lbw'>$lng->{eptEditRaw}\n",
		"<textarea class='raw' name='raw' rows='14' spellcheck='false'>$rawBodyEsc",
		"</textarea></label>\n",
		"</fieldset>\n"
		if $cfg->{rawBody};

	# Print notification section
	my $noteChk = $cfg->{noteDefMod} ? 'checked' : "";
	print		
		"<fieldset>\n",
		"<div><label><input type='checkbox' name='notify' $noteChk>$lng->{notNotify}</label></div>\n",
		"<datalist id='reasons'>\n",
		map("<option value='$_'>\n", @{$cfg->{modReasons}}),
		"</datalist>\n",
		"<input type='text' class='fwi' name='reason' list='reasons'>\n",
		"</fieldset>\n"
		if $post->{userId} > 0 && $post->{userId} != $userId;

	# Print submit section
	print
		$m->submitButton('eptEditB', 'edit', 'edit'),
		$m->submitButton('eptEditPrvB', 'preview', 'preview'),
		"<input type='hidden' name='pid' value='$postId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Print preview
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{eptPrvTtl}</span></div>\n",
		"<div class='ccl'>\n",
		$preview->{body}, "\n",
		"</div>\n",
		"</div>\n\n"
		if $preview;
	
	# Log action and finish
	$m->logAction(3, 'post', 'edit', $userId, $boardId, $topicId, $postId);
	$m->printFooter();
}
$m->finish();
