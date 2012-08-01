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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new(@_, autocomplete => 1);
$m->cacheUserStatus() if $userId;

# Check if access should be denied
$cfg->{attachList} || $user->{admin} or $m->error('errNoAccess');
$cfg->{attachList} != 2 || $userId or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Get CGI parameters
my $page = $m->paramInt('pg') || 1;
my $words = $m->paramStr('words');
my $userName = $m->paramStr('user');
my $categBoardIdStr = $m->paramStrId('board') || "0";  # Sanitize later
my $field = $m->paramStrId('field') || 'filename';
my $minAge = $m->paramInt('min');
my $maxAge = $m->paramInt('max');
my $order = $m->paramStr('order') || 'desc';
my $gallery = $m->paramBool('gallery');

# Enforce valid options
$minAge = $m->min($minAge, 24855);
$maxAge = $m->min($maxAge, 24855);
$field = 'filename' if $field !~ /^(?:filename|caption)\z/;
$order = 'desc' if $order !~ /^(?:asc|desc)\z/;
$gallery = 0 if !$cfg->{attachGallery};

# Preserve parameters in links
my @params = ( words => $words, user => $userName, board => $categBoardIdStr, field => $field,
	min => $minAge, max => $maxAge, order => $order, gallery => $gallery );

# Get visible boards with attachments enabled
my $boards = $m->fetchAllHash("
	SELECT boards.*, 
		categories.title AS categTitle
	FROM boards AS boards
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
	WHERE boards.attach > 0
	ORDER BY categories.pos, boards.pos");
@$boards = grep($m->boardVisible($_), @$boards);

# Search words
my $fieldStr = "attachments.$field";
my $like = $m->{pgsql} ? 'ILIKE' : 'LIKE';
my $wordsLike = $m->dbEscLike($words);
my @words = $wordsLike =~ /"[^"]+"|[^"\s]+/g;
splice(@words, 10) if @words > 10;
my @wordPreds = ();
my @wordValues = ();
for (my $i = 0; $i < @words; $i++) {
	$words[$i] =~ s/"//g;
	$words[$i] = $m->escHtml($words[$i]);
	push @wordPreds, "$fieldStr $like :word$i";
	push @wordValues, "word$i" => "%$words[$i]%";
}
my $wordStr = @wordPreds ? "AND (" . join(" AND ", @wordPreds) . ")" : "";

# Search username
my $userNameLike = "%" . $m->dbEscLike($userName) . "%";
my $userNameStr = $userName ? "AND posts.userNameBak LIKE :userNameLike" : "";

# Limit to age
my $minAgeStr = $minAge ? "AND posts.postTime < :now - :minAge * 86400" : "";
my $maxAgeStr = $maxAge ? "AND posts.postTime > :now - :maxAge * 86400" : "";

# Limit to category or board
my $boardJoinStr = "";
my $boardStr = "";
my $boardId = 0;
if ($categBoardIdStr =~ /^bid([0-9]+)\z/) {
	$boardStr = "AND posts.boardId = $1";
	$boardId = $1;
} 
elsif ($categBoardIdStr =~ /^cid([0-9]+)\z/) {
	$boardJoinStr = "INNER JOIN boards AS boards ON boards.id = posts.boardId";
	$boardStr = "AND boards.categoryId = $1";
	$boardId = 0;
}

# Get ids of attachments
my $galleryStr = $gallery ? "AND attachments.webImage > 0" : "";
my @boardIds = map($_->{id}, @$boards);
my $attachments = $m->fetchAllArray("
	SELECT attachments.id
	FROM attachments AS attachments
		INNER JOIN posts AS posts
			ON posts.id = attachments.postId
		$boardJoinStr
	WHERE posts.boardId IN (:boardIds)
		$wordStr
		$userNameStr
		$minAgeStr
		$maxAgeStr
		$galleryStr
		$boardStr
	ORDER BY attachments.id $order",
	{ @wordValues, userNameLike => $userNameLike, now => $m->{now},
		minAge => $minAge, maxAge => $maxAge, boardIds => \@boardIds });
	
