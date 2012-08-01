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

# Get messages
my $msgsIn = $m->fetchAllHash("
	SELECT messages.id, messages.senderId, messages.receiverId, messages.sendTime,
		messages.hasRead, messages.subject, messages.sendTime > :prevOnTime AS new,
		users.userName
	FROM messages AS messages
		INNER JOIN users AS users
			ON users.id = messages.senderId
	WHERE messages.receiverId = :userId
		AND messages.inbox = 1
	ORDER BY messages.sendTime DESC",
	{ prevOnTime => $user->{prevOnTime}, userId => $userId });

my $msgsSent = $m->fetchAllHash("
	SELECT messages.id, messages.senderId, messages.receiverId, messages.sendTime,
		messages.hasRead, messages.subject, messages.sendTime > :prevOnTime AS new,
		users.userName
	FROM messages AS messages
		INNER JOIN users AS users
			ON users.id = messages.receiverId
	WHERE messages.senderId = :userId
		AND messages.sentbox = 1
	ORDER BY messages.sendTime DESC",
	{ prevOnTime => $user->{prevOnTime}, userId => $userId });

# Print page bar
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
my @userLinks = ();
push @userLinks, { url => $m->url('message_add'), txt => 'mslSend', ico => 'write' };
push @userLinks, { url => $m->url('message_export'), txt => 'mslExport', ico => 'archive' }
	if @$msgsIn || @$msgsSent;
push @userLinks, { url => $m->url('user_confirm', script => 'message_delete', act => 'delAllRead'), 
	txt => 'mslDelAll', ico => 'delete' }
	if @$msgsIn || @$msgsSent;
$m->printPageBar(mainTitle => $lng->{mslTitle}, navLinks => \@navLinks, userLinks => \@userLinks);

# Print expiration note	
$m->printHints([$m->formatStr($lng->{mslExpire}, { days => $cfg->{msgExpiration} })])
	if $cfg->{msgExpiration};

# Print inbox table header
print
	"<table class='tbl'>\n",
	"<tr class='hrw'>\n",
	"<th>$lng->{mslInbox}</th>\n",
	"<th class='shr'>$lng->{mslFrom}</th>\n",
	"<th class='shr'>$lng->{mslDate}</th>\n",
	"<th class='shr'>$lng->{mslCommands}</th>\n",
	"</tr>\n";

# Print messages in inbox
my $emptyPixel = "src='$cfg->{dataPath}/epx.png'";
for my $msg (@$msgsIn) {
	# Determine variable message icon attributes
	my $imgName; 
	my $imgTitle = "";
	my $imgAlt = "";
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
	my $imgAttr = "class='sic sic_$imgName' title='$imgTitle' alt='$imgAlt'";

	# Format output
	my $infUrl = $m->url('user_info', uid => $msg->{senderId});
	my $shwUrl = $m->url('message_show', mid => $msg->{id});
	my $delUrl = $m->url('user_confirm', mid => $msg->{id}, script => 'message_delete',
		name => $msg->{subject}, ori => 1);
	my $timeStr = $m->formatTime($msg->{sendTime}, $user->{timezone});
	my $userNameStr = "<a href='$infUrl'>$msg->{userName}</a>";

	# Print message
	print
		"<tr class='crw'>\n",
		"<td><a href='$shwUrl'><img $emptyPixel $imgAttr> $msg->{subject}</a></td>\n",
		"<td class='shr'>$userNameStr</td>\n",
		"<td class='shr'>$timeStr</td>\n",
		"<td class='shr'><a class='btl' href='$delUrl'>$lng->{mslDelete}</a></td>\n",
		"</tr>\n";
}

# If inbox is empty, display notification
print "<tr class='crw'><td colspan='4'>$lng->{mslNotFound}</td></tr>\n" if !@$msgsIn;

# Print outbox table header
print
	"</table>\n\n",
	"<table class='tbl'>\n",
	"<tr class='hrw'>\n",
	"<th>$lng->{mslOutbox}</th>\n",
	"<th class='shr'>$lng->{mslTo}</th>\n",
	"<th class='shr'>$lng->{mslDate}</th>\n",
	"<th class='shr'>$lng->{mslCommands}</th>\n",
	"</tr>\n";

# Print messages in outbox
for my $msg (@$msgsSent) {
	# Determine variable message icon attributes
	my $imgName; 
	my $imgTitle = "";
	my $imgAlt = "";
	if ($msg->{new}) { 
		$imgName = "post_nr"; $imgTitle = $lng->{comNewReadTT}; $imgAlt = $lng->{comNewRead};
	}
	else { 
		$imgName = "post_or"; $imgTitle = $lng->{comOldReadTT}; $imgAlt = $lng->{comOldRead};
	}
	my $imgAttr = "class='sic sic_$imgName' title='$imgTitle' alt='$imgAlt'";

	# Format output
	my $infUrl = $m->url('user_info', uid => $msg->{receiverId});
	my $shwUrl = $m->url('message_show', mid => $msg->{id});
	my $delUrl = $m->url('user_confirm', mid => $msg->{id}, script => 'message_delete',
		name => $msg->{subject}, ori => 1);
	my $timeStr = $m->formatTime($msg->{sendTime}, $user->{timezone});
	my $userNameStr = "<a href='$infUrl'>$msg->{userName}</a>";

	# Print message
	print
		"<tr class='crw'>\n",
		"<td><a href='$shwUrl'><img $emptyPixel $imgAttr> $msg->{subject}</a></td>\n",
		"<td class='shr'>$userNameStr</td>\n",
		"<td class='shr'>$timeStr</td>\n",
		"<td class='shr'><a class='btl' href='$delUrl'>$lng->{mslDelete}</a></td>\n",
		"</tr>\n";
}

# If outbox is empty, display notification
print "<tr class='crw'><td colspan='4'>$lng->{mslNotFound}</td></tr>\n" if !@$msgsSent;

print "</table>\n\n";

# Log action and finish
$m->logAction(2, 'msg', 'list', $userId);
$m->printFooter();
$m->finish();
