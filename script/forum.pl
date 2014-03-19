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
my $boardId = $m->paramInt('bid');

# Update user's previous online time
if ($userId) {
	my $prevOnCookie = int($m->getCookie('prevon') || 0);
	my $prevOnTime = $m->max($prevOnCookie, $user->{lastOnTime}) || $m->{now};
	$m->{userUpdates}{prevOnTime} = $prevOnTime;
	$m->setCookie('prevon', $prevOnTime);
}

# Log action and finish
$m->logAction(2, 'forum', 'enter', $userId);
if ($boardId) { $m->redirect('board_show', bid => $boardId) }
else { $m->redirect('forum_show') }
