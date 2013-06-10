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
$cfg->{messages} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $action = $m->paramStrId('act');
my $msgId = $m->paramInt('mid');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

if ($action eq 'delAllRead') {
	# Delete all read messages
	$m->dbDo("
		UPDATE messages SET inbox = 0 WHERE receiverId = ? AND hasRead > 0", $userId);
	$m->dbDo("
		UPDATE messages SET sentbox = 0 WHERE senderId = ?", $userId);
	$m->dbDo("
		DELETE FROM messages WHERE inbox = 0 AND sentbox = 0");

	# Log action and finish
	$m->logAction(1, 'msg', 'delallrd', $userId, 0, 0, 0, $msgId);
	$m->redirect('message_list', msg => 'MsgDel');
}
else {
	$msgId or $m->error('errParamMiss');

	# Get message
	my $msg = $m->fetchHash("
		SELECT senderId, receiverId, inbox, sentbox FROM messages WHERE id = ?", $msgId);
	$msg or $m->error('errMsgNotFnd');
	my $received = $msg->{receiverId} == $userId;
	my $sent = $msg->{senderId} == $userId;
	
	# Check if user can see message
	$received && $msg->{inbox} || $sent && $msg->{sentbox} or $m->error('errNoAccess');

	# Delete or remove from box	
	if (($received && $sent)
		|| ($received && $msg->{inbox} && !$msg->{sentbox})
		|| ($sent && $msg->{sentbox} && !$msg->{inbox})) {
		# Delete message
		$m->dbDo("
			DELETE FROM messages WHERE id = ?", $msgId);
	}
	elsif ($received && $msg->{inbox} && $msg->{sentbox}) {
		# Remove from inbox
		$m->dbDo("
			UPDATE messages SET inbox = 0 WHERE id = ?", $msgId);
	}
	elsif ($sent && $msg->{sentbox} && $msg->{inbox}) {
		# Remove from sentbox
		$m->dbDo("
			UPDATE messages SET sentbox = 0 WHERE id = ?", $msgId);
	}
	else {
		$m->error('errMsgNotFnd');
	}
		
	# Log action and finish
	$m->logAction(1, 'msg', 'delete', $userId, 0, 0, 0, $msgId);
	$m->redirect('message_list', msg => 'MsgDel');
}
