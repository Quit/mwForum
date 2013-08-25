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

# Get CGI parameters
my $repUserId = $m->paramInt('uid');
my $postId = $m->paramInt('pid');
$postId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get post
my ($boardId, $topicId) = $m->fetchArray("	
	SELECT boardId, topicId FROM posts WHERE id = ?", $postId);
$boardId or $m->error('errPstNotFnd');

# Check if user is admin or moderator
$user->{admin} || $m->boardAdmin($userId, $boardId) or $m->error('errNoAccess');

# Delete report
$m->dbDo("
	DELETE FROM postReports WHERE userId = ? AND postId = ?", $repUserId, $postId);

# Log action and finish
$m->logAction(1, 'report', 'delete', $userId, $boardId, $topicId, $postId);
$m->redirect('report_list', msg => 'PstRemRep');
