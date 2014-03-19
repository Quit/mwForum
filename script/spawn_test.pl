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
no warnings qw(uninitialized once);

# Imports
use Getopt::Std ();
use MwfMain;

#------------------------------------------------------------------------------

# Get arguments
my %opts = ();
Getopt::Std::getopts('sf:', \%opts);
my $spawned = $opts{s};
my $forumId = $opts{f};

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId, spawned => $spawned, upgrade => 1);
my $output = "";
$| = 1;
output("mwForum long-running script test running...\n");

# Simulate work
output("Pretending to do work that takes 20 minutes...\n");
for (1 .. 20) {
	output("Sleeping $_...\n");
	sleep 60;
}

# Still alive?
output("Nice, the script wasn't interrupted.\n");
output("mwForum long-running script test done.\n");

# Log action
$m->dbDo("
	INSERT INTO log (level, entity, action, logTime, string) VALUES (1, ?, ?, ?)", 
	'spawn', 'test', $m->{now});

#------------------------------------------------------------------------------
# Print and collect output

sub output
{
	my $text = shift();

	print $text;
	$output .= $text;
	$m->dbDo("
		DELETE FROM variables WHERE name = ?", 'upgOutput');
	$m->dbDo("
		INSERT INTO variables (name, value) VALUES (?, ?)", 'upgOutput', $output);
}
