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
my $categId = $m->paramInt('cid');
my $title = $m->paramStr('title');
my $pos = $m->paramInt('pos');
my $submitted = $m->paramBool('subm');
$categId or $m->error('errParamMiss');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Get category
	my $oldPos = $m->fetchArray("
		SELECT pos FROM categories WHERE id = ?", $categId);
	$oldPos or $m->error('errCatNotFnd');

	# Check fields
	$title or $m->formError("Title is empty.");

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update category
		my $titleEsc = $m->escHtml($title);
		$m->dbDo("
			UPDATE categories SET title = ? WHERE id = ?", $titleEsc, $categId);

		# Update positions
		if ($pos > -1) {
			$pos = $pos - 1 if $pos > $oldPos;
			$m->dbDo("
				UPDATE categories SET pos = pos - 1 WHERE pos > ?", $oldPos);
			$m->dbDo("
				UPDATE categories SET pos = pos + 1 WHERE pos > ?", $pos);
			$m->dbDo("
				UPDATE categories SET pos = ? + 1 WHERE id = ?", $pos, $categId);
		}
		
		# Log action and finish
		$m->logAction(1, 'categ', 'options', $userId, 0, 0, 0, $categId);
		$m->redirect('categ_admin');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Get category
	my $categ = $m->fetchHash("
		SELECT title, pos FROM categories WHERE id = ?", $categId);
	$categ or $m->error('errCatNotFnd');
	
	# Get other categories
	my $categs = $m->fetchAllHash("
		SELECT title, pos FROM categories WHERE id <> ? ORDER BY pos", $categId);

	# Print page bar
	my @navLinks = ({ url => $m->url('categ_admin'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Category", subTitle => $categ->{title}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Prepare values
	my $titleEsc = $submitted ? $m->escHtml($title) : $categ->{title};

	# Print options form
	print
		"<form action='categ_options$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Options</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>Title (50 chars)\n",
		"<input type='text' class='hwi' name='title' maxlength='50' value='$titleEsc'",
		" autofocus required></label>\n",
		"<label class='lbw'>Position\n",
		"<select name='pos' size='1'>\n",
		"<option value='-1' selected>Unchanged</option>\n",
		"<option value='0'>Top</option>\n",
		map("<option value='$_->{pos}'>Below \"$_->{title}\"</option>\n", @$categs),
		"</select></label>\n",
		$m->submitButton("Change", 'admopt'),
		"<input type='hidden' name='cid' value='$categId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'categ', 'options', $userId, 0, 0, 0, $categId);
	$m->printFooter();
}
$m->finish();
