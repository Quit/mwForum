#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2015 Markus Wichitill
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

# Check if OpenID is enabled
$cfg->{openId} or $m->error('errNoAccess');

# Load additional modules
require MwfCaptcha if $cfg->{captchaOpenId};
eval { require URI } or $m->error("URI module not available.");

# Get CGI parameters
my $openIdUrl = $m->paramStr('openid_url');
my $remember = $m->paramBool('rmb');
my $origin = $m->paramStr('ori');
my $submitted = $m->paramBool('subm');
my $openIdMode = $m->paramStrId('openid.mode');
my $prevOnCookie = int($m->getCookie('prevon') || 0);

# Process form or returning UA
if ($submitted || $openIdMode) {
	# Log URL to see what worked and what didn't
	$m->logError("OpenID login attempt with URL $openIdUrl") if $submitted && $cfg->{debug};

	# Verify id length
	length($openIdUrl) <= 200 or $m->error('errOidLen');
	
	# Load modules
	eval { require Cache::FastMmap } or $m->error("Cache::FastMmap module not available.");
	eval { require LWPx::ParanoidAgent } or $m->error("LWPx::ParanoidAgent module not available.");
	eval { require Net::OpenID::Consumer } or $m->error("Net::OpenID::Consumer module not available.");

	# Prepare cache
	my $cacheFsPath = "$cfg->{attachFsPath}/openid";
	$m->createDirectories($cacheFsPath);
	my $cache = Cache::FastMmap->new(share_file => "$cacheFsPath/cache.db",
		page_size => 4096, num_pages => 31, raw_values => 1, unlink_on_exit => 0);

	# Use own nonce
	my $nonce = $m->randomId();
	$cache->set("mwf.nonce:$nonce", 1);

	# Create consumer object
	my $env = $m->{env};
	my $schema = $cfg->{sslOnly} || $env->{https} ? 'https' : 'http';
	my $baseUrl = "$schema://$env->{host}";
	my $csr = Net::OpenID::Consumer->new(cache => $cache, consumer_secret => 1,
		ua => LWPx::ParanoidAgent->new(timeout => 5),
		args => sub { @_ ? $m->paramStr($_[0]) : $m->params() },
		required_root => $baseUrl, debug => $cfg->{debug} ? 1 : 0);
	$csr or $m->error("OpenID consumer creation failed.");
	my $verifiedId = undef;

	if ($submitted && !$openIdUrl) {
		$m->formError('errOidEmpty');
	}
	elsif ($submitted && $openIdUrl) {
		# Check captcha
		MwfCaptcha::checkCaptcha($m, 'regCpt') if $cfg->{captchaOpenId};

		# Get id server info from canonicalized URL
		my $claimedId = $csr->claimed_identity($openIdUrl);
		if ($claimedId) {
			# Check id server against whitelist
			my $idServer = URI->new($claimedId->identity_server())->canonical()->host();
			grep(URI->new($_)->canonical()->host() eq $idServer, @{$cfg->{openIdServers}})
				or $m->formError('errOidPrNtAc')
				if @{$cfg->{openIdServers}};

			# Redirect to id server in setup mode
			if (!@{$m->{formErrors}}) {
				$origin =~ s/([^A-Za-z_0-9.!~()-])/'%'.unpack("H2",$1)/eg;
				my $ori = $origin ? "ori=$origin&" : "";
				my $returnUrl = "$baseUrl$env->{scriptUrlPath}/user_openid$m->{ext}?"
					. "${ori}rmb=$remember&nnc=$nonce";
				my $checkUrl = $claimedId->check_url(delayed_return => 1,
					trust_root => $baseUrl, return_to => $returnUrl);
				my $sregNs = "openid.ns.sreg=http://openid.net/extensions/sreg/1.1";
				my $sregParams = "openid.sreg.optional=nickname,fullname,dob,country";
				redirectRaw($m, "$checkUrl&$sregNs&$sregParams");
			}
		}
		else { $m->formError($lng->{errOidNotFnd} . " (" . $csr->errcode() . ")") }
	}
	elsif ($openIdMode) {
		# Returning from id server
		if ($csr->user_cancel()) {
			# User cancelled
			$m->formError('errOidCancel');
		}
		elsif ($verifiedId = $csr->verified_identity()) {
			# Verification succeeded, check id length
			length($verifiedId->url()) <= 200 or $m->formError('errOidLen');

			# Verify and delete own nonce
			my $nonce = substr($m->paramStr('nnc'), 0, 32);
			my $nonceValid = 0;
			$cache->get_and_set("mwf.nonce:$nonce", sub { $nonceValid = $_[1]; undef });
			$m->formError('errOidReplay') if !$nonceValid;
		}
		else {
			# Verification failed
			$m->formError($lng->{errOidFail} . " (" . $csr->errcode() . ")");
		}
	}

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Do additional URL normalization
		my $openId = $m->escHtml($verifiedId->url());
		$openId =~ s!^https!http!;
		$openId =~ s!/\z!!;

		# Get user
		my $dbUser = $m->fetchHash("
			SELECT * FROM users WHERE openId = ?", $openId);

		# Create user account if one doesn't exist yet
		if (!$dbUser) {
			# Get username from sreg.nick or simplified OpenID or full OpenID
			my $userName = $m->paramStr('openid.sreg.nickname');
			$userName =~ s!^ +!!;
			$userName =~ s! +\z!!;
			$userName =~ s! {2,}! !g;
			my $gone = $m->fetchArray("
				SELECT 1 FROM users WHERE userName = ?", $userName);
			my $valid = validUserName($m, $userName);
			my $useUrlName = 0;
			if (!$valid || $gone) {
				$useUrlName = 1;
				$userName = $openId;
				$userName =~ s!^https?://!!;
				$userName =~ s!^www\.!!;
				$userName =~ s!#.*!!;
				$userName = substr($userName, 0, $cfg->{maxUserNameLen});
				$gone = $m->fetchArray("
					SELECT 1 FROM users WHERE userName = ?", $userName);
				$userName = $openId if $gone;
			}

			# Create account
			require Locale::Country;
			my ($birthyear, $birthday) = 
				$m->paramStr('openid.sreg.dob') =~ /([0-9]{4})-([0-9]{2}-[0-9]{2})/;
			my $realName = $m->paramStr('openid.sreg.fullname');
			my $regUserId = $m->createUser(
				userName => $userName,
				realName => $m->escHtml(substr($realName, 0, 100)),
				openId => $openId,
				password => $m->randomId(),
				birthyear => $birthyear,
				birthday => $birthday,
				location => Locale::Country::code2country($m->paramStr('openid.sreg.country')),
				renamesLeft => $useUrlName ? $cfg->{renamesLeft} + 1 : $cfg->{renamesLeft},
			);
			$dbUser = $m->getUser($regUserId);

			# Add notification message about renaming and email
			$m->addNote('oidRen', $dbUser->{id}, 'notOidRen', namUrl => "user_name$m->{ext}")
				if $useUrlName;
			$m->addNote('emlReg', $dbUser->{id}, 'notEmlReg', emlUrl => "user_email$m->{ext}", 
				usrNam => $dbUser->{userName});
		}
		else {
			# Update user's previous online time and remember-me selection
			my $prevOnTime = $m->max($prevOnCookie, $dbUser->{lastOnTime});
			my $tempLogin = $remember ? 0 : 1;
			$m->dbDo("
				UPDATE users SET prevOnTime = ?, tempLogin = ? WHERE id = ?",
				$dbUser->{lastOnTime}, $tempLogin, $dbUser->{id});
			$m->setCookie('prevon', $prevOnTime);
		}

		# Set login cookie
		$m->setCookie('login', "$dbUser->{id}:$dbUser->{loginAuth}", !$remember);

		# Log action and finish
		$m->logAction(1, 'user', 'openid', $dbUser->{id});
		$m->redirect('forum_show');
	}
}

# Print forms
if (!$submitted || @{$m->{formErrors}}) {
	# Check cookie support
	$m->setCookie('check', "1", 1) if !$submitted;

	# Print header
	$m->printHeader(undef, { !$prevOnCookie ? (checkCookie => 1) : () });

	# Print page bar
	my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{oidTitle}, navLinks => \@navLinks);

	# Print hints and form errors
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
	my $openIdUrlEsc = $m->escHtml($openIdUrl);

	# Print OpenID login form
	print
		"<form action='user_openid$m->{ext}' method='post'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{oidLoginTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$lng->{oidLoginUrl}\n",
		"<input type='text' class='hwi' id='openid_url' name='openid_url' maxlength='200'",
		" value='$openIdUrlEsc' autofocus required></label>\n",
		"</fieldset>\n",
		"<fieldset>\n",
		"<label><input type='checkbox' name='rmb' $rememberChk>",
		" $lng->{oidLoginRmbr}</label>\n",
		"</fieldset>\n",
		$m->submitButton('oidLoginB', 'openid'),
		$cfg->{captchaOpenId} ? MwfCaptcha::captchaInputs($m, 'regCpt') : "",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Print list of accepted id servers
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{oidListTtl}</span></div>\n",
		"<div class='ccl'>\n",
		map("<div>" . URI->new($_)->canonical() . "</div>\n", @{$cfg->{openIdServers}}),
		"</div>\n",
		"</div>\n\n"
		if @{$cfg->{openIdServers}};

	# Log action and finish
	$m->logAction(3, 'user', 'openid', $userId);
	$m->printFooter();
}
$m->finish();


###############################################################################
# Utility Functions

#------------------------------------------------------------------------------
# Redirect outside of mwForum

sub redirectRaw
{
	my $m = shift();
	my $location = shift();

	# Shortcuts
	my $ap = $m->{ap};
	my $cfg = $m->{cfg};

	my $status = $m->{env}{protocol} eq "HTTP/1.1" ? 303 : 302;

	if ($MwfMain::MP) {
		$ap->status($status);
		$ap->headers_out->{'Location'} = $location;
		$ap->send_http_header() if $MwfMain::MP1;
	}
	else {
		print "HTTP/1.1 $status\n" if $cfg->{nph};
		print "Status: $status\n" if !$cfg->{nph};
		print "Location: $location\n\n";
	}

	$m->finish();
}

#------------------------------------------------------------------------------
# Check sreg nickname validity as username

sub validUserName
{
	my $m = shift();
	my $userName = shift();

	# Shortcuts
	my $cfg = $m->{cfg};

	length($userName) >= 2 or return 0;
	length($userName) <= $cfg->{maxUserNameLen} or return 0;
	$userName =~ /$cfg->{userNameRegExp}/ or return 0;
	$userName !~ /https?:/ or return 0;
	index(lc($userName), lc($_)) < 0 or return 0 for @{$cfg->{reservedNames}};
	
	return 1;
}
