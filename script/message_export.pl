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

# Check if access should be denied
$cfg->{messages} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Get messages
my $messages = $m->fetchAllHash("
	SELECT messages.*, 
		senders.userName AS senderName,
		receivers.userName AS receiverName
	FROM messages AS messages
		INNER JOIN users AS senders
			ON senders.id = messages.senderId
		INNER JOIN users AS receivers
			ON receivers.id = messages.receiverId
	WHERE (messages.senderId = :userId AND messages.sentbox = 1)
		OR (messages.receiverId = :userId AND messages.inbox = 1)
	ORDER BY messages.sendTime DESC", 
	{ userId => $userId });

# Print header
$m->printHttpHeader({ 'content-disposition' => "attachment; filename=Messages.html" });
my $fontFaceStr = $user->{fontFace} ? "font-family: '$user->{fontFace}', sans-serif;" : "";
my $fontSizeStr = $user->{fontSize} ? "font-size: $user->{fontSize}px;" : "";
print
	"<!DOCTYPE html>\n",
	"<html>\n",
	"<head>\n",
	"<title>$lng->{mslTitle}</title>\n",
	"<meta http-equiv='content-type' content='text/html; charset=utf-8'>\n",
	"<style type='text/css'>\n",
	"  body { $fontFaceStr $fontSizeStr }\n",
	"  h1 { margin: 1em 0 0 0; border-top: 1px solid black; padding: 1em 0 0 0; $fontFaceStr $fontSizeStr }\n",
	"  table { margin: 1em 0; padding: 0; border-collapse: collapse; }\n",
	"  th, td { margin: 0; padding: 0 1em 0 0; text-align: left; }\n",
	"  blockquote {	margin: 0; color: gray; }\n",
	"  blockquote p { margin: 0; }\n",
  "</style>\n",
	"</head>\n",
	"<body>\n\n";

# Print messages
for my $msg (@$messages) {
	# Print message
	my $subject = $msg->{subject};
	$subject =~ s!Re: !!;
	my $time = $m->formatTime($msg->{sendTime}, $user->{timezone});
	my $timeIso = $m->formatTime($msg->{sendTime}, 0, "%Y-%m-%dT%TZ");
	print
		"<article>\n",
		"<header>\n",
		"<h1>$subject</h1>\n",
		"<table>\n",
		"<tr><th>$lng->{mssFrom}</th><td>$msg->{senderName}</td></tr>\n",
		"<tr><th>$lng->{mssTo}</th><td>$msg->{receiverName}</td></tr>\n",
		"<tr><th>$lng->{mssDate}</th><td><time pubdate datetime='$timeIso'>$time</time></td></tr>\n",
		"</table>\n",
		"</header>\n",
		"<div>\n$msg->{body}\n</div>\n",
		"</article>\n\n";
}

print
	"</body>\n",
	"</html>\n";

# Log action and finish
$m->logAction(2, 'msg', 'export', $userId);
$m->finish();
