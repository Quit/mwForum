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

# Get CGI parameters
$m->{ajax} = $m->paramBool('ajax');
my $action = $m->paramStrId('act');
my $postId = $m->paramInt('pid');
my $attachId = $m->paramInt('aid');
my $caption = $m->paramStr('caption');
my $embed = $m->paramBool('embed');
my $change = $m->paramBool('change');
my $delete = $m->paramBool('delete');
my $submitted = $m->paramBool('subm');
$postId or $m->error('errParamMiss') if $action eq 'upload';
$attachId or $m->error('errParamMiss') if $change || $delete;

# Get attachment
my $attachment = undef;
if ($attachId) {
	$attachment = $m->fetchHash("
		SELECT * FROM attachments WHERE id = ?", $attachId);
	$attachment or $m->error('errAttNotFnd');
	$postId = $attachment->{postId};
}

# Get post
my $post = $m->fetchHash("
	SELECT * FROM posts WHERE id = ?", $postId);
$post or $m->error('errPstNotFnd');
my $postIdMod = $postId % 100;
my $boardId = $post->{boardId};
my $topicId = $post->{topicId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);

# Check if user can see and write to board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId);
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');
$boardAdmin || $m->boardWritable($board, 1) or $m->error('errNoAccess');

# Check if user owns post or is moderator
$userId && $userId == $post->{userId} || $boardAdmin or $m->error('errNoAccess');

# Check if attachments are enabled
$cfg->{attachments} && ($board->{attach} == 1 || $board->{attach} == 2 && $boardAdmin)  
	or $m->error('errNoAccess');

# Check if topic or post is locked
!$m->fetchArray("
	SELECT locked FROM topics WHERE id = ?", $topicId)
	|| $boardAdmin or $m->error('errTpcLocked');
!$post->{locked} || $boardAdmin or $m->error('errPstLocked');

# Check authorization
$m->checkAuthz($user, 'attach');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Process upload form
	if ($action eq 'upload') {
		my $fileSize = 0;
		my $fileName = "";
		my $upload = undef;
	
		# Get filename and size
		if ($MwfMain::MP) {
			require Apache2::Upload if $MwfMain::MP2;
			$upload = $m->{apr}->upload('file');
			$upload or $m->error('errAttSize');
			$fileName = $upload->filename();
			$fileSize = $upload->size();
		}
		else {
			$fileName = $m->{cgi}->param_filename('file');
			$fileSize = length($m->{cgi}->param('file'));
		}
	
		# Check filename and size
		length($fileName) or $m->error('errAttName');
		$fileSize or $m->error('errAttSize');
		
		# Is embedding allowed?
		$embed = 0 if !$cfg->{attachImg} || $fileName !~ /\.(?:jpg|png|gif)\z/i;
	
		# Remove problematic stuff from filename
		$fileName =~ s!.*[\\/]!!;  # Remove path
		if (lc($cfg->{fsEncoding}) ne 'ascii') {
			# Get rid of non-convertible und replacement chars
			require Encode;
			utf8::decode($fileName);
			$fileName =~ s![^\w.-]+!!g;
			$fileName = Encode::encode($cfg->{fsEncoding}, $fileName);
			$fileName =~ s!\?+!!g;
			$fileName = Encode::decode($cfg->{fsEncoding}, $fileName);
		}
		else {
			$fileName =~ s![^A-Za-z0-9_\.-]+!!g;
		}

		# Make sure filename doesn't end up special or empty
		$fileName = "attachment" if $fileName eq ".htaccess";
		$fileName = "attachment" if !length($fileName);

		# Make sure filenames don't clash
		my ($name, $ext) = $fileName =~ /(.+?)(\.[^.]+)?\z/;
		my $isImage = $ext =~ /^\.(?:jpg|png|gif)\z/i;
		my $num = "";
		for my $i (0 .. 100) {
			$num = $i ? "-$i" : "";
			my $like = $isImage ? "$name$num%" : "$name$num$ext";
			my $nameExists = $m->fetchArray("
				SELECT 1 FROM attachments WHERE postId = ? AND LOWER(fileName) LIKE LOWER(?)", 
				$postId, $like);
			last if !$nameExists;
			$i < 100 or $m->formError("Too many filename collisions.");
		}
		$fileName = "$name$num$ext";

		# Check for disallowed extensions after all name changes
		$fileName !~ /\.(?:$cfg->{attachBlockExt})\z/i or $m->formError('errAttExt');

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Create directories
			my $attachFsPath1 = "$cfg->{attachFsPath}/$postIdMod";
			if (!-d $attachFsPath1) {
				mkdir $attachFsPath1 or $m->error("Attachment directory creation failed. ($!)");
				$m->setMode($attachFsPath1, 'dir');
			}
			my $attachFsPath2 = "$cfg->{attachFsPath}/$postIdMod/$postId";
			if (!-d $attachFsPath2) {
				mkdir $attachFsPath2 or $m->error("Attachment directory creation failed. ($!)");
				$m->setMode($attachFsPath2, 'dir');
			}
		
			# Create attachment file
			my $saveFile = "$cfg->{attachFsPath}/$postIdMod/$postId/" . $m->encFsPath($fileName);
			if ($MwfMain::MP1) {
				# Create new hardlink for tempfile or copy tempfile
				my $success = $upload->link($saveFile);
				if (!$success) {
					require File::Copy;
					File::Copy::copy($upload->tempname(), $saveFile)
						or $m->error("Attachment storing failed. ($!)");
				}
			}
			elsif ($MwfMain::MP2) {
				# Create new hardlink for tempfile or copy tempfile
				# or write data from memory to file for small uploads
				eval { $upload->link($saveFile) } or $m->error("Attachment storing failed. ($@)");
			}
			else {
				# Write data from memory to file
				open my $fh, ">:raw", $saveFile or $m->error("Attachment storing failed. ($!)");
				print $fh $m->{cgi}->param('file') or $m->error("Attachment storing failed. ($!)");
				close $fh;
			}
			$m->setMode($saveFile, 'file');
			
			# Add attachments table entry
			my $webImage = $fileName =~ /\.(?:jpg|png|gif)\z/i ? 1 : 0;
			$webImage = 2 if $embed && $webImage;
			$caption = substr($caption, 0, 100);
			my $captionEsc = $m->escHtml($caption);
			$m->dbDo("
				INSERT INTO attachments (postId, webImage, fileName, caption) VALUES (?, ?, ?, ?)",
				$postId, $webImage, $fileName, $captionEsc);
			$attachId = $m->dbInsertId("attachments");

			# Resize image
			resizeImg($m, $postId, $attachId, $fileName) if $webImage && $cfg->{attachImgRsz};
			
			# Log action and finish
			$m->logAction(1, 'post', 'attach', $userId, $boardId, $topicId, $postId, $attachId);
			if ($m->{ajax}) {
				$m->printHttpHeader();
				print $m->json({ ok => 1 });
			}
			else { 
				$m->redirect('post_attach', pid => $postId, msg => 'PstAttach');
			}
		}
	}
	# Process delete all action
	elsif ($action eq 'delAll') {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Delete all attachments
			my $attachments = $m->fetchAllArray("
				SELECT id FROM attachments WHERE postId = ?", $postId);
			$m->deleteAttachment($_->[0]) for @$attachments;
	
			# Log action and finish
			$m->logAction(1, 'post', 'attdlall', $userId, $boardId, $topicId, $postId);
			$m->redirect('post_attach', pid => $postId, msg => 'PstDetach');
		}
	}
	# Process delete form action
	elsif ($delete) {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Delete attachment
			$m->deleteAttachment($attachId);
	
			# Log action and finish
			$m->logAction(1, 'post', 'detach', $userId, $boardId, $topicId, $postId, $attachId);
			$m->redirect('post_attach', pid => $postId, msg => 'PstDetach');
		}
	}
	# Process change form action
	elsif ($change) {
		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Update attachment
			my $webImage = $attachment->{fileName} =~ /\.(?:jpg|png|gif)\z/i ? 1 : 0;
			$webImage = 2 if $embed && $webImage;
			$caption = substr($caption, 0, 100);
			my $captionEsc = $m->escHtml($caption);
			$m->dbDo("
				UPDATE attachments SET webImage = ?, caption = ? WHERE id = ?", 
				$webImage, $captionEsc, $attachId);
				
			# Delete thumbnail
			if ($webImage && !$embed) {
				my $file = "$cfg->{attachFsPath}/$postIdMod/$postId/$attachment->{fileName}";
				$file =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
				unlink $file;
			}
	
			# Log action and finish
			$m->logAction(1, 'post', 'attchg', $userId, $boardId, $topicId, $postId, $attachId);
			$m->redirect('post_attach', pid => $postId, msg => 'PstAttChg');
		}
	}
	else { $m->error('errParamMiss') }
}

