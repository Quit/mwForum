#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2014 Markus Wichitill
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
my $boardId = $m->paramInt('bid');
my $title = $m->paramStr('title');
my $shortDesc  = $m->paramStr('shortDesc');
my $longDesc = $m->paramStr('longDesc');
my $locking = $m->paramInt('locking');
my $topicAdmins = $m->paramBool('topicAdmins');
my $expiration = $m->paramInt('expiration');
my $catPos = $m->paramStr('catPos');
my $approve = $m->paramBool('approve');
my $unregistered = $m->paramBool('unregistered');
my $private = $m->paramInt('private');
my $list = $m->paramBool('list');
my $announce = $m->paramInt('announce');
my $flat = $m->paramBool('flat');
my $attach = $m->paramInt('attach');
my $submitted = $m->paramBool('subm');
$boardId or $m->error('errParamMiss');

# Parse category/position
my ($categId, $pos) = $catPos =~ /(-?[0-9]+) (-?[0-9]+)/;

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Get board
	my ($oldCategId, $oldPos) = $m->fetchArray("
		SELECT categoryId, pos FROM boards WHERE id = ?", $boardId);
	$oldCategId or $m->error('errBrdNotFnd');

	# Check fields
	$title or $m->formError("Title is empty.");
	$categId or $m->formError("Category ID is empty or zero.");

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update board
		my $titleEsc = $m->escHtml($title);
		$longDesc =~ s!\n!<br/>!g;
		$m->dbDo("
			UPDATE boards SET
				title = ?, expiration = ?, locking = ?, topicAdmins = ?, approve = ?, private  = ?,
				list = ?, unregistered = ?, announce = ?, flat = ?,
				attach = ?, shortDesc = ?, longDesc = ?
			WHERE id = ?",
			$titleEsc, $expiration, $locking, $topicAdmins, $approve, $private, 
			$list, $unregistered, $announce, $flat, 
			$attach, $shortDesc, $longDesc, 
			$boardId);

		# Update category and positions
		if ($categId > -1 && $pos > -1) {
			$pos = $pos - 1 if $pos > $oldPos && $categId == $oldCategId;
			$m->dbDo("
				UPDATE boards SET pos = pos - 1 WHERE categoryId = ? AND pos > ?",
				$oldCategId, $oldPos);
			$m->dbDo("
				UPDATE boards SET pos = pos + 1 WHERE categoryId = ? AND pos > ?",
				$categId, $pos);
			$m->dbDo("
				UPDATE boards SET categoryId = ?, pos = ? + 1 WHERE id = ?",
				$categId, $pos, $boardId);
		}
		
		# Log action and finish
		$m->logAction(1, 'board', 'options', $userId, $boardId);
		$m->redirect('board_admin');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Get board
	my $board = $m->fetchHash("
		SELECT * FROM boards WHERE id = ?", $boardId);
	$board or $m->error('errBrdNotFnd');
	
	# Get categories
	my $categs = $m->fetchAllHash("
		SELECT id, title FROM categories ORDER BY pos");

	# Print page bar
	my @navLinks = ({ url => $m->url('board_show', bid => $boardId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Board", subTitle => $board->{title}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Set submitted or database values
	my $titleEsc = $submitted ? $m->escHtml($title) : $board->{title};
	my $shortDescEsc = $submitted ? $m->escHtml($shortDesc) : $m->escHtml($board->{shortDesc});
	my $longDescEsc = $submitted ? $m->escHtml($longDesc) : $m->escHtml($board->{longDesc});
	$locking = $submitted ? $locking : $board->{locking};
	$expiration = $submitted ? $expiration : $board->{expiration};
	$topicAdmins = $submitted ? $topicAdmins : $board->{topicAdmins};
	$flat = $submitted ? $flat : $board->{flat};
	$attach = $submitted ? $attach : $board->{attach};
	$approve = $submitted ? $approve : $board->{approve};
	$unregistered = $submitted ? $unregistered : $board->{unregistered};
	$private = $submitted ? $private : $board->{private};
	$list = $submitted ? $list : $board->{list};
	$announce = $submitted ? $announce : $board->{announce};

	# Prepare long description	
	$longDescEsc =~ s!&lt;br/&gt;!\n!g;

	# Determine checkbox, radiobutton and listbox states
	my $topicAdminsChk = $topicAdmins ? 'checked' : "";
	my $flatChk = $flat ? 'checked' : "";
	my $approveChk = $approve ? 'checked' : "";
	my $unregisteredChk = $unregistered ? 'checked' : "";
	my $listChk = $list ? 'checked' : "";
	my %state = ( "private$private" => 'checked', "announce$announce" => 'checked',
		"attach$attach" => 'checked', "category$categId" => 'selected' );
	$state{attach} = 'disabled' if !$cfg->{attachments};

	# Print options form
	print
		"<form action='board_options$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Options</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>Title (50 chars)\n",
		"<input type='text' class='hwi' name='title' maxlength='50' value='$titleEsc'",
		" autofocus required></label>\n",
		"<label class='lbw'>Short Description (200 chars, shown on forum page, HTML enabled)\n",
		"<input type='text' class='fwi' name='shortDesc' maxlength='200' value='$shortDescEsc'></label>\n",
		"<label class='lbw'>Long Description (shown on board info and optionally board page, HTML enabled)\n",
		"<textarea name='longDesc' rows='3'>$longDescEsc</textarea></label>\n",
		"<label class='lbw'>Locking (days after that inactive topics get locked, 0 = never)\n",
		"<input type='number' name='locking' value='$locking'></label>\n",
		"<label class='lbw'>Expiration (days after that inactive topics get deleted, 0 = never)\n",
		"<input type='number' name='expiration' value='$expiration'></label>\n",
		"<label class='lbw'>Category and position\n",
		"<select name='catPos' size='1'>\n",
		"<option value='-1 -1' selected>Unchanged</option>\n";

	# Print category/position list
	for my $cat (@$categs) {
		print "<option value='$cat->{id} 0'>Top of \"$cat->{title}\"</option>\n";
		my $boards = $m->fetchAllHash("
			SELECT title, pos 
			FROM boards 
			WHERE categoryId = :categId
				AND id <> :boardId
			ORDER BY pos",
			{ categId => $cat->{id}, boardId => $boardId });
		print map("<option value='$cat->{id} $_->{pos}'>- Below \"$_->{title}\"</option>\n", @$boards);
	}

	print 
		"</select></label>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<legend>Read Access</legend>\n",
		"<div><label><input type='radio' name='private' value='1' $state{private1}>",
		"Only moderators and members can read board</label></div>\n",
		"<div><label><input type='radio' name='private' value='2' $state{private2}>",
		"Only registered users can read board</label></div>\n",
		"<div><label><input type='radio' name='private' value='0' $state{private0}>",
		"Everybody can read board</label></div>\n",
		"<div><label><input type='checkbox' name='list' $listChk>",
		"List board on forum page even if user has no access</label></div>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<legend>Write Access</legend>\n",
		"<div><label><input type='radio' name='announce' value='1' $state{announce1}>",
		"Only moderators and members can post</label></div>\n",
		"<div><label><input type='radio' name='announce' value='2' $state{announce2}>",
		"Only moderators and members can start topics, all users can reply</label></div>\n",
		"<div><label><input type='radio' name='announce' value='0' $state{announce0}>",
		"All users can post</label></div>\n",
		"<div><label><input type='checkbox' name='unregistered' $unregisteredChk>",
		"Unregistered Posting (unregistered guests can post)</label></div>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<legend>Attachments</legend>\n",
		"<div><label><input type='radio' name='attach' value='0' $state{attach0}>",
		"Disable</label></div>\n",
		"<div><label><input type='radio' name='attach' value='2' $state{attach2}>",
		"Enable uploading for admins and moderators only</label></div>\n",
		"<div><label><input type='radio' name='attach' value='1' $state{attach1}>",
		"Enable uploading for all registered users</label></div>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<legend>Miscellaneous Options</legend>\n",
		"<div><label><input type='checkbox' name='flat' $flatChk>",
		"Non-Threaded (no topic tree structure)</label></div>\n",
		"<div><label><input type='checkbox' name='approve' $approveChk>",
		"Moderation (posts have to be approved by moderators to be visible)</label></div>\n",
		"<div><label><input type='checkbox' name='topicAdmins' $topicAdminsChk>",
		"Topic Moderators (topic creators are moderators inside their topics)</label></div>\n",
		"</fieldset>\n",
		$m->submitButton("Change", 'admopt'),
		"<input type='hidden' name='bid' value='$boardId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'board', 'options', $userId, $boardId);
	$m->printFooter();
}
$m->finish();
