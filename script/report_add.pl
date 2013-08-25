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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0], autocomplete => 1);

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $postId = $m->paramInt('pid');
my $reason = $m->paramStr('reason');
my $userName = $m->paramStr('userName');
my $really = $m->paramBool('really');
my $email = $m->paramBool('email');
my $action = $m->paramStrId('act');
my $submitted = $m->paramBool('subm');
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
	SELECT subject FROM topics WHERE id = ?", $topicId);
$topic or $m->error('errTpcNotFnd');

# Check if user can see board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId);
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');

# Check if there's already a report from user
my $reported = $m->fetchArray("
	SELECT userId FROM postReports WHERE userId = ? AND postId = ?", $userId, $postId);

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	if ($action eq 'ping') {
		# Get recipient
		$userName or $m->formError('errNamEmpty');
		my $pingUserId = $m->fetchArray("
			SELECT id FROM users WHERE userName = ?", $userName);
		$pingUserId or $m->formError('errUsrNotFnd');

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Notify if not ignored
			my $ignored = $m->fetchArray("
				SELECT 1 FROM userIgnores WHERE userId = ? AND ignoredId = ?", $pingUserId, $userId);
			if (!$ignored) {
				# Add ping notification
				my $url = "topic_show$m->{ext}?pid=$postId";
				$m->addNote('pstPng', $pingUserId, 'notPstPng',
					usrNam => $user->{userName}, pstUrl => $url);
	
				# Send notification email
				my $pingUser = $m->getUser($pingUserId);
				if ($email && $pingUser->{email} && !$pingUser->{dontEmail}) {
					$m->dbToEmail({}, $post);
					$lng = $m->setLanguage($pingUser->{language});
					my $subject = "$lng->{arpPngMlSbPf} $user->{userName}: $topic->{subject}";
					my $body = $lng->{arpPngMlT} . "\n\n" . "-" x 70 . "\n\n"
						. $lng->{subLink} . "$cfg->{baseUrl}$m->{env}{scriptUrlPath}/$url\n"
						. $lng->{subBoard} . $board->{title} . "\n"
						. $lng->{subTopic} . $topic->{subject} . "\n"
						. $lng->{subBy} . $post->{userNameBak} . "\n"
						. $lng->{subOn} . $m->formatTime($post->{postTime}, $pingUser->{timezone}) . "\n\n"
						. $post->{body} . "\n\n"
						. ($post->{rawBody} ? $post->{rawBody} . "\n\n" : "")
						. "-" x 70 . "\n\n";
					$lng = $m->setLanguage();
					$m->sendEmail(user => $pingUser, subject => $subject, body => $body);
				}
			}
	
			# Log action and finish
			$m->logAction(1, 'report', 'ping', $userId, $boardId, $topicId, $postId, $pingUserId);
			$m->redirect('topic_show', pid => $postId, msg => 'PstPing');
		}
	}
	elsif ($action eq 'report') {
		# Check for errors
		!$reported or $m->formError('errRepDupe');
		$reason or $m->formError('errRepReason');

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Filter and quote strings
			my $fakePost = { isReport => 1, body => $reason };
			$m->editToDb({}, $fakePost);
			
			# Add post to list
			$m->dbDo("
				INSERT INTO postReports (userId, postId, reason) VALUES (?, ?, ?)", 
				$userId, $postId, $fakePost->{body});
			
			# Log action and finish
			$m->logAction(1, 'report', 'add', $userId, $boardId, $topicId, $postId);
			$m->redirect('topic_show', pid => $postId, msg => 'PstAddRep');
		}
	}
	elsif ($action eq 'threading') {
		# Only for admins
		$boardAdmin or $m->error('errNoAccess');

		# Don't let user report their own posts
		$userId != $post->{userId} or $m->error("Reporting your own post?");
		
		# Add thread structure notification
		my $url = "topic_show$m->{ext}?pid=$postId";
		$m->addNote('thrStr', $post->{userId}, 'notThrStr', pstUrl => $url);

		# Log action and finish
		$m->logAction(1, 'report', 'thread', $userId, $boardId, $topicId, $postId);
		$m->redirect('topic_show', pid => $postId);
	}
	else { $m->error('errParamMiss') }
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('topic_show', pid => $postId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{arpTitle}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();

	# Prepare values
	my $userNameEsc = $m->escHtml($userName);
	my $emailChk = $email ? 'checked' : "";
	my $autofocus = !$really ? 'autofocus' : "";
	
	# Print ping form
	print
		"<form action='report_add$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{arpPngTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<p>$lng->{arpPngT}</p>",
		"<label class='lbw'>$lng->{arpPngUser}\n",
		"<input type='text' class='qwi acu acs' name='userName' value='$userNameEsc'",
		" $autofocus required></label>\n",
		"<fieldset>\n",
		"<label><input type='checkbox' name='email' $emailChk>$lng->{arpPngEmail}</label>\n",
		"</fieldset>\n",
		$m->submitButton('arpPngB', 'report'),
		"<input type='hidden' name='act' value='ping'>\n",
		"<input type='hidden' name='pid' value='$postId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	if ($cfg->{reports} && !$reported && !$really && !$boardAdmin) {
		# Remind user that this is not the reply form
		my $url = $m->url('report_add', pid => $postId, really => 1);
		print
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{arpRepTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<p>$lng->{arpRepT}</p>\n",
			"<p><a href='$url'>$lng->{arpRepYarly}</a></p>\n",
			"</div>\n",
			"</div>\n";
	}
	elsif ($cfg->{reports} && !$reported) {
		# Print report form
		$autofocus = $really ? 'autofocus' : "";
		print
			"<form action='report_add$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{arpRepTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<label class='lbw'>$lng->{arpRepReason}\n",
			"<textarea name='reason' rows='4' $autofocus required></textarea></label>\n",
			$m->submitButton('arpRepB', 'report'),
			"<input type='hidden' name='act' value='report'>\n",
			"<input type='hidden' name='pid' value='$postId'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}
	
	if (!$board->{flat} && $boardAdmin && $post->{postTime} > $m->{now} - 86400) {
		# Check if there's already a notification
		my $notified = $m->fetchArray("
			SELECT 1 FROM notes WHERE type = ? AND userId = ?", 'thrStr', $post->{userId});
		
		# Print thread structure notification form
		print
			"<form action='report_add$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{arpThrTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<p>$lng->{arpThrT}</p>\n",
			$m->submitButton('arpThrB', 'report'),
			"<input type='hidden' name='act' value='threading'>\n",
			"<input type='hidden' name='pid' value='$postId'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n"
			if !$notified;
	}

	# Log action and finish
	$m->logAction(3, 'report', 'add', $userId, $boardId, $topicId, $postId);
	$m->printFooter();
}
$m->finish();