# Print AJAX errors or form
if ($m->{ajax} && @{$m->{formErrors}}) {
	$m->printHttpHeader();
	print $m->json({ error => $m->{formErrors}[0] });
}
elsif (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader(undef, { postId => $postId, maxAttachLen => $cfg->{maxAttachLen}});

	# Get existing attachments
	my $attachments = $m->fetchAllHash("
		SELECT * FROM attachments WHERE postId = ? ORDER BY id", $postId);

	# Print bar
	my @navLinks = ({ url => $m->url('topic_show', pid => $postId), txt => 'comUp', ico => 'up' });
	my @userLinks = ();
	push @userLinks, { url => $m->url('user_confirm', script => 'post_attach', pid => $postId, 
		act => 'delAll'), txt => 'attDelAll', ico => 'delete' }
		if @$attachments;
	$m->printPageBar(mainTitle => $lng->{attTitle}, navLinks => \@navLinks, userLinks => \@userLinks);

	# Print hints and form errors
	$m->printHints([$lng->{attDropNote}], 'dropNote', 1);
	$m->printFormErrors();

	# Print attachment form
	my $maxSize = sprintf("%.0fk", $cfg->{maxAttachLen} / 1024);
	my $label = $m->formatStr($lng->{attUplFiles}, { size => $maxSize });
	print	
		"<form id='upload' action='post_attach$m->{ext}' method='post' enctype='multipart/form-data'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{attUplTtl}</span></div>\n",
		"<div class='ccl' id='dropZone'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$label\n",
		"<input type='file' class='fcs' name='file' autofocus='autofocus'/></label>\n",
		"<label class='lbw'>$lng->{attUplCapt}\n",
		"<input type='text' class='hwi' name='caption' maxlength='100' value=''/></label>\n",
		"</fieldset>\n";
		
	print	
		"<fieldset>\n",
		"<label><input type='checkbox' name='embed'/>$lng->{attUplEmbed}</label>\n",
		"</fieldset>\n"
		if $cfg->{attachImg};
	
	print
		$m->submitButton('attUplB', 'attach', 'upload'),
		"<input type='hidden' name='pid' value='$postId'/>\n",
		"<input type='hidden' name='act' value='upload'/>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Print existing attachments		
	for my $attach (@$attachments) {
		print	
			"<form action='post_attach$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{attAttTtl}</span> $attach->{fileName}</div>\n",
			"<div class='ccl'>\n";

		my $attFsBasePath = "$cfg->{attachFsPath}/$postIdMod/$postId";
		my $attUrlBasePath = "$cfg->{attachUrlPath}/$postIdMod/$postId";
		my $fileName = $attach->{fileName};
		my $attFsPath = "$attFsBasePath/$fileName";
		my $attUrlPath = "$attUrlBasePath/$fileName";
		my $imgShowUrl = $m->url('attach_show', aid => $attach->{id});
		my $caption = $attach->{caption};
		my $checked = $attach->{webImage} == 2 ? "checked='checked'" : "";
		my $size = -s $m->encFsPath($attFsPath) || 0;
		$size = sprintf("%.0fk", $size / 1024);
		if ($cfg->{attachImg} && $attach->{webImage} == 2 && $user->{showImages}) {
			my $thbFsPath = $attFsPath;
			my $thbUrlPath = $attUrlPath;
			$thbFsPath =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
			$thbUrlPath =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
			my $title = "title='$size'";
			print $cfg->{attachImgThb} && (-f $thbFsPath || $m->addThumbnail($attFsPath) > 0)
				? "<p><a href='$imgShowUrl'><img class='amt' src='$thbUrlPath' $title alt=''/></a></p>"
				: "<p><img class='ami' src='$attUrlPath' $title alt=''/></p>";
		}
		elsif ($attach->{webImage}) {
			print "<p><a href='$imgShowUrl'>$fileName</a> ($size)</p>";
		}
		else {
			print "<p><a href='$attUrlPath'>$fileName</a> ($size)</p>";
		}

		print 
			"<label class='lbw'>$lng->{attUplCapt}\n",
			"<input type='text' class='hwi' name='caption' maxlength='100' value='$caption'/></label>\n",
			$cfg->{attachImg} && $attach->{webImage}
				? "<div><label><input type='checkbox' name='embed' $checked/>$lng->{attUplEmbed}</label></div>\n" 
				: "",
			$m->submitButton('attAttChgB', 'edit', 'change'),
			$m->submitButton('attAttDelB', 'delete', 'delete'),
			"<input type='hidden' name='aid' value='$attach->{id}'/>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
	}

	# Log action and finish
	$m->logAction(3, 'post', 'attach', $userId, $boardId, $topicId, $postId);
	$m->printFooter();
}
$m->finish();

#------------------------------------------------------------------------------
# Resize images if dimensions or file size are bigger than configured maxima

sub resizeImg
{
	my $m = shift();
	my $postId = shift();
	my $attachId = shift();
	my $fileName = shift();

	# Load modules
	my $cfg = $m->{cfg};
	my $module;
	if (!$cfg->{noGd} && eval { require GD }) { $module = 'GD' }
	elsif (!$cfg->{noImager} && eval { require Imager }) { $module = 'Imager' }
	elsif (!$cfg->{noGMagick} && eval { require Graphics::Magick }) { $module = 'Graphics::Magick' }
	elsif (!$cfg->{noIMagick} && eval { require Image::Magick }) { $module = 'Image::Magick' }
	else { $m->logError("GD, Imager or Magick modules not available."), return }
	
	# Get image info
	my $postIdMod = $postId % 100;
	my $oldFsPath = "$cfg->{attachFsPath}/$postIdMod/$postId/$fileName";
	my $newFsPath = $oldFsPath;
	$newFsPath =~ s!\.(?:jpg|png|gif)$!.rsz.jpg!i;
	my $oldFsPathEnc = $m->encFsPath($oldFsPath);
	my $newFsPathEnc = $m->encFsPath($newFsPath);
	my ($oldW, $oldH, $img, $err);
	if ($module eq 'GD') {
		GD::Image->trueColor(1);
		$img = GD::Image->new($oldFsPathEnc) 
			or $m->logError("ImgRsz: image loading failed."), return;
		$oldW = $img->width();
		$oldH = $img->height();
		$oldW && $oldH or $m->logError("ImgRsz: image size check failed."), return;
	}
	elsif ($module eq 'Imager') {
		$img = Imager->new() 
			or $m->logError("ImgRsz: image creating failed."), return;
		$img->read(file => $oldFsPathEnc) 
			or $m->logError("ImgRsz: image loading failed. " . $img->errstr), return;
		$oldW = $img->getwidth();
		$oldH = $img->getheight();
		$oldW && $oldH or $m->logError("ImgRsz: image size check failed."), return;
	}
	elsif ($module eq 'Graphics::Magick' || $module eq 'Image::Magick') {
		my $magick = $module->new() 
			or $m->logError("ImgRsz: magick creating failed."), return;
		($oldW, $oldH) = $magick->Ping($oldFsPathEnc);
		$oldW && $oldH or $m->logError("ImgRsz: image size check failed."), return;
	}

	# Check whether resizing is required
	my $maxW = $cfg->{attachImgRszW} || 1280;
	my $maxH = $cfg->{attachImgRszH} || 1024;
	my $maxS = $cfg->{attachImgRszS} || 153600;
	my $fact = $m->min($maxW / $oldW, $maxH / $oldH, 1);
	my $oldS = -s $oldFsPathEnc;
	return if !($fact < 1 || $oldS > $maxS);
	
	# Resize image
	my $newW = int($oldW * $fact + .5);
	my $newH = int($oldH * $fact + .5);
	my $quality = $cfg->{attachImgRszQ} || 80;
	if ($module eq 'GD') {
		my $newImg = GD::Image->new($newW, $newH, 1)
			or $m->logError("ImgRsz: image creation failed."), return;
		$newImg->copyResampled($img, 0, 0, 0, 0, $newW, $newH, $oldW, $oldH);
		open my $fh, ">:raw", $newFsPathEnc
			or $m->logError("ImgRsz: image opening failed. $!"), return;
		print $fh $newImg->jpeg($quality) 
			or $m->logError("ImgRsz: image storing failed. $!"), return;
		close $fh;
	}
	elsif ($module eq 'Imager') {
		my $newImg = $img->scale(xpixels => $newW, ypixels => $newH, 
			type => 'nonprop', qtype => 'mixing')
			or $m->logError("ImgRsz: image scaling failed. " . Imager->errstr()), return;
		$newImg->write(file => $newFsPathEnc, jpegquality => $quality)
			or $m->logError("ImgRsz: image storing failed. " . $newImg->errstr()), return;
	}
	elsif ($module eq 'Graphics::Magick' || $module eq 'Image::Magick') {
		my $newImg = $module->new() 	
			or $m->logError("ImgRsz: image creation failed."), return;
		$err = $newImg->Read($oldFsPathEnc . "[0]")
			and $m->logError("ImgRsz: image loading failed. $err"), return;
		$err = $newImg->Scale(width => $newW, height => $newH)
			and $m->logError("ImgRsz: image scaling failed. $err"), return;
		$err = $newImg->Write(filename => $newFsPathEnc, compression => 'JPEG', quality => $quality)
			and $m->logError("ImgRsz: image storing failed. $err"), return;
	}
	$m->setMode($newFsPathEnc, 'file');
	unlink $oldFsPathEnc;

	# Update attachment	filename
	$fileName =~ s!\.(?:jpg|png|gif)$!.rsz.jpg!i;
	$m->dbDo("
		UPDATE attachments SET fileName = ? WHERE id = ?", $fileName, $attachId);
}
