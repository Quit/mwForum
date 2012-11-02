package MwfConfig;
use strict;
use warnings;
our ($VERSION, $cfg);
$VERSION = "2.27.4";

#-----------------------------------------------------------------------------
# Basic options
# The following options are required by the forum before it can load the 
# rest of the configuration from the database.

# Base URL without path (no trailing /)
$cfg->{baseUrl}        = "http://www.example.com";

# URL path to data directory (no trailing /)
$cfg->{dataPath}       = "/mwf";

# Database server host
$cfg->{dbServer}       = "localhost";

# Database name
$cfg->{dbName}         = "mwforum";

# Database user
$cfg->{dbUser}         = "mwforum";

# Database password
$cfg->{dbPassword}     = "password";

# Database table name prefix in MySQL (usually not required)
$cfg->{dbPrefix}       = "";

# DBI driver. Either "mysql", "Pg" or "SQLite".
$cfg->{dbDriver}       = "mysql";

# Additional DBI parameters (usually not required)
# Example: "port=321;mysql_socket=/tmp/mysql.sock"
$cfg->{dbParam}        = "";

# Max. size of attachments 
# Also limits general CGI input. Don't set it below a few thousand byte.
$cfg->{maxAttachLen}   = 1048576;

#-----------------------------------------------------------------------------
# The following options can only be changed here and not in the online form 
# for security reasons.

# Sendmail executable and options (only required for sendmail mailer)
$cfg->{sendmail}       = "/usr/sbin/sendmail -oi -oeq -t";

# Filesystem path of the attachment directory (no trailing /)
$cfg->{attachFsPath}   = "";

# Filesystem path of the script directory (no trailing /)
# Required for cron emu, manual cron starting and instant subscriptions
# Example: "/usr/local/apache/cgi-bin/mwf"
$cfg->{scriptFsPath}   = "";

# Filesystem path of the Perl interpreter
# Required for cron emu, manual cron starting and instant subscriptions
$cfg->{perlBinary}     = "/usr/bin/perl";

# Limit forum options and details pages to certain admins, otherwise
# all admins have access
# Comma-sep. list of numeric user IDs, example: "1,2,3"
$cfg->{cfgAdmins}      = "";

# Log errors/warnings into this file in addition to the webserver log
# Example: "/var/log/forum.log"
$cfg->{errorLog}       = "";

#------------------------------------------------------------------------------
# Other options go here


#-----------------------------------------------------------------------------
# Return OK
1;
