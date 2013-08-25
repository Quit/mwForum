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

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Insert new group
$m->dbDo("
	INSERT INTO groups (title) VALUES (?)", 
	"New Group");
my $groupId = $m->dbInsertId("groups");

# Log action and finish
$m->logAction(1, 'group', 'add', $userId, 0, 0, 0, $groupId);
$m->redirect('group_options', gid => $groupId);
