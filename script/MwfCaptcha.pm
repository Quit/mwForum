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

package MwfCaptcha;
use strict;
use warnings;
no warnings qw(uninitialized redefine);
our $VERSION = "2.27.4";

#------------------------------------------------------------------------------
# Return captcha input elements

sub captchaInputs
{
	my $m = shift();
	my $type = shift();

	# Shortcuts
	my $cfg = $m->{cfg};
	my $lng = $m->{lng};

	if ($cfg->{captchaMethod} == 0) {
		# Invisible honeypot field
		return "<div class='ihf'><input type='text' name='url'></div>\n";
	}
	elsif ($cfg->{captchaMethod} == 1) {
		# Topic-specific question and answer
		return
			"<fieldset>\n",
			"<label class='lbw'>$cfg->{captchaQuestn}\n",
			"<input type='text' class='qwi' name='captchaAnswer' required></label>\n",
			"</fieldset>\n";
	}
	elsif ($cfg->{captchaMethod} == 2) {
		# GD::SecurityImage
		my $captchaTicketId = addGdCaptcha($m, 'pstCpt');
		return
			"<fieldset>\n",
			"<label class='lbw'>$lng->{comCaptcha}\n",
			"<input type='text' class='qwi' name='captchaCode' maxlength='6' required>",
			"</label>\n",
			"<input type='hidden' name='captchaTicketId' value='$captchaTicketId'>\n",
			"<div><img class='cpt' src='$cfg->{attachUrlPath}/captchas/$captchaTicketId.png'",
			" alt=''></div>\n",
			"</fieldset>\n";
	}
	elsif ($cfg->{captchaMethod} == 3) {
		# reCAPTCHA.net service
		eval { require Captcha::reCAPTCHA } or $m->error("Captcha::reCAPTCHA module not available.");
		my $captcha = Captcha::reCAPTCHA->new();
		my $html = $captcha->get_html($cfg->{reCapPubKey}, undef, 0,
			{ theme => $cfg->{reCapTheme} || 'white' });
		$html =~ s!https?:!!g;
		return "<fieldset>\n", $html, "</fieldset>\n";
	}
	elsif ($cfg->{captchaMethod} == 4) {
		# Akismet service
	}
	elsif ($cfg->{captchaMethod} == 5) {
		# DNSBL service
	}
}

#------------------------------------------------------------------------------
# Check captcha input

