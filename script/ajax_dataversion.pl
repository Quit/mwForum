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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0], ajax => 1);

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Check if feature is enabled
$cfg->{dataVersion} or $m->error("Feature is disabled.");

# Increase data version
my $dataVersion = $cfg->{dataVersion} + 1;
$m->dbDo("
	UPDATE config SET value = ? WHERE name = ?", $dataVersion, 'dataVersion');
$m->dbDo("
	UPDATE config SET value = ? WHERE name = ?", $m->{now}, 'lastUpdate');

# Answer in JSON	
$m->printHttpHeader();
print $m->json({ dataVersion => $dataVersion });
	
# Log action and commit
$m->logAction(1, 'ajax', 'dataver', $userId);
$m->finish();
