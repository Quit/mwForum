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
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new(@_);

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Check if admin is among admins that may edit configuration
$cfg->{cfgAdmins} =~ /\b$userId\b/ or $m->error('errNoAccess') if $cfg->{cfgAdmins};

# Print header
$m->printHeader();

# Get CGI parameters
my $more = $m->paramBool('more');
my $terseSize = $m->paramBool('size');

# Print page bar
my @userLinks = ();
push @userLinks, { url => $m->url('forum_details', more => 1), txt => "More", ico => 'info' }
	if !$more;
my @navLinks = ({ url => $m->url('forum_info'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{fifTitle}, navLinks => \@navLinks, userLinks => \@userLinks);

# Shortcuts
my $dbh = $m->{dbh};
my $env = $m->{env};

# Database info
my ($mysqlVersion, $mysqlFork, $mysqlUser, $mysqlDatabase, $mysqlEngine,
	$mysqlTableStatus, $mysqlVariables, $mysqlStatistics,
	$pgsqlVersion, $pgsqlLocale, $pgsqlEncoding, $pgsqlSrchPath, $pgsqlVariables,
	$sqliteJournalMode);
my $schemaVersion = $m->getVar('version');
if ($m->{mysql}) {
	($mysqlVersion, $mysqlUser, $mysqlDatabase) = $m->fetchArray("
		SELECT VERSION(), USER(), DATABASE()");
	$mysqlFork = $mysqlVersion =~ /MariaDB/ ? "MariaDB" : "MySQL";
	if ($more) {
		$mysqlTableStatus = "\n<table class='tiv'>\n<tr>"
			. "<th>Name</th><th>Engine</th><th>Format</th><th>Rows</th><th>DataLen</th>"
			. "<th>IndexLen</th><th>AutoInc</th><th>Collation</th><th>Options</th></tr>\n";
		my $tables = $m->fetchAllHash("SHOW TABLE STATUS LIKE '$cfg->{dbPrefix}'");
		for my $t (@$tables) {
			$mysqlEngine = $t->{Engine} if $t->{Name} eq "$cfg->{dbPrefix}posts";
			$mysqlTableStatus .= "<tr><td>$t->{Name}</td><td>$t->{Engine}</td><td>$t->{Row_format}</td>"
				. "<td>$t->{Rows}</td><td>$t->{Data_length}</td><td>$t->{Index_length}</td>"
				. "<td>$t->{Auto_increment}</td><td>$t->{Collation}</td><td>$t->{Create_options}</td>"
				. "</tr>\n";
		}
		$mysqlTableStatus .= "</table>\n";
		$mysqlVariables = "\n<table class='tiv'>\n";
		my $variables = $m->fetchAllArray("SHOW VARIABLES");
		for my $var (@$variables) {
			my $value = $var->[1];
			$value =~ s!,!, !g;
			my $valueEsc = $m->escHtml($value);
			$mysqlVariables .= "<tr><td>$var->[0]</td><td>$valueEsc</td></tr>\n";
		}
		$mysqlVariables .= "</table>\n";
		my $stats = $m->fetchAllArray("SHOW GLOBAL STATUS");
		$mysqlStatistics = "\n<table class='tiv'>\n"
			. join("", map("<tr><td>$_->[0]</td><td>$_->[1]</td></tr>\n", @$stats))
			. "</table>\n";
	}
}
elsif ($m->{pgsql}) {
	$pgsqlVersion = $m->fetchArray("SHOW server_version");
	$pgsqlSrchPath = $m->fetchArray("SHOW search_path");
	$pgsqlLocale = $m->fetchArray("SHOW lc_ctype");
	$pgsqlEncoding = lc($m->fetchArray("SHOW server_encoding"));
	$pgsqlEncoding .= " (warning: should be 'utf8'!)" if $pgsqlEncoding ne 'utf8';
	if ($more) {
		$pgsqlVariables = "\n<table class='tiv'>\n";
		my $variables = $m->fetchAllArray("SHOW ALL");
		for my $var (@$variables) {
			my $value = $var->[1];
			$value =~ s!,!, !g;
			my $valueEsc = $m->escHtml($value);
			$pgsqlVariables .= "<tr><td>$var->[0]</td><td>$valueEsc</td></tr>\n";
		}
		$pgsqlVariables .= "</table>\n";
	}
}
elsif ($m->{sqlite}) {
	$sqliteJournalMode = $m->fetchArray("PRAGMA journal_mode");
}

# Perl versions
my $perlVersion = $^V ? sprintf("%vd", $^V) : $];
($perlVersion) = $perlVersion =~ /([0-9]+\.[0-9]+\.[0-9]+)/;
my ($modperlVersion) = $ENV{MOD_PERL} =~ /([0-9]+\.[0-9]+\.?[0-9]*)/;

# Perl @INC
my $perlIncStr = join("", map("<div>$_</div>\n", @INC));

# Perl %INC
my $perlIncModStr = "<table class='tiv'>\n";
eval { require B::TerseSize } or $m->error("B::TerseSize module not available.") if $terseSize;
for my $key (sort keys %INC) {
	next if $key =~ /^\// || $key =~ /\.pl\z/;
	my $mod = $key;
	$mod =~ s!/!::!g;
	$mod =~ s!\.pm!!g;
	my $ver = eval "\$${mod}::VERSION";
	$perlIncModStr .= "<tr><td>$mod</td><td>$ver</td><td>$INC{$key}</td>";
	$perlIncModStr .= "<td>" . B::TerseSize::package_size($mod) . "</td>" if $terseSize;
	$perlIncModStr .= "</tr>\n";
}
$perlIncModStr .= "</table>\n";

# Perl %ENV
my $perlEnvStr = "";
for my $key (sort keys %ENV) { 
	my $value = $ENV{$key};
	$value =~ s/([;,])(?![\s\\])/$1 /g;
	my $valueEsc = $m->escHtml($value);
	$perlEnvStr .= "<div>$key = $valueEsc</div>\n";
}

# Working directory
require Cwd;
my $cwd = Cwd::getcwd();

# Apache subprocess environment
my $ap = $m->{ap};
my $apEnvStr = "";
my $apNotesStr = "";
my $apHeadersStr = "";
if ($MwfMain::MP) {
	my $subEnv = $ap->subprocess_env;
	for my $key (sort keys %$subEnv) { 
		my $valueEsc = $m->escHtml($subEnv->{$key});
		$apEnvStr .= "<div>$key = $valueEsc</div>\n";
	}

	# Apache notes table
	my $notes = $ap->notes;
	for my $key (sort keys %$notes) { 
		my $valueEsc = $m->escHtml($notes->{$key});
		$apNotesStr .= "<div>$key = $valueEsc</div>\n";
	}

	# Apache headers
	my $headers = $ap->headers_in;
	for my $key (sort keys %$headers) { 
		my $valueEsc = $m->escHtml($headers->{$key});
		$apHeadersStr .= "<div>$key = $valueEsc</div>\n";
	}
}

# mwForum $m->{env}
my $mwfEnvStr = "";
for my $key (sort keys %$env) {
	my $valueEsc = $m->escHtml($env->{$key});
	$mwfEnvStr .= "<div>$key = $valueEsc</div>\n";
}

# C env
my $cEnvStr = "";
if (eval { require Env::C }) {
	my $vars = Env::C::getallenv();
	for my $var (sort @$vars) { 
		my $valueEsc = $m->escHtml($var);
		$cEnvStr .= "<div>$var</div>\n";
	}
}

# System info
my $unameEsc = $m->escHtml(scalar qx(uname -a), 1);
chomp $unameEsc;
my $uptimeEsc = $m->escHtml(scalar qx(uptime), 1);
chomp $uptimeEsc;
my $freeEsc = $m->escHtml(scalar qx(free), 1);
chomp $freeEsc;
my $dfEsc = $m->escHtml(scalar qx(df), 1);
chomp $dfEsc;
my $psEsc = $more ? $m->escHtml(scalar qx(ps faxu), 1) : "";
chomp $psEsc;

print "<table class='tbl'>\n";

# Print MySQL info
print
	"<tr class='hrw'><th colspan='2'>MySQL</th></tr>\n",
	"<tr class='crw'><td class='hco'>Version</td><td>$mysqlVersion</td></tr>\n",
	"<tr class='crw'><td class='hco'>Host</td><td>$dbh->{mysql_hostinfo}</td></tr>\n",
	"<tr class='crw'><td class='hco'>User</td><td>$mysqlUser</td></tr>\n",
	"<tr class='crw'><td class='hco'>Database</td><td>$mysqlDatabase</td></tr>\n",
	"<tr class='crw'><td class='hco'>Prepared</td><td>$dbh->{mysql_server_prepare}</td></tr>\n",
	"<tr class='crw'><td class='hco'>Status</td><td>$dbh->{mysql_stat}</td></tr>\n",
	$more? "<tr class='crw'><td class='hco'>Tables</td><td>$mysqlTableStatus</td></tr>\n" : "",
	$more? "<tr class='crw'><td class='hco'>Variables</td><td>$mysqlVariables</td></tr>\n" : "",
	$more? "<tr class='crw'><td class='hco'>Statistics</td><td>$mysqlStatistics</td></tr>\n" : "",
	if $m->{mysql};

# Print PgSQL info
print
	"<tr class='hrw'><th colspan='2'>PostgreSQL</th></tr>\n",
	"<tr class='crw'><td class='hco'>Version</td><td>$pgsqlVersion</td></tr>\n",
	"<tr class='crw'><td class='hco'>Host</td><td>$dbh->{pg_host}</td></tr>\n",
	"<tr class='crw'><td class='hco'>User</td><td>$dbh->{pg_user}</td></tr>\n",
	"<tr class='crw'><td class='hco'>Database</td><td>$dbh->{pg_db}</td></tr>\n",
	"<tr class='crw'><td class='hco'>Search Path</td><td>$pgsqlSrchPath</td></tr>\n",
	"<tr class='crw'><td class='hco'>Locale</td><td>$pgsqlLocale</td></tr>\n",
	"<tr class='crw'><td class='hco'>Encoding</td><td>$pgsqlEncoding</td></tr>\n",
	"<tr class='crw'><td class='hco'>Prepared</td><td>$dbh->{pg_server_prepare}</td></tr>\n",
	$more? "<tr class='crw'><td class='hco'>Variables</td><td>$pgsqlVariables</td></tr>\n" : "",
	if $m->{pgsql};

# Print SQLite info
print
	"<tr class='hrw'><th colspan='2'>SQLite</th></tr>\n",
	"<tr class='crw'><td class='hco'>Version</td><td>$m->{dbh}{sqlite_version}</td></tr>\n",
	"<tr class='crw'><td class='hco'>Journal Mode</td><td>$sqliteJournalMode</td></tr>\n",
	if $m->{sqlite};

print
	"<tr class='crw'><td class='hco'>Schema Version</td><td>$schemaVersion</td></tr>\n",
	"</table>\n\n";

# Print Perl info
print
	"<table class='tbl'>\n",
	"<tr class='hrw'><th colspan='2'>Perl</th></tr>\n",
	"<tr class='crw'><td class='hco'>Version</td><td>$perlVersion</td></tr>\n",
	"<tr class='crw'><td class='hco'>mod_perl</td><td>$modperlVersion</td></tr>\n",
	"<tr class='crw'><td class='hco'>cwd</td><td>$cwd</td></tr>\n",
	"<tr class='crw'><td class='hco'>\$^X</td><td>$^X</td></tr>\n",
	"<tr class='crw'><td class='hco'>\@INC</td><td>\n$perlIncStr</td></tr>\n",
	$more ? "<tr class='crw'><td class='hco'>\%INC</td><td>$perlIncModStr</td></tr>\n" : "",
	"<tr class='crw'><td class='hco'>\%ENV</td><td>\n$perlEnvStr</td></tr>\n",
	"</table>\n\n";

# Print Apache info
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Apache Environment</span></div>\n",
	"<div class='ccl'>\n$apEnvStr</div>\n",
	"</div>\n\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Apache Notes</span></div>\n",
	"<div class='ccl'>\n$apNotesStr</div>\n",
	"</div>\n\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Apache Headers</span></div>\n",
	"<div class='ccl'>\n$apHeadersStr</div>\n",
	"</div>\n\n"
	if $MwfMain::MP;

# Print mwForum env
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>mwForum Environment</span></div>\n",
	"<div class='ccl'>\n$mwfEnvStr</div>\n",
	"</div>\n\n";

# Print C env
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>C Environment</span></div>\n",
	"<div class='ccl'>\n$cEnvStr</div>\n",
	"</div>\n\n"
	if $cEnvStr && $more;

# Print system info
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>System Info</span></div>\n",
	"<div class='ccl'><pre>\n",
	$unameEsc ? "<samp>$unameEsc</samp><br>\n" : "",
	$uptimeEsc ? "<samp>$uptimeEsc</samp><br>\n" : "",
	$freeEsc ? "<samp>$freeEsc</samp><br>\n" : "",
	$dfEsc ? "<samp>$dfEsc</samp>\n" : "",
	"</pre></div>\n",
	"</div>\n\n"
	if $unameEsc || $uptimeEsc || $freeEsc || $dfEsc;

# Print process tree
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Process Tree</span></div>\n",
	"<div class='ccl'><pre>\n",
	"<samp>$psEsc</samp>\n",
	"</pre></div>\n",
	"</div>\n\n"
	if $psEsc;

# Log action and finish
$m->logAction(3, 'forum', 'details', $userId);
$m->printFooter();
$m->finish();
