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

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Get CGI parameters
my $groupId = $m->paramInt('gid');
$groupId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Delete user badges
$m->dbDo("
	DELETE FROM userBadges 
	WHERE badge = (SELECT badge FROM groups WHERE id = ?)", $groupId);

# Delete board moderator permissions
$m->dbDo("
	DELETE FROM boardAdminGroups WHERE groupId = ?", $groupId);

# Delete board member permissions
$m->dbDo("
	DELETE FROM boardMemberGroups WHERE groupId = ?", $groupId);

# Delete group admins
$m->dbDo("
	DELETE FROM groupAdmins WHERE groupId = ?", $groupId);

# Delete group memberships
$m->dbDo("
	DELETE FROM groupMembers WHERE groupId = ?", $groupId);

# Delete group
$m->dbDo("
	DELETE FROM groups WHERE id = ?", $groupId);

# Log action and finish
$m->logAction(1, 'group', 'delete', $userId, 0, 0, 0, $groupId);
$m->redirect('group_admin');
