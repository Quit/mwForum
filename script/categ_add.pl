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

# Get position
my $pos = $m->fetchArray("
	SELECT MAX(pos) + 1 FROM categories");
$pos ||= 1;

# Insert new category
$m->dbDo("
	INSERT INTO categories (title, pos) VALUES (?, ?)",
	'New Category', $pos);
my $categId = $m->dbInsertId("categories");

# Log action and finish
$m->logAction(1, 'categ', 'add', $userId, 0, 0, 0, $categId);
$m->redirect('categ_options', cid => $categId);
