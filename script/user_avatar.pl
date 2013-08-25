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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0]);

# Check if access should be denied
$cfg->{avatars} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Load additional modules
eval { require Image::Info } or $m->error("Image::Info module not available.")
	if $cfg->{avatarUpload};

# Get CGI parameters
my $optUserId = $m->paramInt('uid');
my $remove = $m->paramBool('remove');
my $avatarUpload = $m->paramBool('avatarUpload');
my $gallerySelect = $m->paramBool('gallerySelect');
my $gravatarSelect = $m->paramBool('gravatarSelect');
my $galleryFile = $m->paramStr('galleryFile');
my $gravatarEmail = $m->paramStr('gravatarEmail');
my $submitted = $m->paramBool('subm');

# Select which user to edit
my $optUser = $optUserId && $user->{admin} ? $m->getUser($optUserId) : $user;
$optUser or $m->error('errUsrNotFnd');
$optUserId = $optUser->{id};

# Shortcuts
my $avaUrlPath = "$cfg->{attachUrlPath}/avatars";
my $avaFsPath = "$cfg->{attachFsPath}/avatars";
my $avatar = $optUser->{avatar};

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Process upload form upload action
	if ($avatarUpload && $cfg->{avatarUpload}) {
		my ($upload, undef, $fileSize) = $m->getUpload('file');
		my $validFileSize = $fileSize <= $cfg->{avatarMaxSize};
		$validFileSize || $cfg->{avatarResize} or $m->formError('errAvaSizeEx');

		# Check image info
		my $info = $MwfMain::MP 
			? Image::Info::image_info($upload->fh())
			: Image::Info::image_info(\$m->{cgi}->param('file'));
		$info && !$info->{error} or $m->formError('errAvaFmtUns');
		my $imgW = int($info->{width});
		my $imgH = int($info->{height});
		!ref($imgW) && !ref($imgH) or $m->formError('errAvaFmtUns');
		my $ext = lc($info->{file_ext});
		$ext =~ /^(?:jpg|png|gif)\z/ or $m->formError('errAvaFmtUns');
		my $avaW = $cfg->{avatarWidth};
		my $avaH = $cfg->{avatarHeight};
		my $validSize = $imgW == $avaW && $imgH == $avaH;
		$validSize || $cfg->{avatarResize} or $m->formError('errAvaDimens');
		my $animated = $info->{GIF_Loop} ? 1 : 0;
		$animated ||= apng($m, $upload) if $ext eq 'png';
		!$animated || $cfg->{avatarResize} or $m->formError('errAvaNoAnim');
		
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Delete old avatar
			unlink "$avaFsPath/$avatar" if $avatar && $avatar !~ /[\/:]/;
		
			# Write avatar file
			my $rnd = sprintf("%04u", int(rand(9999)));
			my $oldFileName = "$optUserId-$rnd.$ext";
			my $oldFile = "$avaFsPath/$oldFileName";
			my $updateFileName = $oldFileName;
			$m->createDirectories($avaFsPath);
			$m->saveUpload('file', $upload, $oldFile);

			# Resize image if enabled and necessary
			if (!$validFileSize || !$validSize || $animated) {
				# Load modules
				my $module;
				if (!$cfg->{noGd} && eval { require GD }) { $module = 'GD' }
				elsif (!$cfg->{noImager} && eval { require Imager }) { $module = 'Imager' }
				elsif (!$cfg->{noGMagick} && eval { require Graphics::Magick }) { $module = 'Graphics::Magick' }
				elsif (!$cfg->{noIMagick} && eval { require Image::Magick }) { $module = 'Image::Magick' }
				else { $m->error("GD, Imager or Magick modules not available.") }

				# Determine values
				my $shrW = $avaW / $imgW;
				my $shrH = $avaH / $imgH;
				my $shrF = $m->min($shrW, $shrH, 1);
				my $dstW = int($imgW * $shrF + .5);
				my $dstH = int($imgH * $shrF + .5);
				my $dstX = int($m->max($avaW - $dstW, 0) / 2 + .5);
				my $dstY = int($m->max($avaH - $dstH, 0) / 2 + .5);
				$rnd = sprintf("%04u", int(rand(99999)));
				my $newFileName = "$optUserId-$rnd.png";
				my $newFile = "$avaFsPath/$newFileName";

				# Resize image
				if ($module eq 'GD') {
					GD::Image->trueColor(1);
					my $oldImg = GD::Image->new($oldFile) or unlink($oldFile), $m->error('errAvaFmtUns');
					my $newImg = GD::Image->new($avaW, $avaH, 1) or $m->error("Avatar creation failed.");
					$newImg->alphaBlending(0);
					$newImg->saveAlpha(1);
					$newImg->fill(0, 0, $newImg->colorAllocateAlpha(255,255,255, 127));
					$newImg->copyResampled($oldImg, $dstX, $dstY, 0, 0, $dstW, $dstH, $imgW, $imgH);
					open my $fh, ">:raw", $newFile or $m->error("Avatar opening failed. $!");
					print $fh $newImg->png() or $m->error("Avatar storing failed. $!");
					close $fh;
				}
				elsif ($module eq 'Imager') {
					my $oldImg = Imager->new(file => $oldFile) 
						or unlink($oldFile), $m->error('errAvaFmtUns');
					$oldImg = $oldImg->scale(xpixels => $dstW, ypixels => $dstH,
						qtype => 'mixing', type => 'nonprop')
						or $m->error("Avatar scaling failed. " . Imager->errstr());
					my $newImg = Imager->new(xsize => $avaW, ysize => $avaH, channels => 4)
						or $m->error("Avatar creation failed. " . Imager->errstr());
					$newImg->paste(img => $oldImg, left => $dstX, top => $dstY)
						or $m->error("Avatar pasting failed. " . $newImg->errstr());
					$newImg->write(file => $newFile) 
						or $m->error("Avatar storing failed. " . $newImg->errstr());
				}
				elsif ($module eq 'Graphics::Magick' || $module eq 'Image::Magick') {
					my $oldImg = $module->new()
						or $m->error("Image creation failed.");
					my $err = $oldImg->Read($oldFile . "[0]")
						and unlink($oldFile), $m->error('errAvaFmtUns');
					$err = $oldImg->Scale(width => $dstW, height => $dstH)
						and $m->error("Avatar scaling failed. $err");
					my $newImg = $module->new(size => "${avaW}x${avaH}")
						or $m->error("Avatar creation failed.");
					$err = $newImg->Read("xc:transparent")
						and $m->error("Avatar filling failed. $err");
					$err = $newImg->Composite(image => $oldImg, x => $dstX, y => $dstY)
						and $m->error("Avatar compositing failed. $err");
					$err = $newImg->Write(filename => $newFile)
						and $m->error("Avatar storing failed. $err");
				}
				unlink($oldFile);
				$m->setMode($newFile, 'file');
				$updateFileName = $newFileName;
			}
			
			# Update user
			$m->dbDo("
				UPDATE users SET showAvatars = 1, avatar = ? WHERE id = ?", $updateFileName, $optUserId);

			# Log action and finish
			$m->logAction(1, 'user', 'avaupl', $userId, 0, 0, 0, $optUserId);
			$m->redirect('user_avatar', uid => $optUserId, msg => 'AvaChange');
		}
	}
	# Process gallery form select action
	elsif ($gallerySelect && $cfg->{avatarGallery}) {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			if ($galleryFile && -f "$avaFsPath/gallery/$galleryFile") {
				# Update user
				$galleryFile = "gallery/$galleryFile";
				$m->dbDo("
					UPDATE users SET showAvatars = 1, avatar = ? WHERE id = ?", $galleryFile, $optUserId);
	
				# Delete uploaded avatar
				unlink "$avaFsPath/$avatar" if $avatar && $avatar !~ /[\/:]/;		
			}
	
			# Log action and finish
			$m->logAction(1, 'user', 'avasel', $userId, 0, 0, 0, $optUserId);
			$m->redirect('user_profile', uid => $optUserId, msg => 'AvaChange');
		}
	}
	# Process gravatar form select action
	elsif ($gravatarSelect && $cfg->{avatarGravatar}) {
		# Check if this looks like an email address
		$gravatarEmail =~ /^[A-Za-z_0-9.+-]+?\@(?:[A-Za-z_0-9-]+\.)+[A-Za-z]{2,}\z/
			or $m->formError('errEmlInval');

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Update user
			$gravatarEmail = lc($gravatarEmail);
			$gravatarEmail = "gravatar:$gravatarEmail";
			$m->dbDo("
				UPDATE users SET showAvatars = 1, avatar = ? WHERE id = ?", $gravatarEmail, $optUserId);
	
			# Delete uploaded avatar
			unlink "$avaFsPath/$avatar" if $avatar && $avatar !~ /[\/:]/;		
	
			# Log action and finish
			$m->logAction(1, 'user', 'avasel', $userId, 0, 0, 0, $optUserId);
			$m->redirect('user_profile', uid => $optUserId, msg => 'AvaChange');
		}
	}
	# Process remove form actions
	elsif ($remove && $avatar) {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Update user
			$m->dbDo("
				UPDATE users SET avatar = '' WHERE id = ?", $optUserId);
	
			# Delete uploaded avatar
			unlink "$avaFsPath/$avatar" if $avatar !~ /[\/:]/;
	
			# Log action and finish
			$m->logAction(1, 'user', 'avadel', $userId, 0, 0, 0, $optUserId);
			$m->redirect('user_avatar', uid => $optUserId, msg => 'AvaChange');
		}
	}
	else { $m->error('errParamMiss') }
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('user_profile', uid => $optUserId), 
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{avaTitle}, subTitle => $optUser->{userName}, 
		navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Print avatar upload form
	if ($cfg->{avatarUpload}) {
		print
			"<form action='user_avatar$m->{ext}' method='post' enctype='multipart/form-data'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{avaUplTtl}</span></div>\n",
			"<div class='ccl'>\n";

		if (!$avatar || $avatar =~ /[\/:]/) {
			my $label = $cfg->{avatarResize}
				? $m->formatStr($lng->{avaUplImgRsz}, { size => $m->formatSize($cfg->{maxAttachLen}) })
				: $m->formatStr($lng->{avaUplImgExc}, { size => $m->formatSize($cfg->{avatarMaxSize}), 
					width => $cfg->{avatarWidth}, height => $cfg->{avatarHeight} });
			print
				"<label class='lbw'>$label\n",
				"<input type='file' name='file' accept='image/*' autofocus></label>\n",
				$m->submitButton('avaUplUplB', 'attach', 'avatarUpload');
		}
		else {
			print
				"<div><img class='ava' src='$avaUrlPath/$avatar' alt=''></div>\n",
				$m->submitButton('avaUplDelB', 'delete', 'remove');
		}
	
		print	
			"<input type='hidden' name='uid' value='$optUserId'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}

	# Print avatar gallery form
	if ($cfg->{avatarGallery}) {
		# Count how often avatars are already used
		my $used = $m->fetchAllArray("
			SELECT avatar, COUNT(*)
			FROM users
			WHERE avatar LIKE 'gallery/%'
			GROUP BY avatar");
		my %used = map(($_->[0] => $_->[1]), @$used);
		
		print
			"<form class='agl' action='user_avatar$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{avaGalTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<fieldset>\n";
    
    require File::Glob;
		for my $file (File::Glob::bsd_glob("$avaFsPath/gallery/*.{jpg,png,gif}", 
			File::Glob::GLOB_NOCASE() | File::Glob::GLOB_BRACE())) {
			$file = $m->decFsPath($file);
			my $chk = $file eq "$avaFsPath/$avatar" ? 'checked' : "";
			$file =~ s!.*[\\/:]!!;
			my ($name) = $file =~ /(.*)\.\w+\z/;
			my $usedNum = $used{"gallery/$file"};
			my $title = $usedNum ? "$name ($usedNum users)" : $name;
			print
				"<label><input type='radio' name='galleryFile' value='$file' $chk>",
				"<img class='ava' src='$avaUrlPath/gallery/$file' title='$title' alt='$name'></label>\n";
		}
	
		print
			"</fieldset>\n",
			$m->submitButton('avaGalSelB', 'avatar', 'gallerySelect'),
			$avatar =~ /\// ? $m->submitButton('avaGalDelB', 'remove', 'remove') : "",
			"<input type='hidden' name='uid' value='$optUserId'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}

	# Print gravatar form
	if ($cfg->{avatarGravatar}) {
		$gravatarEmail = index($avatar, "gravatar:") == 0 ? substr($avatar, 9) : "";
		print
			"<form action='user_avatar$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{avaGrvTtl}</span></div>\n",
			"<div class='ccl'>\n",
			"<datalist id='email'><option value='$optUser->{email}'></datalist>\n",
			"<label class='lbw'>$lng->{avaGrvEmail}\n",
			"<input type='email' class='hwi' name='gravatarEmail' list='email'",
			" value='$gravatarEmail'></label>\n",
			$m->submitButton('avaGrvSelB', 'avatar', 'gravatarSelect'),
			$avatar =~ /:/ ? $m->submitButton('avaGrvDelB', 'remove', 'remove') : "",
			"<input type='hidden' name='uid' value='$optUserId'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}
	
	# Log action and finish
	$m->logAction(3, 'user', 'avatar', $userId, 0, 0, 0, $optUserId);
	$m->printFooter();
}
$m->finish();

#------------------------------------------------------------------------------
# Check if PNG is APNG (based on PD code by Foone/WAHa)

sub apng
{
	my $m = shift();
	my $upload = shift();

	my ($fh, $bytes, $buffer);
	if ($MwfMain::MP) { $fh = $upload->fh() }
	else { open $fh, '<', \$m->{cgi}->param('file') }
	seek($fh, 0, 0);
	$bytes = read($fh, $buffer, 24);
	seek($fh, 0, 0);
	return undef if $bytes != 24;
	my ($magic1, $magic2, $length, $ihdr, $width, $height) = unpack("NNNNNN", $buffer);
	return undef if $magic1 != 0x89504e47 || $magic2 != 0x0d0a1a0a || $ihdr != 0x49484452;
	seek($fh, 8, 0);
	while (1) {
		$bytes = read($fh, $buffer, 8);
		last if $bytes != 8;
		my ($length, $type) = unpack('NA4', $buffer);
		last if $type eq 'IDAT';
		last if $type eq 'IEND';
		if ($type eq 'acTL') {
			seek($fh, 0, 0); 
			return 1;
		}
		last if seek($fh, $length + 4, 1) == 0;
	}
	seek($fh, 0, 0); 
	return 0;
}