# Print page bar
my $attachmentsPP = $gallery ? ($cfg->{attachGallPP} || 12) : ($cfg->{attachPP} ||  25);
my $pageNum = int(@$attachments / $attachmentsPP) + (@$attachments % $attachmentsPP != 0);
my @pageLinks = $pageNum < 2 ? () : $m->pageLinks('attach_list', \@params, $page, $pageNum);
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{aliTitle}, navLinks => \@navLinks, pageLinks => \@pageLinks);

# Get attachments on page
my @pageAttachIds = @$attachments[($page - 1) * $attachmentsPP 
	.. $m->min($page * $attachmentsPP, scalar @$attachments) - 1];
@pageAttachIds = map($_->[0], @pageAttachIds);
$attachments = $m->fetchAllHash("
	SELECT attachments.*, 
		posts.userId, posts.userNameBak
	FROM attachments AS attachments
		INNER JOIN posts AS posts
			ON posts.id = attachments.postId
	WHERE attachments.id IN (:pageAttachIds)
	ORDER BY attachments.id $order",
	{ pageAttachIds => \@pageAttachIds });

# Determine checkbox, radiobutton and listbox states
my $galleryChk = $gallery ? 'checked' : "";
my %state = ( $categBoardIdStr => 'selected', $field => 'selected', $order => 'selected' );

# Display age 0 as empty string
$minAge = $minAge ? $minAge : "";
$maxAge = $maxAge ? $maxAge : "";

# Escape submitted values
my $wordsEsc = $m->escHtml($words);
my $userNameEsc = $m->escHtml($userName);

# Print attachment list form
print
	"<form action='attach_list$m->{ext}' method='get'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{aliLfmTtl}</span></div>\n",
	"<div class='ccl'>\n",
	"<div class='cli'>\n",
	"<label>$lng->{aliLfmWords}\n",
	"<input type='text' name='words' size='20' value='$wordsEsc' autofocus></label>\n",
	"<label>$lng->{aliLfmUser}\n",
	"<input type='text' class='acu acs' name='user' size='15' value='$userNameEsc'></label>\n",
	"<label>$lng->{aliLfmBoard}\n",
	"<select name='board' size='1'>\n",
	"<option value='0'>$lng->{seaBoardAll}</option>\n";

my $lastCategoryId = 0;
for my $board (@$boards) {
	if ($lastCategoryId != $board->{categoryId}) {
		$lastCategoryId = $board->{categoryId};
		my $sel = $state{"cid$board->{categoryId}"};
		print "<option value='cid$board->{categoryId}' $sel>$board->{categTitle}</option>\n";
	}
	my $sel = $state{"bid$board->{id}"};
	print "<option value='bid$board->{id}' $sel>- $board->{title}</option>\n";
}

print
	"</select></label>\n",
	"</div>\n",
	"<div class='cli'>\n",
	"<label>$lng->{aliLfmField}\n",
	"<select name='field' size='1'>\n",
	"<option value='filename' $state{filename}>$lng->{aliLfmFldFnm}</option>\n",
	"<option value='caption' $state{caption}>$lng->{aliLfmFldCpt}</option>\n",
	"</select></label>\n",
	"<datalist id='age'>\n",
	"<option value='1'>\n",
	"<option value='7'>\n",
	"<option value='30'>\n",
	"<option value='90'>\n",
	"<option value='365'>\n",
	"</datalist>\n",
	"<label>$lng->{aliLfmMinAge}\n",
	"<input type='text' name='min' size='3' maxlength='4' list='age' value='$minAge'></label>\n",
	"<label>$lng->{aliLfmMaxAge}\n",
	"<input type='text' name='max' size='3' maxlength='4' list='age' value='$maxAge'></label>\n",
	"<label>$lng->{aliLfmOrder}\n",
	"<select name='order' size='1'>\n",
	"<option value='desc' $state{desc}>$lng->{aliLfmOrdDsc}</option>\n",
	"<option value='asc' $state{asc}>$lng->{aliLfmOrdAsc}</option>\n",
	"</select></label>\n",
	$cfg->{attachGallery} ? "<label><input type='checkbox' name='gallery' value='1'"
		. " $galleryChk>$lng->{aliLfmGall}</label>\n" : "",
	$m->submitButton('aliLfmListB', 'search'),
	"</div>\n",
	"</div>\n",
	"</div>\n",
	"</form>\n\n";

