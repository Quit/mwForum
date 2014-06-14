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

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $realName = $m->paramStr('realName') || "";
my $homepage = $m->paramStr('homepage') || "";
my $occupation = $m->paramStr('occupation') || "";
my $hobbies = $m->paramStr('hobbies') || "";
my $location = $m->paramStr('location') || "";
my $icq = $m->paramStr('icq') || "";
my $signature = $m->paramStr('signature') || "";
my $blurb = $m->paramStr('blurb') || "";
my $extra1 = $m->paramStr('extra1') || "";
my $extra2 = $m->paramStr('extra2') || "";
my $extra3 = $m->paramStr('extra3') || "";
my $birthdate = $m->paramStr('birthdate') || "";
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $admin = $user->{admin};
my $optUser = $optUserId && $admin ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Don't update fields if they are not displayed in form
	$extra1 = $optUser->{extra1} if !$cfg->{extra1} || $cfg->{regExtra1} == 2;
	$extra2 = $optUser->{extra2} if !$cfg->{extra2} || $cfg->{regExtra2} == 2;
	$extra3 = $optUser->{extra3} if !$cfg->{extra3} || $cfg->{regExtra3} == 2;
	
	# Parse birthdate
	my ($birthyear, $birthday) = $birthdate =~ /(?:([0-9]{4})-)?([0-9]{2}-[0-9]{2})/;
	$birthyear ||= 0;
	$birthday ||= "";
	
	# Add http:// to homepage if missing
	$homepage = "http://$homepage" if $homepage && $homepage !~ /^http/ && $homepage =~ /^www\./;
	
	# Limit string lengths
	($realName, $homepage, $occupation, $hobbies, $location, $icq) =
		map(substr($_, 0, 100), $realName, $homepage, $occupation, $hobbies, $location, $icq);
	($extra1, $extra2, $extra3) =
		map(substr($_, 0, 255), $extra1, $extra2, $extra3);
		
	# Process signature
	if ($cfg->{fullSigs}) {
		my $fakePost = { body => $signature };
		$m->editToDb({}, $fakePost);
		$signature = $fakePost->{body};
		length($signature) <= $cfg->{maxBodyLen} or $m->formError('errBdyLen');
	}
	else {
		$signature =~ s/\r//g;
		($signature) = $signature =~ /(.+\n?.*)/;
		$signature = substr($signature, 0, 100);
		$signature = $m->escHtml($signature, 2);
	}

	# Process blurb	
	my $fakePost = { isBlurb => 1, body => $blurb };
	$m->editToDb({}, $fakePost);
	$blurb = $fakePost->{body};
	length($blurb) <= $cfg->{maxBodyLen} or $m->formError('errBdyLen');

	# Escape submitted values
	my $realNameEsc = $m->escHtml($realName);
	my $homepageEsc = $m->escHtml($homepage);
	my $occupationEsc = $m->escHtml($occupation);
	my $hobbiesEsc = $m->escHtml($hobbies);
	my $locationEsc = $m->escHtml($location);
	my $icqEsc = $m->escHtml($icq);
	my $extra1Esc = $m->escHtml($extra1);
	my $extra2Esc = $m->escHtml($extra2);
	my $extra3Esc = $m->escHtml($extra3);
	my $birthdayEsc = $m->escHtml($birthday);
	
	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update user
		$m->dbDo("
			UPDATE users SET
				realName = ?, homepage = ?, occupation = ?, hobbies = ?, location = ?, icq = ?,
				signature = ?, blurb = ?, extra1 = ?, extra2 = ?, extra3 = ?, birthyear = ?, birthday = ?
			WHERE id = ?",
			$realNameEsc, $homepageEsc, $occupationEsc, $hobbiesEsc, $locationEsc, $icqEsc,
			$signature, $blurb, $extra1Esc, $extra2Esc, $extra3Esc, $birthyear, $birthdayEsc,
			$optUserId);

		# Log action and finish
		$m->logAction(1, 'user', 'profile', $userId, 0, 0, 0, $optUserId);
		$m->redirect('forum_show', msg => 'PrfChange');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader(undef, { cfg_userInfoMap => $cfg->{userInfoMap} });

	# Check if there are badges user can select
	my $selfBadge = 0;
	for my $line (@{$cfg->{badges}}) {
		my ($type) = $line =~ /\w+\s+(\w+)/;
		if ($type eq 'user') { $selfBadge = 1; last }
	}

	# User button links
	my @userLinks = ();
	push @userLinks, { url => $m->url('user_info', uid => $optUserId), 
		txt => 'uopInfo', ico => 'info' };
	push @userLinks, { url => $m->url('user_name'), txt => 'uopName', ico => 'name' }
		if $userId == $optUserId && $optUser->{renamesLeft};
	push @userLinks, { url => $m->url('user_avatar', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopAvatar', ico => 'avatar' } 
		if $cfg->{avatars};
	push @userLinks, { url => $m->url('user_badges', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopBadges', ico => 'tag' } 
		if @{$cfg->{badges}} && ($selfBadge || $admin);
	for my $plugin (@{$cfg->{includePlg}{userProfileLink}}) {
		$m->callPlugin($plugin, links => \@userLinks, user => $optUser);
	}

	# Print page bar
	my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{uopTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks, userLinks => \@userLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Set submitted or database values
	my $realNameEsc = $submitted ? $m->escHtml($realName) : $optUser->{realName};
	my $homepageEsc = $submitted ? $m->escHtml($homepage) : $optUser->{homepage};
	my $occupationEsc = $submitted ? $m->escHtml($occupation) : $optUser->{occupation};
	my $hobbiesEsc = $submitted ? $m->escHtml($hobbies) : $optUser->{hobbies};
	my $locationEsc = $submitted ? $m->escHtml($location) : $optUser->{location};
	my $icqEsc = $submitted ? $m->escHtml($icq) : $optUser->{icq};
	my $extra1Esc = $submitted ? $m->escHtml($extra1) : $optUser->{extra1};
	my $extra2Esc = $submitted ? $m->escHtml($extra2) : $optUser->{extra2};
	my $extra3Esc = $submitted ? $m->escHtml($extra3) : $optUser->{extra3};
	$signature = $submitted ? $signature : $optUser->{signature};
	$blurb = $submitted ? $blurb : $optUser->{blurb};
	
	# Concat birthdate
	if (!$submitted) {
		$birthdate = $optUser->{birthyear} . "-" if $optUser->{birthyear};
		$birthdate .= $optUser->{birthday};
	}
	my $birthdateEsc = $m->escHtml($birthdate);

	# Prepare signature
	if ($cfg->{fullSigs}) { 
		my $fakePost = { body => $signature };
		$m->dbToEdit({}, $fakePost);
		$signature = $fakePost->{body};
	}
	else {
		$signature = $m->escHtml($signature, 1) if $submitted;
		$signature =~ s!<br/?>!\n!g;
	}
	
	# Prepare blurb
	my $fakePost = { isBlurb => 1, body => $blurb };
	$m->dbToEdit({}, $fakePost);
	$blurb = $fakePost->{body};

	# Print profile options
	print
		"<form action='user_profile$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{uopProfTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>$lng->{uopProfRName}\n",
		"<input type='text' class='qwi' name='realName' maxlength='100' value='$realNameEsc'",
		" autofocus></label>\n",
		"<label class='lbw'>$lng->{uopProfBdate}\n",
		"<input type='text' class='qwi' name='birthdate' maxlength='10' value='$birthdateEsc'",
		" pattern='\\d{4}-\\d{2}-\\d{2}|\\d{2}-\\d{2}'></label>\n",
		"<label class='lbw'>$lng->{uopProfPage}\n",
		"<input type='url' class='hwi' name='homepage' maxlength='100' value='$homepageEsc'></label>\n",
		"<label class='lbw'>$lng->{uopProfOccup}\n",
		"<input type='text' class='hwi' name='occupation' maxlength='100' value='$occupationEsc'></label>\n",
		"<label class='lbw'>$lng->{uopProfHobby}\n",
		"<input type='text' class='hwi' name='hobbies' maxlength='100' value='$hobbiesEsc'></label>\n",
		"<label class='lbw'>$lng->{uopProfLocat}",
		" <a class='clk' id='loc' style='display: none'>$lng->{uopProfLocIn}</a>\n",
		"<input type='text' class='hwi' name='location' maxlength='100' value='$locationEsc'></label>\n",
		"<label class='lbw'>$lng->{uopProfIcq}\n",
		"<input type='text' class='hwi' name='icq' maxlength='100' value='$icqEsc'></label>\n",
		$cfg->{extra1} && $cfg->{regExtra1} < 2 ? "<label class='lbw'>$cfg->{longExtra1}\n" . 
			"<input type='text' class='hwi' name='extra1' maxlength='255' value='$extra1Esc'></label>\n" : "",
		$cfg->{extra2} && $cfg->{regExtra2} < 2 ? "<label class='lbw'>$cfg->{longExtra2}\n" .
			"<input type='text' class='hwi' name='extra2' maxlength='255' value='$extra2Esc'></label>\n" : "",
		$cfg->{extra3} && $cfg->{regExtra3} < 2 ? "<label class='lbw'>$cfg->{longExtra3}\n" .
			"<input type='text' class='hwi' name='extra3' maxlength='255' value='$extra3Esc'></label>\n" : "",
		"<label class='lbw'>$lng->{uopProfSig} ", $cfg->{fullSigs} ? "" : $lng->{uopProfSigLt}, "\n",
		"<textarea name='signature' rows='2'>$signature</textarea></label>\n",
		"<label class='lbw'>$lng->{uopProfBlurb}\n",
		"<textarea name='blurb' rows='5'>$blurb</textarea></label>\n",
		$m->submitButton('uopSubmitB', 'profile'),
		"<input type='hidden' name='uid' value='$optUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'user', 'profile', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
