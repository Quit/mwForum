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
my $email = $m->paramStr('email');
my $remember = $m->paramBool('remember');
my $action = $m->paramStrId('act') || 'login';
my $submitted = $m->paramBool('subm') || $userName && $password;
my $prevOnCookie = int($m->getCookie('prevon') || 0);

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
				my $passwordHash = $m->hashPassword($password, $dbUser->{salt});
				if ($passwordHash ne $dbUser->{password}) {
					$m->logError("Login attempt with invalid password for user $userName");
					$m->formError('errPwdWrong');
				}
			}
		}
		
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Update salt to new length
			if (length($dbUser->{salt}) < 22) {
				my $salt = $m->randomId();
				my $passwordHash = $m->hashPassword($password, $salt);
				$m->dbDo("
					UPDATE users SET salt = ?, password = ? WHERE id = ?",
					$salt, $passwordHash, $dbUser->{id});
			}

			# Update user's previous online time and remember-me selection
			my $prevOnTime = $m->max($prevOnCookie, $dbUser->{lastOnTime});
			my $tempLogin = $remember ? 0 : 1;
			$m->dbDo("
				UPDATE users SET prevOnTime = ?, tempLogin = ? WHERE id = ?",
				$prevOnTime, $tempLogin, $dbUser->{id});
			$m->setCookie('prevon', $prevOnTime);

			# Set login cookie
			$m->setCookie('login', "$dbUser->{id}:$dbUser->{loginAuth}", !$remember);

			# Log action and finish
			$m->logAction(1, 'user', 'login', $dbUser->{id});
			$m->redirect('forum_show');
		}
	} 
	# Process forgot password form
	elsif ($action eq 'forgotPwd') {
		# Don't enable when auth plugin is used
		!$cfg->{authenPlg}{login} or $m->error("Forgot-password n/a when auth plugin is used.");

		# Get user
		my $dbUser = $m->fetchHash("
			SELECT * FROM users WHERE email = ?", $email);
		if (!$dbUser) {
			$m->logError("Forgot-password request for non-existing email $email");
			$m->formError('errUsrNotFnd');
		}
		else {
			# Don't send if blocked, user has just registered or used this recently
			!$dbUser->{dontEmail} or $m->error('errDontEmail');
			$dbUser->{regTime} < $m->{now} - 900 or $m->error('errFgtPwdDuh');
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
			my $subject = "$cfg->{forumName}: $lng->{lgiFpwMlSbj}";
			my $body = "$lng->{lgiFpwMlT}\n\n"
				. "$cfg->{baseUrl}$m->{env}{scriptUrlPath}/user_ticket$m->{ext}?t=$ticketId\n";
			$m->sendEmail(user => $dbUser, subject => $subject, body => $body);
		
			# Log action and finish
			$m->logAction(1, 'user', 'fgtpwd', $dbUser->{id});
			$m->redirect('forum_show', msg => 'TksFgtPwd');
		}
	} 
}

# Print forms
if (!$submitted || @{$m->{formErrors}}) {
	# Check cookie support
	$m->setCookie('check', "1", 1) if !$submitted && !$prevOnCookie;

	# Print header
	$m->printHeader(undef, { !$prevOnCookie ? (checkCookie => 1) : () });

	# Print page bar
	my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{lgiTitle}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints([$m->formatStr($lng->{lgiLoginT}, { regUrl => $m->url('user_register') })])
		if !$cfg->{authenPlg}{login};
	print
		"<div class='frm hnt err' id='cookieError' style='display: none'>\n",
		"<div class='ccl'>\n",
		"<img class='sic sic_hint_error' src='$m->{cfg}{dataPath}/epx.png' alt=''>\n",
		"<p>$lng->{errNoCookies}</p>\n",
		"</div>\n",
		"</div>\n\n"
		if !$submitted;
	$m->printFormErrors();

	# Prepare values
	$remember = $submitted ? $remember : !$cfg->{tempLogin};
	my $rememberChk = $remember ? 'checked' : "";
	my $userNameEsc = $m->escHtml($userName);
	my $emailEsc = $m->escHtml($email);

	# Print login form
	print
		"<form action='user_login$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{lgiLoginTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{lgiLoginName}\n",
		"<input type='text' class='qwi' name='userName' value='$userNameEsc'",
		" autofocus required></label>\n",
		"<label class='lbw'>$lng->{lgiLoginPwd}\n",
		"<input type='password' class='qwi' name='password' required>",
		"</label>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<label><input type='checkbox' name='remember' $rememberChk>",
		" $lng->{lgiLoginRmbr}</label>\n",
		"</fieldset>\n",
		$m->submitButton('lgiLoginB', 'login'),
		"<input type='hidden' name='act' value='login'>\n",
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
			"<label class='lbw'>$lng->{lgiFpwEmail}\n",
			"<input type='email' class='qwi' name='email' value='$emailEsc' required></label>\n",
			$m->submitButton('lgiFpwB', 'subscribe'),
			"<input type='hidden' name='act' value='forgotPwd'>\n",
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
