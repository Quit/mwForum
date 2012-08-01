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
$cfg->{chat} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $parentId = $m->paramInt('pid');
my $body = $m->paramStr('body');

# Fake board
my $board = { flat => 1 };

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Check body length
length($body) or $m->error('errBdyEmpty');
length($body) <= $cfg->{chatMaxLength} or $m->error('errBdyLen');

# Process text
my $chat = { isChat => 1, body => $body };
$m->editToDb({}, $chat);

# Any text left after filtering?
length($chat->{body}) or $m->error('errBdyEmpty');

# Insert chat message
$m->dbDo("
	INSERT INTO chat (userId, postTime, body) VALUES (?, ?, ?)",
	$userId, $m->{now}, $chat->{body});
my $chatId = $m->dbInsertId("chat");

# Expire old messages
$m->dbDo("
	DELETE FROM chat WHERE postTime < ? - ? * 86400", $m->{now}, $cfg->{chatMaxAge})
	if $cfg->{chatMaxAge};

# Log action and finish
$m->logAction(1, 'chat', 'add', $userId, 0, 0, 0, $chatId);
$m->redirect('chat_show', msg => 'ChatAdd');
