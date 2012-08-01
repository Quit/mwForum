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

# Check if access should be denied
$cfg->{messages} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Get CGI parameters
my $msgId = $m->paramInt('mid');
$msgId or $m->error('errParamMiss');

# Print page bar
my @navLinks = ({ url => $m->url('message_list'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{mssTitle}, navLinks => \@navLinks);

# Get message
my ($sent, $received) = $m->fetchArray("
	SELECT senderId = :userId, receiverId = :userId FROM messages WHERE id = :msgId",
	{ userId => $userId, msgId => $msgId });
$sent || $received or $m->error('errMsgNotFnd');
my $joinUserId = $sent ? 'receiverId' : 'senderId';
my $msg = $m->fetchHash("
	SELECT messages.*, messages.sendTime > :prevOnTime AS new,
		users.id AS userId, users.userName, users.title AS userTitle
	FROM messages AS messages
		INNER JOIN users AS users
			ON users.id = messages.$joinUserId
	WHERE messages.id = :msgId", 
	{ prevOnTime => $user->{prevOnTime}, msgId => $msgId });
$msg or $m->error('errMsgNotFnd');

# Check if user can see message
$received && $msg->{inbox} || $sent && $msg->{sentbox} or $m->error('errNoAccess');

# Determine message icon attributes
my $imgName; 
my $imgTitle = "";
my $imgAlt = "";
if ($received) { 
	if ($msg->{hasRead} == 2) { 
		$imgName = "post_a"; $imgTitle = $lng->{comAnswerTT}; $imgAlt = $lng->{comAnswer};
	}
	elsif ($msg->{new} && !$msg->{hasRead}) { 
		$imgName = "post_nu"; $imgTitle = $lng->{comNewUnrdTT}; $imgAlt = $lng->{comNewUnrd};
	}
	elsif ($msg->{new}) { 
		$imgName = "post_nr"; $imgTitle = $lng->{comNewReadTT}; $imgAlt = $lng->{comNewRead};
	}
	elsif (!$msg->{hasRead}) { 
		$imgName = "post_ou"; $imgTitle = $lng->{comOldUnrdTT}; $imgAlt = $lng->{comOldUnrd};
	}
	else { 
		$imgName = "post_or"; $imgTitle = $lng->{comOldReadTT}; $imgAlt = $lng->{comOldRead};
	}
}
else {
	if ($msg->{new}) { 
		$imgName = "post_nr"; $imgTitle = $lng->{comNewReadTT}; $imgAlt = $lng->{comNewRead};
	}
	else { 
		$imgName = "post_or"; $imgTitle = $lng->{comOldReadTT}; $imgAlt = $lng->{comOldRead};
	}
}
my $imgAttr = "class='sic sic_$imgName' title='$imgTitle' alt='$imgAlt'";

# Format output
my $infUrl = $m->url('user_info', uid => $msg->{userId});
my $addUrl = $m->url('message_add', mid => $msgId);
my $qotUrl = $m->url('message_add', mid => $msgId, quote => 1);
my $delUrl = $m->url('user_confirm', mid => $msgId, script => 'message_delete', 
	name => $msg->{subject});
my $userNameStr = "<a href='$infUrl'>$msg->{userName}</a>";
$userNameStr .= " " . $m->formatUserTitle($msg->{userTitle}) 
	if $msg->{userTitle} && $user->{showDeco};
my $sendTimeStr = $m->formatTime($msg->{sendTime}, $user->{timezone});
$m->dbToDisplay({}, $msg);
my $toFrom = $sent ? $lng->{mssTo} : $lng->{mssFrom};
my $emptyPixel = "src='$cfg->{dataPath}/epx.png'";

# Print message form
print
	"<div class='frm msg'>\n",
	"<div class='hcl'>\n",
	"<img $emptyPixel $imgAttr>\n",
	"<span class='htt'>$toFrom</span> $userNameStr\n",
	"<span class='htt'>$lng->{mssDate}</span> $sendTimeStr\n",
	"<span class='htt'>$lng->{mssSubject}</span> $msg->{subject}\n",
	"</div>\n",
	"<div class='ccl'>\n",
	"$msg->{body}\n",
	"</div>\n",
	"<div class='bcl'>\n",
	$received ? $m->buttonLink($addUrl, 'mssReply', 'write') : "",
	$received && $cfg->{quote} ? $m->buttonLink($qotUrl, 'mssQuote', 'write') : "",
	$m->buttonLink($delUrl, 'mssDelete', 'delete'),
	"</div>\n",
	"</div>\n\n";
	
# Update message status
$m->dbDo("
	UPDATE messages SET hasRead = 1 WHERE id = ?", $msgId) 
	if $received && !$msg->{hasRead};

# Log action and finish
$m->logAction(2, 'msg', 'show', $userId, 0, 0, 0, $msgId);
$m->printFooter();
$m->finish();
