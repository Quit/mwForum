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
my $action = $m->paramStrId('act');
my $optUserId = $m->paramInt('uid');
my $keyId = $m->paramStrId('keyId');
my $key = $m->paramStr('key');
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Shortcuts
my $keyFsPath = "$cfg->{attachFsPath}/keys";
my $keyFile = "$keyFsPath/$optUserId.gpg";
my $gpgPath = $cfg->{gpgPath} || "gpg";
my @gpgOptions = $cfg->{gpgOptions} ? @{$cfg->{gpgOptions}} : ();
my $result = "";

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Process edit form
	if ($action eq 'edit') {
		# Check length
		length($keyId) == 0 || length($keyId) >= 8 
			or $m->formError("OpenPGP key ID is too short.");
		length($keyId) <= 18 
			or $m->formError("OpenPGP key ID is too long.");
	
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Update user
			my $keyIdEsc = $m->escHtml($keyId);
			$m->dbDo("
				UPDATE users SET gpgKeyId = ? WHERE id = ?", $keyIdEsc, $optUserId);
			
			# Log action and finish
			$m->logAction(1, 'user', 'keyopt', $userId, 0, 0, 0, $optUserId);
			$m->redirect('user_options', uid => $optUserId);
		}
	}
	# Process upload form
	elsif ($action eq 'upload') {
		# Check key
		length($key) > 200 or $m->formError("OpenPGP key is empty or too short.");
		length($key) <= 100000 or $m->formError("OpenPGP key is too long.");
		$key =~ /-----BEGIN PGP PUBLIC KEY BLOCK-----/ 
			&& $key =~ /-----END PGP PUBLIC KEY BLOCK-----/
			or $m->formError("Input doesn't look like an OpenPGP key.");
		$key !~ /-----BEGIN PGP PRIVATE KEY BLOCK-----/
			or $m->formError("You uploaded your private key. Game over, man, game over.");
		
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Import key into user's new keyring
			$m->createDirectories($keyFsPath);
			my ($out, $err);
			my $cmd = [ $gpgPath, "--batch", "--no-auto-check-trustdb", "--charset=utf-8",
				"--no-default-keyring", "--keyring=$keyFile", @gpgOptions, "--import" ];
			$m->ipcRun($cmd, \$key, \$out, \$err) or $m->logError("Key import failed. ($err)");
			utf8::decode($err);
			$err =~ s!keyring.*created!keyring created!;
			$result = $err;
	
			# Log action
			$m->logAction(1, 'user', 'keyupl', $userId, 0, 0, 0, $optUserId);
		}
	}
}

# Print header
$m->printHeader();

# Print page bar
my @navLinks = ({ url => $m->url('user_options', uid => $optUserId), 
	txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => "User", subTitle => $optUser->{userName}, navLinks => \@navLinks);

# Prepare values
my $keyIdEsc = $submitted ? $m->escHtml($keyId) : $optUser->{gpgKeyId};
my $resultEsc = $m->escHtml($result, 1);

# Print hints and form errors
my $pgpUrl = "http://en.wikipedia.org/wiki/Pretty_Good_Privacy";
$m->printHints(["You can have your emails signed and encrypted for you by uploading your" .
	" <a href='$pgpUrl'>OpenPGP</a> public key and filling in your key ID."]);
$m->printFormErrors();

# Print upload form
print
	"<form action='user_key$m->{ext}' method='post' spellcheck='false'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Key Upload</span></div>\n",
	"<div class='ccl'>\n",
	"<label class='lbw'>ASCII-armored public key\n",
	"<textarea name='key' rows='4' autofocus required>",
	"</textarea></label>\n",
	$m->submitButton("Upload", 'attach', 'upload'),
	"<input type='hidden' name='uid' value='$optUserId'>\n",
	"<input type='hidden' name='act' value='upload'>\n",
	$m->stdFormFields(),
	"</div>\n",
	"</div>\n",
	"</form>\n\n";

# Print keyId form
print
	"<form action='user_key$m->{ext}' method='post'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Key Selection</span></div>\n",
	"<div class='ccl'>\n",
	"<label class='lbw'>Key ID (example: 0xC7A962BD)\n",
	"<input type='text' class='qwi' name='keyId' maxlength='18' value='$keyIdEsc'></label>\n",
	$m->submitButton("Change", 'key', 'change'),
	"<input type='hidden' name='uid' value='$optUserId'>\n",
	"<input type='hidden' name='act' value='edit'>\n",
	$m->stdFormFields(),
	"</div>\n",
	"</div>\n",
	"</form>\n\n";

# Print output
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Key Upload Result</span></div>\n",
	"<div class='ccl'>\n",
	"<pre><samp>$resultEsc</samp></pre>\n",
	"</div>\n",
	"</div>\n\n"
	if $result;
	
# Show keys in user's ring
if (-s $keyFile) {
	my ($in, $out, $err);
	my $cmd = [ $gpgPath, "--batch", "--no-auto-check-trustdb", "--verbose", "--charset=utf-8",
		"--no-default-keyring", "--keyring=$keyFile", @gpgOptions, "--list-keys" ];
	$m->ipcRun($cmd, \$in, \$out, \$err) or $m->logError("Keyring list failed. ($err)");
	utf8::decode($out);
	$out =~ s!^.*?-{10,}\s*!!s;
	$out =~ s!\n+\z!\n!;
	my $outEsc = $m->escHtml($out, 1);
	$outEsc =~ s!(\[expired: .+?\])!<em>$1</em>!g;

	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>User Keyring</span></div>\n",
		"<div class='ccl'>\n",
		"<pre><samp>$outEsc</samp></pre>\n",
		"</div>\n",
		"</div>\n\n";
}

# Show forum public key
if (!$result) {
	my ($in, $out, $err);
	my $cmd = [ $gpgPath, "--batch", "--no-auto-check-trustdb", "--no-emit-version", "--armor",
		"--charset=utf-8", @gpgOptions, "--export=$cfg->{gpgSignKeyId}" ];
	$m->ipcRun($cmd, \$in, \$out, \$err) or $m->logError("Key export failed. ($err)");
	my $outEsc = $m->escHtml($out, 1);

	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Forum Key</span></div>\n",
		"<div class='ccl'>\n",
		"<pre><samp>$outEsc</samp></pre>\n",
		"</div>\n",
		"</div>\n\n";
}

# Log action and finish
$m->logAction(3, 'user', 'key', $userId, 0, 0, 0, $optUserId);
$m->printFooter();
$m->finish();
