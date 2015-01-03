#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2015 Markus Wichitill
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

# Print header
$m->printHeader();

# Get CGI parameters
my $boardId = $m->paramInt('bid');
$boardId or $m->error('errParamMiss');

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Is board visible to user?
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $board->{id});
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');

# Admin button links
my @adminLinks = ();
if ($boardAdmin && !$m->{archive}) {
	if ($user->{admin}) {
		push @adminLinks, { url => $m->url('board_options', bid => $boardId, ori => 1), 
			txt => "Options", ico => 'admopt' };
		push @adminLinks, { url => $m->url('board_groups', bid => $boardId, ori => 1), 
			txt => "Groups", ico => 'group' };
		push @adminLinks, { url => $m->url('board_merge', bid => $boardId), 
			txt => "Merge", ico => 'merge' };
		push @adminLinks, { url => $m->url('board_split', bid => $boardId), 
			txt => "Split", ico => 'split' };
		push @adminLinks, { url => $m->url('board_archive', bid => $boardId), 
			txt => "Archive", ico => 'archive' }
			if !$m->{sqlite};
		push @adminLinks, { url => $m->url('user_confirm', bid => $boardId, script => 'board_delete', 
			name => $board->{title}), txt => "Delete", ico => 'delete' };
		for my $plugin (@{$cfg->{includePlg}{boardAdminLink}}) {
			$m->callPlugin($plugin, links => \@adminLinks, board => $board);
		}
			
	}
	else {
		push @adminLinks, { url => $m->url('board_groups', bid => $boardId, ori => 1), 
			txt => 'brdAdmGrp', ico => 'group' };
		push @adminLinks, { url => $m->url('board_split', bid => $boardId), 
			txt => 'brdAdmSpl', ico => 'split' };
		for my $plugin (@{$cfg->{includePlg}{boardAdminLink}}) {
			$m->callPlugin($plugin, links => \@adminLinks, board => $board)
		}
	}
}

