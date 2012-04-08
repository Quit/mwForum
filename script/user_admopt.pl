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
my $optUserId = $m->paramInt('uid');
my $userName = $m->paramStr('userName') || "";
my $title = $m->paramStr('titleSel') || $m->paramStr('title') || "";
my $oldNames = $m->paramStr('oldNames');
my $renamesLeft = $m->paramInt('renamesLeft');
my $comment = $m->paramStr('comment');
my $admin = $m->paramBool('admin');
my $dontEmail = $m->paramBool('dontEmail');
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');
	
	# Check if username is free
	!$m->fetchArray("
		SELECT id FROM users WHERE userName = ? AND id <> ?", $userName, $optUserId)
		or $m->formError('errNamGone');
	
	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Limit numerical values to valid range
		$renamesLeft = $m->min($m->max(0, $renamesLeft), 100);

		# Append old username if changed
		$oldNames = join(", ", $optUser->{userName}, $optUser->{oldNames} ? $optUser->{oldNames} : ())
			if $userName ne $optUser->{userName};
		
		# Escape strings
		my $oldNamesEsc = $m->escHtml($oldNames);
		my $commentEsc = $m->escHtml($comment, 2);

		# Update user
		$m->dbDo("
			UPDATE users SET 
				userName = ?, title = ?, admin = ?, dontEmail = ?,
				renamesLeft = ?, oldNames = ?, comment = ?
			WHERE id = ?",
			$userName, $title, $admin, $dontEmail, 
			$renamesLeft, $oldNamesEsc, $commentEsc, 
			$optUserId);
		
		# If username changed, update posts.userNameBak
		$m->dbDo("
			UPDATE posts SET userNameBak = ? WHERE userId = ?", $userName, $optUserId)
			if $userName ne $optUser->{userName};
		
		# Log action and finish
		$m->logAction(1, 'user', 'admopt', $userId, 0, 0, 0, $optUserId);
		$m->redirect('forum_show');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_info', uid => $optUserId), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{uopTitle}, subTitle => $optUser->{userName},
		navLinks => \@navLinks);
	
	# Set submitted or database values
	my $oldNamesEsc = $submitted ? $m->escHtml($oldNames) : $optUser->{oldNames};
	my $commentEsc = $submitted ? $m->escHtml($comment) : $optUser->{comment};
	my $titleEsc = $submitted ? $m->escHtml($title) : $m->escHtml($optUser->{title});
	$renamesLeft = $submitted ? $renamesLeft : $optUser->{renamesLeft};
	$dontEmail = $submitted ? $dontEmail : $optUser->{dontEmail};
	$admin = $submitted ? $admin : $optUser->{admin};
	
	# Prepare admin comment
	$commentEsc =~ s!<br/>!\n!g;

	# Determine checkbox, radiobutton and listbox states
	my $checked = "checked='checked'";
	my $selected = "selected='selected'";
	my %state = (
		dontEmail => $dontEmail ? $checked : undef,
		admin => $admin ? $checked : undef,
	);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Print admin only options
	print
		"<form action='user_admopt$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Admin Options</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>Username\n",
		"<input type='text' class='fcs hwi' name='userName' maxlength='$cfg->{maxUserNameLen}'",
		" autofocus='autofocus' required='required' value='$optUser->{userName}'/></label>\n",
		"<label class='lbw'>Old usernames (will be extended automatically when user is renamed)\n",
		"<input type='text' class='fwi' name='oldNames' value='$oldNamesEsc'/></label>",
		"<label class='lbw'>Remaining number of times user can change username\n",
		"<input type='number' name='renamesLeft' value='$renamesLeft'/></label>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<label class='lbw'>Title (see FAQ.html for details)\n",
		"<select name='titleSel' size='1'>\n",
		"<option value=''>(individual title below)</option>\n";
	
	for my $ttl (@{$cfg->{userTitles}}) {
		my $ttlEsc = $m->escHtml($ttl);
		my $sel = $ttlEsc eq $title ? "selected='selected'" : "";
		print "<option value='$ttlEsc' $sel>$ttlEsc</option>\n";
	}
	
	print
		"</select></label>\n",
		"<input type='text' class='hwi' name='title' value='$titleEsc'/>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<label class='lbw'>Comments (only visible to admins)\n",
		"<textarea name='comment' rows='4'>$commentEsc</textarea></label>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<div><label><input type='checkbox' name='admin' $state{admin}/>",
		" User is a forum admin</label></div>\n",
		"<div><label><input type='checkbox' name='dontEmail' $state{dontEmail}/>",
		" Don't send email to this user</label></div>\n",
		"</fieldset>\n",
		$m->submitButton("Change", 'admopt'),
		"<input type='hidden' name='uid' value='$optUserId'/>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'user', 'admopt', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
