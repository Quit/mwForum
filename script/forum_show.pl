#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2014 Markus Wichitill
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

# Get categories
my $categs = $m->fetchAllHash("
	SELECT id, title FROM categories ORDER BY pos");

# Get boards
my $arcPfx = $m->{archive} ? 'arc_' : "";
my $boardHiddenStr = $userId ? ",
	boardHiddenFlags.boardId IS NOT NULL AS hidden, 
	boardHiddenFlags.manual AS manualHidden" : "";
my $boardHiddenJoinStr = $userId ? "
	LEFT JOIN boardHiddenFlags AS boardHiddenFlags
		ON boardHiddenFlags.userId = :userId
		AND boardHiddenFlags.boardId = boards.id" : "";
my $boards = $m->fetchAllHash("
	SELECT boards.*
		$boardHiddenStr
	FROM ${arcPfx}boards AS boards
		$boardHiddenJoinStr
	ORDER BY boards.pos",
	{ userId => $userId });
for my $board (@$boards) {
	$board->{visible} = $m->boardVisible($board);
	$board->{visible} = 2 if !$board->{visible} && $board->{list};
}
@$boards = grep($_->{visible}, @$boards);
my %boards = ();
my %boardsByCateg = ();
my @adminBoardIds = ();
my @statBoardIds = ();
for my $board (@$boards) { 
	my $boardId = $board->{id};
	$boards{$boardId} = $board;
	push @{$boardsByCateg{$board->{categoryId}}}, $board;
	push @adminBoardIds, $boardId if $userId && $m->boardAdmin($userId, $boardId);
	push @statBoardIds, $boardId if $board->{visible} == 1 && !$board->{hidden};
}

# New posts/read posts statistics
my $newPostsExist = 0;
my $unreadPostsExist = 0;
if ($user->{prevOnTime} < 2147483647 && !$m->{archive}) {
	# Get new post numbers
	my $approvedStr = $user->{admin} ? "" : "AND approved = 1";
	my $stats = $m->fetchAllArray("
		SELECT boardId, COUNT(*) AS newNum
		FROM posts 
		WHERE boardId IN (:boardIds)
			AND postTime > :prevOnTime
			$approvedStr
		GROUP BY boardId",
		{ boardIds => \@statBoardIds, prevOnTime => $user->{prevOnTime} });
	for my $stat (@$stats) {
		$boards{$stat->[0]}{newNum} = $stat->[1];
		$newPostsExist = 1;
	}

	# Check whether there's at least one unread topic
	if ($userId) {
		my $lowestUnreadTime = $m->max($user->{fakeReadTime}, 
			$m->{now} - $cfg->{maxUnreadDays} * 86400);
		$stats = $m->fetchAllArray("
			SELECT boards.id, COUNT(topics.id) AS hasUnread
			FROM boards AS boards
				INNER JOIN topics AS topics
					ON topics.boardId = boards.id
				LEFT JOIN topicReadTimes AS topicReadTimes
					ON topicReadTimes.userId = :userId
					AND topicReadTimes.topicId = topics.id 
			WHERE boards.id IN (:boardIds)
				AND topics.lastPostTime > :lowestUnreadTime
				AND (topics.lastPostTime > topicReadTimes.lastReadTime 
					OR topicReadTimes.topicId IS NULL)
			GROUP BY boards.id",
			{ userId => $userId, boardIds => \@statBoardIds, lowestUnreadTime => $lowestUnreadTime });
		for my $stat (@$stats) {
			$boards{$stat->[0]}{hasUnread} = $stat->[1];
			$unreadPostsExist = 1;
		}
	}
}

# User button links
my @userLinks = ();
if (!$m->{archive}) {
	push @userLinks, { url => $m->url('forum_info'), txt => 'frmInfo', ico => 'info' };
	push @userLinks, { url => $m->url('user_list'), txt => 'frmUsers', ico => 'user' }
		if $cfg->{userList} == 1 || $cfg->{userList} == 2 && $userId;
	push @userLinks, { url => $m->url('attach_list'), txt => 'frmAttach', ico => 'attach' }
		if $cfg->{attachList} == 1 || $cfg->{attachList} == 2 && $userId 
		|| $cfg->{attachList} == 3 && $user->{admin};
	push @userLinks, { url => $m->url('forum_feeds'), txt => 'comFeeds', ico => 'feed' } 
		if $cfg->{rssLink};
	push @userLinks, { url => $m->url('user_mark', act => 'old', time => $m->{now}, auth => 1),
		txt => 'frmMarkOld', ico => 'markold' }
		if $newPostsExist || (!$userId && !$cfg->{noGuestCookies} && $user->{prevOnTime} == 2147483647);
	push @userLinks, { url => $m->url('user_mark', act => 'read', time => $m->{now}, auth => 1), 
		txt => 'frmMarkRd', ico => 'markread' }
		if $unreadPostsExist && $userId;
	push @userLinks, { url => $m->url('forum_overview', act => 'new'), 
		txt => 'comShowNew', ico => 'shownew' }
		if $newPostsExist;
	push @userLinks, { url => $m->url('forum_overview', act => 'unread'), 
		txt => 'comShowUnr', ico => 'showunread' }
		if $userId && $unreadPostsExist;
	for my $plugin (@{$cfg->{includePlg}{forumUserLink}}) {
		$m->callPlugin($plugin, links => \@userLinks);
	}
}

# Admin button links
my @adminLinks = ();
if ($user->{admin} && !$m->{archive}) {
	my $reportNum = 0;
	$reportNum = $m->fetchArray("
		SELECT COUNT(*) FROM postReports")
		if $cfg->{reports};
	push @adminLinks, { url => $m->url('forum_options'), txt => "Options", ico => 'admopt' };
	push @adminLinks, { url => $m->url('user_admin'), txt => "Users", ico => 'user' };
	push @adminLinks, { url => $m->url('group_admin'), txt => "Groups", ico => 'group' };
	push @adminLinks, { url => $m->url('board_admin'), txt => "Boards", ico => 'board' };
	push @adminLinks, { url => $m->url('categ_admin'), txt => "Categories", ico => 'category' };
	push @adminLinks, { url => $m->url('cron_admin'), txt => "Cron", ico => 'cron' };
	push @adminLinks, { url => $m->url('log_admin'), txt => "Log", ico => 'log' };
	push @adminLinks, { url => $m->url('forum_purge'), txt => "Purge", ico => 'delete' };
	push @adminLinks, { url => $m->url('report_list'), 
		txt => "<em class='eln'>Reports ($reportNum)</em>", ico => 'report' } 
		if $reportNum;
	for my $plugin (@{$cfg->{includePlg}{forumAdminLink}}) {
		$m->callPlugin($plugin, links => \@adminLinks);
	}
}
elsif (@adminBoardIds && !$m->{archive}) {
	my $reportNum = $m->fetchArray("
		SELECT COUNT(*) 
		FROM postReports AS postReports
			INNER JOIN posts AS posts
				ON posts.id = postReports.postId
		WHERE posts.boardId IN (:boardIds)",
		{ boardIds => \@adminBoardIds });
		push @adminLinks, { url => $m->url('report_list'), 
			txt => "<em class='eln'>$lng->{brdAdmRep} ($reportNum)</em>", ico => 'report' }
			if $reportNum;
	for my $plugin (@{$cfg->{includePlg}{forumAdminLink}}) {
		$m->callPlugin($plugin, links => \@adminLinks);
	}
}

# Print page bar
$m->printPageBar(mainTitle => $lng->{frmTitle}, userLinks => \@userLinks, 
	adminLinks => \@adminLinks);

# Print notifications
if ($userId && !$m->{archive}) {
	my $notes = $m->fetchAllHash("
		SELECT id, body, sendTime
		FROM notes
		WHERE userId = :userId
		ORDER BY id DESC", 
		{ userId => $userId });
	if (@$notes) {
		print
			"<div class='frm ntf'>\n",
			"<div class='hcl'><span class='htt'>$lng->{frmNotTtl}</span></div>\n",
			"<div class='ccl not'>\n",
			"<table class='tiv'>\n";
		for my $note (@$notes) {
			my $body = $note->{body};
			$body =~ s!$m->{ext}\?!$m->{ext}?dln=$note->{id};!;
			my $timeStr = $m->formatTime($note->{sendTime}, $user->{timezone});
			print "<tr><td class='shr'>$timeStr: </td><td>$body</td></tr>\n";
		}
		print
			"</table>\n",
			"<form action='note_delete$m->{ext}' method='post'>\n",
			$m->submitButton('frmNotDelB', 'remove'),
			$m->stdFormFields(),
			"</form>\n",
			"</div>\n",
			"</div>\n\n";
	}
}

# Print table
print "<table class='tbl'>\n";

# Print categories/boards
my $emptyPixel = "src='$cfg->{dataPath}/epx.png'";
my $boardsPrinted = 0;
for my $categ (@$categs) {
	my $categId = $categ->{id};
	next if !$boardsByCateg{$categId};
	next if !grep(!$_->{manualHidden}, @{$boardsByCateg{$categId}});
	
	# Print category
	my $allHidden = !grep(!$_->{hidden}, @{$boardsByCateg{$categId}});
	my $action = $allHidden ? 'show' : 'hide';
	my $toggleUrl = $m->url('categ_toggle', act => $action, cid => $categId, auth => 1);
	my $toggle = "";
	if ($userId && $allHidden) { 
		$toggle = "<a href='$toggleUrl'><img class='sic sic_nav_plus'"
			. " $emptyPixel title='$lng->{frmCtgExpand}' alt='+'></a>";
	}
	elsif ($userId) { 
		$toggle = "<a href='$toggleUrl'><img class='sic sic_nav_minus'"
			. " $emptyPixel title='$lng->{frmCtgCollap}' alt='-'></a>";
	}
	print
		"<tr class='hrw' id='cid$categId'>\n",
		"<th class='icl'>$toggle</th>\n",
		"<th>$categ->{title}</th>\n",
		"<th class='shr'>$lng->{frmPosts}</th>\n",
		"<th class='shr'>$lng->{frmLastPost}</th>\n",
		"</tr>\n";

	for my $board (@{$boardsByCateg{$categId}}) {
		my $boardId = $board->{id};
		next if $board->{hidden};
		
		# Format output
		my $lastPostTimeStr = $board->{lastPostTime} > 0 
			? $m->formatTime($board->{lastPostTime}, $user->{timezone}) : " - ";
		my $ovwUrl = $m->url('forum_overview', act => 'new', bid => $boardId);
		my $newNumStr = $board->{newNum} 
			? " <a href='$ovwUrl'>($board->{newNum} $lng->{frmNew})</a>" : "";

		# Determine variable board icon attributes
		my ($imgName, $imgTitle, $imgAlt);
		if ($userId) {
			if ($board->{newNum} && $board->{hasUnread}) { 
				$imgName = "board_nu"; $imgTitle = $lng->{comNewUnrdTT}; $imgAlt = $lng->{comNewUnrd};
			}
			elsif ($board->{newNum}) { 
				$imgName = "board_nr"; $imgTitle = $lng->{comNewReadTT}; $imgAlt = $lng->{comNewRead};
			}
			elsif ($board->{hasUnread}) { 
				$imgName = "board_ou"; $imgTitle = $lng->{comOldUnrdTT}; $imgAlt = $lng->{comOldUnrd};
			}
			else { 
				$imgName = "board_or"; $imgTitle = $lng->{comOldReadTT}; $imgAlt = $lng->{comOldRead};
			}
		}
		else {
			if ($board->{newNum}) { 
				$imgName = "board_nu"; $imgTitle = $lng->{comNewTT}; $imgAlt = $lng->{comNew};
			}
			else { 
				$imgName = "board_ou"; $imgTitle = $lng->{comOldTT}; $imgAlt = $lng->{comOld};
			}
		}
		my $imgAttr = "class='sic sic_$imgName' title='$imgTitle' alt='$imgAlt'";

		# Print board
		if ($board->{visible} == 1) {
			# Normally accessible board
			my $boardUrl = $m->url('board_show', bid => $boardId);
			print 
				"<tr class='crw'>\n",
				"<td class='icl'><img $emptyPixel $imgAttr></td>\n",
				"<td><a id='bid$boardId' href='$boardUrl'>$board->{title}</a>",
				$user->{boardDescs} && $board->{shortDesc} 
					? "<div class='bds'>$board->{shortDesc}</div>" : "",
				"</td>\n",
				"<td class='shr'>$board->{postNum} $newNumStr</td>\n",
				"<td class='shr'>$lastPostTimeStr</td>\n",
				"</tr>\n";
		}
		else {
			# Board for which user has no access, but which should be listed anyway
			my $reason = $board->{private} == 1 ? $lng->{frmMbrOnly} : $lng->{frmRegOnly};
			print
				"<tr class='crw'>\n",
				"<td class='icl'><img class='sic sic_board_ou' $emptyPixel alt=''></td>\n",
				"<td><span class='nxs' title='$reason'>$board->{title}</span>\n",
				$user->{boardDescs} && $board->{shortDesc} 
					? "<div class='bds'>$board->{shortDesc}</div>" : "",
				"</td>\n",
				"<td class='shr'>$board->{postNum}</td>\n",
				"<td class='shr'>$lastPostTimeStr</td>\n",
				"</tr>\n";
		}
			
		# At least one board printed
		$boardsPrinted++;
	}
}

print "</table>\n\n";

# Print notification that there were no visible boards
$m->printHints([$lng->{frmNoBoards}]) if !$boardsPrinted;

# Get users online in the last five minutes
my $privacyStr = $user->{admin} ? "" : "AND privacy = 0";
my $maxOnlUserNum = $cfg->{maxOnlUserNum} || 50;
my $maxOnlUserAge = $cfg->{maxOnlUserAge} || 300;
my $onlUsers = [];
if ($cfg->{showOnlUsers} && ($userId || $cfg->{showOnlUsers} == 2) && !$m->{archive}) {
	$onlUsers = $m->fetchAllArray("
		SELECT id, userName
		FROM users
		WHERE :now - lastOnTime < :maxOnlUserAge
			AND id <> :userId
			AND lastOnTime <> regTime
			$privacyStr
		ORDER BY lastOnTime DESC
		LIMIT :maxOnlUserNum", 
		{ now => $m->{now}, maxOnlUserAge => $maxOnlUserAge, userId => $userId, 
			maxOnlUserNum => $maxOnlUserNum });
}

# Get newest users
my $maxNewUserNum = $cfg->{maxNewUserNum} || 10;
my $maxNewUserAge = $cfg->{maxNewUserAge} || 3;
my $newUsers = [];
if ($cfg->{showNewUsers} && ($userId || $cfg->{showNewUsers} == 2) && !$m->{archive}) {
	$newUsers = $m->fetchAllArray("
		SELECT id, userName
		FROM users
		WHERE :now - regTime < :maxNewUserAge * 86400
			$privacyStr
		ORDER BY regTime DESC
		LIMIT :maxNewUserNum",
		{ now => $m->{now}, maxNewUserAge => $maxNewUserAge, maxNewUserNum => $maxNewUserNum });
}

# Get birthday boys/girls
my $bdayUsers = [];
if ($cfg->{showBdayUsers} && ($userId || $cfg->{showBdayUsers} == 2) && !$m->{archive}) {
	my (undef, undef, undef, undef, undef, $year) = localtime(time);
	$year += 1900;
	my $day = $m->formatTime($m->{now}, $user->{timezone}, "%m-%d");
	$bdayUsers = $m->fetchAllArray("
		SELECT id, userName, birthyear, :year - birthyear AS age
		FROM users
		WHERE birthday = :day", 
		{ year => $year, day => $day });
	for my $bdayUser (@$bdayUsers) { 
		$bdayUser->[1] .= " ($bdayUser->[3])" if $bdayUser->[2] 
	}
}

# Print statistics
print
	"<div class='frm sta'>\n",
	"<div class='hcl'><span class='htt'>$lng->{frmStats}</span></div>\n",
	"<div class='ccl'>\n"
	if @$onlUsers || @$newUsers || @$bdayUsers;

print 
	"<div><span title='$lng->{frmOnlUsrTT}'>$lng->{frmOnlUsr}:\n",
	join(",\n", map("<a href='" . $m->url('user_info', uid => $_->[0]) . "'>$_->[1]</a>",
		@$onlUsers)), "\n",
	"</span></div>\n"
	if @$onlUsers;

print
	"<div><span title='$lng->{frmNewUsrTT}'>$lng->{frmNewUsr}:\n",
	join(",\n", map("<a href='" . $m->url('user_info', uid => $_->[0]) . "'>$_->[1]</a>",
		@$newUsers)), "\n",
	"</span></div>\n"
	if @$newUsers;

print
	"<div><span title='$lng->{frmBdayUsrTT}'>$lng->{frmBdayUsr}:\n",
	join(",\n", map("<a href='" . $m->url('user_info', uid => $_->[0]) . "'>$_->[1]</a>",
		@$bdayUsers)), "\n",
	"</span></div>\n"
	if @$bdayUsers;

print 
	"</div>\n</div>\n\n"
	if @$onlUsers || @$newUsers || @$bdayUsers;

# Log action and finish
$m->logAction(2, 'forum', 'show', $userId);
$m->printFooter();
$m->finish();