# Print page bar
my @navLinks = ({ url => $m->url('board_show', bid => $boardId), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{bifTitle}, subTitle => $board->{title}, 
	navLinks => \@navLinks, adminLinks => \@adminLinks);

# Prepare strings
my $descStr = $board->{longDesc} || $board->{shortDesc};
my $privStr = $lng->{"bifOptPriv$board->{private}"};
my $anncStr = $lng->{"bifOptAnnc$board->{announce}"};
my $unrgStr = $board->{unregistered} ? $lng->{bifOptUnrgY} : $lng->{bifOptUnrgN};
my $aprvStr = $board->{approve} ? $lng->{bifOptAprvY} : $lng->{bifOptAprvN};
my $flatStr = $board->{flat} ? $lng->{bifOptFlatY} : $lng->{bifOptFlatN};
my $attcStr = $board->{attach} ? $lng->{bifOptAttcY} : $lng->{bifOptAttcN};
my $lockStr = $board->{locking} ? "$board->{locking} $lng->{bifOptLockT}" : "-";
my $expiStr = $board->{expiration} ? "$board->{expiration} $lng->{bifOptExpT}" : "-";

# Print board options
print
	"<table class='tbl'>\n",
	"<tr class='hrw'><th colspan='2'>$lng->{bifOptTtl}</th></tr>\n",
	"<tr class='crw'><td class='hco'>$lng->{bifOptDesc}</td><td>$descStr</td></tr>\n",
	"<tr class='crw'><td class='hco'>$lng->{bifOptPriv}</td><td>$privStr</td></tr>\n",
	"<tr class='crw'><td class='hco'>$lng->{bifOptAnnc}</td><td>$anncStr</td></tr>\n",
	"<tr class='crw'><td class='hco'>$lng->{bifOptUnrg}</td><td>$unrgStr</td></tr>\n",
	"<tr class='crw'><td class='hco'>$lng->{bifOptAprv}</td><td>$aprvStr</td></tr>\n",
	"<tr class='crw'><td class='hco'>$lng->{bifOptFlat}</td><td>$flatStr</td></tr>\n",
	"<tr class='crw'><td class='hco'>$lng->{bifOptAttc}</td><td>$attcStr</td></tr>\n",
	"<tr class='crw'><td class='hco'>$lng->{bifOptLock}</td><td>$lockStr</td></tr>\n",
	"<tr class='crw'><td class='hco'>$lng->{bifOptExp}</td><td>$expiStr</td></tr>\n",
	"</table>\n\n";

# Get moderator groups
my $adminGroups = $m->fetchAllArray("
	SELECT groups.id, groups.title, 
		groups.public = 1 
		OR groupMembers.userId IS NOT NULL 
		OR groupAdmins.userId IS NOT NULL AS visible
	FROM boardAdminGroups AS boardAdminGroups
		INNER JOIN groups AS groups
			ON groups.id = boardAdminGroups.groupId
		LEFT JOIN groupMembers AS groupMembers
			ON groupMembers.userId = :userId
			AND groupMembers.groupId = groups.id
		LEFT JOIN groupAdmins AS groupAdmins
			ON groupAdmins.userId = :userId
			AND groupAdmins.groupId = groups.id
	WHERE boardAdminGroups.boardId = :boardId
	ORDER BY groups.title",
	{ userId => $userId, boardId => $boardId });

# Print moderator groups
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{bifAdmsTtl}</span></div>\n",
	"<div class='ccl'>\n",
	join(",\n", map($user->{admin} || $_->[2] 
		? "<a href='" . $m->url('group_info', gid => $_->[0]) . "'>$_->[1]</a>"	
		: $_->[1], @$adminGroups)) || " - ", "\n",
	"</div>\n",
	"</div>\n\n";

# Get member groups
my $memberGroups = $m->fetchAllArray("
	SELECT groups.id, groups.title, groupMembers.userId,
		groups.public = 1 
		OR groupMembers.userId IS NOT NULL 
		OR groupAdmins.userId IS NOT NULL AS visible
	FROM boardMemberGroups AS boardMemberGroups
		INNER JOIN groups AS groups
			ON groups.id = boardMemberGroups.groupId
		LEFT JOIN groupMembers AS groupMembers
			ON groupMembers.userId = :userId
			AND groupMembers.groupId = groups.id
		LEFT JOIN groupAdmins AS groupAdmins
			ON groupAdmins.userId = :userId
			AND groupAdmins.groupId = groups.id
	WHERE boardMemberGroups.boardId = :boardId
	ORDER BY groups.title",
	{ userId => $userId, boardId => $boardId });

# Print member groups
print
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>$lng->{bifMbrsTtl}</span></div>\n",
	"<div class='ccl'>\n",
	join(",\n", map($user->{admin} || $_->[2] 
		? "<a href='" . $m->url('group_info', gid => $_->[0]) . "'>$_->[1]</a>" 
		: $_->[1], @$memberGroups)) || " - ", "\n",
	"</div>\n",
	"</div>\n\n";

if ($user->{admin}) {
	# Get subscribers
	my $maxUserListNum = $cfg->{maxUserListNum} || 500;
	my $subscribers = $m->fetchAllArray("
		SELECT users.id, users.userName, boardSubscriptions.instant
		FROM boardSubscriptions AS boardSubscriptions
			INNER JOIN users AS users
				ON users.id = boardSubscriptions.userId 
		WHERE boardSubscriptions.boardId = :boardId
		ORDER BY users.userName
		LIMIT :maxUserListNum",
		{ boardId => $boardId, maxUserListNum => $maxUserListNum });

	# Print subscribers
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Subscribers</span></div>\n",
		"<div class='ccl'>\n",
		join(",\n", map("<a href='" . $m->url('user_info', uid => $_->[0]) 
			. "' title='Instant: $_->[2]'>$_->[1]</a>", @$subscribers)) || " - ", "\n",
		"</div>\n",
		"</div>\n\n";
}
	
# Log action and finish
$m->logAction(3, 'board', 'info', $userId, $boardId);
$m->printFooter();
$m->finish();
