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
$cfg->{userList} or $m->error('errNoAccess');
$cfg->{userList} != 2 || $userId or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Get CGI parameters
my $page = $m->paramInt('pg') || 1;
my $search = $m->paramStr('search') || "";
my $field = $m->paramStrId('field') || 'userName';
my $sort = $m->paramStrId('sort') || 'field';
my $order = $m->paramStrId('order') || 'desc';
my $hideEmpty = $m->paramBool('hide');

# Define values and names for selectable fields
my %fields = (
	userName => $lng->{uifProfUName},
	realName => $lng->{uifProfRName},
	homepage => $lng->{uifProfPage},
	occupation => $lng->{uifProfOccup},
	hobbies => $lng->{uifProfHobby},
	location => $lng->{uifProfLocat},
	icq => $lng->{uifProfIcq},
	avatar => $lng->{uifProfAvat},
	birthday => $lng->{uifProfBdate},
	regTime => $lng->{uifStatRegTm},
	postNum => $lng->{uifStatPNum},
);
$fields{extra1} = $cfg->{extra1} if $cfg->{extra1} && $cfg->{showExtra1};
$fields{extra2} = $cfg->{extra2} if $cfg->{extra2} && $cfg->{showExtra2};
$fields{extra3} = $cfg->{extra3} if $cfg->{extra3} && $cfg->{showExtra3};

# Enforce valid options
$field = 'userName' if !$fields{$field};
$sort = 'userName' if $sort !~ /^(?:userName|id|field)\z/;
$order = 'desc' if $order !~ /^(?:asc|desc)\z/;

# Preserve parameters in links
my @params = 
	(search => $search, field => $field, sort => $sort, order => $order, hide => $hideEmpty);

# Search for username
my $fieldCast = $m->{pgsql} ? "CAST($field AS VARCHAR)" : $field;
my $hideEmptyStr = $hideEmpty ? "AND $fieldCast <> ''" : "";
my $searchEsc = $m->escHtml($search);
my $searchLike = "%" . $m->dbEscLike($searchEsc) . "%";
my $like = $m->{pgsql} ? 'ILIKE' : 'LIKE';
my $searchStr = $search ? "AND $fieldCast $like :search" : "";

# Sort list by
my $orderStr = "";
if ($sort eq 'userName') { $orderStr = "userName $order" }
elsif ($sort eq 'field') { $orderStr = "$field $order" }
else { $orderStr = "id $order" }

# Get ids of users
my $users = $m->fetchAllArray("
	SELECT id
	FROM users 
	WHERE 1 = 1 
		$searchStr 
		$hideEmptyStr
	ORDER BY $orderStr",
	{ search => $searchLike });

# Print page bar
my $usersPP = $cfg->{usersPP} || 25;
my $pageNum = int(@$users / $usersPP) + (@$users % $usersPP != 0);
my @pageLinks = $pageNum < 2 ? () : $m->pageLinks('user_list', \@params, $page, $pageNum);
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{uliTitle}, navLinks => \@navLinks, pageLinks => \@pageLinks);

# Get users on page
my @pageUsers = @$users[($page - 1) * $usersPP .. $m->min($page * $usersPP, scalar @$users) - 1];
my @pageUserIds = map($_->[0], @pageUsers);
$users = $m->fetchAllHash("
	SELECT id, userName, email, birthyear, $field 
	FROM users
	WHERE id IN (:pageUserIds)
	ORDER BY $orderStr",
	{ pageUserIds => \@pageUserIds });

# Determine checkbox, radiobutton and listbox states
my $hideEmptyChk = $hideEmpty ? 'checked' : "";
my %state = ( $sort => 'selected', $order => 'selected', "field$field" => 'selected' );

# Print user list form
print
	"<form action='user_list$m->{ext}' method='get'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{uliLfmTtl}</span></div>\n",
	"<div class='ccl'>\n",
	"<div class='cli'>\n",
	"<label>$lng->{uliLfmField}\n",
	"<select name='field' size='1'>\n",
	map("<option value='$_' $state{\"field$_\"}>$fields{$_}</option>\n",
		sort({$fields{$a} cmp $fields{$b}} keys(%fields))),
	"</select></label>\n",
	"<label>$lng->{uliLfmSort}\n",
	"<select name='sort' size='1'>\n",
	"<option value='field' $state{field}>$lng->{uliLfmSrtFld}</option>\n",
	"<option value='userName' $state{userName}>$lng->{uliLfmSrtNam}</option>\n",
	"<option value='id' $state{id}>$lng->{uliLfmSrtUid}</option>\n",
	"</select></label>\n",
	"<label>$lng->{uliLfmOrder}\n",
	"<select name='order' size='1'>\n",
	"<option value='desc' $state{desc}>$lng->{uliLfmOrdDsc}</option>\n",
	"<option value='asc' $state{asc}>$lng->{uliLfmOrdAsc}</option>\n",
	"</select></label>\n",
	"<label>$lng->{uliLfmSearch}\n",
	"<input type='text' name='search' style='width: 100px' value='$searchEsc'></label>\n",
	"<label><input type='checkbox' name='hide' $hideEmptyChk>$lng->{uliLfmHide}</label>\n",
	$m->submitButton('uliLfmListB', 'search'),
	"</div>\n",
	"</div>\n",
	"</div>\n",
	"</form>\n\n";

# Print user list header
print 
	"<table class='tbl'>\n",
	"<tr class='hrw'>\n",
	"<th class='shr'>$lng->{uliLstName}</th>\n",
	$field ne 'userName' ? "<th>$fields{$field}</th>\n" : "",
	"</tr>\n";

# Print user list
for my $listUser (@$users) {
	# Get string for selectable field
	my $fieldStr = $listUser->{$field};
	if ($field eq 'userName') { $fieldStr = "" }
	elsif ($field eq 'postNum') { $fieldStr .= " " . $m->formatUserRank($fieldStr) }
	elsif ($field eq 'birthday' && $listUser->{birthyear}) {
		$fieldStr = "$listUser->{birthyear}-$fieldStr";
	}
	elsif ($field =~ /Time\z/) { $fieldStr = $m->formatTime($fieldStr, $user->{timezone}) }
	elsif ($fieldStr =~ /^https?:/) { $fieldStr = "<a href='$fieldStr'>$fieldStr</a>" }
	elsif ($field eq 'avatar' && $fieldStr) { 
		my $url = "";
		if (index($fieldStr, "gravatar:") == 0) {
			my $md5 = $m->md5(substr($fieldStr, 9));
			$url = "//gravatar.com/avatar/$md5?s=$cfg->{avatarWidth}";
		}
		else {
			$url = "$cfg->{attachUrlPath}/avatars/$fieldStr";
		}
		$fieldStr = "<img src='$url' alt=''>";
	}

	my $url = $m->url('user_info', uid => $listUser->{id});
	print
		"<tr class='crw'>\n",
		"<td><a href='$url'>$listUser->{userName}</a></td>\n",
		$field ne 'userName' ? "<td>$fieldStr</td>\n" : "",
		"</tr>\n";
}

print "</table>\n\n";

# Log action and finish
$m->logAction(3, 'user', 'list', $userId);
$m->printFooter();
$m->finish();
