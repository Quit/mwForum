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
my $topicId = $m->paramInt('tid');
my $tag = $m->paramStrId('tag');
my $submitted = $m->paramBool('subm');
$topicId or $m->error('errParamMiss');

# Get topic
my ($boardId, $basePostId, $oldTag) = $m->fetchArray("
	SELECT boardId, basePostId, tag FROM topics WHERE id = ?", $topicId);
$boardId or $m->error('errTpcNotFnd');

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
	
# Check if user can see and write to board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId);
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');
$boardAdmin || $m->boardWritable($board, 1) or $m->error('errNoAccess');

# Check if user owns topic or is moderator
if ($cfg->{allowTopicTags} == 0) { 
	$m->error('errNoAccess'); 
}
elsif ($cfg->{allowTopicTags} == 1) {
	$boardAdmin or $m->error('errNoAccess');
}
elsif ($cfg->{allowTopicTags} == 2) {
	my $topicUserId = $m->fetchArray("
		SELECT userId FROM posts WHERE id = ?", $basePostId);
	$userId == $topicUserId || $boardAdmin or $m->error('errNoAccess');
}

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Check if tag exists
	!length($tag) || length($cfg->{topicTags}{$tag}) or $m->formError("Tag doesn't exist.");

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update topic
		$m->dbDo("
			UPDATE topics SET tag = ? WHERE id = ?", $tag, $topicId);

		# Log action and finish
		$m->logAction(1, 'topic', 'tag', $userId, $boardId, $topicId);
		$m->redirect('board_show', tid => $topicId, msg => 'TpcTag', tgt => "tid$topicId");
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
	$m->printPageBar(mainTitle => $lng->{ttgTitle}, subTitle => $subject, navLinks => \@navLinks);
	
	# Print hints and form errors
	$m->printFormErrors();

	# Prepare values
	my $noTagChk = !$oldTag ? 'checked' : "";

	# Print tag form
	print
		"<form action='topic_tag$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{ttgTagTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<div><label><input type='radio' name='tag' value='' autofocus $noTagChk></label></div>\n";

	# Print tag list	
	for my $key (sort keys %{$cfg->{topicTags}}) {
		my $chk = $key eq $oldTag ? 'checked' : "";
		my ($title) = $cfg->{topicTags}{$key} =~ /[\w.]+\s*(.*)?/;
		print
			"<div><label><input type='radio' name='tag' value='$key' $chk>",
			$m->formatTopicTag($key), " $title</label></div>\n";
	}

	# Print submit section	
	print
		$m->submitButton('ttgTagB', 'tag'),
		"<input type='hidden' name='tid' value='$topicId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'topic', 'tag', $userId, 0, $topicId);
	$m->printFooter();
}
$m->finish();
