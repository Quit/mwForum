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

# Remove obsolete and default configuration entries from the config table.

use strict;
use warnings;
no warnings qw(uninitialized once);

# Imports
use Getopt::Std ();
require MwfMain;

# Get arguments
my %opts = ();
Getopt::Std::getopts('?hxf:', \%opts);
my $help = $opts{'?'} || $opts{h};
my $execute = $opts{x};
my $forumId = $opts{f};
usage() if $help;

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId);
$m->dbBegin();

# Dry run?
print "\n-x not specified, performing dry run.\n\n" if !$execute;

# Get default options
my %defOptions;
for my $opt (@$MwfDefaults::options) {
	$defOptions{$opt->{name}} = $opt->{default} if $opt->{name};
}
if (eval { $MwfDefaultsLocal::options }) {
	for my $opt (@$MwfDefaultsLocal::options) {
		$defOptions{$opt->{name}} = $opt->{default} if $opt->{name};
	}
}

# Get database options
my %dbOptions;
my $dbOptions = $m->fetchAllHash("
	SELECT name, value, parse FROM config");
for my $opt (@$dbOptions) {
	$dbOptions{$opt->{name}} = $opt->{value} if $opt->{name};
}

for my $name (sort keys %dbOptions) {
	next if $name eq 'lastUpdate';
	
	# Delete obsolete/experimental options that are not in MwfDefaults.pm	
	if (!exists $defOptions{$name}) {
		print "Deleting $name (not in defaults)\n";
		$m->dbDo("
			DELETE FROM config WHERE name = ?", $name) 
			if $opts{x};
		next;
	}
	
	# Delete option if equal to default value
	if (deep_eq($cfg->{$name}, $defOptions{$name})) {
		print "Deleting $name (same as default)\n";
		$m->dbDo("
			DELETE FROM config WHERE name = ?", $name) 
			if $opts{x};
	}
}

$m->dbCommit();

#------------------------------------------------------------------------------

# deep_eq() from http://www.perlmonks.org/index.pl?node_id=121559
sub deep_eq {
	my ($a, $b) = @_;
	if (not defined $a)        { return not defined $b }
	elsif (not defined $b)     { return 0 }
	elsif (not ref $a)         { $a eq $b }
	elsif ($a eq $b)           { return 1 }
	elsif (ref $a ne ref $b)   { return 0 }
	elsif (ref $a eq 'SCALAR') { $$a eq $$b }
	elsif (ref $a eq 'ARRAY')  {
		if (@$a == @$b) {
			for (0 .. $#$a) {
				my $rval;
				return $rval unless ($rval = deep_eq($a->[$_], $b->[$_]));
			}
			return 1;
		}
		else { return 0 }
	}
	elsif (ref $a eq 'HASH') {
		if (keys %$a == keys %$b) {
			for (keys %$a) {
				my $rval;
				return $rval unless ($rval = deep_eq($a->{$_}, $b->{$_}));
			}
			return 1;
		}
		else { return 0 }
	}
	elsif (ref $a eq ref $b)   { warn 'Cannot test '.(ref $a)."\n"; undef }
	else                       { return 0 }
}

#------------------------------------------------------------------------------

sub usage
{
	print
		"\nRemove obsolete and default configuration entries from the config table.\n\n",
		"Usage: util_cleancfg.pl [-x] [-f forum]\n",
		"  -x   Execute cleanup. Otherwise only a dry run is performed.\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
	;
	
	exit 1;
}
