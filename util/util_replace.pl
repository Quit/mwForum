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

# Search and replace text in mwForum database fields.

use strict;
use warnings;
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
require MwfMain;

# Get arguments
my %opts = ();
Getopt::Std::getopts('?hxiquf:t:c:', \%opts);
my $help = $opts{'?'} || $opts{h};
my $execute = $opts{x};
my $caseIns = $opts{i};
my $quiet = $opts{q};
my $mysqlUseResult = $opts{u};
my $forumId = $opts{f};
my $table = $opts{t} || 'posts';
my $col = $opts{c} || 'body';
my $txt1 = $ARGV[0];
my $txt2 = $ARGV[1];
usage() if $help || !length($txt1);

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId);
$m->{dbh}{mysql_use_result} = 1 if $mysqlUseResult;

# Decode UTF-8 or treat as Latin1
utf8::decode($txt1) or utf8::upgrade($txt1);
utf8::decode($txt2) or utf8::upgrade($txt2);

# Search and replace
$m->dbBegin();
my $sum = 0;
my $switch = $caseIns ? "(?i)" : "";
my $updSth = $m->dbPrepare("
	UPDATE $table SET $col = ? WHERE id = ?");
my $selSth = $m->fetchSth("
	SELECT id, $col FROM $table");
my ($id, $body);
$selSth->bind_columns(\($id, $body));
while ($selSth->fetch()) {
	utf8::decode($body);
	my $num = $body =~ s!$switch$txt1!$txt2!go;
	$sum += $num;
	if ($execute && $num) {
		# Replace
		$m->dbExecute($updSth, $body, $id);
		print "Replaced $num occurrences in #$id\n" if !$quiet;
	}
	else {
		# Print occurrences only
		print "Found $num occurrences in #$id\n" if !$quiet && $num;
	}
}
$m->dbCommit();

# Print sum of occurrences
my $verb = $execute ? "Replaced" : "Found";
print "$verb $sum occurrences\n";

#------------------------------------------------------------------------------

sub usage
{
	print
		"\nSearch and replace in database fields.\n\n",
		"Usage: util_replace.pl [-xiq] [-f forum] [-t table] [-c column] [--] searchExp [replaceExp]\n",
		"  -x   Execute replacements. Otherwise, only number of occurrences is printed.\n",
		"  -i   Search-expression is case-insensitive.\n",
		"  -q   Quiet, print summary only.\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
		"  -t   Table name, default: posts.\n",
		"  -c   Column name, default: body.\n",
		"\nNotes:\n",
		"  - searchExp is a regular expression.\n",
		"  - replaceExp cannot use backreferences.\n",
		"  - Can only be used on tables with an 'id' field.\n",
		"  - Non-ASCII characters may not work if not passed as UTF-8 or Latin1.\n",
	;
	
	exit 1;
}
