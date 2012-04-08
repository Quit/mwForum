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

# Get CGI parameters
my $topicId = $m->paramInt('tid');
my $action = $m->paramStrId('act');
$topicId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get board id
my $boardId = $m->fetchArray("
	SELECT boardId FROM topics WHERE id = ?", $topicId);
$boardId or $m->error('errTpcNotFnd');

# Check if user is admin or moderator
$user->{admin} || $m->boardAdmin($userId, $boardId) or $m->error('errNoAccess');

# Lock or unlock
my $sticky = $action eq "stick" ? 1 : 0;

# Update
$m->dbDo("
	UPDATE topics SET sticky = ? WHERE id = ?", $sticky, $topicId);

# Log action and finish
$m->logAction(1, 'topic', $sticky ? 'stick' : 'unstick', $userId, $boardId, $topicId);
$m->redirect('topic_show', tid => $topicId, msg => $sticky ? 'TpcStik' : 'TpcUnstik');
