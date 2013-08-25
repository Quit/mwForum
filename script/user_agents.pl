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
	'Gecko', 'Firefox', 
	'MSIE', 'MSIE 10.0', 'MSIE 9.0', 'MSIE 8.0', 'MSIE 7.0', 'MSIE 6.0',
	'WebKit', 'Chrome', 'Safari', 
	'Other',
);

# Order of OS printed
my @os = (
	'Windows', 'Windows 8', 'Windows 7', 'Windows Vista', 'Windows XP',
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
		if    (index($ua, 'Windows NT 6.2') > -1) { $os{'Windows 8'}++ }
		elsif (index($ua, 'Windows NT 6.1') > -1) { $os{'Windows 7'}++ }
		elsif (index($ua, 'Windows NT 6.0') > -1) { $os{'Windows Vista'}++ }
		elsif (index($ua, 'Windows NT 5.1') > -1) { $os{'Windows XP'}++ }
	}
	elsif (index($ua, 'Linux') > -1) { $os{'Linux'}++ }
	elsif (index($ua, 'Mac') > -1)   { $os{'Mac'}++ }
	else { $os{'Other'}++ }

	if (index($ua, 'WebKit') > -1) { 
		$ua{'WebKit'}++;
		if (index($ua, 'Chrome') > -1) { 
			$ua{'Chrome'}++;
		}
		elsif (index($ua, 'Safari') > -1) { 
			$ua{'Safari'}++;
		}
	}
	elsif ($ua =~ /(?<!like )Gecko/) { 
		$ua{'Gecko'}++;
		if ($ua =~ /Firefox\/(\d+\.\d+)/) {
			$ua{'Firefox'}++;
		}
	}
	elsif ($ua =~ /MSIE (\d+)\.\d+/) { 
		$ua{'MSIE'}++;
		if    ($1 == 10) { $ua{'MSIE 10.0'}++ }
		elsif ($1 == 9)  { $ua{'MSIE 9.0'}++ }
		elsif ($1 == 8)  { $ua{'MSIE 8.0'}++ }
		elsif ($1 == 7)  { $ua{'MSIE 7.0'}++ }
		elsif ($1 == 6)  { $ua{'MSIE 6.0'}++ }
	}
	else { $ua{'Other'}++ }
}

# Print hint
$m->printHints([$m->formatStr($lng->{uasUsersT}, { users => $users, days => $days })]);

# Print pie charts
if ($users && $cfg->{uaChartType} ne 'none') {
	my @uaLabels = qw(MSIE Gecko WebKit Other);
	my @osLabels = qw(Windows Linux Mac Other);
	my $printChart = undef;
	my $clientSide = 0;
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{uasChartTtl}</span></div>\n",
		"<div class='ccl'>\n";
	if ($cfg->{uaChartType} eq 'GD::Graph') {
		# GD::Graph: old-school, but good enough with supersampling
		$printChart = sub {
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
	}
	elsif ($cfg->{uaChartType} eq 'Imager::Graph') {
		# Imager::Graph: nice 
		$printChart = sub {
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
	}
	elsif ($cfg->{uaChartType} eq 'GoogleChart' || !$cfg->{uaChartType}) {
		# Google Chart API: nice, no modules, no incompat, but images from Google servers
		$printChart = sub {
			my ($labels, $values) = @_;
			$labels = join("|", @$labels);
			$values = "t:" . join(",", map(int($_ + .5), @$values));
			my $url = "//chart.googleapis.com/chart?";
			my %params = (chs => "350x150", cht => "p3", chf => "bg,s,00000000", 
				chl => $labels, chd => $values);
			for my $key (keys %params) {
				my $value = $params{$key};
				$value =~ s/([^A-Za-z_0-9.!~()|,-])/'%'.unpack("H2",$1)/eg;
				$url .= "$key=$value&amp;";
			}
			print "<img src='$url' width='350' height='150' alt=''>\n";
		};
	}
	elsif ($cfg->{uaChartType} eq 'GoogleVis') {
		# Google Visualizaton API: SVG/VML generated by JS
		# Using deprecated 'piechart' package because 'corechart' lacks features
		$clientSide = 1;
		my $uaLabels = "'" . join("','", @uaLabels) . "'";
		my $osLabels = "'" . join("','", @osLabels) . "'";
		my $uaValues = join(",", map($ua{$_} || 0, @uaLabels));
		my $osValues = join(",", map($os{$_} || 0, @osLabels));
		print <<"EOHTML";
			<span id='uaPie' style='display: inline-block; margin-top: 10px'></span>
			<span id='osPie' style='display: inline-block; margin-top: 10px'></span>
			<script src='//www.google.com/jsapi'></script>
			<script>
			google.load('visualization', '1', { packages: ['piechart'] });
			\$(window).load(function () {
				function printChart(id, labels, values) {
					var i,
						data = new google.visualization.DataTable(),
						chart = new google.visualization.PieChart(\$('#' + id + 'Pie')[0]);
					data.addColumn('string');
					data.addColumn('number');
					for (i = 0; i < labels.length; i++) { data.addRow([ labels[i], values[i] ]); }
					chart.draw(data, { width: 450, height: 250, is3D: true, legend: 'label' });
				}
				printChart('ua', [$uaLabels], [$uaValues]);
				printChart('os', [$osLabels], [$osValues]);
			});
			</script>
EOHTML
	}
	if (!$clientSide) {
		print "<div class='pie'>\n";
		my @values = map(($ua{$_} / $users) * 100, @uaLabels);
		$printChart->(\@uaLabels, \@values);
		@values = map(($os{$_} / $users) * 100, @osLabels);
		$printChart->(\@osLabels, \@values);
		print "</div>\n\n";
	}
	print "</div>\n</div>\n\n";
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
