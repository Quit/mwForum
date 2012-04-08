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
my $field = $m->paramStrId('field');
my $value = $m->paramStr('value');
my $submitted = $m->paramBool('subm');

# Define names and descriptions of fields
my %fields = (
	title => "Title",
	hideEmail => "Hide Email",
	dontEmail => "Disable Email",
	notify => "Reply Notifications",
	msgNotify => "Email Notifications",
	tempLogin => "Temporary Login",
	privacy => "Hide Online Status",
	signature => "Signature",
	blurb => "Miscellaneous",
	extra1 => "Extra 1",
	extra2 => "Extra 2",
	extra3 => "Extra 3",
	timezone => "Timezone",
	language => "Language",
	style => "Style",
	fontFace => "Font Face",
	fontSize => "Font Size",
	boardDescs => "Show Board Desc.",
	showDeco => "Show Decorations",
	showAvatars => "Show Avatars",
	showImages => "Show Embed. Imgs",
	showSigs => "Show Signatures",
	collapse => "Collapse Branches",
	indent => "Threading Indent",
	topicsPP => "Topics Per Page",
	postsPP => "Posts Per Page",
	bounceNum => "Bounce Counter",
	renamesLeft => "Renames Left",
	oldNames => "Old Usernames",
);

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Make sure valid field is selected
	$fields{$field} or $m->formError("Invalid field");

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update users
		$m->dbDo("
			UPDATE users SET $field = ?", $value);
		
		# Log action and finish
		$m->logAction(1, 'user', 'set', $userId);
		$m->redirect('user_set');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_admin'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "User Administration", navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints(["This form sets the selected user field of all users to the same value. " .
		" Use carefully."]);
	$m->printFormErrors();

	# Print mass setting form
	print
		"<form action='user_set$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Mass-Setting User Fields</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>Field\n",
		"<select class='fcs' name='field' size='1' autofocus='autofocus'>\n";

	print "<option value='$_'>$fields{$_}</option>\n"
		for sort({$fields{$a} cmp $fields{$b}} keys(%fields));
	
	print
		"</select></label>\n",
		"<label class='lbw'>Value\n",
		"<input type='text' class='hwi' name='value'/></label>\n",
		$m->submitButton("Mass Set", 'edit'),
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'user', 'set', $userId);
	$m->printFooter();
}
$m->finish();
