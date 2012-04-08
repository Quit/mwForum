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

# Change the charset declaration of text columns in MySQL DBs so that 
# conversion to UTF-8 doesn't result in garbage during 2.15.0 upgrade,
# if the charset declared so far is not correct.
# See http://dev.mysql.com/doc/refman/4.1/en/charset-charsets.html for names of
# charsets in MySQL format.

use strict;
use warnings;
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
require MwfMain;

#------------------------------------------------------------------------------

# Get arguments
my %opts = ();
Getopt::Std::getopts('?hf:c:', \%opts);
my $help = $opts{'?'} || $opts{h};
my $forumId = $opts{f};
my $charset = $opts{c};
usage() if $help;
$charset or usage();

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId);

open my $fh, "install.pl" or $m->error("Opening install.pl failed");
while (<$fh>) {
	if (my ($table) = /^CREATE TABLE (\w+)/) {
		while (<$fh>) {
			last if /^\)/;
			my ($col, $type) = /^\t(\w+)\s+((?:TEXT|VARCHAR\([0-9]+\)) NOT NULL DEFAULT '')/;
			if ($type =~ /^(?:TEXT|VARCHAR)/) {
				my $blob = $type;
				$blob =~ s!VARCHAR!VARBINARY!;
				$blob =~ s!TEXT!BLOB!;
				$type =~ s!(VARCHAR\([0-9]+\)|TEXT)!$1 CHARSET $charset!;
				print "ALTER TABLE $table CHANGE $col $col $blob;\n";
				print "ALTER TABLE $table CHANGE $col $col $type;\n";
				$m->dbDo("ALTER TABLE $cfg->{dbPrefix}$table CHANGE $col $col $blob");
				$m->dbDo("ALTER TABLE $cfg->{dbPrefix}$table CHANGE $col $col $type");
			}
		}
		print "ALTER TABLE $table CHARSET $charset;\n";
		$m->dbDo("ALTER TABLE $cfg->{dbPrefix}$table CHARSET $charset");
	}
}

#------------------------------------------------------------------------------

sub usage
{
	print
		"\nFix character set declarations in MySQL databases.\n\n",
		"Usage: util_fixcharset.pl [-f forum] -c charset\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
		"  -c   Name of the correct charset in MySQL format (e.g. koi8r).\n",
	;
	
	exit 1;
}
