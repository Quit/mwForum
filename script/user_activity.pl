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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0]);

# Check if access should be denied
(!$cfg->{userInfoReg} || $userId) && ($cfg->{statForumActiv} || $user->{admin})
	or $m->error('errNoAccess');

# Get CGI parameters
my $infUserId = $m->paramInt('uid');

# Get user
my $infUser = $m->getUser($infUserId);
$infUser or $m->error('errUsrNotFnd');
my $userTitle = $infUser->{title} ? $m->formatUserTitle($infUser->{title}) : "";

# Get statistics
my $query = "";
my $yearStats = undef;
if ($m->{mysql}) {
	$m->dbDo("
		CREATE TEMPORARY TABLE times AS
			SELECT FROM_UNIXTIME(postTime) AS ts 
			FROM posts 
			WHERE userId = ?
		UNION ALL
			SELECT FROM_UNIXTIME(postTime) AS ts 
			FROM arc_posts 
			WHERE userId = ?", 
			$infUserId, $infUserId);
	$m->dbDo("
		CREATE TEMPORARY TABLE postsPerDay AS
		SELECT YEAR(ts) AS year, DAYOFYEAR(ts) - 1 AS doy, COUNT(*) AS num
		FROM times
		GROUP BY year, doy");
	$yearStats = $m->fetchAllArray("
		SELECT YEAR(ts) AS year, COUNT(*) AS num
		FROM times
		GROUP BY year
		ORDER BY year");
}
elsif ($m->{pgsql}) {
	$m->dbDo("
		CREATE TEMPORARY TABLE times AS
			SELECT TIMESTAMP 'epoch' + INTERVAL '1 second' * postTime AS ts 
			FROM posts 
			WHERE userId = ?
		UNION ALL
			SELECT TIMESTAMP 'epoch' + INTERVAL '1 second' * postTime AS ts 
			FROM arc_posts 
			WHERE userId = ?", 
			$infUserId, $infUserId);
	$m->dbDo("
		CREATE TEMPORARY TABLE postsPerDay AS
		SELECT EXTRACT(YEAR FROM ts) AS year, EXTRACT(DOY FROM ts) - 1 AS doy, COUNT(*) AS num
		FROM times
		GROUP BY year, doy");
	$yearStats = $m->fetchAllArray("
		SELECT EXTRACT(YEAR FROM ts) AS year, COUNT(*) AS num
		FROM times
		GROUP BY year
		ORDER BY year");
}
my $ppdStats = $m->fetchAllArray("
	SELECT * FROM postsPerDay");
my $ppdMaxPerDay = $m->fetchArray("
	SELECT MAX(num) FROM postsPerDay");
my $firstYear = $m->fetchArray("
	SELECT MIN(year) FROM postsPerDay");
my $lastYear = $m->fetchArray("
	SELECT MAX(year) FROM postsPerDay");

# Print header
$m->printHeader(undef, { firstYear => $firstYear, lastYear => $lastYear });

# Print page bar
my @userLinks = ();
my @navLinks = ({ url => $m->url('user_info', uid => $infUserId), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{uacTitle}, subTitle => "$infUser->{userName} $userTitle",
	navLinks => \@navLinks, userLinks => \@userLinks);

# Print hint
$m->printHints([$lng->{uacPstDayT}]);

# Print posts-per-day data, canvas and script
my $fac = 3;
my $ppdJson = "{" . join(",", map("\"$_->[0].$_->[1]\":" 
	. $m->min($_->[2] * $fac, 150), @$ppdStats)) . "}";
my $ppdWidth = ($lastYear - $firstYear + 1) * 365;
my $ppdHeight = $m->min($m->max($ppdMaxPerDay * $fac, 30), 300);
print
	"<div id='postsPerDay' style='display: none'>$ppdJson</div>\n\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{actPstDayTtl}</span></div>\n",
	"<div class='ccl' style='overflow: auto'>\n",
	"<canvas width='$ppdWidth' height='$ppdHeight'>$lng->{errUAFeatSup}</canvas>\n",
	"</div>\n",
	"</div>\n\n";

# Print table
print 
	"<table class='tbl'>\n",
	"<tr class='hrw'><th colspan='2'>$lng->{actPstYrTtl}</th></tr>\n",
	map("<tr class='crw'><td class='hco'>$_->[0]</td><td>$_->[1]</td></tr>\n", @$yearStats),
	"</table>\n\n";

# Drop temp tables
$m->dbDo("DROP TABLE times");
$m->dbDo("DROP TABLE postsPerDay");

# Log action and finish
$m->logAction(3, 'user', 'activity', $userId, 0, 0, 0, $infUserId);
$m->printFooter();
$m->finish();
