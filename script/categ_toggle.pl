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

# Check if access should be denied
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $action = $m->paramStrId('act');
my $categId = $m->paramInt('cid');
$categId or $m->error('errParamMiss');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

if ($action eq 'hide') {
	# Hide all non-hidden boards of category
	$m->dbDo("
		INSERT INTO boardHiddenFlags (userId, boardId)
		SELECT :userId, id 
		FROM boards AS boards
			LEFT JOIN boardHiddenFlags AS bhf
				ON bhf.userId = :userId
				AND bhf.boardId = boards.id
		WHERE boards.categoryId = :categId
			AND bhf.userId IS NULL",
		{ userId => $userId, categId => $categId });

	# Log action and finish
	$m->logAction(1, 'categ', 'hide', $userId, 0, 0, 0, $categId);
	$m->redirect('forum_show');
}
elsif ($action eq 'show') {
	# Show all boards of category, except manually hidden ones
	$m->dbDo("
		DELETE FROM boardHiddenFlags 
		WHERE userId = ?
			AND boardId IN (SELECT id FROM boards WHERE categoryId = ?)
			AND manual = 0", 
		$userId, $categId);

	# Log action and finish
	$m->logAction(1, 'categ', 'show', $userId, 0, 0, 0, $categId);
	$m->redirect('forum_show');
}
