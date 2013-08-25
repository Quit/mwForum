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

# Get CGI parameters
my ($script) = $m->paramStr('script') =~ /^([A-Za-z_0-9]+)\z/;
my $act = $m->paramStrId('act');
my $uid = $m->paramInt('uid');
my $gid = $m->paramInt('gid');
my $cid = $m->paramInt('cid');
my $bid = $m->paramInt('bid');
my $tid = $m->paramInt('tid');
my $pid = $m->paramInt('pid');
my $mid = $m->paramInt('mid');
my $pollId = $m->paramInt('pollId');
my $name = $m->paramStr('name');
my $notify = $m->paramBool('notify');

# Print header
$m->printHeader();

# Determine entity type	
my $entity = "";
if ($pollId) { $entity = $lng->{cnfTypePoll} }
elsif ($uid) { $entity = $lng->{cnfTypeUser} }
elsif ($gid) { $entity = $lng->{cnfTypeGroup} }
elsif ($cid) { $entity = $lng->{cnfTypeCateg} }
elsif ($bid) { $entity = $lng->{cnfTypeBoard} }
elsif ($tid) { $entity = $lng->{cnfTypeTopic} }
elsif ($pid) { $entity = $lng->{cnfTypePost} }
elsif ($mid) { $entity = $lng->{cnfTypeMsg} }

# Determine question
my $question = "";
if ($script eq 'post_attach') {
	$question = $lng->{cnfDelAllAtt};
}
elsif ($entity) {
	my $nameEsc = $m->escHtml($m->deescHtml($name));
	$question = "$lng->{cnfQuestion} $entity \"$nameEsc\"$lng->{cnfQuestion2}";
}
elsif ($script eq 'message_delete') {
	$question = $lng->{cnfDelAllMsg};
}
elsif ($script eq 'chat_delete') {
	$question = $lng->{cnfDelAllCht};
}

# Print confirmation form
print
	"<form action='$script$m->{ext}' method='post'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{cnfTitle}</span></div>\n",
	"<div class='ccl'>\n",
	"<p>$question</p>\n";
	
# Print notification section
my $noteChk = $cfg->{noteDefMod} ? 'checked' : "";
print
	"<fieldset>\n",
	"<div><label><input type='checkbox' name='notify' autofocus $noteChk>",
	"$lng->{notNotify}</label></div>\n",
	"<datalist id='reasons'>\n",
	map("<option value='$_'>\n", @{$cfg->{modReasons}}),
	"</datalist>\n",
	"<input type='text' class='fwi' name='reason' list='reasons'>\n",
	"</fieldset>\n"
	if $notify;
	
print
	$m->submitButton('cnfDeleteB', 'delete'),
	"<input type='hidden' name='act' value='$act'>\n",
	"<input type='hidden' name='uid' value='$uid'>\n",
	"<input type='hidden' name='gid' value='$gid'>\n",
	"<input type='hidden' name='cid' value='$cid'>\n",
	"<input type='hidden' name='bid' value='$bid'>\n",
	"<input type='hidden' name='tid' value='$tid'>\n",
	"<input type='hidden' name='pid' value='$pid'>\n",
	"<input type='hidden' name='mid' value='$mid'>\n",
	"<input type='hidden' name='pollId' value='$pollId'>\n",
	$m->stdFormFields(),
	"</div>\n",
	"</div>\n",
	"</form>\n\n";

# Print footer
$m->printFooter();
$m->finish();
