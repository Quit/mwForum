package MwfConfigGlobal;
use strict;
use warnings;
our ($VERSION, $gcfg);
$VERSION = "2.23.0";

#------------------------------------------------------------------------------
# Multi-forum options 
# Only touch if you want to use the multi-forum support. See FAQ.html.

# Map hostnames or URL paths to forums
#$gcfg->{forums} = {
#  'foo.example.com' => 'MwfConfigFoo',
#  'bar.example.com' => 'MwfConfigBar',
#};
#$gcfg->{forums} = {
#  '/perl/foo'       => 'MwfConfigFoo',
#  '/perl/bar'       => 'MwfConfigBar',
#};

# Database name of one of the used databases under MySQL
#$gcfg->{dbName}         = "";

#-----------------------------------------------------------------------------
# Advanced options

# Print page creation time?
# Measures runtime, not CPU-time and not overhead like compilation time.
$gcfg->{pageTime}       = 0;

# Script filename extension
$gcfg->{ext}            = ".pl";

#-----------------------------------------------------------------------------
# Return OK
1;
