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

# Mass-delete users (and their dependencies) matching a partial SQL query.

use strict;
use warnings;
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
require MwfMain;

# Get arguments
my %opts = ();
Getopt::Std::getopts('?hxf:', \%opts);
my $help = $opts{'?'} || $opts{h};
my $execute = $opts{x};
my $forumId = $opts{f};
my $sql = $ARGV[0];
usage() if $help || !length($sql);

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId);

# Delete users
$m->dbBegin();
my $users = $m->fetchAllArray("
	SELECT id FROM users WHERE $sql");
my $sum = 0;
for my $user (@$users) {
	$m->deleteUser($user->[0]) if $execute;
	$sum++;
}
$m->dbCommit();

# Print sum of occurrences
my $verb = $execute ? "Deleted" : "Found";
print "$verb $sum users\n";

#------------------------------------------------------------------------------

sub usage
{
	print
		"\nMass-delete users. Argument is a partial SQL query that defines affected users.\n\n",
		"Usage: util_deleteusers.pl [-x] [-f forum] \"email = '' AND lastOnTime < 1199142000\"\n",
		"  -x   Execute deletions. Otherwise, only number of affected users is printed.\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
	;
	
	exit 1;
}
