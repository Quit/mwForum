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
my $action = $m->paramStrId('act');

if ($action eq 'cookie') {
	# Get and delete checking cookie
	my $ok = $m->getCookie('check') ? 1 : 0;
	$m->deleteCookie('check');

	# Answer in JSON
	print $m->json({ ok => $ok });

	# Log action and commit
	$m->logAction(3, 'ajax', 'ckcookie');
	$m->finish();
}
elsif ($action eq 'userName') {
	# Check username for validity
	my $userName = $m->paramStr('name');
	my $errStr = "";
	if (length($userName) == 0) {
		$errStr = $lng->{errNamEmpty};
	}
	elsif (length($userName) < 2 || length($userName) > $cfg->{maxUserNameLen}) {
		$errStr = $lng->{errNamSize};
	}
	elsif ($userName =~ /\s{2,}/ || $userName =~ /https?:/ || $userName !~ /$cfg->{userNameRegExp}/) {
		$errStr = $lng->{errNamChar};
	}
	elsif (grep(index(lc($userName), lc($_)) > -1, @{$cfg->{reservedNames}})) {
		$errStr = $lng->{errNamResrvd};
	}
	elsif ($m->fetchArray("SELECT id FROM users WHERE userName = ?", $userName)) {
		$errStr = $lng->{errNamGone};
	}

	# Answer in JSON
	chop($errStr) if substr($errStr, -1) eq ".";
	print $errStr ? $m->json({ error => $errStr }) : $m->json({ ok => 1 });

	# Log action and commit
	$m->logAction(3, 'ajax', 'ckname', $userId, 0, 0, 0, 0, $m->escHtml($userName));
	$m->finish();
}
