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
$cfg->{statUserCntry} || $user->{admin} or $m->error('errNoAccess');

# Get CGI parameters
my $days = $m->paramInt('days') || 365;

# Print header
$m->printHeader();

# Print page bar
my @userLinks = ();
push @userLinks, { url => $m->url('user_countries', days => 7), txt => 7 };
push @userLinks, { url => $m->url('user_countries', days => 30), txt => 30 };
push @userLinks, { url => $m->url('user_countries', days => 90), txt => 90 };
push @userLinks, { url => $m->url('user_countries', days => 365), txt => 365 };
my @navLinks = ({ url => $m->url('forum_info'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{ucoTitle}, navLinks => \@navLinks, userLinks => \@userLinks);

# Create GeoIP object
my $geoIp = undef;
if (eval { require Geo::IP }) {
	$geoIp = Geo::IP->open($cfg->{geoIp},
		defined($cfg->{geoIpCacheMode}) ? $cfg->{geoIpCacheMode} : 1);
}
elsif (eval { require Geo::IP::PurePerl }) {
	$geoIp = Geo::IP::PurePerl->open($cfg->{geoIp});
}
else {
	$m->error("Geo::IP or Geo::IP::PurePerl modules not available.");
}
$geoIp or $m->error("Opening GeoIP file failed.");

# Get country stats
my $sth = $m->fetchSth("
	SELECT lastIp FROM users WHERE lastIp <> '' AND lastOnTime > ? - ? * 86400",
	$m->{now}, $days);
my $ip;
$sth->bind_col(1, \$ip);
my %countries = ();
my $users = 0;
my $city = index($cfg->{geoIp}, 'City') > -1 ? 1 : 0;
while ($sth->fetch()) {
	$users++;
	my ($code, $name);
	if ($city) {
		if (my $rec = $geoIp->record_by_addr($ip)) {
			$code = $rec->country_code();
			$name = $rec->country_name();
		}
	}
	else {
		$code = $geoIp->country_code_by_addr($ip);
		$name = $geoIp->country_name_by_addr($ip);
	}
	next if $code !~ /^[A-Z]{2}\z/;
	if ($countries{$code}) { $countries{$code}[1]++ }
	else { $countries{$code} = [ $name, 1 ] }
}
my @codes = sort keys %countries;
my $json = "[" . join(",", map("[\"$_\",$countries{$_}[1]]", @codes)) . "]";

# Print hint
$m->printHints([$m->formatStr($lng->{uasUsersT}, { users => $users, days => $days })]);

# Print map
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{ucoMapTtl}</span></div>\n",
	"<div class='ccl'>\n",
	"<div id='map' data-array='$json'>\n",
	"<script src='//www.google.com/jsapi?autoload={\"modules\":[{\"name\":\"visualization\",",
	"\"version\":\"1\",\"packages\":[\"geochart\"]}]}'></script>\n",
	"<script src='$cfg->{dataPath}/google.js'></script>\n",
	"</div>\n",
	"</div>\n",
	"</div>\n\n";

# Print table
print
	"<table class='tbl'>\n",
	"<tr class='hrw'><th colspan='2'>$lng->{ucoCntryTtl}</th></tr>\n";
for my $code (sort { $countries{$b}[1] <=> $countries{$a}[1] } @codes) {
	print 
		"<tr class='crw'><td class='hco'>",
		"$countries{$code}[0]</td><td>$countries{$code}[1]</td></tr>\n";
}
print "</table>\n\n";

# Log action and finish
$m->logAction(3, 'user', 'country', $userId);
$m->printFooter();
$m->finish();
