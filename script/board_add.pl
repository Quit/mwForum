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

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get first category id
my $firstCatId = $m->fetchArray("
	SELECT MIN(id) FROM categories");
$firstCatId 
	or $m->error("Can't create board without existing category. Create a category first.");

# Get position
my $pos = $m->fetchArray("
	SELECT MAX(pos) + 1 FROM boards WHERE categoryId = ?", $firstCatId);
$pos ||= 1;

# Insert new board
$m->dbDo("
	INSERT INTO boards (title, categoryId, pos, private) VALUES (?, ?, ?, ?)", 
	'New Board', $firstCatId, $pos, 1);
my $boardId = $m->dbInsertId("boards");

# Log action and finish
$m->logAction(1, 'board', 'add', $userId, $boardId);
$m->redirect('board_options', bid => $boardId);
