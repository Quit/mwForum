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

# Create moderator and member groups from board member and moderator entries.
# Must be used before upgrading to 2.17.1, or the entries are gone.

use strict;
use warnings;
no warnings qw(uninitialized);

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
$m->dbBegin();
$| = 1;

# Get boards
my $boards = $m->fetchAllHash("
	SELECT id, title FROM boards");
		
for my $board (@$boards) {
	# Create group for moderators
	my $boardAdmins = $m->fetchAllArray("
		SELECT userId FROM boardAdmins WHERE boardId = ?", $board->{id});
	if ($boardAdmins) {
		my $title = "\"$board->{title}\" Moderators";
		$m->dbDo("
			INSERT INTO groups (title, public) VALUES (?, ?)", $title, 1);
		my $groupId = $m->dbInsertId('groups');
		$m->dbDo("
			INSERT INTO groupMembers (userId, groupId) VALUES (?, ?)", $_->[0], $groupId)
			for @$boardAdmins;
		print "Created moderator group for board \"$board->{title}\"\n";
	}

	# Create group for members
	my $boardMembers = $m->fetchAllArray("
		SELECT userId FROM boardMembers WHERE boardId = $board->{id}");
	if ($boardAdmins) {
		my $title = "\"$board->{title}\" Members";
		$m->dbDo("
			INSERT INTO groups (title, public) VALUES (?, ?)", $title, 1);
		my $groupId = $m->dbInsertId('groups');
		$m->dbDo("
			INSERT INTO groupMembers (userId, groupId) VALUES (?, ?)", $_->[0], $groupId)
			for @$boardMembers;
		print "Created member group for board \"$board->{title}\"\n";
	}
}

# Commit transaction
$m->dbCommit();

#------------------------------------------------------------------------------

sub usage
{
	print
		"\nCreate moderator and member groups from board member and moderator entries.\n\n",
		"Usage: util_migratexs.pl [-f forum]\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
	;
	
	exit 1;
}
