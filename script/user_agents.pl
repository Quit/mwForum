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
$cfg->{statUserAgent} || $user->{admin} or $m->error('errNoAccess');

# Get CGI parameters
my $days = $m->paramInt('days') || 30;

# Print header
$m->printHeader();

# Print page bar
my @userLinks = ();
push @userLinks, { url => $m->url('user_agents', days => 7), txt => 7 };
push @userLinks, { url => $m->url('user_agents', days => 30), txt => 30 };
push @userLinks, { url => $m->url('user_agents', days => 90), txt => 90 };
push @userLinks, { url => $m->url('user_agents', days => 365), txt => 365 };
my @navLinks = ({ url => $m->url('forum_info'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{uasTitle}, navLinks => \@navLinks, userLinks => \@userLinks);

# Order of UA printed
my @ua = (
	'Gecko', '- Firefox',
	'WebKit', '- Chrome', '- Safari', 
	'MSIE', '- Edge', '- MSIE 11', '- MSIE 10', '- MSIE 9', '- MSIE 8',
	'Other',
);

# Order of OS printed
my @os = (
	'Windows', '- Windows 10', '- Windows 8', '- Windows 7', '- Windows Vista', '- Windows XP',
	'Mac', 'Linux', 'Android', 'iOS', 'Windows Phone', 'Other',
);

# Collect browser stats of users
my $sth = $m->fetchSth("
	SELECT userAgent FROM users WHERE userAgent <> '' AND lastOnTime > ? - ? * 86400",
	$m->{now}, $days);
my $ua;
$sth->bind_col(1, \$ua);
my %os = (); 
my %ua = (); 
my $users = 0;
while ($sth->fetch()) {
	$users++;
	if (index($ua, 'Android') > -1) {
		$os{'Android'}++;
	}
	elsif (index($ua, 'iPhone') > -1 || index($ua, 'iPad') > -1 || index($ua, 'iPod') > -1) { 
		$os{'iOS'}++;
	}
	elsif (index($ua, 'Windows Phone') > -1) { 
		$os{'Windows Phone'}++;
	}
	elsif (index($ua, 'Windows') > -1) { 
		$os{'Windows'}++;
		if    (index($ua, 'Windows NT 10.') > -1) { $os{'- Windows 10'}++ }
		elsif (index($ua, 'Windows NT 6.3') > -1) { $os{'- Windows 8'}++ }
		elsif (index($ua, 'Windows NT 6.2') > -1) { $os{'- Windows 8'}++ }
		elsif (index($ua, 'Windows NT 6.1') > -1) { $os{'- Windows 7'}++ }
		elsif (index($ua, 'Windows NT 6.0') > -1) { $os{'- Windows Vista'}++ }
		elsif (index($ua, 'Windows NT 5.1') > -1) { $os{'- Windows XP'}++ }
	}
	elsif (index($ua, 'Linux') > -1) { $os{'Linux'}++ }
	elsif (index($ua, 'Mac') > -1)   { $os{'Mac'}++ }
	else { $os{'Other'}++ }

	if (index($ua, 'WebKit') > -1) { 
		$ua{'WebKit'}++;
		if (index($ua, 'Chrome') > -1) { 
			$ua{'- Chrome'}++;
		}
		elsif (index($ua, 'Safari') > -1) { 
			$ua{'- Safari'}++;
		}
	}
	elsif ($ua =~ /Edge\//) { 
		$ua{'MSIE'}++;
		$ua{'- Edge'}++;
	}
	elsif ($ua =~ /Trident\/(\d+)\.\d+/) { 
		$ua{'MSIE'}++;
		if    ($1 == 7) { $ua{'- MSIE 11'}++ }
		elsif ($1 == 6) { $ua{'- MSIE 10'}++ }
		elsif ($1 == 5) { $ua{'- MSIE 9'}++ }
	}
	elsif ($ua =~ /MSIE (\d+)\.\d+/) { 
		$ua{'MSIE'}++;
		if    ($1 == 8) { $ua{'- MSIE 8'}++ }
	}
	elsif ($ua =~ /(?<!like )Gecko/) { 
		$ua{'Gecko'}++;
		if ($ua =~ /Firefox\/(\d+\.\d+)/) {
			$ua{'- Firefox'}++;
		}
	}
	else { $ua{'Other'}++ }
}

# Print hint
$m->printHints([$m->formatStr($lng->{uasUsersT}, { users => $users, days => $days })]);

# Print pie charts
if ($users && $cfg->{uaChartType} ne 'none') {
	my @uaLabels = qw(MSIE Gecko WebKit Other);
	my @osLabels = qw(Windows Linux Mac Other);
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{uasChartTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<div class='pie'>\n";
		
	if ($cfg->{uaChartType} eq 'GD::Graph') {
		# GD::Graph: old-school, but good enough with supersampling
		my $chart = sub {
			my ($labels, $values) = @_;
			eval { require GD::Graph::pie } or $m->error("GD::Graph module not available.");
			require MIME::Base64;
			my ($w, $h, $f) = (200, 200, 4);
			my $graph = GD::Graph::pie->new($w * $f, $h * $f) or $m->error('Pie creation failed.');
			$graph->set('3d' => 0, suppress_angle => 2, start_angle => 270,
				dclrs => [ '#ff7f7f', '#7f7fff', '#7fff7f', '#ffe67f', '#7fe6ff' ]);
			$graph->set_value_font($cfg->{ttf}, 7 * $f) or $m->error('Font setting failed.');;
			my $img = $graph->plot([ $labels, $values ]) or $m->error('Pie drawing failed.');
			my $thb = GD::Image->new($w, $h, 1);
			$thb->saveAlpha(1);
			$thb->fill(0, 0, $thb->colorAllocateAlpha(255,255,255, 127));
			$thb->copyResampled($img, 0, 0, 0, 0, $w, $h, $w * $f, $w * $f);
			my $bin = $thb->png() or $m->error('Pie export failed.');
			my $size = length($bin);
			print 
				"<img src='data:image/png;base64,", MIME::Base64::encode_base64($bin, ''), 
				"' style='margin: 10px' title='$size' alt='$lng->{errUAFeatSup}'>\n";
		};
		$chart->(\@uaLabels, [ map(($ua{$_} / $users) * 100, @uaLabels) ]);
		$chart->(\@osLabels, [ map(($os{$_} / $users) * 100, @osLabels) ]);
	}
	elsif ($cfg->{uaChartType} eq 'Imager::Graph') {
		# Imager::Graph: prettier, but uncommon module requirements 
		my $chart = sub {
			my ($labels, $values) = @_;
			eval { require Imager::Graph::Pie } or $m->error("Imager::Graph module not available.");
			require MIME::Base64;
			my $graph = Imager::Graph::Pie->new() or $m->error('Pie creation failed.');
			my $font = Imager::Font->new(file => $cfg->{ttf});
			my $img = $graph->draw(labels => $labels, data => $values, font => $font, 
				text => { size => 9 }, back => "FFFFFF00", channels => 4, width => 350, height => 200,
				features => [ 'labelspc', 'allcallouts' ])
				or $m->error('Pie drawing failed: ' . $graph->error());
			my $bin = undef;
			$img->write(data => \$bin, type => 'png') or $m->error('Pie export failed.');
			my $size = length($bin);
			print 
				"<img src='data:image/png;base64,", MIME::Base64::encode_base64($bin, ''), 
				"' title='$size' alt='$lng->{errUAFeatSup}'>\n";
		};
		$chart->(\@uaLabels, [ map(($ua{$_} / $users) * 100, @uaLabels) ]);
		$chart->(\@osLabels, [ map(($os{$_} / $users) * 100, @osLabels) ]);
	}
	elsif ($cfg->{uaChartType} eq 'GoogleVis' || !$cfg->{uaChartType}) {
		# Google Charts/Visualization API: SVG/VML generated by JS from Google's servers
		my $chart = sub {
			my ($labels, $values, $id) = @_;
			my $json = "[" . join(",", map("[\"$_\"," . ($values->{$_} || 0) . "]", @$labels)) . "]";
			print "<span id='${id}Pie' data-array='$json' style='display: inline-block'></span>\n",
		};
		$chart->(\@uaLabels, \%ua, 'ua');
		$chart->(\@osLabels, \%os, 'os');
		print 
			"<script src='//www.google.com/jsapi?autoload={\"modules\":[{\"name\":\"visualization\",",
			"\"version\":\"1\",\"packages\":[\"corechart\"]}]}'></script>\n",
			"<script src='$cfg->{dataPath}/google.js'></script>\n";
	}

	print "</div>\n</div>\n</div>\n\n",
}

# Print stats tables
print
	"<table class='tbl'>\n",
	"<tr class='hrw'><th colspan='2'>$lng->{uasUaTtl}</th></tr>\n";
for my $k (@ua) {
	next if !$ua{$k};
	my $pc = sprintf("%.1f%%", ($ua{$k} / $users) * 100);
	print "<tr class='crw'><td class='hco'>$k</td><td>$pc ($ua{$k})</td></tr>\n";
}
print
	"</table>\n\n",
	"<table class='tbl'>\n",
	"<tr class='hrw'><th colspan='2'>$lng->{uasOsTtl}</th></tr>\n";
for my $k (@os) {
	next if !$os{$k};
	my $pc = sprintf("%.1f%%", ($os{$k} / $users) * 100);
	print "<tr class='crw'><td class='hco'>$k</td><td>$pc ($os{$k})</td></tr>\n";
}

print
	"</table>\n\n";

# Log action and finish
$m->logAction(3, 'user', 'agents', $userId);
$m->printFooter();
$m->finish();
