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

package MwfMain;
use 5.008001;
use strict;
use warnings;
no warnings qw(uninitialized redefine once);
our $VERSION = "2.29.0";

#------------------------------------------------------------------------------

# Constants
our $MP1  = defined($mod_perl::VERSION) && $mod_perl::VERSION < 1.99 ? 1 : 0;
our $MP2  = defined($mod_perl2::VERSION) && $mod_perl2::VERSION > 1.99 ? 1 : 0;
our $MP   = $MP1 || $MP2;
our $CGI  = !$MP && $ENV{GATEWAY_INTERFACE} ? 1 : 0;
our $FCGI = $CGI && $ENV{FCGI_ROLE} ? 1 : 0;


###############################################################################
# Initialization

#------------------------------------------------------------------------------
# Create MwfMain object for CGI/mod_perl requests

sub new
{
	my $class = shift();
	my $ap = shift();
	my %params = @_;
	
	# Check execution environment
	$MP || $CGI or die "Execution environment unknown, should be CGI or mod_perl.";

	# Load global configuration
	eval { require MwfConfigGlobal } or die "MwfConfigGlobal module not available"
		. " (maybe you forgot to rename MwfConfigGlobalDefault).";
	my $gcfg = $MwfConfigGlobal::gcfg;
	my $ext = defined($gcfg->{ext}) ? $gcfg->{ext} : ".pl";

	# Create instance	
	my $m = { 
		cfg => undef,       # Forum options
		gcfg => $gcfg,      # Global forum options for multi-forum setup
		ext => $ext,        # Script file extension
		ap => $ap,          # Apache/Apache::RequestRec object
		apr => undef,       # Apache(2)::Request object
		dbh => undef,       # DBI handle
		now => time(),      # Request time (instead of local $now vars)
		env => {},          # CGI-environment-style vars
		query => "",        # Last SQL query, since MySQL's errmsg are useless
		queries => [],      # All SQL queries in debug mode
		queryNum => 0,      # Number of SQL queries performed
		printPhase => 0,    # 1=HTTP-header, 2=page-header, 4=all printed
		noIndex => 0,       # Don't index this page
		autoXa => 1,        # Start transaction in dbConnect?
		activeXa => 0,      # Currently in SQL transaction?
		mysql => 0,         # Using MySQL
		pgsql => 0,         # Using PostgreSQL
		sqlite => 0,        # Using SQLite
		user => undef,      # Current user
		userUpdates => {},  # User fields to be updated at end of request
		robotMetas => {},   # Names of robot meta tag flags to set
		boardAdmin => {},   # Cached boardAdmin status
		boardMember => {},  # Cached boardMember status
		pluginCache => {},  # Cached plugin code refs
		pageBar => [],      # Cached HTML for repeated page bars
		warnings => [],     # Warnings shown in page footer
		formErrors => [],   # Errors from form validation
		cookies => [],      # Cookies to be printed in CGI mode
		contentType => '',  # HTML or JSON
		lngModule => '',    # Name of negotiated language module (e.g. "MwfGerman")
		lngName => '',      # Name of negotiated language (e.g. "Deutsch")
		style => 'default2', # Current style subpath/filename
		styleOptions => {}, # Current style's options
		buttonIcons => 0,   # Show button icons to user?
		ajax => $params{ajax}, # AJAX output mode?
		allowBanned => $params{allowBanned}, # Can banned user use feature?
		autocomplete => $params{autocomplete}, # Include autocomplete plugin?
	};
	bless $m, $class;

	# Measure page creation time
	if ($MwfConfigGlobal::gcfg->{pageTime}) {
		require Time::HiRes;
		$m->{startTime} = [Time::HiRes::gettimeofday()];
	}
	
	# Load mod_perl modules
	$m->initModPerl() if $MP;

	# Init CGI environment variable equivalents
	$m->initEnvironment();

	# Load basic configuration
	$m->initConfiguration();
	my $cfg = $m->{cfg};

	# Create CGI or mod_perl request object
	$m->initRequestObject();

	# Connect database
	$m->dbConnect();

	# Load configuration from database
	$m->loadConfiguration();

	# Set default user
	$m->initDefaultUser();

	# Set preliminary language
	$m->setLanguage();

	# Authenticate user and do user-specific stuff
	$m->authenticateUser();
	$m->initUser();

	# Call early include plugin	
	$m->callPlugin($_) for @{$cfg->{includePlg}{early}};
	
	# Cron emulation
	$m->cronEmulation();

	# Cache user access rights if needed for board jumplist anyway
	$m->cacheUserStatus() if $cfg->{boardJumpList} && $m->{user}{id};
	
	# Copy global parameters
	$m->{archive} = $m->paramBool('arc');
	
	return ($m, $cfg, $m->{lng}, $m->{user}, $m->{user}{id}) if wantarray;
	return $m;
}

#------------------------------------------------------------------------------
# Create MwfMain object for commandline scripts

sub newShell
{
	my $class = shift();
	my %params = @_;
	my $allowCgi = $params{allowCgi};  # Allow execution over CGI
	my $spawned = $params{spawned};  # Signal spawned by mwForum, in case $MP/$CGI get inherited
	my $upgrade = $params{upgrade};  # Avoid incompatibilities with install/upgrade scripts
	my $forumId = $params{forumId};  # Hostname or path of forum in multi-forum installation

	# Load global configuration
	eval { require MwfConfigGlobal } or die "MwfConfigGlobal module not available"
		. " (maybe you forgot to rename MwfConfigGlobalDefault).";
	my $gcfg = $MwfConfigGlobal::gcfg;
	my $ext = defined($gcfg->{ext}) ? $gcfg->{ext} : ".pl";

	# Create instance	
	my $m = { gcfg => $gcfg, ext => $ext, now => time(), env => {}, autoXa => 0, activeXa => 0 };
	$class = ref($class) || $class;
	bless $m, $class;

	# Don't run this over CGI unless explicitly allowed
	!$CGI && !$MP || $allowCgi || $spawned
		or die "This script must not be executed via CGI or mod_perl.";

	# Set unbuffered UTF-8 output
	$| = 1;
	binmode STDOUT, ':utf8';

	# Print HTTP header under CGI (e.g. for install.pl and upgrade.pl)
	print "Content-Type: text/plain\n\n" if ($CGI || $MP) && !$spawned;

	# Load base configuration
	$m->{env}{realHost} = $forumId;
	$m->initConfiguration();

	# Connect database
	$m->dbConnect();

	# Load configuration from database
	$m->loadConfiguration() if !$upgrade;

	# Set language
	$m->setLanguage() if !$upgrade;

	return ($m, $m->{cfg}, $m->{lng}) if wantarray;
	return $m;
}

#------------------------------------------------------------------------------
# mod_perl initialization

sub initModPerl
{
	my $m = shift();

	if ($MP1) {
		require Apache;
		require Apache::Constants;
		require Apache::Connection;
		require Apache::File;
		require Apache::Util;
		require Apache::Request;
	}
	else {
		require Apache2::Connection;
		require Apache2::RequestRec;
		require Apache2::RequestIO;
		require Apache2::RequestUtil;
		require Apache2::ServerUtil;
		require Apache2::Request;
		require Apache2::Util;
		require ModPerl::Util;
	}
}

#------------------------------------------------------------------------------
# Init CGI environment variable equivalents

sub initEnvironment
{
	my $m = shift();

	my $ap = $m->{ap};
	my $env = $m->{env};
	
	if ($MP) {
		my $hi = $ap->headers_in();
		$env->{port} = $ap->get_server_port();
		$env->{method} = $ap->method();
		$env->{protocol} = $ap->protocol();
		$env->{host} = $ap->hostname();
		$env->{realHost} = $hi->{'X-Forwarded-Host'} || $hi->{'X-Host'} || $env->{host};
		($env->{script}) = $ap->uri() =~ m!.*/(.*)\.!;
		($env->{scriptUrlPath}) = $ap->uri() =~ m!(.*)/!;
		$env->{cookie} = $hi->{'Cookie'};
		$env->{referrer} = $hi->{'Referer'};
		$env->{accept} = lc($hi->{'Accept'});
		$env->{acceptLang} = lc($hi->{'Accept-Language'});
		$env->{userAgent} = $hi->{'User-Agent'};
		$env->{userIp} = lc($ap->connection->remote_ip());
		$env->{userAuth} = $ap->user();
		$env->{params} = $ap->args();
		$env->{https} = $ap->subprocess_env()->{HTTPS} eq 'on' || $env->{port} == 443;
	}
	else {
		$env->{port} = $ENV{SERVER_PORT};
		$env->{method} = $ENV{REQUEST_METHOD};
		$env->{protocol} = $ENV{SERVER_PROTOCOL};
		$env->{host} = $ENV{HTTP_HOST};
		$env->{host} =~ s!:\d+\z!!;
		$env->{realHost} = $ENV{HTTP_X_FORWARDED_HOST} || $ENV{HTTP_X_HOST} || $env->{host};
		($env->{script}) = $ENV{SCRIPT_NAME} =~ m!.*/(.*)\.!;
		($env->{scriptUrlPath}) = $ENV{SCRIPT_NAME} =~ m!(.*)/!;
		$env->{cookie} = $ENV{HTTP_COOKIE} || $ENV{COOKIE};
		$env->{referrer} = $ENV{HTTP_REFERER};
		$env->{accept} = lc($ENV{HTTP_ACCEPT});
		$env->{acceptLang} = lc($ENV{HTTP_ACCEPT_LANGUAGE});
		$env->{userAgent} = $ENV{HTTP_USER_AGENT};
		$env->{userIp} = lc($ENV{REMOTE_ADDR});
		$env->{userAuth} = $ENV{REMOTE_USER};
		$env->{params} = $ENV{QUERY_STRING};
		$env->{https} = $ENV{HTTPS} eq 'on' || $env->{port} == 443;
	}

	$env->{host} = "[$env->{host}]" if index($env->{host}, ":") > -1;
	($m->{uaLangCode}) = $m->{env}{acceptLang} =~ /^([A-Za-z]{2})/;
}

#------------------------------------------------------------------------------
# Create CGI or mod_perl request object

sub initRequestObject
{
	my $m = shift();

	my $ap = $m->{ap};
	my $cfg = $m->{cfg};
	my $errParse = "Input exceeds maximum allowed size or is corrupted.";

	# Set STDOUT encoding
	binmode STDOUT, ':utf8';

	if ($MP1) {
		# Use Apache::Request object
		$m->{apr} = Apache::Request->new($ap,
			POST_MAX => $cfg->{maxAttachLen}, TEMP_DIR => $cfg->{attachFsPath});
		$m->{apr}->parse() == 0 or $m->error($errParse) if $ap->method() eq 'POST';
	}
	elsif ($MP2) {
		# Use Apache2::Request object
		$m->{apr} = Apache2::Request->new($ap,
			POST_MAX => $cfg->{maxAttachLen}, TEMP_DIR => $cfg->{attachFsPath} );
		$m->{apr}->discard_request_body() == 0 or $m->error("Input is corrupted.");
		$m->{apr}->parse() == 0 or $m->error($errParse) if $ap->method() eq 'POST';
	}
	else {
		# Use MwfCGI object
		require MwfCGI;
		MwfCGI::_reset_globals() if $FCGI;
		MwfCGI::max_read_size($cfg->{maxAttachLen});
		$m->{cgi} = MwfCGI->new();
		!$m->{cgi}->truncated() or $m->error($errParse);
	}
}	

#------------------------------------------------------------------------------
# Load basic configuration

sub initConfiguration
{
	my $m = shift();

	# Load basic configuration
	my $host = $m->{env}{realHost};
	my $path = $m->{env}{scriptUrlPath};
	my $hostModule = $m->{gcfg}{forums}{$host};
	my $pathModule = $m->{gcfg}{forums}{$path};
	my $module = $hostModule || $pathModule || "MwfConfig";
	eval { require "$module.pm" };
	!$@ or die "Configuration loading failed. ($@)";
	eval "\$m->{cfg} = \$${module}::cfg";
	!$@ or die "Configuration assignment failed. ($@)";

	# Store used host or path for passing to spawned processes
	if ($hostModule) { $m->{forumId} = $host } 
	elsif ($pathModule) { $m->{forumId} = $path }
	
	# Load configuration defaults
	my $cfg = $m->{cfg};
	if (!$cfg->{lastUpdate}) {
		require MwfDefaults;
		$cfg->{$_->{name}} = $_->{default} for @$MwfDefaults::options;
	}
}

#------------------------------------------------------------------------------
# Load configuration from database