# Print normal attachment list
if (!$gallery) {
	print 
		"<table class='tbl'>\n",
		"<tr class='hrw'>\n",
		"<th>$lng->{aliLstFile}</th>\n",
		"<th>$lng->{aliLstCapt}</th>\n",
		"<th>$lng->{aliLstSize}</th>\n",
		"<th>$lng->{aliLstPost}</th>\n",
		"<th>$lng->{aliLstUser}</th>\n",
		"</tr>\n";
	
	for my $attach (@$attachments) {
		my $fileName = $attach->{fileName};
		my $postId = $attach->{postId};
		my $postIdMod = $postId % 100;
		my $attShowUrl = $attach->{webImage} ? $m->url('attach_show', aid => $attach->{id}) 
			: "$cfg->{attachUrlPath}/$postIdMod/$postId/$fileName";
		my $postUrl = $m->url('topic_show', pid => $postId);
		my $size = -s $m->encFsPath("$cfg->{attachFsPath}/$postIdMod/$postId/$fileName");
		my $sizeStr = $m->formatSize($size);
		my $userNameStr = $attach->{userNameBak} || " - ";
		my $userUrl = $m->url('user_info', uid => $attach->{userId});
		
		print
			"<tr class='crw'>\n",
			"<td><a href='$attShowUrl'>$fileName</a></td>\n",
			"<td>$attach->{caption}</td>\n",
			"<td>$sizeStr</td>\n",
			"<td><a href='$postUrl'>$postId</a></td>\n",
			"<td><a href='$userUrl'>$userNameStr</a></td>\n",
			"</tr>\n";
	}
	
	print "</table>\n\n";
}
# Print attachment image gallery
else {
	print	"<table class='tbl igl'>\n<tr class='crw'>\n";
	for (my $i = 0; $i < @$attachments; $i++) {
		print "</tr><tr class='crw'>\n" if $i && $i % 4 == 0;
		
		# Determine values
		my $attach = @$attachments[$i];
		my $fileName = $attach->{fileName};
		my $postId = $attach->{postId};
		my $postIdMod = $postId % 100;
		my $imgFile = "$cfg->{attachFsPath}/$postIdMod/$postId/$fileName";
		my $imgUrl = "$cfg->{attachUrlPath}/$postIdMod/$postId/$fileName";
		my $imgShowUrl = $m->url('attach_show', aid => $attach->{id});
		my $thbFile = $imgFile;
		my $thbUrl = $imgUrl;
		$thbFile =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
		$thbUrl =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
		my $size = -s $m->encFsPath($imgFile);
		my $sizeStr = $m->formatSize($size);
		my $useThb = -f $m->encFsPath($thbFile) || $m->addThumbnail($imgFile);
		my $postUrl = $m->url('topic_show', pid => $postId);
		my $src = $useThb ? $thbUrl : $imgUrl;
		my $thbStr = $useThb >= 0 
			? "<img class='igl' src='$src' title='$sizeStr' alt=''>" : ($size ? "?" : "404");
		
		# Print image and file size
		print
			"<td>\n",
			"<div><a href='$postUrl'>$thbStr</a></div>\n",
			"<div><a href='$imgShowUrl'>$fileName</a></div>\n",
			"<div>$attach->{caption}</div>\n",
			"</td>\n";
	}

	# Print rest of table
	my $empty = 4 - @$attachments % 4; 
	$empty = 0 if $empty == 4;
	print "<td></td>\n" while $empty-- > 0;
	print	
		"</tr>\n",
		"</table>\n\n";
}

# Log action and finish
$m->logAction(3, 'attach', 'list', $userId, $boardId);
$m->printFooter();
$m->finish();
