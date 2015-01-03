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

# This script migrates databases between MySQL, PgSQL and SQLite.
#
# Create the destination database, set up MwfConfig.pm for it, and call
# install.pl to create its schema.
#
# Call this script with DBI connection strings for the source and
# destination database, incl. user and password, e.g.:
#
# util_migratedb.pl
#   "dbi:mysql:dbname=mwforum;user=x;password=x"
#   "dbi:Pg:dbname=mwforum;user=x;password=x"

use strict;
use warnings;

# Imports
use Getopt::Std ();
use DBI ();

# Get arguments
my %opts = ();
Getopt::Std::getopts('t', \%opts);
my $truncate = $opts{t};
@ARGV == 2 or die "Not enough parameters.";
my $srcDsn = $ARGV[0];
my $dstDsn = $ARGV[1];

# Init
my $startTime = time();

# Connect databases
my $srcDbh = DBI->connect($srcDsn, undef, undef, { RaiseError => 1 });
my $dstDbh = DBI->connect($dstDsn, undef, undef, { RaiseError => 1 });
my $srcDriver = lc($srcDbh->{Driver}{Name});
my $dstDriver = lc($dstDbh->{Driver}{Name});

# Set client encoding
$srcDbh->do("SET NAMES 'utf8'") if $srcDriver eq 'mysql' || $srcDriver eq 'pg';
$dstDbh->do("SET NAMES 'utf8'") if $dstDriver eq 'mysql' || $dstDriver eq 'pg';

# Parse schema
open my $fh, "install.pl" or die "Opening install.pl failed";
my @schema = ();
my @serials = ();
while (my $line = <$fh>) {
	if (my ($name) = $line =~ /^CREATE TABLE (\w+)/) {
		my $table = [ $name ];
		while ($line = <$fh>) {
			last if $line =~ /^\)/;
			my ($col) = $line =~ /^\t(\w+)/;
			push @$table, $col if $col ne 'PRIMARY';
			push @serials, $name if $line =~ /AUTO_INCREMENT/;
		}
		push @schema, $table;
		if ($dstDriver ne 'sqlite' && $name =~ /^(?:boards|topics|posts)\z/) {
			my $arcTable = [ @$table ];
			$arcTable->[0] = "arc_$arcTable->[0]";
			push @schema, $arcTable;
		}
	}
}

# Handle entries in destination db
if ($truncate) {
	# Truncate tables
	for my $table (@schema) {
		my $name = $table->[0];
		print "Truncating table $name...\n";
		if ($dstDriver eq 'mysql') { $dstDbh->do("TRUNCATE $name") }
		elsif ($dstDriver eq 'pg') { $dstDbh->do("TRUNCATE $name RESTART IDENTITY CASCADE") }
		elsif ($dstDriver eq 'sqlite') { $dstDbh->do("DELETE FROM $name") }
	}
}
else {
	# Delete version entry
	$dstDbh->do("DELETE FROM variables WHERE name = 'version'");
}

# Copy tables
$srcDbh->begin_work();
$dstDbh->begin_work();
for my $table (@schema) {
	my $name = $table->[0];
	print "Copying table $name...\n";
	my $fields = join(",", @$table[1 .. @$table - 1]);
	#print "  $fields\n";
	my $order = $table->[1] eq 'id' ? "ORDER BY id" : "";
	my $selSth = $srcDbh->prepare("SELECT $fields FROM $name $order");
	$selSth->execute();
	my $placeholders = $fields;
	$placeholders =~ s!\w+!?!g;
	my $insSth = $dstDbh->prepare("INSERT INTO $name ($fields) VALUES ($placeholders)");
	while (my $row = $selSth->fetchrow_arrayref()) {
		$insSth->execute(@$row);
	}
}

# Set sequences
if ($dstDriver eq 'pg') {
	print "Setting sequences...\n";
	for my $serial (@serials) {
		$dstDbh->do("SELECT SETVAL('${serial}_id_seq', MAX(id)) FROM $serial");
	}
}

# Commit and vacuum
print "Committing...\n";
$srcDbh->commit();
$dstDbh->commit();
print "Optimizing...\n";
if ($dstDriver eq 'mysql') {
	for my $table (@schema) {
		$dstDbh->do("OPTIMIZE TABLE $table->[0]");
	}
}
elsif ($dstDriver eq 'pg') {
	for my $table (@schema) {
		$dstDbh->do("VACUUM FULL ANALYZE $table->[0]");
	}
}
elsif ($dstDriver eq 'sqlite') {
	$dstDbh->do("VACUUM");
	$dstDbh->do("ANALYZE");
}

print "Finished in " . (time() - $startTime) . "s.\n";