sub loadConfiguration
{
	my $m = shift();

	# Return if database config hasn't changed
	my $cfg = $m->{cfg};
	if ($MP || $FCGI) {
		my $lastUpdate = $m->fetchArray("
			SELECT value FROM config WHERE name = ?", 'lastUpdate');
		return if $lastUpdate <= $cfg->{lastUpdate};
	}

	# Copy database config to $cfg
	my $sth = $m->fetchSth("
		SELECT name, value, parse FROM config");
	my ($name, $value, $parse);
	$sth->bind_columns(\($name, $value, $parse));
	while ($sth->fetch()) {
		utf8::decode($value);
		if (!$parse) { $cfg->{$name} = $value }
		elsif ($parse eq 'array') { $cfg->{$name} = [ $value =~ /^ *(.+?) *$/gm ] }
		elsif ($parse eq 'hash') { $cfg->{$name} = { $value =~ /^ *(.+?) *= *(.*?) *$/gm } }
		elsif ($parse eq 'arrayhash') { 
			$cfg->{$name} = {};
			for my $line ($value =~ /^ *(.+?) *$/gm) {
				my ($k, $v) = $line =~ /(.+?) *= *(.*)/;
				push @{$cfg->{$name}{$k}}, $v if $k && length($v);
			}
		}
	}

	# Special treatment for some options
	if ($cfg->{dataVersion}) {
		if ($cfg->{dataPath} !~ /\/v\d+\z/) { $cfg->{dataPath} .= "/v" . $cfg->{dataVersion} }
		else { $cfg->{dataPath} =~ s!/v\d+\z!/v$cfg->{dataVersion}! }
	}
	$m->{env}{scriptUrlPath} = $cfg->{scriptUrlPath} if $cfg->{fScriptUrlPath};
}

#------------------------------------------------------------------------------
# Load and set language based on various factors

sub setLanguage
{
	my $m = shift();
	my $forceLang = shift() || undef;

	# Try to load specified or user-selected language
	my $cfg = $m->{cfg};
	return $m->{lng} if $forceLang && $m->loadLanguage($forceLang);
	return $m->{lng} if $m->{user}{language} && $m->loadLanguage($m->{user}{language});

	# Try to load user agent-accepted language (ignores countries, goes by order not q value)
	my (@langCodes, %seen);
	for my $lc (split(/\s*,\s*/, $m->{env}{acceptLang})) {
		$lc =~ s!(?:-[a-z]+)|(?:;q=[0-9.]+)!!g;
		push @langCodes, $lc if !$seen{$lc}++;
	}
	for my $lc (@langCodes) {	
		return $m->{lng} if $cfg->{languageCodes}{$lc} && $m->loadLanguage($cfg->{languageCodes}{$lc});
	}

	# Try to load default language, fall back to English if necessary
	return $m->{lng} if $m->loadLanguage($cfg->{language});
	return $m->{lng} if $m->loadLanguage("English");
	return {};
}

#------------------------------------------------------------------------------
# Try to load language

sub loadLanguage
{
	my $m = shift();
	my $lang = shift();

	my $module = $m->{cfg}{languages}{$lang};
	$module =~ /^Mwf[A-Za-z_0-9]+\z/ or return 0;
	eval { require "$module.pm" } or return 0;
	eval "\$m->{lng} = \$${module}::lng" or return 0;
	$m->{lngModule} = $module;
	$m->{lngName} = $lang;
	return 1;
}

#------------------------------------------------------------------------------
# Wrap up if there was no error

sub finish
{
	my $m = shift();

	$m->updateUser() if $m->{user}{id};
	$m->dbCommit();
	$m->{dbh}->disconnect();
	$FCGI ? die : exit;
}

#------------------------------------------------------------------------------
# Cron emulation

sub cronEmulation
{
	my $m = shift();

	return if !$m->{cfg}{cronEmu};
	my (undef, undef, undef, $today) = localtime(time());
	my $lastExecDay = $m->getVar('crnExcDay') || 0;
	return if $today == $lastExecDay;

	$m->setVar('crnExcDay', $today);
	$m->dbCommit();

	$m->printHeader();
	$m->printHints([$m->{lng}{errCrnEmuBsy}]);
	$m->printFooter();

	$m->spawnScript('cron_jobs');
	$m->spawnScript('cron_subscriptions');

	$m->{user}{id} = 0;
	$m->finish();
}


###############################################################################
# Utility Functions

#------------------------------------------------------------------------------
# Replace placeholders in language string

sub formatStr
{
	my $m = shift();
	my $str = shift();
	my $params = shift();

	for my $key (keys %$params) {
		my $repl = $params->{$key};
		if (ref($repl)) {
			my ($format, $value) = @$repl;
			$value = sprintf($format, $value);
			$str =~ s!\[\[$key\]\]!$value!;
		}
		else {
			$str =~ s!\[\[$key\]\]!$repl!;
		}
	}
	return $str;
}

#------------------------------------------------------------------------------
# Get time string from seconds-since-epoch

sub formatTime
{
	my $m = shift();
	my $epoch = shift();
	my $tz = shift() || 0;
	my $format = shift() || $m->{cfg}{timeFormat};
	
	if ($MP1) { 
		return $tz eq 'SVR' 
			? Apache::Util::ht_time($epoch, $format, 0)
			: Apache::Util::ht_time($epoch + $tz * 3600, $format);
	}
	elsif ($MP2 && $m->{ap}) { 
		return $tz eq 'SVR' 
			? Apache2::Util::ht_time($m->{ap}->pool(), $epoch, $format, 0)
			: Apache2::Util::ht_time($m->{ap}->pool(), $epoch + $tz * 3600, $format);
	}
	else {
		require POSIX;
		return $tz eq 'SVR' 
			? POSIX::strftime($format, localtime($epoch))
			: POSIX::strftime($format, gmtime($epoch + $tz * 3600));
	}
}

#------------------------------------------------------------------------------
# Format file size

sub formatSize
{
	my $m = shift();
	my $size = shift() || 0;

	return $size >= 1024 ? int($size / 1024 + .5) . "k" : "${size}B";
}

#------------------------------------------------------------------------------
# Format topic tag icon/string

sub formatTopicTag
{
	my $m = shift();
	my $key = shift();
	
	my $tag = $m->{cfg}{topicTags}{$key};

	if ($tag =~ /\.(?:jpg|png|gif)/i && $tag !~ /[<]/) {
		# Create image tag from image file name
		my ($src, $alt) = $tag =~ /(\S+)\s*(.*)?/;
		return "<img class='ttg' src='$m->{cfg}{dataPath}/$src' title='$alt' alt='[$alt]'>";
	}
	else {
		# Use tag as is
		return $tag;
	}
}

#------------------------------------------------------------------------------
# Format user title icon/string

sub formatUserTitle 
{
	my $m = shift();
	my $title = shift();

	if ($title =~ /[<\[\(]/) {
		# Use title with < ( [ as is
		return $title;
	}
	elsif ($title =~ /\.(?:jpg|png|gif)/i) {
		# Create image tag from image file name
		my ($src, $alt) = $title =~ /(\S+)\s*(.*)?/;
		return "<img class='utt' src='$m->{cfg}{dataPath}/$src' title='$alt' alt='($alt)'>";
	}
	else {
		# Put title in parens
		return "($title)";
	}
}

#------------------------------------------------------------------------------
# Format user rank icon/string

sub formatUserRank
{
	my $m = shift();
	my $postNum = shift();

	for my $line (@{$m->{cfg}{userRanks}}) {
		my ($num, $rank) = $line =~ /([0-9]+)\s+(.+)/;
		if ($postNum >= $num) {
			if ($rank =~ /[<\[\(]/) {
				# Use rank with < ( [ as is
				return $rank;
			}
			elsif ($rank =~ /\.(?:jpg|png|gif)/i) {
				# Create image tag from image file name
				my ($src, $alt) = $rank =~ /(\S+)\s*(.*)?/;
				return "<img class='rnk' src='$m->{cfg}{dataPath}/$src' title='$alt' alt='($alt)'>";
			}
			else {
				# Put rank in parens
				return "($rank)";
			}
		}
	}
}

#------------------------------------------------------------------------------
# Shorten string and add ellipsis if necessary 

sub abbr
{
	my $m = shift();
	my $str = shift();
	my $maxLength = shift() || 10;  # Excluding dots
	my $removeHtml = shift() || 0;

	# Remove HTML
	$str =~ s!<.+?>! !g if $removeHtml;

	# Compress multiple spaces to make better use of given length
	$str =~ s!&#160;! !g;
	$str =~ s!\s{2,}! !g;

	# Unescape HTML to count actual characters and to avoid breaking entities
	$str = $m->deescHtml($str);
	
	# Shorten and append ellipsis
	my $oldLen = length($str);
	$str = substr($str, 0, $maxLength);
	$str .= "\x{2026}" if $oldLen > length($str);

	# Escape again
	$str = $m->escHtml($str);
	
	return $str;
}

#------------------------------------------------------------------------------
# Get the greatest of the args

sub max 
{
	my $m = shift();

	my $max = undef;
	for (@_) { $max = $_ if $_ > $max || !defined($max) }
	return $max;
}

#------------------------------------------------------------------------------
# Get the least of the args

sub min 
{
	my $m = shift();

	my $min = undef;
	for (@_) { $min = $_ if $_ < $min || !defined($min) }
	return $min;
}

#------------------------------------------------------------------------------
# Get the first argument that is defined

sub firstDef
{
	my $m = shift();

	for (@_) { return $_ if defined }
	return undef;
}

#------------------------------------------------------------------------------
# Call plugin

sub callPlugin
{
	my $m = shift();
	my $plugin = shift();
	
	return if !$plugin;

	# Get plugin function
	my $func = $m->{pluginCache}{$plugin};
	if (!$func) {
		my ($module) = $plugin =~ /(.+?)::/;
		if ($module !~ /^MwfPlg[A-Za-z_0-9]+\z/) {
			$m->logError("Invalid plugin module configuration", 1);
			return undef;
		}
		eval { 
			require "$module.pm"; 
			$func = \&$plugin 
		};
		!$@ && $func or $m->logError("Plugin module loading failed: $@", 1);
		$m->{pluginCache}{$plugin} = $func;
	}

	# Call function
	my $result = undef;
	eval { $result = &$func(m => $m, @_) };

	# Handle exceptions and fatal errors
	if ($@ && ref($@) eq 'MwfMain::PluginError') {
		# Throw this exception to print error msg and exit, plugins can't exit otherwise
		$m->error(${$@});
	}
	elsif ($@) {
		$m->logError("Plugin execution failed: $@", 1);
	}

	return $result;
}

#------------------------------------------------------------------------------
# Execute external program with cmd/in/out/err 

sub ipcRun
{
	my $m = shift();
	my $cmd = shift();
	my $in = shift();
	my $out = shift();
	my $err = shift();

	my $inCopy = $$in;
	eval { require IPC::Run } or $m->error("IPC::Run module not available.");
	eval { IPC::Run::run($cmd, $in, $out, $err) };
	my $rv = $? >> 8;
	$rv == 0 && !$@ or $m->logError("IPC::Run possibly failed. (rv: $rv, \$\@: $@)");
	my $sep = "\n" . "#" x 70 . "\n";
	$m->logToFile($m->{cfg}{runLog}, $sep . join(" ", @$cmd) 
		. "$sep$inCopy$sep$$out$sep$$err$sep\$\@: $@${sep}rv: $rv$sep\n") 
		if $m->{cfg}{runLog};
	return $rv == 0;
}

#------------------------------------------------------------------------------
# Spawn an independently running script

sub spawnScript
{
	my $m = shift();
	my $script = shift();
	my @args = @_;

	# Add forum id for multi-forum setups
	my $cfg = $m->{cfg};
	push @args, "-s";
	push @args, "-f" => $m->{forumId} if $m->{forumId};

	if ($^O eq 'MSWin32') {
		# So far untested
		require Win32;
		require Win32::Process;
		$script = "$cfg->{scriptFsPath}/$script$m->{ext}";
		Win32::Process::Create(my $kid, $cfg->{perlBinary}, join(" ", $script, @args), 
			0, Win32::Process::NORMAL_PRIORITY_CLASS(), $cfg->{scriptFsPath})
			or $m->logError("CreateProcess() failed. " . Win32::FormatMessage(Win32::GetLastError()));
	}
	else {
		# Unix forking voodoo nonsense
		require POSIX;
		$SIG{CHLD} = 'IGNORE';
		$script = "$cfg->{scriptFsPath}/$script$m->{ext}";
		defined(my $kid = fork()) or $m->logError("fork() failed. $!");
		return if $kid;
		open STDIN, "<", "/dev/null";
		open STDOUT, ">>", "/dev/null";
		open STDERR, ">>", "/dev/null";
		for (my $fd = 3; $fd < 20; $fd++) { POSIX::close($fd) }
		POSIX::setsid() != -1 or die "setsid() failed. $!";
		exec($cfg->{perlBinary}, "-I", $cfg->{scriptFsPath}, $script, @args) or CORE::exit;
	}
}

#------------------------------------------------------------------------------
# Get MD5 hash

sub md5
{
	my $m = shift();
	my $data = shift();
	my $rounds = shift() || 1;
	my $base64url = shift() || 0;

	require Digest::MD5;
	utf8::encode($data) if utf8::is_utf8($data);
	if ($rounds > 1) { $data = Digest::MD5::md5($data) for 1 .. $rounds - 1 }
	if ($base64url) {
		$data = Digest::MD5::md5_base64($data);
		$data =~ tr!+/!-_!;
	}
	else {
		$data = Digest::MD5::md5_hex($data);
	}
	return $data;
}

#------------------------------------------------------------------------------
# Convert password and salt to current hashed format

sub hashPassword
{
	my $m = shift();
	my $password = shift();
	my $salt = shift();

  return $m->md5($password . $salt, 100000, 1);
}

#------------------------------------------------------------------------------
# Get 128-bit base64url random ID

sub randomId
{
	my $m = shift();

	my $rnd = "";
	if ($^O ne 'MSWin32') {
		eval { 
			open my $fh, "<", "/dev/urandom" or die;
			read $fh, $rnd, 16;
			close $fh;
		};
	}
	if (length($rnd) != 16) {
		require Time::HiRes;
		$rnd = Time::HiRes::gettimeofday() . rand() . $$ . $< . $] . $m;
	}
	return $m->md5($rnd, 1, 1);
}

#------------------------------------------------------------------------------
# Convert filename/path to filesystem encoding

sub encFsPath
{
	my $m = shift();
	my $path = shift();

	if (lc($m->{cfg}{fsEncoding}) ne 'ascii' && utf8::is_utf8($path)) {	
		require Encode;
		return Encode::encode($m->{cfg}{fsEncoding}, $path);
	}
	else {
		return $path;
	}
}

#------------------------------------------------------------------------------
# Convert filename/path from filesystem encoding to UTF-8

sub decFsPath
{
	my $m = shift();
	my $path = shift();

	if (lc($m->{cfg}{fsEncoding}) ne 'ascii') {	
		require Encode;
		return Encode::decode($m->{cfg}{fsEncoding}, $path);
	}
	else {
		return $path;
	}
}

#------------------------------------------------------------------------------
# Set file permissions

sub setMode
{
	my $m = shift();
	my $path = shift();
	my $type = shift();

	my $cfg = $m->{cfg};

	if ($type eq 'dir') {
		chmod $cfg->{dirMode} ? oct($cfg->{dirMode}) : 0777 & ~umask(), $path;
	}
	elsif ($type eq 'file') {
		chmod $cfg->{fileMode} ? oct($cfg->{fileMode}) : 0666 & ~umask(), $path;
	}
}

#------------------------------------------------------------------------------
# Create directory hierarchy

sub createDirectories
{
	my $m = shift();
	my @dirs = @_;

	# First arg is absolute path, rest are relative dir names
	my $path;
	for my $dir (@dirs) {
		$path = $path ? "$path/$dir" : $dir;
		if (!-d $path) { 
			mkdir $path or $m->error("Directory creation failed. ($!)");
			$m->setMode($path, 'dir');
		}
	}
}

#------------------------------------------------------------------------------
# Read whole file into variable

sub slurpFile
{
	my $m = shift();
	my $file = shift();
	my $mode = shift() || "<";

	open(my $fh, $mode, $file);
	local $/;
	return scalar <$fh>;
}

#------------------------------------------------------------------------------
# Create resized image as JPEG if sizes are bigger than specified max

sub resizeImage
{
	my $m = shift();
	my $oldFile = shift();
	my $newFile = shift();
	my $cfg = $m->{cfg};
	my $maxW = shift() || $cfg->{attachImgRszW} || 1280;
	my $maxH = shift() || $cfg->{attachImgRszH} || 1024;
	my $maxS = shift() || $cfg->{attachImgRszS} || 204800;
	my $newQ = shift() || $cfg->{attachImgRszQ} || 80;

	# Load modules
	my $module;
	if (!$cfg->{noGd} && eval { require GD }) { $module = 'GD' }
	elsif (!$cfg->{noImager} && eval { require Imager }) { $module = 'Imager' }
	elsif (!$cfg->{noGMagick} && eval { require Graphics::Magick }) { $module = 'Graphics::Magick' }
	elsif (!$cfg->{noIMagick} && eval { require Image::Magick }) { $module = 'Image::Magick' }
	else { $m->logError("GD, Imager or Magick modules not available."), return }
	
	# Get image info
	my $oldFileEnc = $m->encFsPath($oldFile);
	my $newFileEnc = $m->encFsPath($newFile);
	my ($oldW, $oldH, $oldImg, $err);
	if ($module eq 'GD') {
		GD::Image->trueColor(1);
		$oldImg = GD::Image->new($oldFileEnc) or $m->logError("Image loading failed."), return;
		$oldW = $oldImg->width();
		$oldH = $oldImg->height();
		$oldW && $oldH or $m->logError("Image size check failed."), return;
	}
	elsif ($module eq 'Imager') {
		$oldImg = Imager->new(file => $oldFileEnc) 
			or $m->logError("Image loading failed. " . Imager->errstr()), return;
		$oldW = $oldImg->getwidth();
		$oldH = $oldImg->getheight();
		$oldW && $oldH or $m->logError("Image size check failed."), return;
	}
	elsif ($module eq 'Graphics::Magick' || $module eq 'Image::Magick') {
		my $magick = $module->new() or $m->logError("Magick creation failed."), return;
		($oldW, $oldH) = $magick->Ping($oldFileEnc);
		$oldW && $oldH or $m->logError("Image size check failed."), return;
	}

	# Check whether resizing is required
	my $fact = $m->min($maxW / $oldW, $maxH / $oldH, 1);
	my $oldS = -s $oldFileEnc;
	return if !($fact < 1 || $oldS > $maxS);
	
	# Resize image to JPEG with white matte
	my $newW = int($oldW * $fact + .5);
	my $newH = int($oldH * $fact + .5);
	if ($module eq 'GD') {
		my $newImg = GD::Image->new($newW, $newH, 1) or $m->logError("Image creation failed."), return;
		$newImg->fill(0, 0, $newImg->colorAllocate(255,255,255));
		$newImg->copyResampled($oldImg, 0, 0, 0, 0, $newW, $newH, $oldW, $oldH);
		open my $fh, ">:raw", $newFileEnc or $m->logError("Image opening failed. $!"), return;
		print $fh $newImg->jpeg($newQ) or $m->logError("Image storing failed. $!"), return;
		close $fh;
	}
	elsif ($module eq 'Imager') {
		$oldImg = $oldImg->scale(xpixels => $newW, ypixels => $newH, 
			type => 'nonprop', qtype => 'mixing') 
			or $m->logError("Image scaling failed. " . Imager->errstr()), return;
		$oldImg->write(file => $newFileEnc, i_background => 'white', jpegquality => $newQ)
			or $m->logError("Image storing failed. " . $oldImg->errstr()), return;
	}
	elsif ($module eq 'Graphics::Magick' || $module eq 'Image::Magick') {
		$oldImg = $module->new()
			or $m->logError("Image creation failed."), return;
		$err = $oldImg->Read($oldFileEnc . "[0]")
			and $m->logError("Image loading failed. $err"), return;
		$err = $oldImg->Scale(width => $newW, height => $newH)
			and $m->logError("Image scaling failed. $err"), return;
		my $newImg = $module->new(size => "${newW}x$newH") 
			or $m->logError("Image creation failed."), return;
		$err = $newImg->Read('xc:#ffffff')
			and $m->logError("Image filling failed. $err"), return;
		$err = $newImg->Composite(image => $oldImg)
			and $m->logError("Image compositing failed. $err"), return;
		$err = $newImg->Write(filename => $newFileEnc, compression => 'JPEG', quality => $newQ)
			and $m->logError("Image storing failed. $err"), return;
	}
	$m->setMode($newFileEnc, 'file');
	
	return 1;
}

#------------------------------------------------------------------------------
# Resize image attachment

sub resizeAttachment
{
	my $m = shift();
	my $attachId = shift();

	# Get attachment
	my ($postId, $oldFileName) = $m->fetchArray("
		SELECT postId, fileName FROM attachments WHERE id = ?", $attachId);
	$postId && $oldFileName or return;

	# Resize image file	
	my $newFileName = $oldFileName;
	$newFileName =~ s!\.(?:jpg|png|gif)\z!.rsz.jpg!i;
	my $postIdMod = $postId % 100;
	my $oldFile = "$m->{cfg}{attachFsPath}/$postIdMod/$postId/$oldFileName";
	my $newFile = "$m->{cfg}{attachFsPath}/$postIdMod/$postId/$newFileName";
	$m->resizeImage($oldFile, $newFile) or return;

	# Update attachment	filename
	$m->dbDo("
		UPDATE attachments SET fileName = ? WHERE id = ?", $newFileName, $attachId);
	unlink $m->encFsPath($oldFile);

	return $newFileName;
}

#------------------------------------------------------------------------------
# Create thumbnail image

sub addThumbnail
{
	my $m = shift();
	my $oldFile = shift();
	
	my $cfg = $m->{cfg};
	my $maxW = $cfg->{attachImgThbW} || 150;
	my $maxH = $cfg->{attachImgThbH} || 150;
	my $maxS = $cfg->{attachImgThbS} || 15360;
	my $newQ = $cfg->{attachImgThbQ} || 90;
	my $newFile = $oldFile;
	$newFile =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
	$m->resizeImage($oldFile, $newFile, $maxW, $maxH, $maxS, $newQ) or return;
	return 1;
}

#------------------------------------------------------------------------------
# Log something to separate logfile

sub logToFile
{
	my $m = shift();
	my $file = shift();
	my $msg = shift();

	open my $fh, ">>:utf8", $file or return 0;
	flock $fh, 2;
	seek $fh, 0, 2;
	my $timestamp = $m->formatTime($m->{now}, 0, "%Y-%m-%d %H:%M:%S");
	print $fh "[$timestamp] [$m->{env}{userIp}] [$m->{env}{script}] $msg\n";
	close $fh;
	return 1;
}

#------------------------------------------------------------------------------
# Format key/value pairs as JSON

sub json
{
	my $m = shift();
	my $params = shift();
	my $options = shift() || {};
	
	my @lines = ();
	for my $key (sort keys %$params) {
		my $value = $params->{$key};
		$value =~ s!\\!\\\\!g;
		$value =~ s!'!\\!g;
		$value =~ s!"!\\"!g;
		$value = "\"$value\"" if $value !~ /^[0-9.]+\z/;
		push @lines, "\"$key\": $value";
	}
	return "{ " . join(", ", @lines) . " }";
}


###############################################################################
# CGI Functions

#------------------------------------------------------------------------------
# Get submitted parameter names

sub params
{
	my $m = shift();

	return $m->{apr}->param() if $MP;
	return $m->{cgi}->param();
}

#------------------------------------------------------------------------------
# Get parameter definedness

sub paramDefined
{
	my $m = shift();
	my $name = shift();
	
	return defined(eval { $m->{apr}->param($name) }) ? 1 : 0 if $MP;
	return defined($m->{cgi}->param($name)) ? 1 : 0;
}

#------------------------------------------------------------------------------
# Get int parameter(s)

sub paramInt
{
	my $m = shift();
	my $name = shift();

	if (wantarray()) {
		my @ints;
		if ($MP) { @ints = eval { $m->{apr}->param($name) } }
		else { @ints = $m->{cgi}->param($name) }
		@ints = map(int($_), @ints);
		return @ints;
	}
	else {
		return int(eval { $m->{apr}->param($name) } || 0) if $MP;
		return int($m->{cgi}->param($name) || 0);
	}
}

#------------------------------------------------------------------------------
# Get boolean parameter

sub paramBool
{
	my $m = shift();
	my $name = shift();

	return eval { $m->{apr}->param($name) } ? 1 : 0 if $MP;
	return $m->{cgi}->param($name) ? 1 : 0;
}

#------------------------------------------------------------------------------
# Get string parameter

sub paramStr
{
	my $m = shift();
	my $name = shift();
	my $trim = shift();
	$trim = 1 if !defined($trim);

	my $str;
	if ($MP) { 
		$str = eval { $m->{apr}->param($name) };
		!$@ or $m->error("Parameter '$name' is not valid.");
	}
	else { 
		$str = $m->{cgi}->param($name);
	}
	$str = "" if !defined($str);
	
	# Decode UTF-8, treat as Latin1 if that fails
	if (!utf8::decode($str)) {
		$m->logError("Parameter '$name' is not valid UTF-8.");
		utf8::upgrade($str);
	}

	# Normalize to NFC (mod_perl only for performance reasons)
	if ($MP || $FCGI) { 
		require Unicode::Normalize;
		my $orgStr = $str;
		$str = Unicode::Normalize::NFC($str);
		$m->logError("Parameter '$name' is not in Unicode NFC.", 1) 
			if $m->{cfg}{debug} && $orgStr ne $str;
	}
	
	# Trim leading and trailing whitespace
	if ($trim && length($str)) { $str =~ s!^\s+!!; $str =~ s!\s+\z!! }

	return $str;
}

#------------------------------------------------------------------------------
# Get identifier string parameter

sub paramStrId
{
	my $m = shift();
	my $name = shift();
	
	my $str;
	if ($MP) { ($str) = eval { $m->{apr}->param($name)} =~ /^([A-Za-z_0-9]+)\z/ }
	else { ($str) = $m->{cgi}->param($name) =~ /^([A-Za-z_0-9]+)\z/ }
	$str = "" if !defined($str);
	return $str;
}

#------------------------------------------------------------------------------
# Get upload object, sanitized filename and size

sub getUpload
{
	my $m = shift();
	my $name = shift();

	# Get object, filename and size
	my $cfg = $m->{cfg};
	my ($upload, $file, $size);
	if ($MP) {
		require Apache2::Upload if $MP2;
		$upload = $m->{apr}->upload($name);
		$upload or return;
		$file = $upload->filename();
		$size = $upload->size();
	}
	else {
		$file = $m->{cgi}->param_filename($name);
		$size = length($m->{cgi}->param($name));
	}

	# Remove path
	$file =~ s!.*[\\/]!!;

	# Get rid of non-convertible and replacement chars
	if (lc($cfg->{fsEncoding}) ne 'ascii') {
		require Encode;
		utf8::decode($file);
		$file =~ s![^\w.-]+!!g;
		$file = Encode::encode($cfg->{fsEncoding}, $file);
		$file =~ s!\?+!!g;
		$file = Encode::decode($cfg->{fsEncoding}, $file);
	}
	else {
		$file =~ s![^A-Za-z_0-9.-]+!!g;
	}

	# Make sure filename doesn't end up special or empty
	if ($file =~ /\.(?:$cfg->{attachBlockExt})\z/i) { $file = "$file.ext" }
	if (!length($file) || $file eq ".htaccess") { $file = "attachment" }

	return ($upload, $file, $size);
}

#------------------------------------------------------------------------------
# Save upload to its final file

sub saveUpload
{
	my $m = shift();
	my $name = shift();
	my $upload = shift();
	my $file = shift();

	$file = $m->encFsPath($file);
	if ($MP1) {
		# Create new hardlink or copy tempfile
		if (!$upload->link($file)) {
			require File::Copy;
			File::Copy::copy($upload->tempname(), $file) or $m->error("Upload saving failed. ($!)");
		}
	}
	elsif ($MP2) {
		# Create new hardlink or copy tempfile or write data from memory for small uploads
		eval { $upload->link($file) } or $m->error("Upload saving failed. ($@)");
	}
	else {
		# Write data from memory to file
		open my $fh, ">:raw", $file or $m->error("Upload saving failed. ($!)");
		print $fh $m->{cgi}->param($name) or $m->error("Upload saving failed. ($!)");
		close $fh;
	}
	$m->setMode($file, 'file');
}

#------------------------------------------------------------------------------
# Assemble script URL with query string

sub url
{
	my $m = shift();
	my $script = shift();
	my @params = @_;

	my $env = $m->{env};

	# Add global parameters	
	push @params, arc => 1 if $m->{archive};
	
	# Start URL
	my $qm = 0;
	my $target = "";
	my $url = $script;
	$url .= $m->{ext} if index($script, ".") == -1;

	# Add query parameters
	for (my $i = 0; $i < @params; $i += 2) {
		my $key = $params[$i];
		my $value = $params[$i+1];
		next if !defined($value);

		# Handle special keys
		if ($key eq 'tgt') { 
			# Fragment id at the end of URLs
			$target = $value; 
			next; 
		}
		elsif ($key eq 'auth') { 
			# Required for non-idempotent links, which should become POSTs one of these days
			next if !$m->{user}{id};
			$value = $m->{user}{sourceAuth};
		}
		elsif ($key eq 'ori') { 
			# Origin redirection
			if ($m->{error}) { 
				# Skip in error cases
				$value = "";
			}
			else {
				$value = $env->{script} . $m->{ext};
				$value .= "?$env->{params}" if $env->{params};
				$value =~ s![?;]?msg=[A-Za-z]+!!;
			}
		}

		# Append question mark before first real param
		if (!$qm) { $url .= "?"; $qm = 1 }

		# Append escaped param
		utf8::encode($value);
		$value =~ s/([^A-Za-z_0-9.!~()-])/'%'.unpack("H2",$1)/eg;
		$url .= "$key=$value;";
	}

	# Remove trailing semicolon	
	chop $url if @params && substr($url, -1, 1) eq ';';
	
	# Append fragment identifier
	$url .= "#$target" if $target;
	
	return $url;
}

#------------------------------------------------------------------------------
# Redirect via HTTP header

sub redirect
{
	my $m = shift();
	my $script = shift();
	my @params = @_;

	my $ap = $m->{ap};
	my $cfg = $m->{cfg};
	my $env = $m->{env};
	
	# Determine status, schema, host, script and params
	my $status = $env->{protocol} eq "HTTP/1.1" ? 303 : 302;
	my $schema = $cfg->{sslOnly} || $env->{https} ? 'https' : 'http';
	my $host = $env->{host};
	if (!$host) {
		($host) = $cfg->{baseUrl} =~ m!^https?://(.+)!;
		$host =~ s!:\d+\z!!;
	}
	$host .= ":" . $env->{port} if $env->{port} != 80;
	my $scriptAndParam = $m->url($script, @params);

	# If there was an origin parameter, use that instead, but add msg
	my $origin = $m->paramStr('ori');
	if ($origin) {
		my %params = @params;
		my $msg = $params{msg};
		$msg = $origin =~ /=/ ? ";msg=$msg" : "?msg=$msg" if $msg;
		$scriptAndParam = $origin . $msg;
	}
	
	# Location URL must be absolute according to HTTP
	my $location = $cfg->{relRedir} 
		? "$env->{scriptUrlPath}/$scriptAndParam" 
		: "$schema://$host$env->{scriptUrlPath}/$scriptAndParam";  

	# Print HTTP redirection	
	if ($MP) {
		$ap->status($status);
		$ap->headers_out->{'Location'} = $location;
		$ap->send_http_header() if $MP1;
	}
	else {
		if ($cfg->{nph}) { print "HTTP/1.1 302 Found\n" }
		else { print "Status: $status\n" }
		print 
			map("Set-Cookie: $_\n", @{$m->{cookies}}),
			"Location: $location\n\n";
	}

	$m->finish();
}


###############################################################################
# User Functions

#------------------------------------------------------------------------------
# Get default user hash ref

sub initDefaultUser
{
	my $m = shift();

	my $cfg = $m->{cfg};

	$m->{user} = {
		default      => 1,
		id           => 0,
		admin        => 0,
		style        => $cfg->{style},
		timezone     => $cfg->{userTimezone},
		fontFace     => $cfg->{fontFace},
		fontSize     => $cfg->{fontSize},
		boardDescs   => $cfg->{boardDescs},
		showDeco     => $cfg->{showDeco},
		showAvatars  => $cfg->{showAvatars},
		showImages   => $cfg->{showImages},
		showSigs     => $cfg->{showSigs},
		indent       => $cfg->{indent},
		topicsPP     => $cfg->{topicsPP},
		postsPP      => $cfg->{postsPP},
		prevOnTime   => $m->getCookie('prevon') || 2147483647,
	};
}

#------------------------------------------------------------------------------
# Authenticate user

sub authenticateUser
{
	my $m = shift();
	
	my $cfg = $m->{cfg};
	if ($cfg->{authenPlg}{request}) {
		# Call request authentication plugin
		my $dbUser = $m->callPlugin($cfg->{authenPlg}{request});
		$m->{user} = $dbUser if $dbUser;
	}
	else {
		# Cookie authentication
		my ($id, $loginAuth) = $m->getCookie('login') =~ /([0-9]+):(.+)/;
		if ($id) {
			my $dbUser = $m->getUser($id);
			$m->{user} = $dbUser if $dbUser && length($loginAuth) && $loginAuth eq $dbUser->{loginAuth};
		}
	}
}

#------------------------------------------------------------------------------
# Do post-auth user setup and checking

sub initUser
{
	my $m = shift();

	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	my $env = $m->{env};
	my $user = $m->{user};
	my $userId = $m->{user}{id};
	
	# Set style and its path
	my $userStyle = $cfg->{styles}{$user->{style}} ? $user->{style} : $cfg->{style};
	my $styleOptions = $m->{styleOptions};
	%$styleOptions = $cfg->{styleOptions}{$userStyle} =~ /(\w+)="(.+?)"/g;
	my $testStyle = $m->paramStrId('css');
	if ($testStyle && $cfg->{styles}{$testStyle}) {
		# Preview style specified in URL
		$m->{style} = $cfg->{styles}{$testStyle};
		$m->{testStyle} = $testStyle;
	}
	elsif ($styleOptions->{excludeUA} && $env->{userAgent} =~ /$styleOptions->{excludeUA}/
		|| $styleOptions->{requireUA} && $env->{userAgent} !~ /$styleOptions->{requireUA}/) {
		# Fallback to default style if selected style is not compatible with UA
		$m->{style} = $cfg->{styles}{$cfg->{style}};
		%$styleOptions = $cfg->{styleOptions}{$m->{style}} =~ /(\w+)="(.+?)"/g;
	}
	else {
		# Use user's selected style
		$m->{style} = $cfg->{styles}{$userStyle};
	}
	
	# Show buttons icons?
	$m->{buttonIcons} = $styleOptions->{buttonIcons} && $user->{showDeco};

	# Set language
	$m->setLanguage();
	
	# Deny access if forum is in lockdown
	if ($cfg->{locked} && !$user->{admin} && $env->{script} ne 'user_login') {
		$m->printHeader();
		$m->printHints(['errForumLock', $cfg->{locked}]);
		$m->finish();
	}

	# Deny access if IP-blocked
	$m->checkIp() if !$m->{user}{id} && @{$cfg->{ipBlocks}};

	# Deny access if banned
	if ($userId && !$m->{user}{admin} && !$m->{allowBanned}) {
		my ($banTime, $reason, $duration) = $m->fetchArray("
			SELECT banTime, reason, duration FROM userBans WHERE userId = ?", $userId);
		if ($banTime) {
			my $durationStr = $duration ? "$lng->{errBannedT2} $duration $lng->{errBannedT3}" : "";
			$m->logAction(1, 'user', 'banned', $userId);
			$m->error("$lng->{errBannedT} $reason. $durationStr");
		}
	}
}

#------------------------------------------------------------------------------
# Cache board admin/board member status

sub cacheUserStatus
{
	my $m = shift();
	
	return if $m->{cachedUserStatus};
	
	my $boardAdmin = $m->{boardAdmin};
	my $boardMember = $m->{boardMember};
	my $userId = $m->{user}{id};
	my $boardId = undef;

	# Get groups user is member of
	my $groups = $m->fetchAllArray("
		SELECT groupId FROM groupMembers WHERE userId = ?", $userId);

	if (@$groups) {
		# Cache group admin status for boards
		my @groupIds = map($_->[0], @$groups);
		my $sth = $m->fetchSth("
			SELECT boardId FROM boardAdminGroups WHERE groupId IN (:groupIds)",
			{ groupIds => \@groupIds });
		$sth->bind_col(1, \$boardId);
		$boardAdmin->{$boardId} = 1 while $sth->fetch();

		# Cache group member status for boards
		$sth = $m->fetchSth("
			SELECT boardId FROM boardMemberGroups WHERE groupId IN (:groupIds)",
			{ groupIds => \@groupIds });
		$sth->bind_col(1, \$boardId);
		$boardMember->{$boardId} = 1 while $sth->fetch();
	}
	
	$m->{cachedUserStatus} = 1;
}

#------------------------------------------------------------------------------
# Get user hash ref from user id

sub getUser 
{
	my $m = shift();
	my $id = shift();

	return $m->fetchHash("
		SELECT * FROM users WHERE id = ?", $id);
}

#------------------------------------------------------------------------------
# Create user account

sub createUser
{
	my $m = shift();
	my %params = @_;

	my $cfg = $m->{cfg};

	# First user gets admin status with hardcoded password
	my $userNum = $m->fetchArray("
		SELECT COUNT(*) FROM users");
	my $admin = $userNum ? 0 : 1;
	$params{password} = "admin" if $admin;
	
	# Set values to params or defaults
	my $userName = $params{userName};
	my $realName = $params{realName} || "";
	my $email = $params{email} || "";
	my $openId = $params{openId} || "";
	my $notify = $m->firstDef($params{notify}, $cfg->{notify}, 0);
	my $msgNotify = $m->firstDef($params{msgNotify}, $cfg->{msgNotify});
	my $tempLogin = $m->firstDef($params{tempLogin}, $cfg->{tempLogin});
	my $privacy = $m->firstDef($params{privacy}, $cfg->{privacy});
	my $extra1 = $params{extra1} || "";
	my $extra2 = $params{extra2} || "";
	my $extra3 = $params{extra3} || "";
	my $birthyear = $m->firstDef($params{birthyear}, 0);
	my $birthday = $params{birthday} || "";
	my $location = $params{location} || "";
	my $timezone = $m->firstDef($params{timezone}, $cfg->{userTimezone});
	my $language = $m->firstDef($params{language}, $cfg->{language});
	my $style = $m->firstDef($params{style}, $cfg->{style});
	my $fontFace = $m->firstDef($params{fontFace}, $cfg->{fontFace});
	my $fontSize = $m->firstDef($params{fontSize}, $cfg->{fontSize});
	my $boardDescs = $m->firstDef($params{boardDescs}, $cfg->{boardDescs});
	my $showDeco = $m->firstDef($params{showDeco}, $cfg->{showDeco});
	my $showAvatars = $m->firstDef($params{showAvatars}, $cfg->{showAvatars});
	my $showImages = $m->firstDef($params{showImages}, $cfg->{showImages});
	my $showSigs = $m->firstDef($params{showSigs}, $cfg->{showSigs});
	my $collapse = $m->firstDef($params{collapse}, $cfg->{collapse});
	my $indent = $m->firstDef($params{indent}, $cfg->{indent});
	my $topicsPP = $m->firstDef($params{topicsPP}, $cfg->{topicsPP});
	my $postsPP = $m->firstDef($params{postsPP}, $cfg->{postsPP});
	my $prevOnTime = $params{prevOnTime} || $m->{now};
	my $ip = $cfg->{recordIp} ? $m->{env}{userIp} : "";
	my $bounceAuth = $m->randomId();
	my $salt = $m->randomId();
	my $password = $m->hashPassword($params{password}, $salt);
	my $loginAuth = $m->randomId();
	my $sourceAuth = $m->randomId();
	my $renamesLeft = $m->firstDef($params{renamesLeft}, $cfg->{renamesLeft});

	# Insert user	
	$m->dbDo("
		INSERT INTO users (
			userName, realName, email, openId, admin, notify, msgNotify, tempLogin, privacy,
			extra1, extra2, extra3, birthyear, birthday, location, timezone, language,
			style, fontFace, fontSize, boardDescs, showDeco, showAvatars, showImages, showSigs,
			collapse, indent, topicsPP, postsPP, regTime, lastOnTime, prevOnTime, 
			lastIp, bounceAuth, salt, password, loginAuth, sourceAuth, sourceAuth2, renamesLeft) 
		VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
		$userName, $realName, $email, $openId, $admin, $notify, $msgNotify, $tempLogin, $privacy,
		$extra1, $extra2, $extra3, $birthyear, $birthday, $location, $timezone, $language, 
		$style, $fontFace, $fontSize, $boardDescs, $showDeco, $showAvatars, $showImages, $showSigs,
		$collapse, $indent, $topicsPP, $postsPP, $m->{now}, $m->{now}, $prevOnTime,
		$ip, $bounceAuth, $salt, $password, $loginAuth, $sourceAuth, $sourceAuth, $renamesLeft);

	# Return id of created user	
	return $m->dbInsertId("users");
}

#------------------------------------------------------------------------------
# Update various user fields etc.

sub updateUser
{
	my $m = shift();

	my $cfg = $m->{cfg};
	my $user = $m->{user};
	my $env = $m->{env};
	my $updates = $m->{userUpdates};

	# Collect fields and values
	$updates->{lastOnTime} = $m->{now} if $m->{now} > $user->{lastOnTime} + 3;
	$updates->{lastIp} = $env->{userIp} if $user->{lastIp} ne $env->{userIp} && $cfg->{recordIp};
	$updates->{userAgent} = $m->escHtml($env->{userAgent}) if $user->{userAgent} ne $env->{userAgent};
	if ($env->{script} !~ /^topic_|^branch_|^post_|^poll_|^report_|^attach_/ 
		&& $user->{lastTopicId}) {
		$updates->{lastTopicId} = 0;
		$updates->{lastTopicTime} = 0;
	}

	# Assemble and execute update query
	my @values = ();
	my $query = "UPDATE users SET";
	for my $key (keys %$updates) {
		$query .= "\n$key = ?,";
		push @values, $updates->{$key};
	}
	chop $query;
	$m->dbDo("$query\nWHERE id = ?", @values, $user->{id}) if %$updates;

	# Delete notification
	if (my $noteId = $m->paramInt('dln')) {
		$m->dbDo("
			DELETE FROM notes WHERE id = ? AND userId = ?", $noteId, $user->{id});
	}
}

#------------------------------------------------------------------------------
# Delete user and dependent data

sub deleteUser
{
	my $m = shift();
	my $userId = shift();
	my $wipe = shift();  # Delete almost everything except account itself

	# Get user
	my $delUser = $m->getUser($userId);
	$delUser or $m->error('errUsrNotFnd');

	# Delete keyring and avatar
	my $cfg = $m->{cfg};
	if (my $path = $cfg->{attachFsPath}) {
		unlink "$path/keys/$userId.gpg";
		unlink "$path/keys/$userId.gpg~";
		unlink "$path/avatars/$delUser->{avatar}" 
			if $delUser->{avatar} && $delUser->{avatar} !~ /[\/:]/;
	}

	# Delete table entries	
	$m->dbDo("
		DELETE FROM userVariables WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM userBadges WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM userBans WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM groupAdmins WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM groupMembers WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM boardHiddenFlags WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM boardSubscriptions WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM topicSubscriptions WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM userIgnores WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM userIgnores WHERE ignoredId = ?", $userId);
	$m->dbDo("
		DELETE FROM topicReadTimes WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM messages WHERE receiverId = ?", $userId);
	$m->dbDo("
		DELETE FROM messages WHERE senderId = ?", $userId);
	$m->dbDo("
		DELETE FROM postLikes WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM postReports WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM pollVotes WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM notes WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM watchWords WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM watchUsers WHERE userId = ?", $userId);
	$m->dbDo("
		DELETE FROM watchUsers WHERE watchedId = ?", $userId);

	if ($wipe) {
		# Wipe profile fields, email, OpenID and password, copy some stuff into admin comments
		my $comment = $delUser->{comment}	. ($delUser->{comment} ? "<br/><br/>" : "")	. "WIPED"
			. ($delUser->{realName} ? "<br/>Real Name: $delUser->{realName}" : "")
			. ($delUser->{email} ? "<br/>Email: $delUser->{email}" : "")
			. ($delUser->{openId} ? "<br/>OpenID: $delUser->{openId}" : "");
		$m->dbDo("
			UPDATE users SET 
				email = '', realName = '', openId = '', title = '', blurb = '',
				homepage = '', occupation = '', hobbies = '', location = '', icq = '', 
				avatar = '', signature = '', extra1 = '', extra2 = '', extra3 = '',
				birthyear = 0, birthday = '',
				password = :password, comment = :comment
			WHERE id = :userId", 
			{ password => $m->randomId(), comment => $comment, userId => $userId });
	}
	else {
		# Set post user ids to 0 and delete user
		$m->dbDo("
			UPDATE posts SET userId = 0 WHERE userId = ?", $userId);
		$m->dbDo("
			DELETE FROM users WHERE id = ?", $userId);
	}
}


#------------------------------------------------------------------------------
# Check if user agent is blocked by IP

sub checkIp
{
	my $m = shift();

	eval { require Net::CIDR::Lite } 
		or $m->logError("Net::CIDR::Lite module not available.", 1), return;
	my $cidr = eval { Net::CIDR::Lite->new(map(/^([^\s#]+)/, @{$m->{cfg}{ipBlocks}})) }
		or $m->logError("Illegal IP format in ipBlocks option.", 1), return;
	if ($cidr->find($m->{env}{userIp})) {
		$m->logAction(2, 'ip', 'blocked');
		$m->error('errBlockIp');
	}
}

#------------------------------------------------------------------------------
# Check authorization with plugin

sub checkAuthz
{
	my $m = shift();
	my $authzUser = shift();
	my $action = shift();

	return if $m->{user}{admin};
	my $reason = $m->callPlugin($m->{cfg}{authzPlg}{$action}, user => $authzUser, @_);
	!$reason or $m->error($reason);
}

#------------------------------------------------------------------------------
# Check request source authentication value

sub checkSourceAuth
{
	my $m = shift();

	return 1 if !$m->{user}{id};
	my $auth = $m->paramStr('auth');
	return 0 if !length($auth);
	return $auth eq $m->{user}{sourceAuth} || $auth eq $m->{user}{sourceAuth2};
}
	
#------------------------------------------------------------------------------
# Get cookie

sub getCookie
{
	my $m = shift();
	my $name = shift();

	for (split(/;\s*/, $m->{env}{cookie})) {
		my ($n, $v) = /^\s*([^=\s]+)\s*=\s*(.*?)\s*\z/;
		return $v if $n eq $m->{cfg}{cookiePrefix}.$name;
	}
}

#------------------------------------------------------------------------------
# Set cookie

sub setCookie
{
	my $m = shift();
	my $name = shift();
	my $value = shift();
	my $temp = shift() || 0;
	my $http = shift() || 1;
	
	my $cfg = $m->{cfg};
	my $domain = $cfg->{cookieDomain} ? "domain=$cfg->{cookieDomain}; " : "";
	my $path = "path=" . ($cfg->{cookiePath} || $m->{env}{scriptUrlPath} || "/") . "; ";
	my $expires = !$temp ? "expires=Wed, 31-Dec-2031 00:00:00 GMT; " : "";
	my $secure = $cfg->{sslOnly} ? "secure; " : "";
	$http = $http ? "httpOnly" : "";
	my $cookie = "$cfg->{cookiePrefix}$name=$value; $domain$path$expires$secure$http";

	if ($MP) { $m->{ap}->err_headers_out->add('Set-Cookie' => $cookie) }
	else { push @{$m->{cookies}}, $cookie }
}

#------------------------------------------------------------------------------
# Remove cookie

sub deleteCookie
{
	my $m = shift();
	my $name = shift();

	my $cfg = $m->{cfg};
	my $domain = $cfg->{cookieDomain} ? "domain=$cfg->{cookieDomain}; " : "";
	my $path = "path=" . ($cfg->{cookiePath} || $m->{env}{scriptUrlPath} || "/") . "; ";
	my $expires = "expires=Thu, 01-Jan-1970 00:00:00 GMT";
	my $cookie = "$cfg->{cookiePrefix}$name=; $domain$path$expires";

	if ($MP) { $m->{ap}->err_headers_out->add('Set-Cookie' => $cookie) }
	else { push @{$m->{cookies}}, $cookie }
}


###############################################################################
# Board Functions

#------------------------------------------------------------------------------
# Check if user is board moderator

sub boardAdmin
{
	my $m = shift();
	my $userId = shift();
	my $boardId = shift();

	# Return cached status if query is for current user
	if ($userId == $m->{user}{id} && $m->{cachedUserStatus}) {
		return 1 if $m->{boardAdmin}{$boardId};
		return 0;
	}

	# Otherwise fetch status from database
	return 1 if $m->fetchArray("
		SELECT 1
		FROM groupMembers AS groupMembers
			INNER JOIN boardAdminGroups AS boardAdminGroups
				ON boardAdminGroups.groupId = groupMembers.groupId
				AND boardAdminGroups.boardId = :boardId
		WHERE groupMembers.userId = :userId",
		{ boardId => $boardId, userId => $userId });
	
	return 0;
}

#------------------------------------------------------------------------------
# Check if user is board member

sub boardMember
{
	my $m = shift();
	my $userId = shift();
	my $boardId = shift();

	# Return cached status if query is for current user
	if ($userId == $m->{user}{id} && $m->{cachedUserStatus}) {
		return 1 if $m->{boardMember}{$boardId};
		return 0;
	}

	# Otherwise fetch status from database
	return 1 if $m->fetchArray("
		SELECT 1
		FROM groupMembers AS groupMembers
			INNER JOIN boardMemberGroups AS boardMemberGroups
				ON boardMemberGroups.groupId = groupMembers.groupId
				AND boardMemberGroups.boardId = :boardId
		WHERE groupMembers.userId = :userId",
		{ boardId => $boardId, userId => $userId });
	
	return 0;
}

#------------------------------------------------------------------------------
# Check if user has write access to board

sub boardWritable
{
	my $m = shift();
	my $board = shift();
	my $replyOrEdit = shift() || 0;

	my $user = $m->{user};
	return 0 if !$user->{id} && !$board->{unregistered};
	return 1 if $board->{announce} == 0;
	return 1 if $board->{announce} == 2 && $replyOrEdit;
	return 1 if $user->{admin};
	return 1 if $m->boardMember($user->{id}, $board->{id});
	return 1 if $m->boardAdmin($user->{id}, $board->{id});
	return 0;
}

#------------------------------------------------------------------------------
# Check if user has read access to board

sub boardVisible
{
	my $m = shift();
	my $board = shift();
	my $user = shift() || $m->{user};

	# Call authz plugin
	my $cfg = $m->{cfg};
	if ($cfg->{authzPlg}{viewBoard}) { 
		my $result = $m->callPlugin($cfg->{authzPlg}{viewBoard}, user => $user, board => $board);
		return 1 if $result == 2;  # unconditional access
		return 0 if $result == 1;  # access denied
	}

	# Normal access checking
	return 1 if $board->{private} == 0;
	return 0 if !$user->{id};
	return 1 if $board->{private} == 2;
	return 1 if $user->{admin};
	return 1 if $m->boardMember($user->{id}, $board->{id});
	return 1 if $m->boardAdmin($user->{id}, $board->{id});
	return 0;
}

#------------------------------------------------------------------------------
# Check if user is topic moderator

sub topicAdmin
{
	my $m = shift();
	my $userId = shift();
	my $topicId = shift();

	return scalar $m->fetchArray("
		SELECT userId = ? FROM posts WHERE id = (SELECT basePostId FROM topics WHERE id = ?)", 
		$userId, $topicId);
}


###############################################################################
# Output Functions

#------------------------------------------------------------------------------
# Print HTTP header

sub printHttpHeader
{
	my $m = shift();
	my $headers = shift() || {};

	# Return if header was already printed
	return if $m->{printPhase} >= 1;

	# Set content type etc.
	if ($m->{ajax}) { $m->{contentType} ||= "application/json; charset=utf-8" }
	else { $m->{contentType} ||= "text/html; charset=utf-8" }

	# Add standard and conditional headers	
	my $cfg = $m->{cfg};
	$headers->{'Cache-Control'} = "private";

	# Print headers
	my $ap = $m->{ap};
	if ($MP) {
		$ap->status(200);
		$ap->content_type($m->{contentType});
		my $ho = $ap->headers_out();
		$ho->{$_} = $headers->{$_} for sort keys %$headers;
		for (@{$cfg->{httpHeader}}) {
			my ($name, $value) = /([\w-]+): (.+)/;
			$ho->{$name} = $value if $name;
		}
	}
	else {
		print 
			$cfg->{nph} ? "HTTP/1.1 200 OK\n" : "",
			"Content-Type: $m->{contentType}\n",
			map("$_: $headers->{$_}\n", sort keys %$headers),
			map("Set-Cookie: $_\n", @{$m->{cookies}}),
			map("$_\n", @{$cfg->{httpHeader}});
	}

	# Call include plugin
	$m->callPlugin($_) for @{$cfg->{includePlg}{httpHeader}};

	# End HTTP header
	if ($MP1) { $ap->send_http_header() }
	elsif ($CGI) { print "\n" }
	$m->{printPhase} = 1;
}

#------------------------------------------------------------------------------
# Print page header

sub printHeader 
{
	my $m = shift();
	my $title = shift() || undef;
	my $jsParams = shift() || {};

	# Return if header was already printed
	return if $m->{printPhase} >= 2;

	my $ap = $m->{ap};
	my $env = $m->{env};
	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	my $user = $m->{user};
	my $userId = $user->{id};
	my $script = $env->{script};
	my $dataPath = $cfg->{dataPath};

	# Print HTTP header if not already done
	$m->printHttpHeader() if $m->{printPhase} < 1;

	# Begin HTML5 header
	print 
		"<!DOCTYPE html>\n<html>\n<head>\n",
		"<meta http-equiv='content-type' content='text/html; charset=utf-8'>\n";

	# Search engines should only index pages or follow links where it makes sense
	if ($cfg->{noIndex} || $m->{noIndex} 
		|| !($script eq 'forum_show' || $script eq 'board_show' || $script eq 'topic_show')
		|| $script eq 'topic_show' && (grep(!/^(?:tid|pg)\z/, $m->params())
		|| $m->paramInt('pg') == 1)) {
		@{$m->{robotMetas}}{'noindex', 'nofollow'} = (1, 1);
	}
	elsif ($script eq 'forum_show' || $script eq 'board_show') {
		$m->{robotMetas}{'noindex'} = 1;
	}
	$m->{robotMetas}{'noarchive'} = 1 if $cfg->{noArchive};
	$m->{robotMetas}{'nosnippet'} = 1 if $cfg->{noSnippet};
	print "<meta name='robots' content='", join(",", keys %{$m->{robotMetas}}), "'>\n"
		if %{$m->{robotMetas}};

	# OpenSearchDescription link
	print 
		"<link rel='search' href='$dataPath/opensearch.xml'",
		" type='application/opensearchdescription+xml' title='$cfg->{forumName}'>\n"
		if $cfg->{openSearch};

	# Feed links
	if ($cfg->{rssDiscovery} && $script eq 'forum_show') {
		print
			"<link rel='alternate' href='$cfg->{attachUrlPath}/xml/forum.atom10.xml'",
			" type='application/atom+xml' title='$lng->{frmForumFeed} (Atom 1.0)'>\n",
			"<link rel='alternate' href='$cfg->{attachUrlPath}/xml/forum.rss200.xml'",
			" type='application/rss+xml' title='$lng->{frmForumFeed} (RSS 2.0)'>\n";
	}
	if ($cfg->{rssDiscovery} && $script eq 'board_show') {
		my $boardId = $m->paramInt('bid');
		print
			"<link rel='alternate' href='$cfg->{attachUrlPath}/xml/board$boardId.atom10.xml'",
			" type='application/atom+xml' title='$lng->{brdBoardFeed} (Atom 1.0)'>\n",
			"<link rel='alternate' href='$cfg->{attachUrlPath}/xml/board$boardId.rss200.xml'",
			" type='application/rss+xml' title='$lng->{brdBoardFeed} (RSS 2.0)'>\n"
			if $boardId;
	}

	# Style-independent, style-dependent and local stylesheets
	print 
		"<link rel='stylesheet' href='$dataPath/mwforum.css'>\n",
		"<link rel='stylesheet' href='$dataPath/$m->{style}/$m->{style}.css'>\n",
		$cfg->{forumStyle} ? "<link rel='stylesheet' href='$dataPath/$cfg->{forumStyle}'>\n" : "";
	
	# Inline styles
	my $fontFaceStr = $user->{fontFace} ? "font-family: '$user->{fontFace}', sans-serif;" : "";
	my $fontSizeStr = $user->{fontSize} ? "font-size: $user->{fontSize}px" : "";
	print
		"<style>\n",
		"body, input, textarea, select, button { $fontFaceStr $fontSizeStr }\n",
		"img.ava { width: $cfg->{avatarWidth}px; height: $cfg->{avatarHeight}px }\n",
		map("span.cst_$_ { $cfg->{customStyles}{$_} }\n", keys %{$cfg->{customStyles}});

	# Style snippets
	if (%{$cfg->{styleSnippets}} && $m->{dbh}) {
		my $snippets = $m->fetchAllArray("
			SELECT name FROM userVariables WHERE userId = ? AND name LIKE ?", $userId, 'sty%');
		print map("$cfg->{styleSnippets}{$_->[0]}\n", @$snippets);
	}
	print "</style>\n";

	# Include Javascript
	my $autocomplete = $m->{autocomplete} && $userId && !$cfg->{noAutocomplete};
	$jsParams->{autocomplete} = $m->{autocomplete} if $autocomplete;
	$jsParams->{m_ext} = $m->{ext};
	$jsParams->{env_script} = $script;
	$jsParams->{cfg_dataPath} = $dataPath;
	$jsParams->{user_sourceAuth} = $user->{sourceAuth} if $userId;
	$jsParams->{cfg_boardJumpList} = 1 if $cfg->{boardJumpList};
	my $json = $m->json($jsParams);
	print "<script src='$dataPath/jquery.js'></script>\n";
	print "<script src='$dataPath/jquery.autocomplete.js'></script>\n" if $autocomplete;
	print "<script src='$dataPath/mwforum.js' id='mwfjs' data-params='$json'></script>\n";
	
	# Print header includes
	print $cfg->{htmlHeader}, "\n" if $cfg->{htmlHeader};
	$m->callPlugin($_) for @{$cfg->{includePlg}{htmlHeader}};

	# End head, start body
	$title ||= $cfg->{forumName};
	print 
		"<title>$title</title>\n",
		"</head>\n",
		"<body class='$script'>\n\n";

	# Print top includes
	print $cfg->{htmlTop}, "\n\n" if $cfg->{htmlTop};
	$m->callPlugin($_) for @{$cfg->{includePlg}{top}};

	# Print title image
	my $topUrl = $m->url('forum_show');
	if ($cfg->{titleImage} && $script ne 'attach_show') {
		print
			"<div class='tim'><a href='$topUrl'>",
			"<img src='$dataPath/$cfg->{titleImage}' alt=''>",
			"</a></div>\n\n";
	}

	# Print wrapper divs for shadow effects etc.	
	print "<div id='dv1'><div id='dv2'><div id='dv3'>\n\n" if $m->{styleOptions}{wrapperDivs};

	# Print top bar
	my $topMsg = "";
	$topMsg .= " - <em>$lng->{hdrArchive}</em>"
		if $m->{archive} && $script =~ /^(?:(?:forum|board|topic)_show|forum_search)\z/;
	$topMsg .= " - <em>FORUM IS LOCKED</em>" if $cfg->{locked} && $user->{admin};
	my $nameStr = !$userId ? $lng->{hdrNoLogin} :
		"<span class='htt'>$lng->{hdrWelcome}</span> $user->{userName}";
	$nameStr = "<span class='nav'>$nameStr</span>";
	print
		"<div class='frm tpb'>\n",
		$cfg->{pageIcons} && $user->{showDeco}
			? "<img class='pic' src='$dataPath/pageicons/$script.png' alt=''>\n" : "",
		"<div class='hcl'>$nameStr<span class='htt'>$cfg->{forumName}</span>$topMsg</div>\n",
		"<div class='bcl'>\n",
		$m->buttonLink($topUrl, 'hdrForum', 'forum');

	# Print home link
	print $m->buttonLink($cfg->{homeUrl}, $cfg->{homeTitle}, 'home') if $cfg->{homeUrl};

	# Print help link
	print $m->buttonLink($m->url('forum_help'), 'hdrHelp', 'help');
		
	# Print search link
	print $m->buttonLink($m->url('forum_search'), 'hdrSearch', 'search') 
		if $cfg->{forumSearch} == 1 || $cfg->{forumSearch} == 2 && $userId || $cfg->{googleSearch};

	# Print chat link
	print $m->buttonLink($m->url('chat_show'), 'hdrChat', 'chat')
		if $cfg->{chat} && ($cfg->{chat} < 2 || $userId);

	# Print private messages link
	print $m->buttonLink($m->url('message_list'), 'hdrMsgs', 'message') 
		if $cfg->{messages} && $userId;

	# Print user profile and options links
	print $m->buttonLink($m->url('user_profile'), 'hdrProfile', 'profile') if $userId;
	print $m->buttonLink($m->url('user_options'), 'hdrOptions', 'options') if $userId;

	# Print user registration link
	print $m->buttonLink("user_register$m->{ext}", 'hdrReg', 'user')
		if (!$userId && $cfg->{openId} != 2 && !$cfg->{adminUserReg} 
			&& !$cfg->{authenPlg}{login} && !$cfg->{authenPlg}{request})
		|| ($cfg->{adminUserReg} && $user->{admin});

	# Print user login link
	if (!$userId && $cfg->{openId} != 2 && !$cfg->{authenPlg}{request}) {
		my $url = $m->url('user_login', $script !~ /^user_|^forum_show/ ? (ori => 1) : ());
		print $m->buttonLink($url, 'hdrLogin', 'login');
	}

	# Print OpenID login link
	if (!$userId && $cfg->{openId} && !$cfg->{authenPlg}{request}) {
		my $url = $m->url('user_openid', $script !~ /^user_|^forum_show/ ? (ori => 1) : ());
		print $m->buttonLink($url, 'hdrOpenId', 'openid');
	}

	# Print logout link
	if ($userId && !$cfg->{authenPlg}{request}) {
		my $url = $m->url('user_logout', auth => 1);
		print	$m->buttonLink($url, 'hdrLogout', 'logout');
	}

	# Print plugin links
	if ($cfg->{includePlg}{topUserLink}) {
		my @userLinks;
		$m->callPlugin($_, links => \@userLinks) for @{$cfg->{includePlg}{topUserLink}};
		print @userLinks;
	}

	print	"</div>\n</div>\n\n";
	
	# Print obsolete browser warning
	if (index($env->{userAgent}, "MSIE 6") > -1) {
		print
			"<!--[if lt IE 7]>\n",
			"<div class='frm hnt err'>\n",
			"<div class='ccl'>\n",
			"<img class='sic sic_hint_error' src='$dataPath/epx.png' alt=''>\n",
			"<p>$lng->{errOldAgent}</p>\n",
			"</div>\n",
			"</div>\n",
			"<![endif]-->\n\n";
	}

	# Print execution message
	my $execMsg = $m->paramStrId('msg') || $m->{execMsg};
	print
		"<div class='frm hnt exe'>\n",
		"<div class='ccl'>\n",
		"<img class='sic sic_hint_exec' src='$dataPath/epx.png' alt=''>\n",
		"<p>", ($lng->{"msg$execMsg"} || $execMsg), "</p>\n",
		"</div>\n",
		"</div>\n\n"
		if $execMsg;
		
	# Print includes
	print $cfg->{htmlMiddle}, "\n\n" if $cfg->{htmlMiddle};
	$m->callPlugin($_) for @{$cfg->{includePlg}{middle}};

	$m->{printPhase} = 2;
}

#------------------------------------------------------------------------------
# Print page footer

sub printFooter 
{
	my $m = shift();
	my $hideBoardList = shift() || 0;
	my $boardId = shift() || undef;

	# Return if footer was already printed
	return if $m->{printPhase} >= 4;

	my $ap = $m->{ap};
	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	my $dbh = $m->{dbh};
	my $user = $m->{user};

	# Print jump-to-board list	
	if ($cfg->{boardJumpList} && !$hideBoardList && $dbh) {
		# Get boards
		my $boards = $m->fetchAllHash("
			SELECT boards.*,
				categories.title AS categTitle
			FROM boards AS boards
				INNER JOIN categories AS categories
					ON categories.id = boards.categoryId
			ORDER BY categories.pos, boards.pos");
		@$boards = grep($m->boardVisible($_), @$boards);

		# Print list
		print
			"<form class='bjp' action='board_show$m->{ext}' method='get'>\n",
			"<div>\n",
			"<select name='bid' size='1'>\n",
			"<option value='0'>$lng->{comBoardList}</option>\n";
			
		my $lastCategId = 0;
		for my $board (@$boards) {
			if ($board->{categoryId} != $lastCategId) {
				$lastCategId = $board->{categoryId};
				print "<option value='cid$board->{categoryId}'>$board->{categTitle}</option>\n";
			}
			my $sel = $boardId && $board->{id} == $boardId ? 'selected' : "";
			print "<option value='$board->{id}' $sel>- $board->{title}</option>\n";
		}

		print "</select>\n</div>\n</form>\n\n";
	}

	# Print wrapper divs for shadow effects etc.	
	print "</div></div></div>\n\n" if $m->{styleOptions}{wrapperDivs};

	# Print copyright message
	print
		"<p class='cpr'>Powered by <a href='http://www.mwforum.org/'>mwForum</a>",
		" $VERSION &#169; 1999-2013 Markus Wichitill</p>\n\n"
		if $m->{env}{script} ne 'forum_info' && $m->{env}{script} ne 'attach_show';
		
	# Print includes
	print $cfg->{htmlBottom}, "\n\n" if $cfg->{htmlBottom};
	$m->callPlugin($_) for @{$cfg->{includePlg}{bottom}};
	
	# Print page creation time
	if ($m->{gcfg}{pageTime}) {
		my $time = Time::HiRes::tv_interval($m->{startTime});
		$time = sprintf("%.3f", $time);
		print "<p class='pct'>Page created in ${time}s with $m->{queryNum} database queries.</p>\n\n";
	}

	# Print non-fatal warnings, since many admins never check webserver log
	if (@{$m->{warnings}}) {
		print
			"<div class='frm hnt err'>\n",
			"<div class='ccl'>\n",
			"<img class='sic sic_hint_error' src='$m->{cfg}{dataPath}/epx.png' alt=''>\n",
			map("<p>" . $m->escHtml($_) . "</p>\n", @{$m->{warnings}}),
			"</div>\n",
			"</div>\n\n";
	}

	print	"</body>\n</html>\n";

	$m->{printPhase} = 4;
}

#------------------------------------------------------------------------------
# Print page bar

sub printPageBar
{
	my $m = shift();
	my %params = @_;
	my $mainTitle = $params{mainTitle};
	my $subTitle = $params{subTitle};
	my $navLinks = $params{navLinks};
	my $pageLinks = $params{pageLinks};
	my $userLinks = $params{userLinks};
	my $adminLinks = $params{adminLinks};

	# Use cached version for repeated page bar (topic page)
	my @lines = $params{repeat} ? @{$m->{pageBar}} : ();
	if (@lines) {
		print @lines;
		return;
	}

	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	my $emptyPixel = "src='$cfg->{dataPath}/epx.png'";

	# Start
	push @lines,
		"<div class='frm pgb'>\n",
		"<div class='hcl'>\n",
		"<span class='nav'>\n";

	# Navigation button links
	for my $link (@$navLinks) {
		my $textId = $link->{txt};
		my $text = $lng->{$textId} || $textId;
		my $textTT = $lng->{$textId . 'TT'};
		$link->{dsb}
			? push @lines, 
				"<img class='sic sic_nav_$link->{ico}_d' $emptyPixel title='$textTT' alt='$text'>\n"
			: push @lines, "<a href='$link->{url}'>",
				"<img class='sic sic_nav_$link->{ico}' $emptyPixel title='$textTT' alt='$text'></a>\n";
	}

	# Title
	push @lines, 
		"</span>\n",
		"<span class='htt'>$mainTitle</span> $subTitle\n",
		"</div>\n";

	# Page links
	my @bclLines = ();
	if ($pageLinks && @$pageLinks) {
		push @bclLines, "<span class='pln'>\n";
		for my $link (@$pageLinks) {
			my $textId = $link->{txt};
			my $text = $lng->{$textId} || $textId;
			my $textTT = $lng->{$textId . 'TT'};
			if (my ($dir) = $textId =~ /(Up|Prev|Next)/) {
				# Prev/next page icons
				my $img = "nav_" . lc($dir);
				$link->{dsb} 
					? push @bclLines, 
						"<img class='sic dsb sic_${img}_d' $emptyPixel title='$textTT' alt='$text'>\n"
					: push @bclLines, "<a href='$link->{url}'>",
						"<img class='sic sic_${img}' $emptyPixel title='$textTT' alt='$text'></a>\n";
			}
			elsif ($textId eq "..." || $textId eq "&#8230;") {
				push @bclLines, "&#8230;\n";
			}
			else {
				# Page number links
				$link->{dsb}
					? push @bclLines, "<span>$text</span>\n"
					: push @bclLines, "<a href='$link->{url}'>$text</a>\n";
			}
		}
		push @bclLines, "</span>\n";
	}

	# Normal button links
	if ($userLinks && @$userLinks) {
		push @bclLines, "<div class='nbl'>\n" if @$userLinks;
		for my $link (@$userLinks) {
			my $textId = $link->{txt};
			my $text = $lng->{$textId} || $textId;
			my $textTT = $lng->{$textId . 'TT'};
			$link->{ico} && $m->{buttonIcons}
				? push @bclLines, "<a href='$link->{url}' title='$textTT'>",
					"<img class='bic bic_$link->{ico}' $emptyPixel alt=''> $text</a>\n"
				: push @bclLines, "<a href='$link->{url}' title='$textTT'>$text</a>\n";
		}
		push @bclLines, "</div>\n" if @$userLinks;
	}

	# Admin button links
	if ($adminLinks && @$adminLinks) {
		push @bclLines, "<div class='abl'>\n" if @$adminLinks;
		for my $link (@$adminLinks) {
			my $textId = $link->{txt};
			my $text = $lng->{$textId} || $textId;
			my $textTT = $lng->{$textId . 'TT'};
			$link->{ico} && $m->{buttonIcons}
				? push @bclLines, "<a href='$link->{url}' title='$textTT'>",
					"<img class='bic bic_$link->{ico}' $emptyPixel alt=''> $text</a>\n"
				: push @bclLines, "<a href='$link->{url}' title='$textTT'>$text</a>\n";
		}
		push @bclLines, "</div>\n" if @$adminLinks;
	}

	# If there's only page links, we need a filler space or float breaks
	push @bclLines, "&#160;\n" 
		if $pageLinks && @$pageLinks && !($userLinks && @$userLinks || $adminLinks && @$adminLinks);
	push @lines, "<div class='bcl'>\n",	@bclLines, "</div>\n" if @bclLines;
	push @lines, "</div>\n\n";

	# Print and cache bar
	print @lines;
	$m->{pageBar} = \@lines;
}

#------------------------------------------------------------------------------
# Print hint box

sub printHints
{
	my $m = shift();
	my $msgs = shift();
	my $id = shift() || undef;
	my $hidden = shift() || 0;
	
	$id = $id ? " id='" . $id . "'" : "";
	$hidden = $hidden ? " style='display: none'" : "";

	print
		"<div class='frm hnt inf'$id$hidden>\n",
		"<div class='ccl'>\n",
		"<img class='sic sic_hint_info' src='$m->{cfg}{dataPath}/epx.png' alt=''>\n",
		map("<p>" . ($m->{lng}{$_} || $_) . "</p>\n", @$msgs),
		"</div>\n",
		"</div>\n\n";
}

#------------------------------------------------------------------------------
# Get page number links and nav buttons

sub pageLinks
{
	my $m = shift();
	my $script = shift();
	my $params = shift();
	my $page = shift();
	my $pageNum = shift();

	# First, second, next-to-last, last, current and two surrounding current
	my @pages = $pageNum <= 10 ? (1 .. $pageNum) : (
		1, 
		2,
		$page > 5                         ? 0 : (),
		$page > 4                         ? $page - 2 : (),
		$page > 3 && $page < $pageNum     ? $page - 1 : (),
		$page > 2 && $page < $pageNum - 1 ? $page : (),
		$page > 1 && $page < $pageNum - 2 ? $page + 1 : (),
		             $page < $pageNum - 3 ? $page + 2 : (),
		             $page < $pageNum - 4 ? 0 : (),
		$pageNum - 1,
		$pageNum);
	my @pageLinks = ();
	push @pageLinks, $_ == 0 ? { txt => "&#8230;" }
		: { url => $m->url($script, @$params, pg => $_), txt => $_, dsb => $_ == $page }
		for @pages;

	# Previous and next nav buttons
	push @pageLinks, { url => $m->url($script, @$params, pg => $page - 1), 
		txt => 'comPgPrev', dsb => $page == 1 };
	push @pageLinks, { url => $m->url($script, @$params, pg => $page + 1), 
		txt => 'comPgNext', dsb => $page == $pageNum };

	return @pageLinks;
}

#------------------------------------------------------------------------------
# Get button link markup

sub buttonLink
{
	my $m = shift();
	my $url = shift();
	my $textId = shift();
	my $icon = shift();

	my $text = $m->{lng}{$textId} || $textId;
	my $title = $m->{lng}{$textId . 'TT'};
	my $str = "<a href='$url' title='$title'>";
	$str .= "<img class='bic bic_$icon' src='$m->{cfg}{dataPath}/epx.png' alt=''> "
		if $icon && $m->{buttonIcons};
	$str .= $text . "</a>\n";
	return $str;
}

#------------------------------------------------------------------------------
# Get submit button markup

sub submitButton
{
	my $m = shift();
	my $text = shift();
	my $icon = shift();
	my $name = shift();

	$text = $m->{lng}{$text} || $text;
	my $nameStr = $name ? "name='$name' value='1'" : "";
	my $img = $m->{buttonIcons} 
		? "<img class='bic bic_$icon' src='$m->{cfg}{dataPath}/epx.png' alt=''> " : "";
	return "<button type='submit' class='isb' $nameStr> $img$text</button>\n";
}

#------------------------------------------------------------------------------
# Get tag buttons markup for post forms

sub tagButtons
{
	my $m = shift();
	my $board = shift() || {};

	my $cfg = $m->{cfg};
	my $lng = $m->{lng};

	# Call include plugin used instead of code below
	return $m->callPlugin($cfg->{includePlg}{tagButtons}) if $cfg->{includePlg}{tagButtons};

	# Don't print when disabled
	return if $cfg->{tagButtons} < 1;

	# Print [tag] buttons
	my @lines = ("<div class='tbb'>\n");
	push @lines,
		"<button type='button' class='tbt' id='tbt_b' accesskey='b' tabindex='-1'",
		" title='$lng->{tbbBold} ($lng->{tbbMod}+B)'><b>b</b></button>\n",
		"<button type='button' class='tbt' id='tbt_i' accesskey='i' tabindex='-1'",
		" title='$lng->{tbbItalic} ($lng->{tbbMod}+I)'><i>i</i></button>\n",
		"<button type='button' class='tbt' id='tbt_tt' accesskey='t' tabindex='-1'",
		" title='$lng->{tbbTeletype} ($lng->{tbbMod}+T)'>tt</button>\n",
		"<button type='button' class='tbt tbt_p' id='tbt_url' accesskey='w' tabindex='-1'",
		" title='URL ($lng->{tbbMod}+W)'>url</button>\n";

	# Print image tag button
	push @lines,
		"<button type='button' class='tbt' id='tbt_img' accesskey='p' tabindex='-1'",
		" title='$lng->{tbbImage} ($lng->{tbbMod}+P)'>img</button>\n"
		if $cfg->{imgTag};

	# Print video tag button
	push @lines,
		"<button type='button' class='tbt' id='tbt_vid_youtube' accesskey='v' tabindex='-1'",
		" title='$lng->{tbbVideo} ($lng->{tbbMod}+V)'>vid</button>\n"
		if $cfg->{videoTag};

	# Print custom style button(s)
	if ($cfg->{cstButtons} == 1) {
		push @lines,
			"<button type='button' class='tbt tbt_p' id='tbt_c' accesskey='c' tabindex='-1'",
			" title='$lng->{tbbCustom} ($lng->{tbbMod}+C)'>c</button>\n";
	}
	elsif ($cfg->{cstButtons} == 2) {
		for my $name (sort keys %{$cfg->{customStyles}}) {
			my $tooltip = $m->escHtml($cfg->{customStyles}{$name});
			push @lines, 
				"<button type='button' class='tbt' id='tbt_c_$name' tabindex='-1'",
				" title='$tooltip'>$name</button>\n";
		}
	}

	# Call include plugin for additional buttons
	$m->callPlugin($_, lines => \@lines) for @{$cfg->{includePlg}{tagButton}};

	# Print text snippet list
	if ($cfg->{textSnippets}) {
		my (@names, @texts, $skip);
		for my $line (split(/\n/, $cfg->{textSnippets})) {
			my ($name, $boardStr) = $line =~ /^\[\[(.+?)(=[\d,]+)?\]\]\z/;
			if ($boardStr && $boardStr !~ /\b$board->{id}\b/) {
				$skip = 1;
				next;
			}
			if ($name) {
				push @names, $name;
				$skip = 0;
			}
			elsif (!$skip) { 
				$texts[@names - 1] .= "$line\n";
			}
		}
		if (@names) {
			push @lines, "<dl id='snippets' style='display: none'>\n";
			for (my $i = 0; $i < @names; $i++) {
				push @lines, "<dt>$names[$i]</dt>\n<dd><pre>$texts[$i]</pre></dd>\n";
			}
			push @lines, "</dl>\n";
		}
	}

	# Print :tag: buttons
	if ($cfg->{tagButtons} == 2) {
		push @lines, "</div>\n<div class='tbb'>\n";
		for my $key (sort keys %{$cfg->{tags}}) {
			my $value = $cfg->{tags}{$key};
			next if substr($value, 0, 1) eq "?";
			$value =~ s/^[?!]//;
			$value =~ s!\[\[dataPath\]\]!$cfg->{dataPath}!g;
			push @lines, "<span class='tbc' id='tbc_$key'>$value</span>\n" 
		}
	}

	push @lines, "</div>\n";
	return @lines;
}

#------------------------------------------------------------------------------
# Return hidden standard form fields

sub stdFormFields
{
	my $m = shift();

	my @lines = ();
	push @lines, "<input type='hidden' name='subm' value='1'>\n";
	push @lines, "<input type='hidden' name='auth' value='$m->{user}{sourceAuth}'>\n"
		if $m->{user} && $m->{user}{sourceAuth};
	my $originEsc = $m->escHtml($m->paramStr('ori'));
	push @lines, "<input type='hidden' name='ori' value='$originEsc'>\n" if $originEsc;
	return @lines;
}


###############################################################################
# Error Functions

#------------------------------------------------------------------------------
# Print error message and exit

sub error 
{
	my $m = shift();
	my $msg = shift();

	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	
	# Avoid recursion
	return if $m->{error};
	$m->{error} = 1;

	# Default to English if error came too early for regular language loading
	if (!$lng->{errDefault}) {
		eval {
			require MwfEnglish;
			$m->{lng} = $lng = $MwfEnglish::lng;
		};
	}

	# Use string id or literal string
	$msg = $lng->{$msg} || $msg || $lng->{errDefault};

	# Log error
	$m->logError($msg);
	
	if (index($m->{contentType}, "application/json") == 0) {
		# JSON output
		$m->printHttpHeader();
		my $msgEsc = $m->escHtml($msg, 2);
		print "{ \"error\": \"$msgEsc\" }";
	}
	elsif (index($m->{contentType}, "text/plain") == 0) {
		# No output
	}
	elsif ($m->{env}{script}) {
		# Normal CGI output
		$m->{noIndex} = 1;
		$m->printHeader();
		my $msgEsc = $m->escHtml($msg, 2);
		print
			"<div class='frm hnt err'>\n",
			"<div class='ccl'>\n",
			"<img class='sic sic_hint_error' src='$cfg->{dataPath}/epx.png' alt=''>\n",
			"<p>$msgEsc</p>\n",
			"</div>\n",
			"</div>\n\n";
		$m->printFooter(1);
	}
	else {
		# Output for cronjobs and shell scripts
		print "$msg\n";
		$m->{printPhase} = 4;
	}

	# Rollback transaction if one was active
	if (my $dbh = $m->{dbh}) {
		$dbh->rollback() if $dbh->{AutoCommit} == 0;
		$dbh->disconnect();
	}
	
	# Don't continue
	$FCGI ? die : exit;
}

#------------------------------------------------------------------------------
# Database error

sub dbError 
{
	my $m = shift();

	# Prepare error message	
	$m->{query} =~ s!\t!!g;
	$m->{query} =~ s!^\n+!!g;
	$m->{query} =~ s!\n+\z!!g;
	$m->{query} =~ s!\n{3,}!\n\n!g;
	my $errStr = "$DBI::errstr";
	utf8::decode($errStr) if !utf8::is_utf8($errStr);
	my $msg = "$errStr\n\n$m->{query}";

	if ($m->{cfg}{dbHideError} && !$m->{user}{admin}) {
		# Log detailed error message but print basic error message only
		$m->logError($msg);
		$m->error('errDbHidden');
	}
	else {
		# Print detailed error message
		$m->error($msg);
	}
}

#------------------------------------------------------------------------------
# Problem with form input, add message to list and continue

sub formError
{
	my $m = shift();
	my $msg = shift();

  # Use string id or literal string
	$msg = $m->{lng}{$msg} || $msg || $m->{lng}{errDefault};
	
	# Add message to error list
	push @{$m->{formErrors}}, $msg;

	# Log error in debug mode	
	$m->logError($msg) if $m->{cfg}{debug};
}

#------------------------------------------------------------------------------
# Print form error messages and continue

sub printFormErrors
{
	my $m = shift();

	return if !@{$m->{formErrors}};
	$m->printHeader();
	print
		"<div class='frm hnt err'>\n",
		"<div class='ccl'>\n",
		"<img class='sic sic_hint_error' src='$m->{cfg}{dataPath}/epx.png' alt=''>\n",
		map("<p>$_</p>\n", @{$m->{formErrors}}),
		"</div>\n",
		"</div>\n\n";
}

#------------------------------------------------------------------------------
# Log non-fatal error to webserver and/or forum log

sub logError
{
	my $m = shift();
	my $msg = shift();
	my $warning = shift();  # Also print at page bottom

	# Log to webserver log	
	$msg =~ s!\s+! !g;
	if ($MP) {
		$m->{ap}->log_error("[forum] [client $m->{env}{userIp}] $msg");
	}
	elsif ($CGI) {
		my $timestamp = $FCGI ? "" : ("[".localtime(time())."] [forum] ");
		warn $timestamp . "[client $m->{env}{userIp}]" . $msg;
	}

	# Optionally log to own logfile	
	$m->logToFile($m->{cfg}{errorLog}, $msg) if $m->{cfg}{errorLog};
	
	# Add to warnings shown at bottom of page if possible
	push @{$m->{warnings}}, $msg if $warning;
}

#------------------------------------------------------------------------------
# Backward compatibility functions

*cfgError   = \&error;
*userError  = \&error;
*paramError = \&error;
*entryError = \&error;
sub accessError { $_[0]->error('errNoAccess') }
sub printError  { $_[0]->error($_[2]) }
sub checkBan    { }


###############################################################################
# Filter Functions

#------------------------------------------------------------------------------
# Escape HTML

sub escHtml
{
	my $m = shift();
	my $text = shift();
	my $newlines = shift() || 0;  # 0 = strip, 1 = ignore, 2 = replace with <br/>

	# Don't waste time with empty strings	
	return "" if !defined($text) || $text eq "";
	
	# Replace entities with plaintext
	if ($m->{cfg}{replHtmlEnt}) {
		require HTML::Entities;
		HTML::Entities::decode_entities($text);
	}

	# Escape HTML special characters
	$text =~ s!&!&amp;!g;
	$text =~ s!<!&lt;!g;
	$text =~ s!>!&gt;!g;
	$text =~ s!'!&#39;!g;
	$text =~ s!"!&quot;!g;

	# Filter newlines, tabs and A0 spaces
	$text =~ s!\n!!g if $newlines == 0;
	$text =~ s!\n!<br/>!g if $newlines == 2;
	$text =~ s!\t!  !g;
	$text =~ s!\xA0! !g;
	
	# Remove control characters
	$text =~ s![\x00-\x09\x0B-\x1F\x7F\p{BidiControl}]!!g;

	return $text;
}

#------------------------------------------------------------------------------
# De-escape HTML

sub deescHtml
{
	my $m = shift();
	my $text = shift();

	# Translate newlines
	$text =~ s!<br/?>!\n!g;

	# Decode HTML special chars
	$text =~ s!&#160;! !g;
	$text =~ s!&quot;!"!g;
	$text =~ s!&#39;!'!g;
	$text =~ s!&lt;!<!g;
	$text =~ s!&gt;!>!g;
	$text =~ s!&amp;!&!g;

	return $text;
}

#------------------------------------------------------------------------------
# Translate text for storage in DB

sub editToDb
{
	my $m = shift();
	shift();
	my $post = shift();

	my $cfg = $m->{cfg};

	# Alias body (also is workaround for Perl bug with tied hashes)
	$post->{body} ||= "";
	my $body = \$post->{body};
	
	#	Alias and escape subject
	my $subject = \$post->{subject};
	$$subject = $m->escHtml($$subject) if $$subject;

	#	Escape raw body
	$post->{rawBody} = $m->escHtml($post->{rawBody}, 1) if $post->{rawBody};

	# Normalize space around quotes
	$$body =~ s!\n*((?:(?:^|\n)>[^\n]*)+)\n*!\n$1\n\n!g;

	# Remove multiple empty lines and empty lines at start and end
	$$body =~ s!\r!!g;
	$$body =~ s!^\n+!!g;
	$$body =~ s!\n+\z!!g;
	$$body =~ s!\n{3,}!\n\n!g;

	# Filter bad words
	for my $word (@{$cfg->{censorWords}}) {
		my $wordRxEsc = quotemeta($word);
		$$subject =~ s!$wordRxEsc!'*' x length($word)!egi if $$subject;
		$$body =~ s!$wordRxEsc!'*' x length($word)!egi;
	}
	
	# Escape HTML
	$$body = $m->escHtml($$body, 2);

	# Translate two spaces to "&#160; " for code snippets etc.
	$$body =~ s!  !&#160; !g;
	$$body =~ s!  !&#160; !g;

	# Quotes
	$$body =~ s~(^|<br/?>)((?:&gt;).*?)(?=(?:<br/?>)+(?!&gt;)|$)~$1<blockquote><p>$2</p></blockquote>~g;
	$$body =~ s~</blockquote>(?:<br/?>){2,}~</blockquote><br/>~g;

	# Style tags
	$$body =~ s!\[(/?)(b|i)\]!"<$1".lc($2).">"!egi;
	$$body =~ s!\[(/?)tt\]!<${1}code>!gi;

	# Custom style tag
	if (%{$cfg->{customStyles}}) {
		$$body =~ s!\[c=([a-z]+)\]!<span class='cst_$1'>!gi;
		$$body =~ s!\[/c\]!</span>!gi;
	}

	# Do image and URL tags in one pass to avoid interference
	$$body =~ s@
		# URL tags with image
		\[url=(https?://[^<>[\]]+?)\]\[img\](https?://[^<>]+?)\[/img\]\[/url\]
		| # Image tags
		\[img\](https?://[^<>]+?)\[/img\]
		| # Simple URL tags
		\[url=?\](https?://[^<>]+?)\[/url\]
		| # Linktext URL tags
		\[url=(https?://[^<>[\]]+?)\]([^[\]]+)\[/url\]
		| # Autolinked URL
		(?<!=|])(https?://[^\s'"<>()]+)
	@
		if ($1 && !$cfg->{imgTag}) { "<a class='url' href='$1'>[img]${2}[/img]</a>" }
		elsif ($1) { "<a class='url' href='$1'><img class='emi' src='$2' alt=''/></a>" }
		elsif ($3 && !$cfg->{imgTag}) { "[img]${3}[/img]" }
		elsif ($3) { "<img class='emi' src='$3' alt=''/>" }
		elsif ($4) {
			my $url = $4;
			$url =~ s!([[\]])!'%'.unpack("H2",$1)!eg;
			"<a class='urs' href='$url'>$url</a>" 
		}
		elsif ($5) { "<a class='url' href='$5'>$6</a>" }
		elsif ($7) { 
			# Don't include trailing entities in autolinked URLs
			my $all = $7;
			my ($ent) = $all =~ /(&quot;|&gt;|&lt;|&#160;|&#39;)/;
			my $pos = $ent ? index($all, $ent, 0) : -1;
			my $url = $ent ? substr($all, 0, $pos) : $all;
			$url =~ s!([[\]])!'%'.unpack("H2",$1)!eg;
			"<a class='ura' href='$url'>$url</a>" . ($pos > -1 ? substr($all, $pos) : "")
		}
	@egix;

	# Make tags correctly balanced and nested
	for my $pass (1..2) {
		my @stack = ();
		my $dropped = 0;
		$$body =~ s%<(/?)(blockquote|p|b|i|code|a|span)( [^>]+)?>%
			my $close = $1; my $name = $2; my $attr = $3;
			if ($pass == 1 && $name eq 'blockquote' && !$close && @stack) {
				my $closeAll = "";
				$closeAll .= "</$_>" while $_ = pop(@stack);
				push @stack, $name;
				"$closeAll<br/><$name>";
			}
			else {
				if (!$close) { push @stack, $name }
				elsif ($name eq $stack[-1]) { pop @stack }
				else { $name = ""; $dropped++ }
				$name ? "<$close$name$attr>" : "";
			}
		%eg;
		if ($pass == 1) {
			$$body .= "</$_>" while $_ = pop(@stack);
		}
		elsif ($dropped || @stack) {
			$$body =~ s!<!(!g;
			$$body =~ s!>!)!g;
		}
	}
}

#------------------------------------------------------------------------------
# Translate stored text for editing

sub dbToEdit
{
	my $m = shift();
	shift();
	my $post = shift();

	my $cfg = $m->{cfg};
	
	# Alias
	$post->{body} ||= "";
	my $body = \$post->{body};

	# Translate linebreaks
	$$body =~ s!<br/?>!\n!g;

	# Translate escaped spaces to normal spaces
	$$body =~ s!&#160;! !g;
	
	# Remove blockquotes
	$$body =~ s!<blockquote><p>!!g;
	$$body =~ s!</p></blockquote>!\n!g;

	# Translate markup tags
	$$body =~ s!<(/?)(b|i)>![$1$2]!g;
	$$body =~ s!<(/?)code>![${1}tt]!g;
	$$body =~ s!<a class='urs' href='(.+?)'>.+?</a>![url]${1}[/url]!g;
	$$body =~ s!<a class='url' href='(.+?)'>(.+?)</a>![url=$1]${2}[/url]!gs;
	$$body =~ s!<a class='ura' href='(.+?)'>(.+?)</a>!$1!g;
	$$body =~ s!<img class='emi' src='(.+?)' alt=''/?>![img]${1}[/img]!g;
	if (%{$cfg->{customStyles}}) {
		$$body =~ s!<span class='cst_([a-z]+)'>![c=$1]!g;
		$$body =~ s!</span>![/c]!g;
	}
}

#------------------------------------------------------------------------------
# Translate stored text for display

sub dbToDisplay
{
	my $m = shift();
	my $board = shift();
	my $post = shift();

	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	my $env = $m->{env};
	my $user = $m->{user};
	my $script = $env->{script};
	my $embed = $user->{showImages} && $script ne 'forum_overview' && $script ne 'forum_search';
	
	# Call display plugins
	my $filter = 1;  # Do all filtering, otherwise only safe stuff
	for my $plugin (@{$cfg->{msgDisplayPlg}}) {
		my $rv = $m->callPlugin($plugin, board => $board, post => $post);
		return if $rv == 1;
		$filter = 0 if $rv == 2;
	}

	# Alias
	$post->{body} ||= "";
	$post->{signature} ||= "";
	my $body = \$post->{body};
	my $sig = \$post->{signature};

	# Replace :tags:
	$$body =~ s%:([A-Za-z_0-9]+):%
		my $v = $cfg->{tags}{$1};
		if ($v && ($user->{showDeco} || substr($v, 0, 1) ne '!')) { 
			$v =~ s/^[?!]//;
			$v =~ s!\[\[dataPath\]\]!$cfg->{dataPath}!g;
			$v
		}
		else { ":$1:" }
	%eg if %{$cfg->{tags}} && $filter;

	# Force user links to open in new window/tab
	if ($cfg->{openUrlNewTab}) {
		$$body =~ s!(?<=<a class='ur[sla]') href! target='_blank' href!g;
		$$sig  =~ s!(?<=<a class='ur[sla]') href! target='_blank' href!g if $$sig && $cfg->{fullSigs};
	}

	# De-embed [img] for overviews and low-bandwidth users
	if (!$embed) {
		$$body =~ s!(?:<a class='url' href='[^']+'>)?<img class='emi' src='([^']+)' alt=''/?>(?:</a>)?![<a href='$1'>$1</a>]!g;
		$$sig  =~ s!(?:<a class='url' href='[^']+'>)?<img class='emi' src='([^']+)' alt=''/?>(?:</a>)?![<a href='$1'>$1</a>]!g 
			if $$sig && $cfg->{fullSigs};
	}

	# Embed videos
	if ($cfg->{videoTag} && $embed && $filter) {
		$$body =~ s%\[vid=(html|youtube|vimeo)\](.+?)\[/vid\]%
			my $srv = lc($1);	my $id = $2;
			if ($srv eq 'html' && $id =~ m!^https?://[^\s\\\[\]{}<>)|^`'"]+\z!) {
				"<video src='$id' controls='controls'><p>$lng->{errUAFeatSup}</p></video>"
			}
			elsif (($srv eq 'youtube' || $srv eq 'vimeo') && $id =~ /^[A-Za-z_0-9-]+\z/) {
				$srv eq 'youtube' 
					?	"<iframe class='vif' width='640' height='385' src='//www.youtube-nocookie.com/embed/$id?rel=0'></iframe>"
					: "<iframe class='vif' width='640' height='360' src='//player.vimeo.com/video/$id'></iframe>"
			} 
			else { "[vid=$srv]${id}[/vid]" }
		%egi;
	}
	elsif ($cfg->{videoTag} && $filter) {
		$$body =~ s!\[vid=(youtube|vimeo)\]([A-Za-z_0-9-]+)\[/vid\]!
			if (lc($1) eq 'youtube') { "[<a href='https://www.youtube.com/watch?v=$2'>YouTube</a>]" }
			else { "[<a href='http://vimeo.com/$2'>Vimeo</a>]" }
		!egi;
	}

	# Append attachments
	my $attachments = $post->{attachments};
	if ($attachments && @$attachments) {
		my $postIdMod = $post->{id} % 100;
		my $attFsPath = "$cfg->{attachFsPath}/$postIdMod/$post->{id}";
		my $attUrlPath = "$cfg->{attachUrlPath}/$postIdMod/$post->{id}";

		# Embed image attachments with tags
		my %attachments = map({ $_->{fileName} => $_ } @$attachments);
		$$body =~ s^\[img( thb)?\]([\w.-]+\.(?:jpg|png|gif))\[/img\]^
			my ($thumb, $fileName) = ($1, $2);
			my $attach = $attachments{$fileName};
			if ($attach) {
				my $attFile = "$attFsPath/$fileName";
				my $attUrl = "$attUrlPath/$fileName";
				my $attShowUrl = $m->url('attach_show', aid => $attach->{id});
				my $sizeStr = $m->formatSize(-s $m->encFsPath($attFile));
				my $thbFile = $attFile;
				my $thbUrl = $attUrl;
				$thbFile =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
				$thbUrl =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
				my $title = $attach->{caption} || $attach->{fileName};
				$title = "title='$title ($sizeStr)'";
				$attach->{drop} = 1;
				if ($embed) {
					($thumb || $cfg->{attachImgThb}) 
						&& (-f $m->encFsPath($thbFile) || $m->addThumbnail($attFile))
						? "<a href='$attShowUrl'><img class='amt' src='$thbUrl' $title alt=''/></a>"
						: "<img class='ami' src='$attUrl' $title alt=''/>";
				}
				else { "[<a href='$attShowUrl'>$fileName</a> ($sizeStr)]" }
			}
			else { "[$fileName]" }
		^egi;
		@$attachments = grep(!$_->{drop}, @$attachments);

		# List normal attachments at post bottom
		$$body .= "\n</div>\n<div class='ccl pat'>" if @$attachments;
		for my $attach (@$attachments) {
			my $fileName = $attach->{fileName};
			my $attFile = "$attFsPath/$fileName";
			my $attUrl = "$attUrlPath/$fileName";
			my $attShowUrl = $m->url('attach_show', aid => $attach->{id});
			my $caption = $attach->{caption} ? "- $attach->{caption}" : "";
			my $sizeStr = $m->formatSize(-s $m->encFsPath($attFile));
			if ($cfg->{attachImg} && $attach->{webImage} == 2 && $embed) {
				my $thbFile = $attFile;
				my $thbUrl = $attUrl;
				$thbFile =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
				$thbUrl =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
				my $title = $attach->{caption} || $attach->{fileName};
				$title = "title='$title ($sizeStr)'";
				$$body .= $cfg->{attachImgThb} 
					&& (-f $m->encFsPath($thbFile) || $m->addThumbnail($attFile))
					? "\n<a href='$attShowUrl'><img class='amt' src='$thbUrl' $title alt=''/></a>"
					: "\n<img class='ami' src='$attUrl' $title alt=''/>";
			}
			else {
				my $url = $attach->{webImage} ? $attShowUrl : $attUrl;
				$$body .=  "\n<div class='amf'>$lng->{tpcAttText} <a href='$url'>$fileName</a>"
					. " $caption ($sizeStr)</div>";
			}
		}
	}

	# Append raw body
	$$body .= "\n</div>\n<div class='ccl raw'>\n<pre>$post->{rawBody}</pre>" if $post->{rawBody};

	# Append signature
	$$body .= "\n</div>\n<div class='ccl sig'>\n$$sig" if $user->{id} && $user->{showSigs} && $$sig;

	# Append appendixes
	my $appendixes = $post->{appendixes};
	if ($appendixes && @$appendixes) {
		$$body .= "\n</div>\n<div class='ccl app $_->{class}'>\n$_->{text}" for @$appendixes;
	}
}	

#------------------------------------------------------------------------------
# Translate stored text for email

sub dbToEmail
{
	my $m = shift();
	shift();
	my $post = shift();

	# Alias
	$post->{body} ||= "";
	my $body = \$post->{body};

	# De-escape HTML
	$post->{subject} = $m->deescHtml($post->{subject}) if $post->{subject};
	$post->{rawBody} = $m->deescHtml($post->{rawBody}) if $post->{rawBody};
	$$body = $m->deescHtml($$body);

	# Remove markup
	$$body =~ s!<blockquote><p>!!g;
	$$body =~ s!</p></blockquote>!\n!g;
	$$body =~ s!</?(?:b|i|code)>!!g;
	$$body =~ s!<span class='cst_[a-z]+'>!!g;
	$$body =~ s!</span>!!g;
	$$body =~ s!<a class='ur[sla]' href='(.+?)'>(.+?)</a>!$2 <$1>!g;
	$$body =~ s!<img class='emi' src='(.+?)' alt=''/?>!<$1>!g;
} 


###############################################################################
# Low-Level Database Functions

#------------------------------------------------------------------------------
# Connect to database

sub dbConnect 
{
	my $m = shift();

	my $cfg = $m->{cfg};
	my $dbh = undef;

	# Load DBI
	eval { require DBI } or $m->error("DBI module not available.");
	$DBI::VERSION >= 1.30 or $m->error("DBI is too old, need at least 1.30.");
	
	# Connect
	if ($cfg->{dbDriver} eq 'mysql') {
		eval { require DBD::mysql } or $m->error("DBD::mysql module not available.");
		$DBD::mysql::VERSION >= 2.9003 
			or $m->error("DBD::mysql is too old, need at least 2.9003, preferably 4.0 or newer.");
		my $dbName = $m->{gcfg}{dbName} || $cfg->{dbName};
		my $encoding = index($cfg->{dbTableOpt}, 'utf8mb4') > -1 ? 'utf8mb4' : 'utf8';
		$dbh = DBI->connect(
			"dbi:mysql:database=$dbName;host=$cfg->{dbServer};$cfg->{dbParam}", 
			$cfg->{dbUser}, $cfg->{dbPassword}, 
			{ PrintError => 0, PrintWarn => 0, AutoCommit => 1,
				mysql_server_prepare => $cfg->{dbPrepare} || 0, mysql_no_autocommit_cmd => 1 })
			or $m->dbError();
		$dbh->do("USE $cfg->{dbName}") if $m->{gcfg}{dbName};
		$dbh->do("SET NAMES '$encoding'");
		$dbh->do("SET SESSION sql_mode = 'ANSI_QUOTES,PIPES_AS_CONCAT'");
		$m->{mysql} = 1;
	}
	elsif ($cfg->{dbDriver} eq 'Pg') {
		eval { require DBD::Pg } or $m->error("DBD::Pg module not available.");
		$dbh = DBI->connect(
			"dbi:Pg:dbname=$cfg->{dbName};host=$cfg->{dbServer};$cfg->{dbParam}",
			$cfg->{dbUser}, $cfg->{dbPassword}, 
			{ PrintError => 0, PrintWarn => 0, AutoCommit => 1,
				pg_server_prepare => $cfg->{dbPrepare} || 0, pg_utf8_strings => 0 })
			or $m->dbError();
		$dbh->do("SET NAMES 'utf8'");
		$dbh->do("SET search_path = $cfg->{dbSchema}, public") if $cfg->{dbSchema};
		$dbh->do("SET synchronous_commit = $cfg->{dbSync}") if $cfg->{dbSync};
		$m->{pgsql} = 1;
	}
	elsif ($cfg->{dbDriver} eq 'SQLite') {
		eval { require DBD::SQLite } or $m->error("DBD::SQLite module not available.");
		$dbh = DBI->connect("dbi:SQLite:dbname=$cfg->{dbName}", "", "",
			{ PrintError => 0, PrintWarn => 0, AutoCommit => 1 })
			or $m->dbError();
		$dbh->do("PRAGMA synchronous = " . ($cfg->{dbSync} || "OFF"));
		$dbh->func(1000, 'busy_timeout');
		$dbh->func('mwforum', sub { my $a = shift(); my $b = shift(); 
			utf8::decode($a); utf8::decode($b); lc($a) cmp lc($b) }, 'create_collation')
			if $cfg->{sqliteCollate};
		$m->{sqlite} = 1;
	}
	else { 
		$m->error("Database driver not supported");
	}
	
	$m->{dbh} = $dbh;

	# Start automatic request-wide transaction, but not for shell scripts
	$m->dbBegin() if $m->{autoXa};
}

#------------------------------------------------------------------------------
# Escape string for inclusion in SQL LIKE search statement

sub dbEscLike
{
	my $m = shift();
	my $str = shift();

	$str =~ s!\\!\\\\!;
	$str =~ s!_!\\\_!;
	$str =~ s!%!\\\%!;
	return $str;
}

#------------------------------------------------------------------------------
# Obsolete, only left here for old upgrade-x.y.z.pl

sub dbQuote 
{
	my $m = shift();
	my $str = shift();

	$str = $m->{dbh}->quote($str);
	utf8::decode($str) if !utf8::is_utf8($str);
	return $str;
}

#------------------------------------------------------------------------------
# Add table name prefixes

sub dbPrefix
{
	my $m = shift();
	my $query = shift();

	my $pfx = $m->{cfg}{dbPrefix};
	$pfx or return $query;

	$query =~ s%\b(FROM|JOIN|INTO|TEMPORARY TABLE|DROP TABLE)\s+([A-Z_a-z]+)\b%$1 $pfx$2%g;
	$query =~ s%\bUPDATE\s+([A-Z_a-z]+)\s+SET\b%UPDATE $pfx$1 SET%g;
	
	return $query;
}

#------------------------------------------------------------------------------
# Replace mwForum-style named placeholders or collect names for PgSQL

sub dbPlaceholders
{
	my $m = shift();
	my $query = shift();
	my $values = shift();
	my $pgPlaceholders = shift();
	
	if ($m->{pgsql}) {
		# For PgSQL, replace int lists, but only collect names for later binding
		$$query =~ s%:([A-Za-z_0-9]+)%
			my $name = $1;
			exists($values->{$name}) or $m->error("Missing placeholder value '$1'.");
			my $value = $values->{$name};
			if (ref($value) eq 'ARRAY') {
				$value = join(",", map(int, @{$values->{$name}}));
				$value = 'NULL' if !length($value);
			}
			else { 
				push @$pgPlaceholders, $name; 
				$value = ":$name";
			}
			$value;
		%eg;
	}
	else {
		# Replace all placeholders with values
		$$query =~ s%:([A-Za-z_0-9]+)%
			my $name = $1;
			exists($values->{$name}) or $m->error("Missing placeholder value '$1'.");
			my $value = $values->{$name};
			if (ref($value) eq 'ARRAY') { 
				$value = join(",", map(int, @$value));
				$value = 'NULL' if !length($value);
			}
			elsif (!DBI::looks_like_number($value)) { 
				$value = $m->{dbh}->quote($value);
				utf8::decode($value) if !utf8::is_utf8($value);
			}
			$value;
		%eg;
	}
}

#------------------------------------------------------------------------------
# Replace all placeholders with values for debug output

sub dbReplaceHolders
{
	my $m = shift();
	my $query = shift();
	my @values = @_;

	my $values = $values[0];	
	if (ref($values)) {
		$query =~ s%:([A-Za-z_0-9]+)%
			my $name = $1;
			my $value = exists($values->{$name}) ? $values->{$name} : "[[missing]]";
			if (ref($value) eq 'ARRAY') { 
				$value = join(",", map(int, @$value));
				$value = 'NULL' if !length($value);
			}
			elsif ($value !~ /^[0-9]+\z/) { 
				$value = $m->{dbh}->quote($value);
				utf8::decode($value) if !utf8::is_utf8($value);
			}
			$value;
		%eg;
	}
	else {
		$query =~ s%\?%
			my $value = shift(@values);
			if ($value !~ /^[0-9]+\z/) {
				$value = $m->{dbh}->quote($value);
				utf8::decode($value) if !utf8::is_utf8($value);
			}
			$value;
		%eg;
	}
	$query =~ s!^\n+!!g;
	$query =~ s!\t!!g;
	$query =~ s!\n{2,}!\n!g;

	return $query;
}

#------------------------------------------------------------------------------
# Begin transaction

sub dbBegin
{
	my $m = shift();

	# Only the outermost call should start a transaction
	$m->{activeXa}++;
	$m->{dbh}->do("BEGIN") if $m->{activeXa} == 1;
}

#------------------------------------------------------------------------------
# Commit transaction

sub dbCommit
{
	my $m = shift();

	# Only the outermost call should commit transaction
	$m->{dbh}->do("COMMIT") or $m->dbError() if $m->{activeXa} == 1;
	$m->{activeXa}--;
}

#------------------------------------------------------------------------------
# Prepare query

sub dbPrepare
{
	my $m = shift();
	my $query = shift();
	my $attr = shift();

	# Add table name prefix
	my $cfg = $m->{cfg};
	$query = $m->dbPrefix($query) if $cfg->{dbPrefix};

	# Debug info
	$m->{query}	= $query;
	if ($cfg->{queryLog}) {
		$query =~ s!^\n+!!g;
		$query =~ s!\t!!g;
		$query =~ s!\n{2,}!\n!g;
		$m->logToFile($cfg->{queryLog}, "EXPLAIN\n$query;\n");
	}

	# Prepare query	
	my $sth = $m->{dbh}->prepare($query, $attr) or $m->dbError();
	return $sth;
}

#------------------------------------------------------------------------------
# Execute prepared query

sub dbExecute
{
	my $m = shift();
	my $sth = shift();
	my @values = @_;

	$m->{queryNum}++;
	my $result = $sth->execute(@values);
	defined($result) or $m->dbError();
	return $result;
}

#------------------------------------------------------------------------------
# Get last inserted autoincrement ID

sub dbInsertId
{
	my $m = shift();
	my $table = shift();

	return $m->{dbh}{mysql_insertid} if $m->{mysql};
	return scalar $m->fetchArray("SELECT CURRVAL(?)", $table . "_id_seq") if $m->{pgsql};
	return $m->{dbh}->func('last_insert_rowid') if $m->{sqlite};
}

#------------------------------------------------------------------------------
# Execute manipulation query

sub dbDo
{
	my $m = shift();
	my $query = shift();
	my @values = @_;
	
	# Add table name prefix
	my $cfg = $m->{cfg};
	$query = $m->dbPrefix($query) if $cfg->{dbPrefix};

	# Debug info
	$m->{query}	= $query;
	$m->{queryNum}++;
	if ($cfg->{queryLog}) {
		my $replacedQuery = $m->dbReplaceHolders($query, @values);
		$m->logToFile($m->{cfg}{queryLog}, "EXPLAIN\n$replacedQuery;\n");
	}

	# Replace custom placeholders or collect their names
	my $values = $values[0];
	my @pgPlaceholders = ();
	my $mwfPlaceholders = @values && ref($values) eq 'HASH';
	if ($mwfPlaceholders) {
		$m->dbPlaceholders(\$query, $values, \@pgPlaceholders);
		@values = () if !$m->{pgsql};
	}

	# Prepare query	
	my $sth = $m->{dbh}->prepare($query) or $m->dbError();
	if ($mwfPlaceholders && $m->{pgsql}) { 
		$sth->bind_param(":$_", $values->{$_}) for @pgPlaceholders;
		@values = ();
	}

	# Execute query	
	my $result = $sth->execute(@values);
	defined($result) or $m->dbError();
	return $result;
}

#------------------------------------------------------------------------------
# Fetch result as statement handle

sub fetchSth
{
	my $m = shift();
	my $query = shift();
	my @values = @_;

	# Add table name prefix
	my $cfg = $m->{cfg};
	$query = $m->dbPrefix($query) if $cfg->{dbPrefix};

	# Debug info
	$m->{query}	= $query;
	$m->{queryNum}++;
	if ($cfg->{queryLog}) {
		my $replacedQuery = $m->dbReplaceHolders($query, @values);
		$m->logToFile($m->{cfg}{queryLog}, "EXPLAIN\n$replacedQuery;\n");
	}

	# Replace custom placeholders or collect their names
	my $values = $values[0];
	my @pgPlaceholders = ();
	my $mwfPlaceholders = @values && ref($values) eq 'HASH';
	if ($mwfPlaceholders) {
		$m->dbPlaceholders(\$query, $values, \@pgPlaceholders);
		@values = () if !$m->{pgsql};
	}

	# Prepare query
	my $sth = $m->{dbh}->prepare($query) or $m->dbError();
	if ($mwfPlaceholders && $m->{pgsql}) {
		$sth->bind_param(":$_", $values->{$_}) for @pgPlaceholders;
		@values = ();
	}

	# Execute query
	$sth->execute(@values) or $m->dbError();
	return $sth;
}

#------------------------------------------------------------------------------
# Fetch one record as array

sub fetchArray
{
	my $m = shift();
	my $query = shift();
	my @values = @_;

	my $sth = $m->fetchSth($query, @values);
	my $ar = $sth->fetchrow_arrayref();
	if ($ar) { utf8::decode($_) for @$ar }
	return $ar ? @$ar : () if wantarray;
	return $ar ? @$ar[0] : undef;
}

#------------------------------------------------------------------------------
# Fetch one record as hash ref

sub fetchHash
{
	my $m = shift();
	my $query = shift();
	my @values = @_;

	my $sth = $m->fetchSth($query, @values);
	if ($m->{pgsql}) {
		my $hr = $sth->fetchrow_hashref();
		if ($hr) {
			utf8::decode($_) for values %$hr;
			tie my %h, 'MwfMain::PgHash', $hr;
			return \%h;
		}
		else { return undef }
	}
	else { 
		my $hr = $sth->fetchrow_hashref();
		if ($hr) { utf8::decode($_) for values %$hr }
		return $hr;
	}
}

#------------------------------------------------------------------------------
# Fetch all records as array ref of array refs

sub fetchAllArray
{
	my $m = shift();
	my $query = shift();
	my @values = @_;

	my $sth = $m->fetchSth($query, @values);
	my $ar = $sth->fetchall_arrayref();
	for (@$ar) { utf8::decode($_) for @$_ }
	return $ar;
}

#------------------------------------------------------------------------------
# Fetch all records as array ref of hash refs

sub fetchAllHash
{
	my $m = shift();
	my $query = shift();
	my @values = @_;

	my $sth = $m->fetchSth($query, @values);
	if ($m->{pgsql}) {
		my (@rows, $hr);
		while ($hr = $sth->fetchrow_hashref()) {
			utf8::decode($_) for values %$hr;
			tie my %h, 'MwfMain::PgHash', $hr;
			push @rows, \%h;
		}
		return \@rows;
	}
	else { 
		my $arhr = $sth->fetchall_arrayref({});
		for (@$arhr) { utf8::decode($_) for values %$_ }
		return $arhr;
	}
}

###############################################################################
# High-Level Database Functions

#------------------------------------------------------------------------------
# Insert/delete entries in simple relation tables with no extra data

sub setRel
{
	my $m = shift();
	my $set = shift();
	my $table = shift();
	my $key1 = shift();
	my $key2 = shift();
	my $val1 = shift();
	my $val2 = shift();

	my $exists = $m->fetchArray("
		SELECT 1 FROM $table WHERE $key1 = ? AND $key2 = ?", $val1, $val2);

	if ($set && !$exists) {	
		return $m->dbDo("
			INSERT INTO $table ($key1, $key2) VALUES (?, ?)", $val1, $val2);
	}
	elsif (!$set && $exists) {
		return $m->dbDo("
			DELETE FROM $table WHERE $key1 = ? AND $key2 = ?", $val1, $val2);
	}
}

#------------------------------------------------------------------------------
# Update board and topic statistics

sub recalcStats
{
	my $m = shift();
	my $boardIds = shift() || [];
	my $topicIds = shift() || [];

	$boardIds = [ $boardIds ] if !ref($boardIds);
	$topicIds = [ $topicIds ] if !ref($topicIds);
	my $pfx = $m->{cfg}{dbPrefix};

	$m->dbDo("
		UPDATE topics SET 
			postNum = (SELECT COUNT(*) FROM posts WHERE topicId = ${pfx}topics.id), 
			lastPostTime = (SELECT MAX(postTime) FROM posts WHERE topicId = ${pfx}topics.id)
		WHERE id IN (:topicIds)", 
		{ topicIds => $topicIds })
		if @$topicIds;

	$m->dbDo("
		UPDATE boards SET 
			postNum = COALESCE((
				SELECT SUM(postNum) FROM topics WHERE boardId = ${pfx}boards.id), 0), 
			lastPostTime = COALESCE((
				SELECT MAX(lastPostTime) FROM topics WHERE boardId = ${pfx}boards.id), 0)
		WHERE id IN (:boardIds)", 
		{ boardIds => $boardIds })
		if @$boardIds;
}

#------------------------------------------------------------------------------
# Store data in variables or userVariables table

sub setVar
{
	my $m = shift();
	my $name = shift();
	my $value = shift();
	my $userId = shift() || 0;

	if ($userId) {
		$m->dbDo("
			DELETE FROM userVariables WHERE userId = ? AND name = ?", $userId, $name);
		$m->dbDo("
			INSERT INTO userVariables (userId, name, value) VALUES (?, ?, ?)", $userId, $name, $value);
	}
	else {
		$m->dbDo("
			DELETE FROM variables WHERE name = ?", $name);
		$m->dbDo("
			INSERT INTO variables (name, value) VALUES (?, ?)", $name, $value);
	}
}

#------------------------------------------------------------------------------
# Retrieve data from variables or userVariables table

sub getVar
{
	my $m = shift();
	my $name = shift();
	my $userId = shift() || 0;

	my $value;
	if ($userId) {	
		$value = $m->fetchArray("
			SELECT value FROM userVariables WHERE userId = ? AND name = ?", $userId, $name);
	}
	else {
		$value = $m->fetchArray("
			SELECT value FROM variables WHERE name = ?", $name);
	}

	return $value;
}

#------------------------------------------------------------------------------
# Log action to database

sub logAction
{
	my $m = shift();
	my $level = shift();	
	my $entity = shift();
	my $action = shift();
	my $userId = shift() || 0;
	my $boardId = shift() || 0;
	my $topicId = shift() || 0;
	my $postId = shift() || 0;
	my $extraId = shift() || 0;
	my $string = shift() || "";

	# Call event plugins
	my $cfg = $m->{cfg};
	$m->callPlugin($_, level => $level, entity => $entity, action => $action,
		userId => $userId, boardId => $boardId, topicId => $topicId,
		postId => $postId, extraId => $extraId, string => $string) for @{$cfg->{logPlg}};

	return if $userId == $cfg->{noLogUserId};
	return if $level > $cfg->{logLevel};

	# Normal logging
	my $ip = $cfg->{recordIp} ? ($m->{env}{userIp} || "") : "";
	$m->dbDo("
		INSERT INTO log (	
			level, entity, action, userId, boardId, topicId, postId, extraId, logTime, ip, string) 
		VALUES (?,?,?,?,?,?,?,?,?,?,?)",
		$level, $entity, $action, $userId, $boardId, $topicId, $postId, $extraId, $m->{now}, $ip,
		$string);
}

#------------------------------------------------------------------------------
# Delete attachment entry, file and directories

sub deleteAttachment
{
	my $m = shift();
	my $attachId = shift();

	my $cfg = $m->{cfg};
	my $attach = $m->fetchHash("
		SELECT postId, fileName FROM attachments WHERE id = ?", $attachId);
	my $path = $cfg->{attachFsPath};
	my $postId = $attach->{postId};
	my $postIdMod = $postId % 100;
	my $attFile = "$path/$postIdMod/$postId/" . $m->encFsPath($attach->{fileName});
	my $thumbFile = $attFile;
	$thumbFile =~ s!\.(?:jpg|png|gif)\z!.thb.jpg!i;
	unlink $attFile, $thumbFile;
	rmdir "$path/$postIdMod/$postId";
	rmdir "$path/$postIdMod";
	$m->dbDo("
		DELETE FROM attachments WHERE id = ?", $attachId);
}

#------------------------------------------------------------------------------
# Delete post and dependent data

sub deletePost
{
	my $m = shift();
	my $postId = shift();
	my $trash = shift() || 0;
	my $hasChildren = shift();
	my $alone = shift();

	# Get topic id, return if post doesn't exist
	my $topicId = $m->fetchArray("
		SELECT topicId FROM posts WHERE id = ?", $postId);
	return if !$topicId;

	# Does post have children?	
	$hasChildren = $m->fetchArray("
		SELECT 1 FROM posts WHERE topicId = ? AND parentId = ?", $topicId, $postId)
		if !defined($hasChildren);
	$alone = 0 if $hasChildren;

	# Is post the only one in the topic?
	$alone = !$m->fetchArray("
		SELECT 1 FROM posts WHERE topicId = ? AND id <> ?", $topicId, $postId)
		if !defined($alone);

	if ($alone) {
		# Delete whole topic if only one post
		$m->deleteTopic($topicId, $trash);
	}
	else {
		# Delete attachments
		my $attachments = $m->fetchAllArray("
			SELECT id FROM attachments WHERE postId = ?", $postId);
		$m->deleteAttachment($_->[0]) for @$attachments;

		# Delete post likes and reports
		$m->dbDo("
			DELETE FROM postLikes WHERE postId = ?", $postId);
		$m->dbDo("
			DELETE FROM postReports WHERE postId = ?", $postId);

		# Is post the topic base post?
		my $base = $m->fetchArray("
			SELECT basePostId = ? FROM topics WHERE id = ?", $postId, $topicId);
			
		if ($hasChildren || $base) {
			# Only modify post body to preserve thread integrity
			$m->setLanguage($m->{cfg}{language});
			$m->dbDo("
				UPDATE posts SET body = ?, rawBody = '' WHERE id = ?", $m->{lng}{eptDeleted}, $postId);
			$m->setLanguage();
		}
		else {
			# Delete post
			$m->dbDo("
				DELETE FROM posts WHERE id = ?", $postId);
		}
	}
	
	return $alone;
}

#------------------------------------------------------------------------------
# Delete topic and dependent data

sub deleteTopic
{
	my $m = shift();
	my $topicId = shift();
	my $trash = shift() || 0;

	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	
	# Get topic
	my ($topicExists, $pollId) = $m->fetchArray("
		SELECT id, pollId FROM topics WHERE id = ?", $topicId);
	return if !$topicExists;
	
	# Delete subscriptions
	$m->dbDo("
		DELETE FROM topicSubscriptions WHERE topicId = ?", $topicId);

	# Delete poll
	if ($pollId && !$trash) {
		$m->dbDo("
			DELETE FROM pollVotes WHERE pollId = ?", $pollId);
		$m->dbDo("
			DELETE FROM pollOptions WHERE pollId = ?", $pollId);
		$m->dbDo("
			DELETE FROM polls WHERE id = ?", $pollId);
	}

	if (!$trash) {	
		# Get IDs of posts in topic
		my $tmp = 'deleteTopic' . int(rand(2147483647));
		$m->dbDo("
			CREATE TEMPORARY TABLE $tmp AS
			SELECT id FROM posts WHERE topicId = ?", $topicId);

		# Delete post attachments
		my $attachments = $m->fetchAllArray("
			SELECT id FROM attachments WHERE postId IN (SELECT id FROM $tmp)");
		$m->deleteAttachment($_->[0]) for @$attachments;

		# Delete post likes and reports
		$m->dbDo("
			DELETE FROM postLikes WHERE postId IN (SELECT id FROM $tmp)");
		$m->dbDo("
			DELETE FROM postReports WHERE postId IN (SELECT id FROM $tmp)");
		$m->dbDo("
			DROP TABLE $tmp");
	}

	# Delete topic and posts
	if ($trash) {
		# Move to trash board instead
		$m->dbDo("
			UPDATE topics SET boardId = ? WHERE id = ?", $cfg->{trashBoardId}, $topicId);
		$m->dbDo("
			UPDATE posts SET boardId = ? WHERE topicId = ?", $cfg->{trashBoardId}, $topicId);
	}
	else {
		# Really delete
		$m->dbDo("
			DELETE FROM topics WHERE id = ?", $topicId);
		$m->dbDo("
			DELETE FROM posts WHERE topicId = ?", $topicId);
	}
}

#------------------------------------------------------------------------------
# Add notification message to user's list

sub addNote
{
	my $m = shift();
	my $type = shift();
	my $userId = shift();
	my $strId = shift();
	my %params = @_;
	
	return if $userId < 1;

	# Limit total number of notifications
	my $noteNum = $m->fetchArray("
		SELECT COUNT(*) FROM notes WHERE userId = ?", $userId);
	return if $noteNum >= 200;
	
	# Moderator action reason
	my $reason = $params{reason};
	delete $params{reason};
	my $reasonEsc = $m->escHtml($reason);

	# Get message template in user's language
	my $userLang = $m->fetchArray("
		SELECT language FROM users WHERE id = ?", $userId);
	$m->setLanguage($userLang);
	my $body = $m->{lng}{$strId} || $strId;
	$body .= " $m->{lng}{notReason} $reasonEsc" if $reason;
	$m->setLanguage();

	# Replace parameters
	$body =~ s!\[\[$_\]\]!$params{$_}! for keys %params;
	
	# Insert notification
	$m->dbDo("
		INSERT INTO notes (type, userId, sendTime, body) VALUES (?, ?, ?, ?)",
		$type, $userId, $m->{now}, $body);

	return $m->dbInsertId("notes");
}

#------------------------------------------------------------------------------
# Get member ids of group, if visible to current user

sub getMemberIds
{
	my $m = shift();
	my $title = shift();

	# Get group if user has access
	$title = substr($title, 1) if substr($title, 0, 1) eq '!';
	my $groupId = $m->fetchArray("
		SELECT groups.id 
		FROM groups AS groups
			LEFT JOIN groupAdmins AS groupAdmins
				ON groupAdmins.userId = :userId
				AND groupAdmins.groupId = groups.id
			LEFT JOIN groupMembers AS groupMembers
				ON groupMembers.userId = :userId
				AND groupMembers.groupId = groups.id
		WHERE groups.title = :title
			AND (groups.public = 1 OR :admin = 1
				OR groupAdmins.userId IS NOT NULL 
				OR groupMembers.userId IS NOT NULL)",
		{ userId => $m->{user}{id}, admin => $m->{user}{admin}, title => $title });

	# Get members	
	my $userIds = undef;
	$userIds = $m->fetchAllArray("
		SELECT userId FROM groupMembers WHERE groupId = ?", $groupId)
		if $groupId;

	return $userIds && @$userIds ? map($_->[0], @$userIds) : ();
}

#------------------------------------------------------------------------------
# Send various notifications for new or newly approved post

sub notifyPost
{
	my $m = shift();
	my %params = @_;
	my $board = $params{board};
	my $topic = $params{topic};
	my $post = $params{post};
	my $parent = $params{parent};

	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	my $postUserId = $post->{userId};
	my $postUserName = $post->{userNameBak};
	my $url = "topic_show$m->{ext}?pid=$post->{id}";

	# Notify parent poster
	if ($parent && $parent->{userId} > 0) {
		my $recvUser = $m->getUser($parent->{userId});
		my $ignored = !$recvUser || $m->fetchArray("
			SELECT 1 FROM userIgnores WHERE userId = ? AND ignoredId = ?", $recvUser->{id}, $postUserId);
		if ($recvUser && $recvUser->{notify} && $recvUser->{id} != $postUserId && !$ignored
			&& $m->boardVisible($board, $recvUser)) {
			$m->addNote('pstAdd', $recvUser->{id}, 'notPstAdd', usrNam => $postUserName, pstUrl => $url);
			$post->{subject} = $topic->{subject};
			$m->dbToEmail({}, $post);
			$lng = $m->setLanguage($recvUser->{language});
			my $subject = "$lng->{rplEmailSbPf} $postUserName: $post->{subject}";
			my $body = $lng->{rplEmailT2} . "\n\n" . "-" x 70 . "\n\n"
				. $lng->{subLink} . "$cfg->{baseUrl}$m->{env}{scriptUrlPath}/$url\n"
				. $lng->{subBoard} . $board->{title} . "\n"
				. $lng->{subTopic} . $post->{subject} . "\n"
				. $lng->{subBy} . $postUserName . "\n"
				. $lng->{subOn} . $m->formatTime($post->{postTime}, $recvUser->{timezone}) . "\n\n"
				. $post->{body} . "\n\n"
				. ($post->{rawBody} ? $post->{rawBody} . "\n\n" : "")
				. "-" x 70 . "\n\n";
			$lng = $m->setLanguage();
			$m->sendEmail(user => $recvUser, subject => $subject, body => $body)
				if $recvUser->{msgNotify} && $recvUser->{email} && !$recvUser->{dontEmail};
		}
	}

	# Notify word watchers
	my %visibleCache = ();
	if ($cfg->{watchWords}) {
		my $bodyLc = lc($post->{body});
		my $watchWords = $m->fetchAllArray("
			SELECT userId, word FROM watchWords WHERE userId <> ?", $postUserId);
		for my $watch (@$watchWords) {
			if (index($bodyLc, $watch->[1]) > -1
				&& ($visibleCache{$watch->[0]} || $m->boardVisible($board, $m->getUser($watch->[0])))) {
				$visibleCache{$watch->[0]} = 1;
				$m->addNote('watWrd', $watch->[0], 'notWatWrd', watWrd => $watch->[1], pstUrl => $url);
			}
		}
	}

	# Notify user watchers
	if ($cfg->{watchUsers}) {
		my $watchUsers = $m->fetchAllArray("
			SELECT userId FROM watchUsers WHERE watchedId = ?", $postUserId);
		for my $watch (@$watchUsers) {
			if ($visibleCache{$watch->[0]} || $m->boardVisible($board, $m->getUser($watch->[0]))) {
				$visibleCache{$watch->[0]} = 1;
				$m->addNote('watUsr', $watch->[0], 'notWatUsr', watUsr => $postUserName, pstUrl => $url);
			}
		}
	}

	# Send instant subscriptions
	if ($cfg->{subsInstant}) {
		my $subscribers = $m->fetchArray("
			SELECT 1 FROM boardSubscriptions WHERE instant = 1 AND boardId = ? LIMIT 1", $board->{id});
		$subscribers = $m->fetchArray("
			SELECT 1 FROM topicSubscriptions WHERE instant = 1 AND topicId = ? LIMIT 1", $topic->{id})
			if !$subscribers;
		$m->spawnScript('spawn_subscriptions', "-p", $post->{id}) if $subscribers;
	}
}

###############################################################################
# Email Functions

#------------------------------------------------------------------------------
# Encode MIME header with RFC 2047

sub encWord
{
	my $m = shift();
	my $str = shift();

	if ($str =~ /[^\000-\177]/) {
		require Encode;
		$str = Encode::encode('MIME-Q', $str);
	}

	return $str;
}

#------------------------------------------------------------------------------
# Send email

sub sendEmail
{
	my $m = shift();
	my %params = @_;

	my $cfg = $m->{cfg};
	my $lng = $m->{lng};

	# Don't send if params or email address are empty	
	return if !@_;
	return if !$params{user}{email} || $params{user}{dontEmail};

	# Determine header values and encode where necessary
	require MIME::QuotedPrint;
	my $from = $m->encWord($cfg->{forumName}) . " <$cfg->{forumEmail}>";
	my $to = $params{user}{email};
	my $subject = $m->encWord($params{subject});
	my $bounceAuth = $params{user}{bounceAuth};

	# Sign and encrypt body
	my $body = $params{body};
	utf8::encode($body);
	if ($cfg->{gpgSignKeyId} && $params{user}{gpgKeyId}) {
		my $gpgPath = $cfg->{gpgPath} || "gpg";
		my @gpgOptions = $cfg->{gpgOptions} ? @{$cfg->{gpgOptions}} : ();
		my $password = $cfg->{gpgSignKeyPwd}; 
		utf8::encode($password);
		my $keyring = "$cfg->{attachFsPath}/keys/$params{user}{id}.gpg";
		my $encrypt = $params{user}{gpgKeyId} && -s $keyring ? 1 : 0;
		my $in = "$password\n$body";
		my $out = "";
		my $err = "";
		my $cmd = [ $gpgPath, "--batch", "--no-auto-check-trustdb", "--no-emit-version", "--armor",
			"--charset=utf-8", "--passphrase-fd=0", "--default-key=$cfg->{gpgSignKeyId}",
			"--always-trust", "--recipient=$params{user}{gpgKeyId}", "--keyring=$keyring", @gpgOptions,
			"--sign", "--encrypt" ];
		my $ok = $m->ipcRun($cmd, \$in, \$out, \$err);
		$ok && $out or $m->logError("Send email: GnuPG failed ($err)");
		$body = $out;
	}

	if ($cfg->{mailer} eq 'SMTP') {
		# Send via SMTP with Mail::Sendmail
		require MwfSendmail;
		MwfSendmail::sendmail(smtp => $cfg->{smtpServer}, From => $from, To => $to, 
			Subject => $subject, Body => $body,
			'Content-Type' => "text/plain; charset=utf-8", 'X-mwForum-BounceAuth' => $bounceAuth) 
			or $m->logError("Send email: $MwfSendmail::error");
	}
	elsif ($cfg->{mailer} eq 'SMTP2') {
		# Send via SMTP with Net::SMTP
		require Net::SMTP;
		$body = MIME::QuotedPrint::encode($body, "\n");
		my $smtp = Net::SMTP->new(Host => $cfg->{smtpServer}, Timeout => 10, Debug => 0);
		my $data = "From: $from\n" . "To: $to\n" . "Subject: $subject\n" . 
			"MIME-Version: 1.0\n" . "Content-Type: text/plain; charset=utf-8\n" . 
			"Content-Transfer-Encoding: quoted-printable\n" . "X-mwForum-BounceAuth: $bounceAuth\n" .
			"\n" . $body;
		$smtp->mail($cfg->{forumEmail}) or $m->logError("Send email: mail() failed."), return;
		$smtp->recipient($to) or $m->logError("Send email: recipient() failed."), return;
		$smtp->data($data) or $m->logError("Send email: data() failed."), return;
		$smtp->quit() or $m->logError("Send email: quit() failed."), return;
	}
	elsif ($cfg->{mailer} eq 'ESMTP') {
		# Send via ESMTP with Mail::Sender
		eval { require Mail::Sender } or $m->error("Mail::Sender module not available.");
		Mail::Sender->new()->MailMsg({ smtp => $cfg->{smtpServer}, from => $from, to => $to, 
			subject => $subject, msg => $body, ctype => "text/plain", charset => "utf-8", 
			encoding => "quoted-printable", auth => $cfg->{esmtpAuth}, authid => $cfg->{esmtpUser},
			authpwd => $cfg->{esmtpPassword}, headers => "X-mwForum-BounceAuth: $bounceAuth" }) >= 0 
			or $m->logError("Send email failed: $Mail::Sender::Error");
	}
	elsif ($cfg->{mailer} eq 'sendmail' || $cfg->{mailer} eq 'mail') {
		# Send via sendmail or mail command
		$body = MIME::QuotedPrint::encode($body, "\n");
		my $cmd = $cfg->{mailer} eq 'mail' ? 'mail' : $cfg->{sendmail};
		my @arg = $cfg->{mailer} eq 'mail' ? ($to) : ();
		$SIG{PIPE} = 'IGNORE';
		open my $pipe, "|-", $cmd, @arg or $m->logError("Send email: opening pipe failed."), return;
		print $pipe
			"From: $from\n", "To: $to\n", "Subject: $subject\n",
			"MIME-Version: 1.0\n", "Content-Type: text/plain; charset=utf-8\n",
			"Content-Transfer-Encoding: quoted-printable\n", "X-mwForum-BounceAuth: $bounceAuth\n",
			"\n", $body;
		close $pipe;
	}
	elsif ($cfg->{mailer} eq 'mailx') {
		# Send via mailx command (no portable way to pass headers except subject)
		$SIG{PIPE} = 'IGNORE';
		open my $pipe, "|-", 'mailx', "-s $subject", $to
			or $m->logError("Send email: opening pipe failed."), return;;
		print $pipe $body;
		close $pipe;
	}
	else { $m->logError("Send email failed: no valid email transport selected.") }
}

#------------------------------------------------------------------------------
# Check email address for blocks and validity

sub checkEmail
{
	my $m = shift();
	my $email = shift();

	length($email) || $m->{user}{admin} or $m->formError('errEmlEmpty');
	
	if (length($email)) {
		length($email) >= 6 && length($email) <= 100 or $m->formError('errEmlSize');

		# Check address syntax
		$email =~ /^[A-Za-z_0-9.+-]+?\@(?:[A-Za-z_0-9-]+\.)+[A-Za-z]{2,}\z/
			or $m->formError('errEmlInval');
		
		# Some n00bs try to add "www." in front of the address
		$email = lc($email);
		$email !~ /^www\./ or $m->formError('errEmlInval');
	
		# Check against hostname blocks
		index($email, lc) < 0 or $m->formError('errBlockEmlT') for @{$m->{cfg}{hostnameBlocks}};
	}
}


###############################################################################
# Helper packages

#------------------------------------------------------------------------------
# Case-i tied hash for PgSQL DBI hashes

package MwfMain::PgHash;

sub TIEHASH  { bless $_[1] }
sub FETCH    { $_[0]->{lc $_[1]} }
sub STORE    { $_[0]->{lc $_[1]} = $_[2] }
sub DELETE   { delete $_[0]->{lc $_[1]} }
sub EXISTS   { exists $_[0]->{lc $_[1]} }
sub FIRSTKEY { scalar keys %{$_[0]}; each %{$_[0]} }
sub NEXTKEY  { each %{$_[0]} }
sub SCALAR   { scalar %{$_[0]} }
sub CLEAR    { $_[0] = {} }

#------------------------------------------------------------------------------
# Exception that plugin functions can use to signal forum to exit

package MwfMain::PluginError;

sub new { bless \$_[1], $_[0] }

#------------------------------------------------------------------------------
# Include module that can override and add methods

do 'MwfMainLocal.pm';

#------------------------------------------------------------------------------
# Return OK
1;
