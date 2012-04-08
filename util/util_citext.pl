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

# Change data type of VARCHAR/TEXT columns to citext in PgSQL databases.

use strict;
use warnings;
no warnings qw(uninitialized once);

# Imports
use Getopt::Std ();
require MwfMain;

# Get arguments
my %opts = ();
Getopt::Std::getopts('?hf:', \%opts);
my $help = $opts{'?'} || $opts{h};
my $forumId = $opts{f};
usage() if $help;

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId);

# Check if PgSQL
$cfg->{dbDriver} eq 'Pg' or $m->error("This script is for PgSQL only.");

# Get columns
my $tablesStr = join(", ", map("'".lc($_)."'", @MwfDefaults::tables, @MwfDefaults::arcTables));
my $columns = $m->fetchAllHash("
	SELECT table_name, column_name
	FROM information_schema.columns
	WHERE table_schema = :schema
		AND table_name IN ($tablesStr)
		AND (data_type = 'character varying' OR data_type = 'text')
	ORDER BY table_name",
	{ schema => $cfg->{dbSchema} || 'public' } );
	
# Change data type to citext
for my $col (@$columns) {
	print "ALTER TABLE $col->{table_name} ALTER $col->{column_name} TYPE citext\n";
	$m->dbDo("ALTER TABLE $col->{table_name} ALTER $col->{column_name} TYPE citext");
}

#------------------------------------------------------------------------------

sub usage
{
	print
		"\nChange data type of VARCHAR/TEXT columns to citext in PgSQL databases.\n\n",
		"Usage: util_citext.pl [-f forum]\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
	;
	
	exit 1;
}
