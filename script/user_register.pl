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

# Load additional modules
require MwfCaptcha if $cfg->{captcha};

# Check if user registration is disabled for normal users
$cfg->{openId} != 2 && !$cfg->{adminUserReg} && !$cfg->{authenPlg}{login}
	|| $user->{admin} or $m->error('errNoAccess');

# Get CGI parameters
my $userName = $m->paramStr('userName');
my $email = $m->paramStr('email');
my $emailV = $m->paramStr('emailV');
my $password = $m->paramStr('password');
my $passwordV = $m->paramStr('passwordV');
my $extra1 = $m->paramStr('extra1') || "";
my $extra2 = $m->paramStr('extra2') || "";
my $extra3 = $m->paramStr('extra3') || "";
my $submitted = $m->paramBool('subm');

# Process form
if ($submitted) {
	# Don't set fields if they are not displayed in form
	$extra1 = "" if !$cfg->{regExtra1};
	$extra2 = "" if !$cfg->{regExtra2};
	$extra3 = "" if !$cfg->{regExtra3};
	
	# Check username for validity
	length($userName) or $m->formError('errNamEmpty');
	if (length($userName)) {
		length($userName) >= 2 && length($userName) <= $cfg->{maxUserNameLen} 
			or $m->formError('errNamSize');
		$userName =~ /$cfg->{userNameRegExp}/ or $m->formError('errNamChar');
		$userName !~ /  / or $m->formError('errNamChar');
		$userName !~ /https?:/ or $m->formError('errNamChar');
		index(lc($userName), lc($_)) < 0 or $m->formError('errNamResrvd')
			for @{$cfg->{reservedNames}};
	}
	
	# Check authorization
	$m->checkAuthz($user, 'regUser');
	
	# Check if username is free
	!$m->fetchArray("
		SELECT id FROM users WHERE userName = ?", $userName) 
		or $m->formError('errNamGone');
	
	# Check if email address is valid and free
	if (!$cfg->{noEmailReq}) {
		$email eq $emailV or $m->formError('errEmlDiffer');
		$m->checkEmail($email);
		!$m->fetchArray("
			SELECT id FROM users WHERE email = ?", $email) 
			or $m->formError('errEmlGone') if $email;
	}
	
	# Handle password
	if (!$cfg->{noEmailReq}) {
		# Generate initial password
		$password = $m->randomId();
		$password =~ s![IOlo01_-]!!g;
		$password = substr($password, 0, 10);
	}
	else {
		# Check password for validity
		$password eq $passwordV or $m->formError('errPwdDiffer');
		length($password) >= 8 or $m->formError('errPwdSize');
	}
		
	# Check captcha
	MwfCaptcha::checkCaptcha($m, 'regCpt') if $cfg->{captcha};

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Insert user
		my $prevOnCookie = int($m->getCookie('prevon') || 0);
		my $regUserId = $m->createUser(
			userName => $userName,
			password => $password,
			email => $email,
			extra1 => $m->escHtml($extra1),
			extra2 => $m->escHtml($extra2),
			extra3 => $m->escHtml($extra3),
			language => $m->{lngName},
			prevOnTime => $prevOnCookie,
		);
		
		# Get inserted user
		my $regUser = $m->getUser($regUserId);
		$regUser or $m->error('errUsrNotFnd');

		# Normal registration with email
		if (!$regUser->{admin} && !$cfg->{noEmailReq}) {
			# Create quick login ticket
			my $ticketId = $m->randomId();
			$m->dbDo("
				INSERT INTO tickets (id, userId, issueTime, type) VALUES (?, ?, ?, ?)",
				$ticketId, $regUser->{id}, $m->{now}, 'usrReg');
			
			# Email account info to user
			my $subject = "$cfg->{forumName}: $lng->{regMailSubj}";
			my $body = "$lng->{regMailT}\n\n"
				. "$cfg->{baseUrl}$m->{env}{scriptUrlPath}/user_ticket$m->{ext}?t=$ticketId\n\n"
				. "$lng->{regMailName}$regUser->{userName}\n"
				. "$lng->{regMailPwd}$password\n\n"
				. "$lng->{regMailT2}\n\n"
				. ($cfg->{policy} ? "\n$cfg->{policyTitle}:\n\n$cfg->{policy}\n" : "");
			$m->sendEmail(user => $regUser, subject => $subject, body => $body);
		}
		# Email-less registration
		elsif ($cfg->{noEmailReq}) {
			# Add notification message about email
			my $url = "user_email$m->{ext}";
			$m->addNote('emlReg', $regUserId, 'notEmlReg', usrNam => $userName, emlUrl => $url);

			# Set cookie
			$m->setCookie('login', "$regUserId:$regUser->{loginAuth}", $regUser->{tempLogin});
		}
		
		# Log action and finish
		$m->logAction(1, 'user', 'register', $regUserId);
		if ($cfg->{noEmailReq}) { $m->redirect('forum_show', msg => 'AccntReg') }
		elsif (!$regUser->{admin}) { $m->redirect('forum_show', msg => 'AccntRegM')	}
		else { 
			$m->printHeader();
			$m->printHints(["As the first user you get admin status and have to use the" . 
				" password mentioned in the documentation to login."]);
		}
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{regTitle}, navLinks => \@navLinks);

	# Print hints and form errors
	$m->printHints([$m->formatStr($lng->{regRegT}, { logUrl => $m->url('user_login') })]);
	$m->printFormErrors();

	# Escape submitted values
	my $userNameEsc = $m->escHtml($userName);
	my $emailEsc = $m->escHtml($email);
	my $emailVEsc = $m->escHtml($emailV);
	my $extra1Esc = $m->escHtml($extra1);
	my $extra2Esc = $m->escHtml($extra2);
	my $extra3Esc = $m->escHtml($extra3);

	# Print user registration form
	print
		"<form action='user_register$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{regRegTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<label class='lbw'>$lng->{regRegName}",
		" <span id='userNameError' style='display: none'></span>\n",
		"<input type='text' class='hwi' name='userName' maxlength='$cfg->{maxUserNameLen}'",
		" value='$userNameEsc' autofocus required></label>\n";

	# Print email or password fields		
	if (!$cfg->{noEmailReq}) {
		print
			"<label class='lbw'>$lng->{regRegEmail}\n",
			"<input type='email' class='hwi' name='email' maxlength='100' value='$emailEsc'",
			" required></label>\n",
			"<label class='lbw'>$lng->{regRegEmailV}\n",
			"<input type='email' class='hwi' name='emailV' maxlength='100' value='$emailVEsc'",
			" required></label>\n"
	}
	else {
		print
			"<label class='lbw'>$lng->{regRegPwd} ($lng->{regRegPwdFmt})\n",
			"<input type='password' class='qwi' name='password' pattern='.{8,}'",
			" title='$lng->{regRegPwdFmt}' required></label>\n",
			"<label class='lbw'>$lng->{regRegPwdV}\n",
			"<input type='password' class='qwi' name='passwordV' pattern='.{8,}'",
			" title='$lng->{regRegPwdFmt}' required></label>\n"
			if $cfg->{noEmailReq};
	}

	# Print custom fields	
	print
		"<label class='lbw'>$cfg->{longExtra1}\n",
		"<input type='text' class='hwi' name='extra1' maxlength='100' value='$extra1Esc'></label>\n"
		if $cfg->{regExtra1};
	
	print
		"<label class='lbw'>$cfg->{longExtra2}\n",
		"<input type='text' class='hwi' name='extra2' maxlength='100' value='$extra2Esc'></label>\n"
		if $cfg->{regExtra2};
	
	print
		"<label class='lbw'>$cfg->{longExtra3}\n",
		"<input type='text' class='hwi' name='extra3' maxlength='100' value='$extra3Esc'></label>\n"
		if $cfg->{regExtra3};

	# Print submit section
	print
		$cfg->{captcha} ? MwfCaptcha::captchaInputs($m, 'regCpt') : "",
		$m->submitButton('regRegB', 'user'),
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'user', 'register', 0, 0, 0, 0, 0, $userNameEsc);
	$m->printFooter();
}
$m->finish();
