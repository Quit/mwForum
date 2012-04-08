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
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $postId = $m->paramInt('pid');
my $reason = $m->paramStr('reason');
my $really = $m->paramBool('really');
my $action = $m->paramStrId('act');
my $submitted = $m->paramBool('subm');
$postId or $m->error('errParamMiss');

# Get post
my $post = $m->fetchHash("
	SELECT userId, boardId, topicId, postTime FROM posts WHERE id = ?", $postId);
$post or $m->error('errPstNotFnd');

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $post->{boardId});
$board or $m->error('errBrdNotFnd');

# Check if user can see board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $board->{id});
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');

# Check if feature is enabled
my $threading = !$board->{flat} && $boardAdmin && $post->{postTime} > $m->{now} - 86400;
$cfg->{reports} || $threading or $m->error('errNoAccess');

# Check if there's already a report from user
my $entry = $m->fetchArray("
	SELECT userId FROM postReports WHERE userId = ? AND postId = ?", $userId, $postId);
!$entry or $m->error('errRepDupe');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	if ($action eq 'report') {
		# Don't let user report his own posts
		$userId != $post->{userId} or $m->error('errRepOwn');
	
		# Check reason
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
			$m->logAction(1, 'report', 'add', $userId, $board->{id}, $post->{topicId}, $postId);
			$m->redirect('topic_show', pid => $postId, msg => 'PstAddRep');
		}
	}
	elsif ($action eq 'threading') {
		# Only for admins
		$boardAdmin or $m->error('errNoAccess');
		
		# Add thread structure notification
		my $url = "topic_show$m->{ext}?pid=$postId";
		$m->addNote('thrStr', $post->{userId}, 'notThrStr', pstUrl => $url);

		# Log action and finish
		$m->logAction(1, 'report', 'thread', $userId, $board->{id}, $post->{topicId}, $postId);
		$m->redirect('topic_show', pid => $postId);
	}
	else { $m->error('errParamMiss') }
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print bar
	my @navLinks = ({ url => $m->url('topic_show', pid => $postId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{arpTitle}, navLinks => \@navLinks);
	
	if ($cfg->{reports} && !$really && !$boardAdmin) {
		# Remind user that this is not the reply form
		my $url = $m->url('report_add', pid => $postId, really => 1);
		print
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{arpRepTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<p>$lng->{arpRepT}</p>\n",
			"<p><em>$lng->{arpRepOrly}</em></p>\n",
			"<p><a href='$url'>$lng->{arpRepYarly}</a></p>\n",
			"</div>\n",
			"</div>\n";
	}
	elsif ($cfg->{reports}) {
		# Print hints and form errors
		$m->printFormErrors();

		# Print report form
		print
			"<form action='report_add$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{arpRepTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<label class='lbw'>$lng->{arpRepReason}\n",
			"<textarea class='fcs' name='reason' rows='4' autofocus='autofocus' required='required'>",
			"</textarea></label>\n",
			$m->submitButton('arpRepB', 'report'),
			"<input type='hidden' name='act' value='report'/>\n",
			"<input type='hidden' name='pid' value='$postId'/>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}
	
	if ($threading) {
		# Check if there's already a notification
		my $notified = $m->fetchArray("
			SELECT 1 FROM notes WHERE type = ? AND userId = ?", 'thrStr', $post->{userId});
		
		# Print thread structure notification form
		print
			"<form action='report_add$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{arpThrTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<p>$lng->{arpThrT}</p>",
			$m->submitButton('arpThrB', 'report'),
			"<input type='hidden' name='act' value='threading'/>\n",
			"<input type='hidden' name='pid' value='$postId'/>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n"
			if !$notified;
	}

	# Log action and finish
	$m->logAction(3, 'report', 'add', $userId, $board->{id}, $post->{topicId}, $postId);
	$m->printFooter();
}
$m->finish();
