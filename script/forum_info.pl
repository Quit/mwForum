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

use strict;
use warnings;
no warnings qw(uninitialized redefine);

# Imports
use MwfMain;

#------------------------------------------------------------------------------

# Init
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new(@_);

# Shortcuts
my $dbh = $m->{dbh};
my $env = $m->{env};

# Print header
$m->printHeader();

# Get CGI parameters
my $details = $m->paramBool('details');
my $terseSize = $m->paramBool('size');

# Print page bar
my @userLinks = ();
push @userLinks, { url => $m->url('forum_info', details => 1), txt => "Details", ico => 'info' }
	if !$details && $user->{admin};
push @userLinks, { url => $m->url('user_agents'), txt => 'fifBrowsers', ico => 'poll' }
	if !$details && ($cfg->{statUserAgent} || $user->{admin});
push @userLinks, { url => $m->url('user_countries'), txt => 'fifCountries', ico => 'poll' }
	if !$details && ($cfg->{statUserCntry} || $user->{admin}) && $cfg->{geoIp};
push @userLinks, { url => $m->url('forum_activity'), txt => 'fifActivity', ico => 'poll' }
	if !$details && ($cfg->{statForumActiv} || $user->{admin}) && !$m->{sqlite};
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{fifTitle}, navLinks => \@navLinks, userLinks => \@userLinks);

