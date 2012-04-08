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

# Print header
$m->printHeader();

# Print page bar
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{hlpTitle}, navLinks => \@navLinks);

# Replace placeholders in text
my $help = $lng->{help};
$help =~ s!\[\[dataPath\]\]!$cfg->{dataPath}!g;

# Print help
print
	"<div class='frm hlp def'>\n",
	"<div class='hcl'><span class='htt'>$lng->{hlpTxtTtl}</span></div>\n",
	"<div class='ccl'>\n",
	$help,
	"</div>\n",
	"</div>\n\n";

# Print FAQ
print
	"<div class='frm hlp faq' id='faq'>\n",
	"<div class='hcl'><span class='htt'>$lng->{hlpFaqTtl}</span></div>\n",
	"<div class='ccl'>\n",
	$lng->{faq},
	"</div>\n",
	"</div>\n\n";

# Log action and finish
$m->logAction(3, 'forum', 'help', $userId);
$m->printFooter();
$m->finish();
