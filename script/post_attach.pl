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
my $attach = undef;
if ($attachId) {
	$attach = $m->fetchHash("
		SELECT * FROM attachments WHERE id = ?", $attachId);
	$attach or $m->error('errAttNotFnd');
	$postId = $attach->{postId};
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

# Disable embed if not allowed
$embed = 0 if !$cfg->{attachImg};

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# Process upload form
	if ($action eq 'upload') {
		# Get upload, check filename and size
		my ($upload, $fileName, $fileSize) = $m->getUpload('file');
		length($fileName) or $m->error('errAttName');
		$fileSize or $m->error('errAttSize');
		
		# Make sure filenames don't clash
		my ($name, $ext) = $fileName =~ /(.+?)(\.[^.]+)?\z/;
		$name = substr($name, 0, $cfg->{attachNameLen} || 40);
		$ext = substr($ext, 0, $cfg->{attachNameLen} || 40);
		my $webImage = $ext =~ /^\.(?:jpg|png|gif)\z/i ? 1 : 0;
		my $like = $m->{pgsql} ? 'ILIKE' : 'LIKE';
		my $num = "";
		for my $i (0 .. 100) {
			$num = $i ? "-$i" : "";
			my $nameExists = $m->fetchArray("
				SELECT 1 FROM attachments WHERE postId = ? AND LOWER(fileName) $like LOWER(?)", 
				$postId, $webImage ? "$name$num%" : "$name$num$ext");
			last if !$nameExists;
			$i < 100 or $m->formError("Too many filename collisions.");
		}
		$fileName = "$name$num$ext";

		# If there's no error, finish action
		if (!@{$m->{formErrors}}) {
			# Create directories and attachment file
			my $path = "$cfg->{attachFsPath}/$postIdMod";
			$m->createDirectories($path, $postId);
			$m->saveUpload('file', $upload, "$path/$postId/" . $m->encFsPath($fileName));
			
			# Add attachments table entry
			$webImage = 2 if $webImage && $embed;
			$caption = substr($caption, 0, 100);
			my $captionEsc = $m->escHtml($caption);
			$m->dbDo("
				INSERT INTO attachments (postId, webImage, fileName, caption) VALUES (?, ?, ?, ?)",
				$postId, $webImage, $fileName, $captionEsc);
			$attachId = $m->dbInsertId("attachments");

			# Resize image
			$m->resizeAttachment($attachId) if $webImage && $cfg->{attachImgRsz};
			
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
			my $webImage = $attach->{fileName} =~ /\.(?:jpg|png|gif)\z/i ? 1 : 0;
			$webImage = 2 if $webImage && $embed;
			$caption = substr($caption, 0, 100);
			my $captionEsc = $m->escHtml($caption);
			$m->dbDo("
				UPDATE attachments SET webImage = ?, caption = ? WHERE id = ?", 
				$webImage, $captionEsc, $attachId);
				
			# Delete thumbnail
			if ($webImage && !$embed) {
				my $file = "$cfg->{attachFsPath}/$postIdMod/$postId/$attach->{fileName}";
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

	# Print page bar
	my @navLinks = ({ url => $m->url('topic_show', pid => $postId), txt => 'comUp', ico => 'up' });
	my @userLinks = ();
	push @userLinks, { url => $m->url('user_confirm', script => 'post_attach', pid => $postId, 
		act => 'delAll'), txt => 'attDelAll', ico => 'delete' }
		if @$attachments;
	$m->printPageBar(mainTitle => $lng->{attTitle}, navLinks => \@navLinks, userLinks => \@userLinks);

	# Print hints and form errors
	if ($m->paramDefined('msg')) { $m->printHints(['attGoPostT']) }
	else { $m->printHints([$lng->{attDropNote}], 'dropNote', 1) }
	$m->printFormErrors();

	# Prepare values
	my $sizeStr = $m->formatSize($cfg->{maxAttachLen});
	my $label = $m->formatStr($lng->{attUplFiles}, { size => $sizeStr });

	# Print attachment form
	print	
		"<form id='upload' action='post_attach$m->{ext}' method='post' enctype='multipart/form-data'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{attUplTtl}</span></div>\n",
		"<div class='ccl' id='dropZone'>\n",
		"<fieldset>\n",
		"<label class='lbw'>$label\n",
		"<input type='file' name='file' autofocus></label>\n",
		"<label class='lbw'>$lng->{attUplCapt}\n",
		"<input type='text' class='hwi' name='caption' maxlength='100'></label>\n",
		"</fieldset>\n";
		
	print	
		"<fieldset>\n",
		"<label><input type='checkbox' name='embed'>$lng->{attUplEmbed}</label>\n",
		"</fieldset>\n"
		if $cfg->{attachImg};
	
	print
		$m->submitButton('attUplB', 'attach', 'upload'),
		"<input type='hidden' name='pid' value='$postId'>\n",
		"<input type='hidden' name='act' value='upload'>\n",
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
	
	# Print existing attachments		
	for my $attach (@$attachments) {
		my $fileName = $attach->{fileName};
		print	
			"<form action='post_attach$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{attAttTtl}</span> $fileName</div>\n",
			"<div class='ccl'>\n";

		my $attFile = "$cfg->{attachFsPath}/$postIdMod/$postId/$fileName";
		my $attUrl = "$cfg->{attachUrlPath}/$postIdMod/$postId/$fileName";
		my $imgShowUrl = $m->url('attach_show', aid => $attach->{id});
		my $caption = $attach->{caption};
		my $embedChk = $attach->{webImage} == 2 ? 'checked' : "";
		my $sizeStr = $m->formatSize(-s $m->encFsPath($attFile));
		if ($cfg->{attachImg} && $attach->{webImage} == 2 && $user->{showImages}) {
			my $thbFile = $attFile;
			my $thbUrl = $attUrl;
			$thbFile =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
			$thbUrl =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
			my $title = "title='$sizeStr'";
			print $cfg->{attachImgThb} && (-f $m->encFsPath($thbFile) || $m->addThumbnail($attFile))
				? "<p><a href='$imgShowUrl'><img class='amt' src='$thbUrl' $title alt=''></a></p>"
				: "<p><img class='ami' src='$attUrl' $title alt=''></p>";
		}
		elsif ($attach->{webImage}) {
			print "<p><a href='$imgShowUrl'>$fileName</a> ($sizeStr)</p>";
		}
		else {
			print "<p><a href='$attUrl'>$fileName</a> ($sizeStr)</p>";
		}

		print 
			"<label class='lbw'>$lng->{attUplCapt}\n",
			"<input type='text' class='hwi' name='caption' maxlength='100' value='$caption'></label>\n",
			$cfg->{attachImg} && $attach->{webImage}
				? "<div><label><input type='checkbox' name='embed' $embedChk>$lng->{attUplEmbed}</label></div>\n" 
				: "",
			$m->submitButton('attAttChgB', 'edit', 'change'),
			$m->submitButton('attAttDelB', 'delete', 'delete'),
			"<input type='hidden' name='aid' value='$attach->{id}'>\n",
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
