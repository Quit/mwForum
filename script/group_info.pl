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
$m->cacheUserStatus() if $userId;

# Print header
$m->printHeader();

# Get CGI parameters
my $groupId = $m->paramInt('gid');
$groupId or $m->error('errParamMiss');

# Get group
my ($groupTitle, $public) = $m->fetchArray("
	SELECT title, public FROM groups WHERE id = ?", $groupId);
$groupTitle or $m->error('errGrpNotFnd');
my $groupAdmin = $m->fetchArray("
	SELECT 1 FROM groupAdmins WHERE userId = ? AND groupId = ?", $userId, $groupId);

# Check if user can see group
if (!$public) {
	my $groupMember = $m->fetchArray("
		SELECT 1 FROM groupMembers WHERE groupId = ? AND userId = ?", $groupId, $userId);
	$groupMember || $user->{admin} or $m->error('errNoAccess');
}

# Admin button links
my @adminLinks = ();
if ($user->{admin}) {
	push @adminLinks, { url => $m->url('group_options', gid => $groupId, ori => 1), 
		txt => "Options", ico => 'admopt' };
	push @adminLinks, { url => $m->url('group_members', gid => $groupId), 
		txt => "Members", ico => 'user' };
	push @adminLinks, { url => $m->url('group_boards', gid => $groupId, ori => 1), 
		txt => "Boards", ico => 'board' };
	push @adminLinks, { url => $m->url('user_confirm', gid => $groupId, script => 'group_delete', 
		name => $groupTitle), txt => "Delete", ico => 'delete' };
}
elsif ($groupAdmin) {
	push @adminLinks, { url => $m->url('group_members', gid => $groupId), 
		txt => $lng->{griMembers}, ico => 'user' };
}

# Print page bar
my @navLinks = ({ url => $m->url('group_admin'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{griTitle}, subTitle => $groupTitle,
	navLinks => \@navLinks, adminLinks => \@adminLinks);

# Get members
my $maxUserListNum = $cfg->{maxUserListNum} || 500;
my $members = $m->fetchAllArray("
	SELECT users.id, users.userName,
		CASE WHEN groupAdmins.userId IS NOT NULL THEN '\@' ELSE '' END
	FROM users AS users
		INNER JOIN groupMembers AS groupMembers
			ON groupMembers.userId = users.id
			AND groupMembers.groupId = :groupId
		LEFT JOIN groupAdmins AS groupAdmins
			ON groupAdmins.userId = users.id
			AND groupAdmins.groupId = :groupId
	ORDER BY users.userName
	LIMIT :maxUserListNum",
	{ groupId => $groupId, maxUserListNum => $maxUserListNum });

# Print members
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{griMbrTtl}</span></div>\n",
	"<div class='ccl'>\n",
	join(",\n", map("<a href='" . $m->url('user_info', uid => $_->[0]) . "'>$_->[2]$_->[1]</a>", 
		@$members)) || " - ", "\n",
	"</div>\n",
	"</div>\n\n";

# Get admin boards
my $boards = $m->fetchAllHash("
	SELECT boards.*
	FROM boardAdminGroups AS boardAdminGroups
		INNER JOIN boards AS boards
			ON boards.id = boardAdminGroups.boardId
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
	WHERE boardAdminGroups.groupId = :groupId
	ORDER BY categories.pos, boards.pos",
	{ groupId => $groupId });
@$boards = grep($m->boardVisible($_), @$boards);

# Print admin boards
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{griBrdAdmTtl}</span></div>\n",
	"<div class='ccl'>\n",
	join(",\n", map("<a href='" . $m->url('board_info', bid => $_->{id}) . "'>$_->{title}</a>", 
		@$boards)) || " - ", "\n",
	"</div>\n",
	"</div>\n\n";

# Get member boards
$boards = $m->fetchAllHash("
	SELECT boards.*
	FROM boardMemberGroups AS boardMemberGroups
		INNER JOIN boards AS boards
			ON boards.id = boardMemberGroups.boardId
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
	WHERE boardMemberGroups.groupId = :groupId
	ORDER BY categories.pos, boards.pos",
	{ groupId => $groupId });
@$boards = grep($m->boardVisible($_), @$boards);

# Print member boards
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{griBrdMbrTtl}</span></div>\n",
	"<div class='ccl'>\n",
	join(",\n", map("<a href='" . $m->url('board_info', bid => $_->{id}) . "'>$_->{title}</a>", 
		@$boards)) || " - ", "\n",
	"</div>\n",
	"</div>\n\n";

# Log action and finish
$m->logAction(3, 'group', 'info', $userId, 0, 0, 0, $groupId);
$m->printFooter();
$m->finish();
