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

# Load additional modules
require MwfCaptcha if $cfg->{captcha};

# Get CGI parameters
my $parentId = $m->paramInt('pid');
my $topicId = $m->paramInt('tid');
my $unregName = $cfg->{allowUnregName} ? $m->paramStr('name') : undef;
my $body = $m->paramStr('body');
my $rawBody = $m->paramStr('raw', 0);
my $wantQuote = $m->paramBool('quote');
my $add = $m->paramBool('add');
my $preview = $m->paramBool('preview');
my $really = $m->paramBool('really');

# Get parent post
my $parent = {};
my $topicReply = undef;
if ($parentId) {
	$parent = $m->fetchHash("
		SELECT *, ROUND((? - postTime) / 86400) AS age FROM posts WHERE id = ?", $m->{now}, $parentId);
	$parent or $m->error('errPstNotFnd');
	$topicId = $parent->{topicId};
	$topicReply = 0;
}
elsif ($topicId) {
	$parentId = 0;
	$topicReply = 1;
}
else {
	$m->error('errParamMiss');
}

# Get topic
my $topic = $m->fetchHash("
	SELECT * FROM topics WHERE id = ?", $topicId);
$topic or $m->error('errTpcNotFnd');
my $boardId = $topic->{boardId};

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Check if user can see and write to board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId) 
	|| $board->{topicAdmins} && $m->topicAdmin($userId, $topicId);
my $boardMember = $m->boardMember($userId, $boardId);
$boardAdmin || $boardMember || $m->boardVisible($board) or $m->error('errNoAccess');
$boardAdmin || $boardMember || $m->boardWritable($board, 1) or $m->error('errNoAccess');

# Check if user is registered
$userId || $board->{unregistered} or $m->error('errNoAccess');

# Check if user has been registered for long enough
$m->{now} > $user->{regTime} + $cfg->{minRegTime}
	or $m->error($m->formatStr($lng->{errMinRegTim}, { hours => $cfg->{minRegTime} / 3600 }))
	if $cfg->{minRegTime} && $userId;

# Check if topic or post is locked
!$topic->{locked} || $boardAdmin or $m->error('errTpcLocked');
!$parent->{locked} || $boardAdmin or $m->error('errPstLocked');

# Check authorization
$m->checkAuthz($user, 'newPost');

# Process form
if ($add) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');
	
	# Flood control
	if ($cfg->{repostTime} && !$boardAdmin) {
		my $lastPostTime = $m->fetchArray("
			SELECT MAX(postTime) FROM posts WHERE userId = ?", $userId);
		my $waitTime = $cfg->{repostTime} - ($m->{now} - $lastPostTime);
		my $errStr = $m->formatStr($lng->{errRepostTim}, { seconds => $waitTime });
		$waitTime < 1 or $m->formError($errStr);
	}

	# Check body length
	length($body) <= $cfg->{maxBodyLen} or $m->formError('errBdyLen');
	length($rawBody) <= $cfg->{maxBodyLen} or $m->formError('errBdyLen');
	
	# Check unregistered name
	if ($unregName && $unregName ne $cfg->{anonName}) {
		length($unregName) <= $cfg->{maxUserNameLen} or $m->formError('errNamSize');
		!$m->fetchArray("
			SELECT 1 FROM users WHERE userName = ?", $unregName)
			or $m->formError('errNamGone');
	}
	
	# Determine misc values
	my $approved = !$board->{approve} || $boardAdmin || ($boardMember && $board->{private} != 1) 
		? 1 : 0;
	my $postUserId = $userId ? $userId : -1;
	my $anonUserName = $m->escHtml($unregName) || $cfg->{anonName} || "?";
	my $postUserName = $userId ? $user->{userName} : $anonUserName;
	my $ip = $cfg->{recordIp} ? $m->{env}{userIp} : "";
	my $insertParentId = $board->{flat} ? 0 : $parentId;

	# Process text
	my $post = { userId => $postUserId, userNameBak => $postUserName, postTime => $m->{now},
		body => $body, rawBody => $rawBody };
	$m->editToDb({}, $post);
	length($post->{body}) or $m->formError('errBdyEmpty');

	# Check captcha
	MwfCaptcha::checkCaptcha($m, 'pstCpt') 
		if $cfg->{captcha} >= 3 || $cfg->{captcha} >= 2 && !$m->{user}{id};

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Check for dupe
		!$m->fetchArray(" 
			SELECT 1 
			FROM posts 
			WHERE topicId = :topicId
				AND parentId = :parentId
				AND userId = :userId
				AND body = :body
			LIMIT 1",
			{ topicId => $topicId, parentId => $parentId, userId => $userId, body => $post->{body} })
			or $m->error('errDupe');
		
		# Insert post
		$m->dbDo("
			INSERT INTO posts (
				userId, userNameBak, boardId, topicId, parentId, approved, ip, postTime, body, rawBody) 
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
			$postUserId, $postUserName, $boardId, $topicId, $insertParentId, $approved, $ip, 
			$m->{now}, $post->{body}, $post->{rawBody});
		my $postId = $post->{id} = $m->dbInsertId('posts');
		
		# Mark read if there haven't been other new posts in the meantime
		my $topicReadTime = $m->fetchArray("
			SELECT lastReadTime FROM topicReadTimes WHERE userId = ? AND topicId = ?", 
			$userId, $topicId);
		my $lowestUnreadTime = $m->max($topicReadTime, $user->{fakeReadTime}, 
			$m->{now} - $cfg->{maxUnreadDays} * 86400);
		my $allRead = $m->fetchArray("
			SELECT lastPostTime <= ? FROM topics WHERE id = ?", $lowestUnreadTime, $topicId);
		if ($allRead) {
			$m->dbDo("
				DELETE FROM topicReadTimes WHERE userId = ? AND topicId = ?", $userId, $topicId);
			$m->dbDo("
				INSERT INTO topicReadTimes (userId, topicId, lastReadTime) VALUES (?, ?, ?)",
				$userId, $topicId, $m->{now} + 1);
		}
		
		# Update board/topic stats
		$m->dbDo("
			UPDATE topics SET postNum = postNum + 1, lastPostTime = ? WHERE id = ?", $m->{now}, $topicId);
		$m->dbDo("
			UPDATE boards SET postNum = postNum + 1, lastPostTime = ? WHERE id = ?", $m->{now}, $boardId);
		
		# Update user stats
		$m->{userUpdates}{postNum} = $user->{postNum} + 1 if $userId;

		# Send notifications
		$m->notifyPost(board => $board, topic => $topic, post => $post, parent => $parent)
			if $approved;

		# Log action and finish
		$m->logAction(1, 'post', 'add', $userId, $boardId, $topicId, $postId, $parentId);
		$m->redirect('topic_show', pid => $postId, msg => 'ReplyPost');
	}
}

# Print form
if (!$add || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader(undef, { tagButtons => 1, lng_tbbInsSnip => $lng->{tbbInsSnip} });
	
	# Print page bar
	my @navLinks = ({ url => $m->url('topic_show', pid => $parentId || $topic->{basePostId}),
		txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => $lng->{rplTitle}, subTitle => $topic->{subject}, 
		navLinks => \@navLinks);

	if ($cfg->{replyAgeWarn} && $cfg->{replyAgeWarn} < $parent->{age}
		&& !$really && !$preview && !$topic->{sticky} && !$boardAdmin && $board->{private} != 1) {
		# Warn if parent post is rather old
		my $title = $topicReply ? $lng->{rplTopicTtl} : $lng->{rplReplyTtl};
		my $orlyText = $m->formatStr($lng->{rplAgeOrly}, { age => $parent->{age} });
		my $url = $m->url('post_add', pid => $parentId, tid => $topicId, 
			quote => $wantQuote, really => 1);
		print
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$title</span></div>\n",
			"<div class='ccl'>\n",
			"<p>$orlyText</p>\n",
			"<p><a href='$url'>$lng->{rplAgeYarly}</a></p>\n",
			"</div>\n",
			"</div>\n";
	}
	else {
		# Print hints and form errors
		$m->printHints(['rplReplyT']) if !$board->{flat} && $user->{postNum} < 20;
		$m->printFormErrors();

		# Quote parent post body
		my $quote = undef;
		if ($cfg->{quote} && $wantQuote	&& ($board->{flat} || $cfg->{quote} == 2)) {
			# Prepare quote
			eval { require Text::Flowed } or $m->error("Text::Flowed module not available.");
			$quote = $parent->{body};
			$quote =~ s!<blockquote>.+?</blockquote>(?:<br/>)?!!g;
			$quote =~ s!<br/?>!\n!g;  # Preserve linebreaks before removing tags
			$quote =~ s!<.+?>!!g;  # Remove tags before quoting
			$quote = $m->deescHtml($quote);
			$quote = Text::Flowed::reformat($quote, { quote => 1, fixed => 1,
				max_length => $cfg->{quoteCols}, opt_length => $cfg->{quoteCols} - 6});
			$quote = "$parent->{userNameBak}:\n$quote" if $cfg->{quotePrefix};
		}
	
		# Prepare parent and preview body
		$m->dbToDisplay($board, $parent);
		if ($preview) {
			$preview = { body => $body, rawBody => $rawBody };
			$m->editToDb({}, $preview);
			$m->dbToDisplay($board, $preview);
		}
	
		# Escape submitted values
		my $unregNameEsc = $m->escHtml($unregName) || $cfg->{anonName};
		$body ||= $quote;
		my $bodyEsc = $m->escHtml($body, 1);
		my $rawBodyEsc = $m->escHtml($rawBody, 1);

		# Prepare values
		my $title = $topicReply ? $lng->{rplTopicTtl} : $lng->{rplReplyTtl};

		# Print reply form
		print
			"<form action='post_add$m->{ext}' method='post'>\n",
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$title</span></div>\n",
			"<div class='ccl'>\n";
	
		# Print username input for guests
		print
			"<fieldset>\n",
			"<label class='lbw'>$lng->{rplReplyName}\n",
			"<input type='text' class='qwi' name='name' maxlength='$cfg->{maxUserNameLen}'",
			" value='$unregNameEsc'></label>\n",
			"</fieldset>\n"
			if $cfg->{allowUnregName} && $board->{unregistered} && !$userId;
	
		# Print body textarea
		print
			"<fieldset>\n",
			$m->tagButtons($board),
	  	"<textarea class='tgi' name='body' rows='14' autofocus required>$bodyEsc</textarea>\n",
			"</fieldset>\n";

		# Print raw body textarea
		print
			$rawBodyEsc ? "<fieldset>\n" : 
				"<div><a class='clk rvl' data-rvlid='#rawtxt' href='#'>$lng->{eptEditIRaw} &#187;"
				. "</a></div>\n<fieldset id='rawtxt' style='display: none'>\n",
			"<label class='lbw'>$lng->{eptEditRaw}\n",
			"<textarea class='raw' name='raw' rows='14' spellcheck='false'>$rawBodyEsc",
			"</textarea></label>\n",
			"</fieldset>\n"
			if $cfg->{rawBody};

		# Print captcha
		print MwfCaptcha::captchaInputs($m, 'pstCpt')
			if $cfg->{captcha} >= 3 || $cfg->{captcha} >= 2 && !$m->{user}{id};

		# Print submit section
		print				
			$m->submitButton('rplReplyB', 'write', 'add'),
			$m->submitButton('rplReplyPrvB', 'preview', 'preview'),
			"<input type='hidden' name='pid' value='$parentId'>\n",
			"<input type='hidden' name='tid' value='$topicId'>\n",
			$m->stdFormFields(),
			"</div>\n",
			"</div>\n",
			"</form>\n\n";
		
		# Print preview
		print
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{rplPrvTtl}</span></div>\n",
			"<div class='ccl'>\n",
			$preview->{body}, "\n",
			"</div>\n",
			"</div>\n\n"
			if $preview;
	
		# Print parent post
		print
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$lng->{rplReplyResp}</span> $parent->{userNameBak}</div>\n",
			"<div class='ccl'>\n",
			$parent->{body}, "\n",
			"</div>\n",
			"</div>\n\n"
			if !$topicReply;
	}
	
	# Log action and finish
	$m->logAction(3, 'post', 'add', $userId, $boardId, $topicId, 0, $parentId);
	$m->printFooter();
}
$m->finish();
