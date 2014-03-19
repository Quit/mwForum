#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2014 Markus Wichitill
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

# Get CGI parameters
my $auth = $m->paramStr('t');

# Unsubscribe
my $cs = 'BINARY';
if ($m->{pgsql}) { $cs = 'TEXT' }
elsif ($m->{sqlite}) { $cs = 'BLOB' }
my ($boardUserId, $boardId) = $m->fetchArray("
	SELECT userId, boardId FROM boardSubscriptions WHERE unsubAuth = CAST(? AS $cs)", $auth);
my ($topicUserId, $topicId) = $m->fetchArray("
	SELECT userId, topicId FROM topicSubscriptions WHERE unsubAuth = CAST(? AS $cs)", $auth);
if ($boardUserId) {
	$m->dbDo("
		DELETE FROM boardSubscriptions WHERE userId = ? AND unsubAuth = CAST(? AS $cs)",
		$boardUserId, $auth);
}
elsif ($topicUserId) {
	$m->dbDo("
		DELETE FROM topicSubscriptions WHERE userId = ? AND unsubAuth = CAST(? AS $cs)",
		$topicUserId, $auth);
}
else {
	$m->error('errUnsNotFnd');
}

# Log action and finish
$m->logAction(1, 'user', 'unsub', $boardUserId || $topicUserId, $boardId, $topicId);
$m->redirect('forum_show', msg => $boardUserId ? 'BrdUnsub' : 'TpcUnsub');