sub checkCaptcha
{
	my $m = shift();
	my $type = shift();

	# Shortcuts
	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	my $env = $m->{env};

	if ($cfg->{captchaMethod} == 0) {
		# Invisible honeypot field
		!$m->paramStr('url') or $m->formError($m->{lng}{errCptFail});
	}
	elsif ($cfg->{captchaMethod} == 1) {
		# Topic-specific question and answer
		lc($m->paramStr('captchaAnswer')) eq lc($cfg->{captchaAnswer}) or $m->formError('errCptFail');
	}
	elsif ($cfg->{captchaMethod} == 2) {
		# GD::SecurityImage
		my $ticketId = $m->paramStr('captchaTicketId');
		my $code = $m->paramStr('captchaCode');

		# Delete old captcha tickets and files
		my $timeout = 120;
		$timeout = 600 if $type eq 'pstCpt' || $type eq 'msgCpt';
		$m->dbDo("
			DELETE FROM tickets WHERE type = ? AND issueTime < ? - ?", $type, $m->{now}, $timeout);
		unlink grep((stat($_))[9] < $m->{now} - $timeout, glob("$cfg->{attachFsPath}/captchas/*"));
		
		# Get and delete current captcha ticket
		my $cs = 'BINARY';
		if ($m->{pgsql}) { $cs = 'TEXT' }
		elsif ($m->{sqlite}) { $cs = 'BLOB' }
		my ($id, $realCode) = $m->fetchArray("
			SELECT id, data FROM tickets WHERE id = CAST(? AS $cs)", $ticketId);
		$m->dbDo("
			DELETE FROM tickets WHERE id = ?", $ticketId) 
			if $realCode;
			
		# Check string
		$realCode or $m->formError($m->formatStr($lng->{errCptTmeOut}, { seconds => $timeout }));
		lc($code) eq lc($realCode) or $m->formError('errCptWrong') if $realCode;
	}
	elsif ($cfg->{captchaMethod} == 3) {
		# reCAPTCHA.net service
		eval { require Captcha::reCAPTCHA } or $m->error("Captcha::reCAPTCHA module not available.");
		my $captcha = Captcha::reCAPTCHA->new();
		my $result = $captcha->check_answer($m->{cfg}{reCapPrvKey}, $m->{env}{userIp},
			$m->paramStr('recaptcha_challenge_field'), $m->paramStr('recaptcha_response_field'));
		$result->{is_valid} or $m->formError('errCptFail');
	}
	elsif ($cfg->{captchaMethod} == 4) {
		# Akismet service
		return if !($type eq 'pstCpt' || $type eq 'msgCpt');
		eval { require LWP::UserAgent } or $m->error("LWP::UserAgent module not available.");
		my $ua = LWP::UserAgent->new(agent => "mwForum/$MwfMain::VERSION", timeout => 5);
		my $resp = $ua->post(
			"http://$cfg->{akismetKey}.rest.akismet.com/1.1/comment-check", [
			blog => "$cfg->{baseUrl}$env->{scriptUrlPath}/forum$m->{ext}",
			user_ip => $env->{userIp},
			user_agent => $env->{userAgent},
			referrer => $env->{referrer},
			comment_type => 'comment',
			comment_author => $m->{user}{userName},
			comment_author_email => $m->{user}{email},
			comment_content => $m->paramStr('body') ]);
		if ($cfg->{akismetDebug}) {
			open my $fh, ">>", "/tmp/akismet.log";
			print $fh $resp->request()->as_string(), "\n", $resp->content(), "\n", "-" x 70, "\n";
		}
		if ($resp->is_success()) {
			if ($resp->content() eq 'true') {
				$m->formError("Sorry, but Akismet considers this spam.");
			}
		}
		else {
			$m->logError("Akismet check failed.");
		}
	}
	elsif ($cfg->{captchaMethod} == 5) {
		# DNSBL service
		require POSIX;
		POSIX::sigaction(POSIX::SIGALRM(), POSIX::SigAction->new(sub { die "alarm\n" })) 
			or $m->error("POSIX::sigaction() not available, don't use DNSBL.");
		my $revIp = join('.', reverse(split('\.', $env->{userIp})));
		my $ip = undef;
		eval {
			alarm 1;
			$ip = gethostbyname("$revIp.$cfg->{dnsbl}.");
			alarm 0;
		};
		$m->formError("Sorry, but your IP is blacklisted for spamming or being an open proxy.") 
			if $ip;
	}
}

###############################################################################
# Utility Functions

#-----------------------------------------------------------------------------
# Create GD::SecurityImage and store captcha ticket

sub addGdCaptcha
{
	my $m = shift();
	my $type = shift();

	# Shortcuts
	my $cfg = $m->{cfg};

	# Load modules
	my $gd = eval { require GD };
	eval { require Image::Magick } 
		or $m->error("GD or Image::Magick modules not available.") if !$gd;
	eval { require GD::SecurityImage }
		or $m->error("GD::SecurityImage module not available.");

	# Generate captcha image
	GD::SecurityImage->import($gd ? () : (use_magick => 1));
	my $img = GD::SecurityImage->new(
		width => $cfg->{captchaWidth} || 250,
		height => $cfg->{captchaHeight} || 60,
		font => $cfg->{captchaTtf},
		ptsize => $cfg->{captchaPts} || ($gd ? 16 : 20),
		scramble => defined($cfg->{captchaScrambl}) ? $cfg->{captchaScrambl} : 1,
		rnd_data => $cfg->{captchaChars} || [qw(A B C D E F G H I J K L M O P R S T U V W X Y)],
	);
	$img->random();
	my $newCaptchaStr = $img->random_str();
	$img->create('ttf', int(rand(2)) ? 'default' : 'ec', "#777777", "#777777");
	$img->particle(3000);

	# Store captcha image
	my ($imgData) = $img->out(force => 'png');
	my $ticketId = $m->randomId();
	my $captchaFsPath = "$cfg->{attachFsPath}/captchas";
	$m->createDirectories($captchaFsPath);
	my $file = "$captchaFsPath/$ticketId.png";
	open my $fh, ">:raw", $file or $m->error("Image storing failed. ($!)");
	print $fh $imgData;
	close $fh;
	$m->setMode($file, 'file');
	
	# Insert captcha ticket
	$m->dbDo("
		INSERT INTO tickets (id, userId, issueTime, type, data)	VALUES (?, ?, ?, ?, ?)",
		$ticketId, 0, $m->{now}, $type, $newCaptchaStr);

	return $ticketId;
}

#-----------------------------------------------------------------------------
1;
