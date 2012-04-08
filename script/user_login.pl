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

# Don't enable when request auth plugin is used
!$cfg->{authenPlg}{request} or $m->error("Login page n/a when request auth plugin is used.");

# Get CGI parameters
my $userName = $m->paramStr('userName');
my $password = $m->paramStr('password');
my $remember = $m->paramBool('remember');
my $action = $m->paramStrId('act') || 'login';
my $submitted = $m->paramBool('subm') || $userName && $password;

# Process form
if ($submitted) {
	# Process login	form
	if ($action eq 'login') {
		my $dbUser = undef;
		if ($cfg->{authenPlg}{login}) {
			# Call login authentication plugin
			$dbUser = $m->callPlugin($cfg->{authenPlg}{login}, 
				userName => $userName, password => $password);
			ref($dbUser) or $m->formError($dbUser);
		}
		else {
			# Get user
			$userName or $m->formError('errNamEmpty');
			$dbUser = $m->fetchHash("
				SELECT * FROM users WHERE userName = ?", $userName);
			$dbUser = $m->fetchHash("
				SELECT * FROM users WHERE email = ?", $userName)
				if !$dbUser && $userName =~ /\@/;
			if (!$dbUser) {
				$m->logError("Login attempt with non-existent user $userName");
				$m->formError('errUsrNotFnd');
			}

			# Check password
			$password or $m->formError('errPwdEmpty');
			if ($dbUser && $password) {
				my $passwordMd5 = $m->md5($password . $dbUser->{salt});
				if ($passwordMd5 ne $dbUser->{password}) {
					$m->logError("Login attempt with invalid password for user $userName");
					$m->formError('errPwdWrong');
				}
			}
		}
		
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Update user's previous online time and remember-me selection
			my $prevOnCookie = $m->getCookie('prevon');
			my $prevOnTime = $m->max($prevOnCookie, $dbUser->{lastOnTime});
			my $tempLogin = $remember ? 0 : 1;
			$m->dbDo("
				UPDATE users SET prevOnTime = ?, tempLogin = ? WHERE id = ?",
				$prevOnTime, $tempLogin, $dbUser->{id});
			$m->setCookie('prevon', $prevOnTime);

			# Set login cookie
			$m->setCookie('login', "$dbUser->{id}-$dbUser->{password}", !$remember);
			
			# Delete old sessions
			$m->dbDo("
				DELETE FROM sessions WHERE lastOnTime < ? - ? * 60", $m->{now}, $cfg->{sessionTimeout});

			# Insert session if cookies might not work
			if (!$prevOnCookie && $cfg->{urlSessions}) {
				$m->{sessionId} = $m->randomId();
				$m->dbDo("
					INSERT INTO sessions (id, userId, lastOnTime, ip) VALUES (?, ?, ?, ?)",
					$m->{sessionId}, $dbUser->{id}, $m->{now}, $m->{env}{userIp});
			}
				
			# Log action and finish
			$m->logAction(1, 'user', 'login', $dbUser->{id});
			$m->redirect('forum_show');
		}
	} 
	# Process forgot password form
	elsif ($action eq 'forgotPwd') {
		# Don't enable when auth plugin is used
		!$cfg->{authenPlg}{login} or $m->error("Password request n/a when auth plugin is used.");

		# Get user
		my $dbUser = $m->fetchHash("
			SELECT * FROM users WHERE userName = ?", $userName);
		$dbUser = $m->fetchHash("
			SELECT * FROM users WHERE email = ?", $userName)
			if !$dbUser && $userName =~ /\@/;

		if (!$dbUser) {
			$m->logError("Forgot-password request for non-existing user $userName");
			$m->formError('errUsrNotFnd');
		}
		else {
			$m->logError("Forgot-password request for user $userName");

			# Don't send email to email-less or defective accounts
			$dbUser->{email} or $m->error('errNoEmail');
			!$dbUser->{dontEmail} or $m->error('errDontEmail');
	
			# Check if user has just registered and shouldn't be using this already
			$dbUser->{regTime} < $m->{now} - 900 or $m->error('errFgtPwdDuh');
			
			# Check if user has already used this function recently
			!$m->fetchArray("
				SELECT 1 FROM tickets WHERE userId = ? AND type = ? AND issueTime > ? - 900",
				$dbUser->{id}, 'fgtPwd', $m->{now})
				or $m->error('errFgtPwdDuh');
		}

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Delete previous tickets
			$m->dbDo("
				DELETE FROM tickets WHERE userId = ? AND type = ?", $dbUser->{id}, 'fgtPwd');
			
			# Create ticket
			my $ticketId = $m->randomId();
			$m->dbDo("
				INSERT INTO tickets (id, userId, issueTime, type) VALUES (?, ?, ?, ?)",
				$ticketId, $dbUser->{id}, $m->{now}, 'fgtPwd');
			
			# Email ticket to user
			$m->sendEmail($m->createEmail(
				type => 'fgtPwd', 
				user => $dbUser, 
				url => "$cfg->{baseUrl}$m->{env}{scriptUrlPath}/user_ticket$m->{ext}?t=$ticketId",
			));
		
			# Log action and finish
			$m->logAction(1, 'user', 'fgtpwd', $dbUser->{id});
			$m->redirect('forum_show', msg => 'TksFgtPwd');
		}
	} 
}

# Print forms
if (!$submitted || @{$m->{formErrors}}) {
	# Check cookie support
	$m->setCookie('check', "1", 1) if !$cfg->{urlSessions} && !$submitted;

	# Print header
	$m->printHeader(undef, { cfg_urlSessions => $cfg->{urlSessions} });

	# Print page bar
	my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{lgiTitle}, navLinks => \@navLinks);

	# Set submitted or database values
	$remember = $submitted ? $remember : !$cfg->{tempLogin};

	# Escape submitted values
	my $userNameEsc = $m->escHtml($userName);

	# Determine checkbox, radiobutton and listbox states
	my %state = (
		remember => $remember ? "checked='checked'" : undef,
	);

	# Print hints and form errors
	$m->printHints([$m->formatStr($lng->{lgiLoginT}, { regUrl => $m->url('user_register') })])
		if !$cfg->{authenPlg}{login};
	print
		"<div class='frm hnt err' id='cookieError' style='display: none'>\n",
		"<div class='ccl'>\n",
		"<img class='sic sic_hint_error' src='$m->{cfg}{dataPath}/epx.png' alt=''/>\n",
		"<p>$lng->{errNoCookies}</p>\n",
		"</div>\n",
		"</div>\n\n"
		if !$cfg->{urlSessions} && !$submitted;
	$m->printFormErrors();
	
	# Print login form
	print
		"<form action='user_login$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{lgiLoginTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{lgiLoginName}\n",
		"<input type='text' class='fcs qwi' name='userName' maxlength='50'",
		" autofocus='autofocus' required='required' value='$userNameEsc'/></label>\n",
		"<label class='lbw'>$lng->{lgiLoginPwd}\n",
		"<input type='password' class='qwi' name='password' maxlength='15' required='required'/>",
		"</label>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<label><input type='checkbox' name='remember' $state{remember}/>",
		" $lng->{lgiLoginRmbr}</label>\n",
		"</fieldset>\n",
		$m->submitButton('lgiLoginB', 'login'),
		"<input type='hidden' name='act' value='login'/>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	if (!$cfg->{authenPlg}{login}) {
		# Print hint
		$m->printHints(['lgiFpwT']);
		
		# Print forgot password form
		print
			"<form action='user_login$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{lgiFpwTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<label class='lbw'>$lng->{lgiLoginName}\n",
			"<input type='text' class='qwi' name='userName' maxlength='50' required='required'",
			" value='$userNameEsc'/></label>\n",
			$m->submitButton('lgiFpwB', 'subscribe'),
			"<input type='hidden' name='act' value='forgotPwd'/>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}
	
	# Log action and finish
	$m->logAction(3, 'user', 'login', $userId, 0, 0, 0, 0, $userNameEsc);
	$m->printFooter();
}
$m->finish();