if (!$details) {
	# Print public info
	my $email = $cfg->{adminEmail};
	$email = "<a href='mailto:$cfg->{adminEmail}'>$cfg->{adminEmail}</a>" if $email =~ /\@/;
	my $admins = $m->fetchAllArray("
		SELECT id, userName FROM users WHERE admin = 1 ORDER BY userName");
	my $adminStr = join(", ", 
		map("<a href='" . $m->url('user_info', uid => $_->[0]) . "'>$_->[1]</a>", @$admins));
	my $languages = "";
	for my $lang (sort keys %{$cfg->{languages}}) {
		my $module = $cfg->{languages}{$lang};
		$module =~ /^Mwf/ or next;
		if ($module =~ /^Mwf[A-Za-z_0-9]+\z/ && eval { require "$module.pm" }) {
			my $author = eval "\$${module}::lng->{author}";
			my $version = eval "\$${module}::VERSION";
			$languages .= "<div>$lang ($version), $author</div>";
		}
	}
	
	print
		"<table class='tbl'>\n",
		"<tr class='hrw'><th colspan='2'>$lng->{fifGenTtl}</th></tr>\n",
		"<tr class='crw'><td class='hco'>$lng->{fifGenAdmEml}</td><td>$email</td></tr>\n",
		"<tr class='crw'><td class='hco'>$lng->{fifGenAdmins}</td><td>$adminStr</td></tr>\n",
		"<tr class='crw'><td class='hco'>$lng->{fifGenVer}</td><td>$MwfMain::VERSION</td></tr>\n",
		"<tr class='crw'><td class='hco'>$lng->{fifGenLang}</td><td>$languages</td></tr>\n",
		"</table>\n\n";

	# Print public statistics
	my $userNum = $m->fetchArray("
		SELECT COUNT(*) FROM users");
	my $topicNum = $m->fetchArray("
		SELECT COUNT(*) FROM topics");
	my $postNum = $m->fetchArray("
		SELECT COUNT(*) FROM posts");
	print
		"<table class='tbl'>\n",
		"<tr class='hrw'><th colspan='2'>$lng->{fifStsTtl}</th></tr>\n",
		"<tr class='crw'><td class='hco'>$lng->{fifStsUsrNum}</td><td>$userNum</td></tr>\n",
		"<tr class='crw'><td class='hco'>$lng->{fifStsTpcNum}</td><td>$topicNum</td></tr>\n",
		"<tr class='crw'><td class='hco'>$lng->{fifStsPstNum}</td><td>$postNum</td></tr>\n";
	
	# Print admin statistics
	if ($user->{admin}) {
		my $pollNum = $m->fetchArray("
			SELECT COUNT(*) FROM polls");
		my $voteNum = $m->fetchArray("
			SELECT COUNT(*) FROM pollVotes");
		my $badgeNum = $m->fetchArray("
			SELECT COUNT(*) FROM userBadges");
		my $banNum = $m->fetchArray("
			SELECT COUNT(*) FROM userBans");
		my $sessionNum = $m->fetchArray("
			SELECT COUNT(*) FROM sessions");
		my $logNum = $m->fetchArray("
			SELECT COUNT(*) FROM log");
		my $ticketNum = $m->fetchArray("
			SELECT COUNT(*) FROM tickets");
		my $ticketUserNum = $m->fetchArray("
			SELECT COUNT(DISTINCT userId) FROM tickets");
		my $noteNum = $m->fetchArray("
			SELECT COUNT(*) FROM notes");
		my $noteUserNum = $m->fetchArray("
			SELECT COUNT(DISTINCT userId) FROM notes");
		my $msgNum = $m->fetchArray("
			SELECT COUNT(*) FROM messages");
		my $msgSenderNum = $m->fetchArray("
			SELECT COUNT(DISTINCT senderId) FROM messages");
		my $msgRecvNum = $m->fetchArray("
			SELECT COUNT(DISTINCT receiverId) FROM messages");
		my $attachNum = $m->fetchArray("
			SELECT COUNT(*) FROM attachments");
		my $attachPostNum = $m->fetchArray("
			SELECT COUNT(DISTINCT postId) FROM attachments");
		my $attachImgNum = $m->fetchArray("
			SELECT COUNT(*) FROM attachments WHERE webImage > 0");
		my $boardSubsNum = $m->fetchArray("
			SELECT COUNT(*) FROM boardSubscriptions");
		my $boardSubsUserNum = $m->fetchArray("
			SELECT COUNT(DISTINCT userId) FROM boardSubscriptions");
		my $boardSubsBoardNum = $m->fetchArray("
			SELECT COUNT(DISTINCT boardId) FROM boardSubscriptions");
		my $topicSubsNum = $m->fetchArray("
			SELECT COUNT(*) FROM topicSubscriptions");
		my $topicSubsUserNum = $m->fetchArray("
			SELECT COUNT(DISTINCT userId) FROM topicSubscriptions");
		my $topicSubsTopicNum = $m->fetchArray("
			SELECT COUNT(DISTINCT topicId) FROM topicSubscriptions");
		my $hiddenNum = $m->fetchArray("
			SELECT COUNT(*) FROM boardHiddenFlags");
		my $hiddenUserNum = $m->fetchArray("
			SELECT COUNT(DISTINCT userId) FROM boardHiddenFlags");
		my $hiddenBoardNum = $m->fetchArray("
			SELECT COUNT(DISTINCT boardId) FROM boardHiddenFlags");
		my $reportNum = $m->fetchArray("
			SELECT COUNT(*) FROM postReports");
		my $reportUserNum = $m->fetchArray("
			SELECT COUNT(DISTINCT userId) FROM postReports");
		my $reportPostNum = $m->fetchArray("
			SELECT COUNT(DISTINCT postId) FROM postReports");
		my $ignoreNum = $m->fetchArray("
			SELECT COUNT(*) FROM userIgnores");
		my $ignoreIgnorerNum = $m->fetchArray("
			SELECT COUNT(DISTINCT userId) FROM userIgnores");
		my $ignoreIgnoredNum = $m->fetchArray("
			SELECT COUNT(DISTINCT ignoredId) FROM userIgnores");
		my $watchUserNum = $m->fetchArray("
			SELECT COUNT(*) FROM watchUsers");
		my $watchUserWatcherNum = $m->fetchArray("
			SELECT COUNT(DISTINCT userId) FROM watchUsers");
		my $watchUserWatchedNum = $m->fetchArray("
			SELECT COUNT(DISTINCT watchedId) FROM watchUsers");
		my $watchWordNum = $m->fetchArray("
			SELECT COUNT(*) FROM watchWords");
		my $watchWordWatcherNum = $m->fetchArray("
			SELECT COUNT(DISTINCT userId) FROM watchWords");
		my $watchWordWordNum = $m->fetchArray("
			SELECT COUNT(DISTINCT word) FROM watchWords");
		my $watchWordSelfNum = $m->fetchArray("
			SELECT COUNT(*) 
			FROM watchWords AS watchWords
				INNER JOIN users AS users
					ON users.id = watchWords.userId
					AND users.userName = watchWords.word");
		my $cronTime = $m->formatTime($m->getVar('crnJobLst'), $user->{timezone});
		my $cronDuration = $m->getVar('crnJobDur') || 0;
		
		print
			"<tr class='crw'><td class='hco'>Polls</td><td>$pollNum</td></tr>\n",
			"<tr class='crw'><td class='hco'>Poll Votes</td><td>$voteNum</td></tr>\n",
			"<tr class='crw'><td class='hco'>User Badges</td><td>$badgeNum</td></tr>\n",
			"<tr class='crw'><td class='hco'>Banned Users</td><td>$banNum</td></tr>\n",
			"<tr class='crw'><td class='hco'>Login Sessions</td><td>$sessionNum</td></tr>\n",
			"<tr class='crw'><td class='hco'>Log Entries</td><td>$logNum</td></tr>\n",
			"<tr class='crw'><td class='hco'>Messages</td>\n",
			"<td>$msgNum messages from $msgSenderNum senders to $msgRecvNum recipients</td></tr>\n",
			"<tr class='crw'><td class='hco'>Board Subscriptions</td>\n",
			"<td>$boardSubsNum subscriptions by $boardSubsUserNum users of $boardSubsBoardNum boards</td></tr>\n",
			"<tr class='crw'><td class='hco'>Topic Subscriptions</td>\n",
			"<td>$topicSubsNum subscriptions by $topicSubsUserNum users of $topicSubsTopicNum topics</td></tr>\n",
			"<tr class='crw'><td class='hco'>Hidden Boards</td>\n",
			"<td>$hiddenNum entries by $hiddenUserNum users for $hiddenBoardNum boards</td></tr>\n",
			"<tr class='crw'><td class='hco'>Attachments</td>\n",
			"<td>$attachNum files incl. $attachImgNum web images in $attachPostNum posts</td></tr>\n",
			"<tr class='crw'><td class='hco'>Post Reports</td>\n",
			"<td>$reportNum reports by $reportUserNum users about $reportPostNum posts</td></tr>\n",
			"<tr class='crw'><td class='hco'>Tickets</td>\n",
			"<td>$ticketNum tickets for $ticketUserNum users</td></tr>\n",
			"<tr class='crw'><td class='hco'>Notifications</td>\n",
			"<td>$noteNum notifications for $noteUserNum users</td></tr>\n",
			"<tr class='crw'><td class='hco'>Ignored Users</td>\n",
			"<td>$ignoreNum entries by $ignoreIgnorerNum ignorants for $ignoreIgnoredNum trolls</td></tr>\n",
			"<tr class='crw'><td class='hco'>Watched Users</td>\n",
			"<td>$watchUserNum entries by $watchUserWatcherNum stalkers for", 
			" $watchUserWatchedNum celebs</td></tr>\n",
			"<tr class='crw'><td class='hco'>Watched Words</td>\n",
			"<td>$watchWordNum entries by $watchWordWatcherNum watchers for $watchWordWordNum words,",
			" incl. $watchWordSelfNum that look for their own name</td></tr>\n",
			"<tr class='crw'><td class='hco'>Cronjob</td>\n",
			"<td>Last executed: $cronTime, time taken: ${cronDuration}s</td></tr>\n";
	}
	
	print "</table>\n\n";

	# Print policy text
	if ($cfg->{policy}) {
		my $policyTitleEsc = $m->escHtml($cfg->{policyTitle});
		my $policyEsc = $m->escHtml($cfg->{policy}, 2);
		print
			"<div class='frm'>\n",
			"<div class='hcl'><span class='htt'>$policyTitleEsc</span></div>\n",
			"<div class='ccl'>\n",
			$policyEsc,
			"</div>\n",
			"</div>\n\n";
	}
}

# Collect values for admin info and mini banners
my $perlVersion = $^V ? sprintf("%vd", $^V) : $];
($perlVersion) = $perlVersion =~ /([0-9]+\.[0-9]+\.[0-9]+)/;
my ($modperlVersion) = $ENV{MOD_PERL} =~ /([0-9]+\.[0-9]+\.?[0-9]*)/;
my ($webserverVersion) = $m->{env}{server} =~ /([0-9]+\.[0-9]+\.[0-9]+)/;
my ($mysqlEngine, $mysqlVersion, $mysqlUser, $mysqlDatabase, $mysqlCollation);
my ($pgsqlVersion, $pgsqlLocale, $pgsqlEncoding, $pgsqlSrchPath);
my ($sqliteJournalMode);
my $schemaVersion = $m->getVar('version');
if ($m->{mysql}) {
	my $stat = $m->fetchHash("
		SHOW TABLE STATUS LIKE '$cfg->{dbPrefix}posts'");
	($mysqlVersion, $mysqlUser, $mysqlDatabase) = $m->fetchArray("
		SELECT VERSION(), USER(), DATABASE()");
	($mysqlVersion) = $mysqlVersion =~ /([0-9]+\.[0-9]+\.[0-9]+)/;
	$mysqlEngine = $stat->{Engine};
	$mysqlCollation = $stat->{Collation};
	$mysqlCollation .= " (warning: should be 'utf8_xxx'!)" if $mysqlCollation !~ /^utf8/;
}
elsif ($m->{pgsql}) {
	$pgsqlVersion = $m->fetchArray("SHOW server_version");
	$pgsqlSrchPath = $m->fetchArray("SHOW search_path");
	$pgsqlLocale = $m->fetchArray("SHOW lc_ctype");
	$pgsqlEncoding = lc($m->fetchArray("SHOW server_encoding"));
	$pgsqlEncoding .= " (warning: should be 'utf8'!)" if $pgsqlEncoding ne 'utf8';
}
elsif ($m->{sqlite}) {
	$sqliteJournalMode = $m->fetchArray("PRAGMA journal_mode");
}

# Print admin info
if ($user->{admin} && $details) {
	my $perlIncStr = join("", map("<div>$_</div>\n", @INC));
	my $perlIncModStr = "<table class='tiv'>\n";
	my ($perlEnvStr, $apEnvStr, $apNotesStr, $apHeadersStr, $mwfEnvStr);

	# Working directory
	require Cwd;
	my $cwd = Cwd::getcwd();
	
	# Perl %INC
	eval { require B::TerseSize } or $m->error("B::TerseSize module not available.") if $terseSize;
	for (sort keys %INC) {
		next if /^\// || /\.pl\z/;
		my $mod = $_;
		$mod =~ s!/!::!g;
		$mod =~ s!\.pm!!g;
		my $ver = eval "\$${mod}::VERSION";
		$perlIncModStr .= "<tr><td>$mod</td><td>$ver</td><td>$INC{$_}</td>";
		$perlIncModStr .= "<td>" . B::TerseSize::package_size($mod) . "</td>" if $terseSize;
		$perlIncModStr .= "</tr>\n";
	}
	$perlIncModStr .= "</table>\n";

	# Perl %ENV
	for (sort keys %ENV) { 
		my $value = $ENV{$_};
		$value =~ s/([;,])(?![\s\\])/$1 /g;
		my $valueEsc = $m->escHtml($value);
		$perlEnvStr .= "<div>$_ = $valueEsc</div>\n";
	}

	# Apache subprocess environment
	my $ap = $m->{ap};
	if ($MwfMain::MP) {
		my $subEnv = $ap->subprocess_env;
		for (sort keys %$subEnv) { 
			my $valueEsc = $m->escHtml($subEnv->{$_});
			$apEnvStr .= "<div>$_ = $valueEsc</div>\n";
		}

		# Apache notes table
		my $notes = $ap->notes;
		for (sort keys %$notes) { 
			my $valueEsc = $m->escHtml($notes->{$_});
			$apNotesStr .= "<div>$_ = $valueEsc</div>\n";
		}

		# Apache headers
		my $headers = $ap->headers_in;
		for (sort keys %$headers) { 
			my $valueEsc = $m->escHtml($headers->{$_});
			$apHeadersStr .= "<div>$_ = $valueEsc</div>\n";
		}
	}

	# mwForum $m->{env}
	for (sort keys %$env) { 
		next if /^cookie/;
		my $valueEsc = $m->escHtml($env->{$_});
		$mwfEnvStr .= "<div>$_ = $valueEsc</div>\n";
	}

	print "<table class='tbl'>\n";

	# Print MySQL info
	print
		"<tr class='hrw'><th colspan='2'>MySQL</th></tr>\n",
		"<tr class='crw'><td class='hco'>Version</td><td>$mysqlVersion</td></tr>\n",
		"<tr class='crw'><td class='hco'>Host</td><td>$dbh->{mysql_hostinfo}</td></tr>\n",
		"<tr class='crw'><td class='hco'>User</td><td>$mysqlUser</td></tr>\n",
		"<tr class='crw'><td class='hco'>Database</td><td>$mysqlDatabase</td></tr>\n",
		"<tr class='crw'><td class='hco'>Engine</td><td>$mysqlEngine</td></tr>\n",
		"<tr class='crw'><td class='hco'>Collation</td><td>$mysqlCollation</td></tr>\n",
		"<tr class='crw'><td class='hco'>Prepared</td><td>$dbh->{mysql_server_prepare}</td></tr>\n",
		"<tr class='crw'><td class='hco'>Status</td><td>$dbh->{mysql_stat}</td></tr>\n",
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
		if $m->{pgsql};

	# Print SQLite info
	print
		"<tr class='hrw'><th colspan='2'>SQLite</th></tr>\n",
		"<tr class='crw'><td class='hco'>Journal Mode</td><td>$sqliteJournalMode</td></tr>\n",
		if $m->{sqlite};

	print
		"<tr class='crw'><td class='hco'>Schema Version</td><td>$schemaVersion</td></tr>\n",
		"</table>\n\n";

	# Print Perl info
	print
		"<table class='tbl'>\n",
		"<tr class='hrw'><th colspan='2'>Perl</th></tr>\n",
		"<tr class='crw'><td class='hco'>Version</td><td>$perlVersion</td></tr>\n";

	print
		"<tr class='crw'><td class='hco'>mod_perl</td><td>$modperlVersion</td></tr>\n"
		if $MwfMain::MP;
		
	print
		"<tr class='crw'><td class='hco'>cwd</td><td>$cwd</td></tr>\n",
		"<tr class='crw'><td class='hco'>\$^X</td><td>$^X</td></tr>\n",
		"<tr class='crw'><td class='hco'>\@INC</td><td>\n$perlIncStr</td></tr>\n",
		"<tr class='crw'><td class='hco'>\%INC</td><td>\n$perlIncModStr</td></tr>\n",
		"<tr class='crw'><td class='hco'>\%ENV</td><td>\n$perlEnvStr</td></tr>\n",
		"</table>\n\n";

	# Print Apache info
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Apache Env</span></div>\n",
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
		"<div class='hcl'><span class='htt'>mwForum Env</span></div>\n",
		"<div class='ccl'>\n$mwfEnvStr</div>\n",
		"</div>\n\n";
}

# This section MUST NOT be removed or rendered unreadable
# Doing so would be a violation of the GPL, section 2c
print 
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>Legal</span></div>\n",
	"<div class='ccl'>\n",
	"<p>Powered by <a href='http://www.mwforum.org/'>mwForum</a>", 
	" &#169; 1999-2012 Markus Wichitill</p>\n",
	"<p>This program is free software; you can redistribute it and/or modify",
	" it under the terms of the GNU General Public License as published by",
	" the Free Software Foundation; either version 3 of the License, or",
	" (at your option) any later version.</p>\n",
	"<p>This program is distributed in the hope that it will be useful,",
	" but WITHOUT ANY WARRANTY; without even the implied warranty of",
	" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the",
	" <a href='http://www.gnu.org/copyleft/gpl.html'>GNU General Public License</a>",
	" for more details.</p>\n",
	"</div>\n",
	"</div>\n\n"
	if !$details;

# Print Perl mini banner
print
	"<div class='bni'>\n",
	"<a href='http://www.perl.org/'>",
	"<img src='$cfg->{dataPath}/pwrd_perl.png' title='Powered by Perl $perlVersion'",
	" alt='Perl'/></a>\n";

# Print database mini banner
if ($m->{mysql}) {
	my $engine = $mysqlEngine eq 'MyISAM' ? "" : " ($mysqlEngine)";
	print
		"<a href='http://www.mysql.com/'>",
		"<img src='$cfg->{dataPath}/pwrd_mysql.png' title='Powered by MySQL $mysqlVersion$engine'",
		" alt='MySQL'/></a>\n";
}
elsif ($m->{pgsql}) {
	print
		"<a href='http://www.postgresql.org/'>",
		"<img src='$cfg->{dataPath}/pwrd_pgsql.png' title='Powered by PostgreSQL $pgsqlVersion'",
		" alt='PostgreSQL'/></a>\n";
}
elsif ($m->{sqlite}) {
	print
		"<a href='http://www.sqlite.org/'>",
		"<img src='$cfg->{dataPath}/pwrd_sqlite.png' title='Powered by SQLite $m->{dbh}{sqlite_version}'",
		" alt='SQLite'/></a>\n";
}

# Print webserver mini banner
my $server = undef;
if ($MwfMain::MP1) { $server = Apache::Constants::SERVER_VERSION() }
elsif ($MwfMain::MP2) { $server = Apache2::ServerUtil::get_server_version() }
else { $server = $ENV{SERVER_SOFTWARE} }
if ($server =~ /Apache/) {
	print
		"<a href='http://www.apache.org/'>",
		"<img src='$cfg->{dataPath}/pwrd_apache.png' title='Powered by Apache $webserverVersion'",
		" alt='Apache'/></a>\n";
}
elsif ($server =~ /lighttpd/) {
	print
		"<a href='http://www.lighttpd.net/'>",
		"<img src='$cfg->{dataPath}/pwrd_lighttpd.png' title='Powered by lighttpd $webserverVersion'",
		" alt='lighttpd'/></a>\n";
}

# Print mod_perl mini banner
print	
	"<a href='http://perl.apache.org/'>",
	"<img src='$cfg->{dataPath}/pwrd_modperl.png' title='Powered by mod_perl $modperlVersion'",
	" alt='mod_perl'/></a>\n"
	if $ENV{MOD_PERL};

print "</div>\n\n";

# Log action and finish
$m->logAction(3, 'forum', 'info', $userId);
$m->printFooter(1);
$m->finish();
