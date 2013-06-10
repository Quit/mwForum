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

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $timezone = $m->paramStr('timezone');
my $language = $m->paramStr('language') || $cfg->{language};
my $style = $m->paramStr('style') || $cfg->{style};
my $fontFace = $m->paramStr('fontFace');
my $fontSize = $m->paramInt('fontSize') || 0;
my $indent = $m->paramInt('indent') || $cfg->{indent};
my $notify = $m->paramBool('notify');
my $msgNotify = $m->paramBool('msgNotify');
my $privacy = $m->paramBool('privacy');
my $boardDescs = $m->paramBool('boardDescs');
my $showDeco = $m->paramBool('showDeco');
my $showAvatars = $m->paramBool('showAvatars');
my $showImages = $m->paramBool('showImages');
my $showSigs = $m->paramBool('showSigs');
my $collapse = $m->paramBool('collapse');
my $topicsPP = $m->paramStr('topicsPP');  # Detaint and default later
my $postsPP = $m->paramStr('postsPP');  # Detaint and default later
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
	$showAvatars = $optUser->{showAvatars} if !$cfg->{avatars};
	
	# Set default values for numbers per page
	$topicsPP = $cfg->{topicsPP} if length($topicsPP) == 0;
	$postsPP = $cfg->{postsPP} if length($postsPP) == 0;
	$topicsPP = $cfg->{maxTopicsPP} if $topicsPP == 0;
	$postsPP = $cfg->{maxPostsPP} if $postsPP == 0;
	$topicsPP = int($topicsPP);
	$postsPP = int($postsPP);
	
	# Limit numerical values to valid range
	$fontSize = $m->min($m->max(0, $fontSize), 20);
	$indent = $m->min($m->max(1, $indent), 10);
	$topicsPP = $m->min($m->max(0, $topicsPP), $cfg->{maxTopicsPP});
	$postsPP = $m->min($m->max(0, $postsPP), $cfg->{maxPostsPP});
	
	# Limit language and style to valid selection
	$language = $cfg->{languages}{$language} ? $language : $cfg->{language};
	$style = $cfg->{styles}{$style} ? $style : $cfg->{style};

	# Escape submitted values
	my $timezoneEsc = $m->escHtml($timezone);
	my $fontFaceEsc = $m->escHtml($fontFace);
	
	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Update user
		$m->dbDo("
			UPDATE users SET
				notify = ?, msgNotify = ?, privacy = ?, timezone = ?, 
				language = ?,	style = ?, fontFace = ?, fontSize = ?, boardDescs = ?,
				showDeco = ?, showAvatars = ?, showImages = ?, showSigs = ?,
				collapse = ?, indent = ?, topicsPP = ?, postsPP = ?
			WHERE id = ?",
			$notify, $msgNotify, $privacy, $timezoneEsc, 
			$language, $style, $fontFaceEsc, $fontSize, $boardDescs,
			$showDeco, $showAvatars, $showImages, $showSigs, 
			$collapse, $indent, $topicsPP, $postsPP,
			$optUserId);

		# Update style snippets
		for my $snippet (keys %{$cfg->{styleSnippets}}) {
			my $enable = $m->paramBool($snippet);
			my $enabled = $m->fetchArray("
				SELECT 1 FROM userVariables WHERE userId = ? AND name = ?", $optUserId, $snippet);

			if (!$enable && $enabled) {
				$m->dbDo("
					DELETE FROM userVariables WHERE userId = ? AND name = ?", $optUserId, $snippet);
			}
			elsif ($enable && !$enabled) {
				$m->dbDo("
					INSERT INTO userVariables (userId, name) VALUES (?, ?)", $optUserId, $snippet);
			}
		}
		
		# Log action and finish
		$m->logAction(1, 'user', 'options', $userId, 0, 0, 0, $optUserId);
		$m->redirect('forum_show', msg => 'OptChange');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Check if there are groups user can join
	my $openGroups = $m->fetchArray("
		SELECT COUNT(*) FROM groups WHERE open = 1");

	# User button links
	my @userLinks = ();
	push @userLinks, { url => $m->url('user_password', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopPasswd', ico => 'password' }
		if !$cfg->{authenPlg}{login} && !$cfg->{authenPlg}{request};
	push @userLinks, { url => $m->url('user_email', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopEmail', ico => 'subscribe' };
	push @userLinks, { url => $m->url('user_key', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopOpenPgp', ico => 'key' }
		if $cfg->{gpgSignKeyId};
	push @userLinks, { url => $m->url('user_ignore', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopIgnore', ico => 'ignore' };
	push @userLinks, { url => $m->url('user_watch', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopWatch', ico => 'watch' } 
		if $cfg->{watchWords} || $cfg->{watchUsers};
	push @userLinks, { url => $m->url('user_groups', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopGroups', ico => 'group' }
		if $openGroups && $optUserId == $userId;
	push @userLinks, { url => $m->url('user_boards', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopBoards', ico => 'board' };
	push @userLinks, { url => $m->url('user_topics', $admin ? (uid => $optUserId) : ()), 
		txt => 'uopTopics', ico => 'topic' }
		if $cfg->{subsInstant} || $cfg->{subsDigest};
	$m->callPlugin($_, links => \@userLinks, user => $optUser)
		for @{$cfg->{includePlg}{userOptionsLink}};

	# Print page bar
	my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{uopTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks, userLinks => \@userLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Determine language
	my ($httpLangCode) = $m->{env}{acceptLang} =~ /^([A-Za-z]{2})/;
	my $httpLang = $cfg->{languageCodes}{$httpLangCode};
	$optUser->{language} ||= $httpLang || $cfg->{language};
	
	# Set submitted or database values
	my $fontFaceEsc = $submitted ? $m->escHtml($fontFace) : $optUser->{fontFace};
	$fontSize = $submitted ? $fontSize : $optUser->{fontSize};
	$indent = $submitted ? $indent : $optUser->{indent};
	$topicsPP = $submitted ? int($topicsPP) : $optUser->{topicsPP};
	$postsPP = $submitted ? int($postsPP) : $optUser->{postsPP};
	$privacy = $submitted ? $privacy : $optUser->{privacy};
	$boardDescs = $submitted ? $boardDescs : $optUser->{boardDescs};
	$showDeco = $submitted ? $showDeco : $optUser->{showDeco};
	$showAvatars = $submitted ? $showAvatars : $optUser->{showAvatars};
	$showImages = $submitted ? $showImages : $optUser->{showImages};
	$showSigs = $submitted ? $showSigs : $optUser->{showSigs};
	$collapse = $submitted ? $collapse : $optUser->{collapse};
	$notify = $submitted ? $notify : $optUser->{notify};
	$msgNotify = $submitted ? $msgNotify : $optUser->{msgNotify};
	$timezone = $submitted ? $timezone : $optUser->{timezone};
	$language = $submitted ? $language : $optUser->{language};
	$style = $submitted ? $style : $optUser->{style};

	# Limit language and style to valid selection
	$language = $cfg->{languages}{$language} ? $language : $cfg->{language};
	$style = $cfg->{styles}{$style} ? $style : $cfg->{style};

	# Determine checkbox, radiobutton and listbox states
	my $privacyChk = $privacy ? 'checked' : "";
	my $boardDescsChk = $boardDescs ? 'checked' : "";
	my $showDecoChk = $showDeco ? 'checked' : "";
	my $showAvatarsChk = $showAvatars ? 'checked' : "";
	my $showImagesChk = $showImages ? 'checked' : "";
	my $showSigsChk = $showSigs ? 'checked' : "";
	my $collapseChk = $collapse ? 'checked' : "";
	my $notifyChk = $notify ? 'checked' : "";
	my $msgNotifyChk = $msgNotify ? 'checked' : "";
	my %state = ( "zone$timezone" => 'selected', "language$language" => 'selected', 
		"style$style" => 'selected' );
	my $snippets = $m->fetchAllArray("
		SELECT name FROM userVariables WHERE userId = ? AND name LIKE ?", $optUserId, 'sty%');
	$state{$_->[0]} = 'checked' for @$snippets;

	# Print options
	print
		"<form action='user_options$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{uopOptTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<div><label><input type='checkbox' name='privacy' $privacyChk>",
		" $lng->{uopPrefPrivc}</label></div>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<div><label><input type='checkbox' name='notify' $notifyChk>",
		" $lng->{uopPrefNt}</label></div>\n",
		"<div><label><input type='checkbox' name='msgNotify' $msgNotifyChk>",
		" $lng->{uopPrefNtMsg}</label></div>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<div><label><input type='checkbox' name='boardDescs' $boardDescsChk>",
		" $lng->{uopDispDescs}</label></div>\n",
		"<div><label><input type='checkbox' name='showDeco' $showDecoChk>",
		" $lng->{uopDispDeco}</label></div>\n",
		$cfg->{avatars} ? "<div><label><input type='checkbox' name='showAvatars' $showAvatarsChk>"
			. " $lng->{uopDispAvas}</label></div>\n" : "",
		"<div><label><input type='checkbox' name='showImages' $showImagesChk>",
		" $lng->{uopDispImgs}</label></div>\n",
		"<div><label><input type='checkbox' name='showSigs' $showSigsChk>",
		" $lng->{uopDispSigs}</label></div>\n",
		"<div><label><input type='checkbox' name='collapse' $collapseChk>",
		" $lng->{uopDispColl}</label></div>\n";

	# Print snippet list
  if (%{$cfg->{styleSnippets}}) {
		for my $snippet (sort keys %{$cfg->{styleSnippets}}) {
			my $label = $lng->{$snippet} || $snippet;
			print 
				"<div><label><input type='checkbox' name='$snippet' $state{$snippet}>",
				" $label</label></div>\n";
		}
	}

	print 
		"</fieldset>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{uopDispLang}\n",
		"<select name='language' size='1'>\n",
		map("<option value='$_' $state{\"language$_\"}>$_</option>\n", sort keys %{$cfg->{languages}}),
		"</select></label>\n",
		"<label class='lbw'>$lng->{uopDispTimeZ}\n",
		"<select name='timezone' size='1'>\n",
		"<option value='SVR' $state{zoneSVR}>$lng->{uopDispTimeS}</option>\n";

	# Print timezone list
	for (-28 .. 28) {
		my $zone  = $_ / 2;
		$zone = "+$zone" if $zone > 0;
		my $name = "GMT" . ($zone ? $zone : "");
		print "<option value='$zone' $state{\"zone$zone\"}>$name</option>\n";
	}

	print 
		"</select></label>\n",
		"<label class='lbw'>$lng->{uopDispStyle}\n",
		"<select name='style' size='1'>\n";

	# Print style list
	for (sort keys %{$cfg->{styles}}) {
		my %styleOpt = $cfg->{styleOptions}{$_} =~ /(\w+)="(.+?)"/g;
		next if $styleOpt{excludeUA} && $m->{env}{userAgent} =~ /$styleOpt{excludeUA}/
			|| $styleOpt{requireUA} && $m->{env}{userAgent} !~ /$styleOpt{requireUA}/;
		print "<option value='$_' $state{\"style$_\"}>$_</option>\n"
	}
	
	print 
		"</select></label>\n",
		"<datalist id='fontFaces'>\n",
		map("<option value='$_'>\n", @{$cfg->{fontFaces}}),
		"</datalist>\n",
		"<label class='lbw'>$lng->{uopDispFFace}\n",
		"<input type='text' class='qwi' name='fontFace' maxlength='20' list='fontFaces'",
		" value='$fontFaceEsc'></label>\n",
		"<label class='lbw'>$lng->{uopDispFSize}\n",
		"<input type='number' name='fontSize' min='0' max='20' value='$fontSize'></label>\n",
		"<label class='lbw'>$lng->{uopDispIndnt}\n",
		"<input type='number' name='indent' min='1' max='10' value='$indent'></label>\n",
		"<label class='lbw'>$lng->{uopDispTpcPP}\n",
		"<input type='number' name='topicsPP' min='0' max='$cfg->{maxTopicsPP}'",
		" value='$topicsPP'></label>\n",
		"<label class='lbw'>$lng->{uopDispPstPP}\n",
		"<input type='number' name='postsPP' min='0' max='$cfg->{maxPostsPP}'",
		" value='$postsPP'></label>\n",
		"</fieldset>\n",
		$m->submitButton('uopSubmitB', 'options'),
		"<input type='hidden' name='uid' value='$optUserId'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Log action and finish
	$m->logAction(3, 'user', 'options', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();
