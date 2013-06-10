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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0], ajax => 1);

# Print header
$m->printHttpHeader();

# Get CGI parameters
my $name = $m->paramStr('q');
#my $limit = $m->min($m->paramInt('limit') || 10, 10);

# Return empty in case of errors
$userId or $m->finish();
length($name) >= 2 or $m->finish();

# Fetch names
my $like = $m->{pgsql} ? 'ILIKE' : 'LIKE';
my $nameLike = $m->dbEscLike($name) . "%";
my $names = $m->fetchAllArray("
	SELECT userName 
	FROM users 
	WHERE userName $like ?
	ORDER BY userName",
	$nameLike);

# Print names
print $_->[0], "\n" for @$names;

# Log action and commit
$m->logAction(3, 'ajax', 'unames', $userId);
$m->finish();
