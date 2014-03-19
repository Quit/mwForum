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

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Get CGI parameters
my $boardId = $m->paramInt('bid');
$boardId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Delete admin groups
$m->dbDo("
	DELETE FROM boardAdminGroups WHERE boardId = ?", $boardId);

# Delete member groups
$m->dbDo("
	DELETE FROM boardMemberGroups WHERE boardId = ?", $boardId);

# Delete subscriptions
$m->dbDo("
	DELETE FROM boardSubscriptions WHERE boardId = ?", $boardId);

# Delete hidden-flags
$m->dbDo("
	DELETE FROM boardHiddenFlags WHERE boardId = ?", $boardId);

# Delete topics
my $topics = $m->fetchAllArray("
	SELECT id FROM topics WHERE boardId = ?", $boardId);
$m->deleteTopic($_->[0]) for @$topics;

# Delete board
$m->dbDo("
	DELETE FROM boards WHERE id = ?", $boardId);

# Log action and finish
$m->logAction(1, 'board', 'delete', $userId, $boardId);
$m->redirect('board_admin');
