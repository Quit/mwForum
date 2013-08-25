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
use List::Util qw(first);

#------------------------------------------------------------------------------

# Init
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0]);

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Get CGI parameters
my $page = $m->paramInt('pg') || 1;
my $search = $m->paramStr('search') || "";
my $field = $m->paramStrId('field') || $m->getVar('usrAdmFld', $userId) || 'realName';
my $sort = $m->paramStrId('sort') || $m->getVar('usrAdmSrt', $userId) || 'userName';
my $order = $m->paramStrId('order') || $m->getVar('usrAdmOrd', $userId) || 'desc';
my $hideEmpty = $m->paramDefined('search')
	? $m->paramBool('hide') : $m->getVar('usrAdmHid', $userId) || 0;

# Enforce valid parameters
$sort = 'userName' if $sort !~ /^(?:userName|id|lastOnTime|field)\z/;
$order = 'desc' if $order !~ /^(?:asc|desc)\z/;

# What to search through when searching for "identity"
my @identity = qw(userName realName oldNames email homepage icq lastIp comment);
push @identity, grep($cfg->{$_}, qw(extra1 extra2 extra3));

# Shared formatting functions
my $defTime = sub { $m->formatTime($_[0]{$field}, $m->{user}{timezone}) };
my $defUrl = sub { my $v = $_[0]{$field}; 
	$v =~ /^https?:\/\/[^\s\\\[\]{}<>)|^`'"]+\z/ ? "<a href='$v'>$v</a>" : $v;
};

#	Install case-i LIKE function for SQLite
$m->{dbh}->func('LIKE', 2, sub { my $a = shift(); my $b = shift();
	utf8::decode($a); utf8::decode($b); index(lc($a), lc($b)) > -1 }, 'create_function')
	if $m->{sqlite} && $cfg->{sqliteLike} && length($search);

# Parse badges
my %badges = ();
if ($field eq '_badges') {
	for my $line (@{$cfg->{badges}}) {
		my ($id, $smallIcon, $bigIcon) = $line =~ /(\w+)\s+\w+\s+(\S+)\s+(\S+)/;
		$badges{$id} = $smallIcon ne '-' ? $smallIcon : $bigIcon;
	}
}

# Define views
my $like = $m->{pgsql} ? 'ILIKE' : 'LIKE';
my $percent = $m->{sqlite} && $cfg->{sqliteLike} ? "" : "%";
my $defFields = join(", ", 'users.id', 'users.userName',
	$sort eq 'lastOnTime' ? 'users.lastOnTime' : ());
my $defFrom = "FROM users AS users WHERE users.id IN (:pageUserIds)";
my $defJoin = $hideEmpty ? 'INNER' : 'LEFT';
my $defGroup = $defFields;
my $defSort = $sort ne 'field' ? "users.$sort" : 'users.userName';
my $searchEsc = $m->escHtml($search);
my $searchLike = $m->dbEscLike($searchEsc);
my $views = [
	{	name => " Identity",
		field => '_identity',
		notes => "no view-specific sorting; searching by username, real name, old usernames, email, "
			. "website, messenger, last IP, comments, and custom profile fields 1-3 when used; "
			. "no empty entry hiding",
		searchParam => $percent . $searchLike . $percent,
		searchUsers => sub {
			my $where = !length($search) ? ""	:
				"WHERE ". join(" $like :search OR ", @identity) . " $like :search";
			$m->fetchAllArray("
				SELECT id FROM users AS users $where ORDER BY $defSort $order", $_[0])
		},
		fetchUsers => sub { $m->fetchAllHash("
			SELECT $defFields, realName, email $defFrom ORDER BY $defSort $order", $_[0]) },
		columns => [
			{ name => "Email", value => sub { "<a href='mailto:$_[0]{email}'>$_[0]{email}</a>" } },
			{	name => "Real Name", value => sub { $_[0]{realName} } },
			{	name => "Old Names", value => sub { $_[0]{oldNames} } },
		],
	},
	{	name => "Bans",
		field => '_bans',
		notes => "view-specific sorting by ban time; searching by both reasons; only banned users are shown",
		searchParam => $percent . $searchLike . $percent,
		searchUsers => sub {
			my $where = length($search) ? "WHERE reason $like :search OR intReason $like :search" : "";
			my $fldSort = $sort eq 'field' ? 'bans.banTime' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id 
				FROM users AS users
					INNER JOIN userBans AS bans 
						ON bans.userId = users.id
				$where 
				ORDER BY $fldSort $order, users.userName", $_[0])
		},
		fetchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'bans.banTime' : "users.$sort";
			$m->fetchAllHash("
				SELECT $defFields, bans.banTime, bans.duration, bans.reason, bans.intReason
				FROM users AS users
					INNER JOIN userBans AS bans 
						ON bans.userId = users.id
				WHERE users.id IN (:pageUserIds)
				ORDER BY $fldSort $order, users.userName", $_[0])
		},
		columns => [
			{ name => "Ban Time", value => sub { 
				my $v = $_[0]{banTime};	$v ? $m->formatTime($v, $m->{user}{timezone}) : "" } },
			{	name => "Dur.", value => sub { 
				my $v = $_[0]{duration}; return "" if !defined($v); return "&#8734;" if $v == 0; $v } },
			{	name => "Reason", value => sub { $_[0]{reason} } },
			{	name => "Internal", value => sub { $_[0]{intReason} } },
		],
	},
	{ name => "Badges",
		field => '_badges',
		notes => "no view-specific sorting; searching by identifier prefix",
		searchParam => $searchLike . $percent,
		searchUsers => sub { 
			my $where = length($search) ? "WHERE userBadges.badge LIKE :search" : "";
			$m->fetchAllArray("
				SELECT users.id, GROUP_CONCAT(userBadges.badge) AS badges
				FROM users AS users
					$defJoin JOIN userBadges AS userBadges ON userBadges.userId = users.id
				$where
				GROUP BY $defGroup
				ORDER BY $defSort $order", $_[0]);
		},
		fetchUsers => sub {
			$m->fetchAllHash("
				SELECT users.id, users.userName, GROUP_CONCAT(userBadges.badge) AS badges
				FROM users AS users
					$defJoin JOIN userBadges AS userBadges ON userBadges.userId = users.id
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $defSort $order", $_[0]);
		},
		columns => [
			{ name => "Badges",
				value => sub {
					join(" ", map("<img class='uba' src='$cfg->{dataPath}/$badges{$_}' alt='$_'>", 
						sort(split(',', $_[0]{badges}))));
				}
			},
		],
	},
	{ name => "Notifications",
		field => '_notes',
		notes => "no view-specific sorting; no searching",
		searchUsers => sub { 
			$m->fetchAllArray("
				SELECT users.id 
				FROM users AS users
					$defJoin JOIN notes AS notes ON notes.userId = users.id
				GROUP BY $defGroup
				ORDER BY $defSort $order");
		},
		fetchUsers => sub {
			$m->dbDo("SET group_concat_max_len = 32768") if $m->{mysql};
			$m->fetchAllHash("
				SELECT users.id, users.userName, GROUP_CONCAT('<div>' || notes.body || '</div>') AS notes
				FROM users AS users
					$defJoin JOIN notes AS notes ON notes.userId = users.id
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $defSort $order", $_[0]);
		},
		columns => [
			{ name => "Notifications",
				value => sub { my $v = $_[0]{notes}; $v =~ s!</div>,<div>!</div>\n<div>!g; $v } },
		],
	},
	{ name => "Style Snippets",
		field => '_snippets',
		notes => "no view-specific sorting; searching by identifier prefix",
		searchParam => $searchLike . $percent,
		searchUsers => sub {
			my $where = length($search) ? "WHERE vars.name LIKE :search" : "";
			$m->fetchAllArray("
				SELECT users.id 
				FROM users AS users
					$defJoin JOIN userVariables AS vars
						ON vars.userId = users.id AND vars.name LIKE 'sty%'
				$where
				GROUP BY $defGroup
				ORDER BY $defSort $order", $_[0]);
		},
		fetchUsers => sub {
			$m->fetchAllHash("
				SELECT users.id, users.userName, GROUP_CONCAT(vars.name) AS snippets
				FROM users AS users
					$defJoin JOIN userVariables AS vars 
						ON vars.userId = users.id AND vars.name LIKE 'sty%'
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $defSort $order", $_[0]);
		},
		columns => [ { name => "Style Snippets", value => sub { $_[0]{snippets} } } ],
	},
	{ name => "Groups",
		field => '_groups',
		notes => "no view-specific sorting; searching by group title",
		searchParam => $searchLike,
		searchUsers => sub { 
			my $where = length($search) ? "WHERE groups.title = :search" : "";
			$m->fetchAllArray("
				SELECT users.id 
				FROM users AS users
					$defJoin JOIN groupMembers AS groupMembers ON groupMembers.userId = users.id
					$defJoin JOIN groups AS groups ON groups.id = groupMembers.groupId
				$where
				GROUP BY $defGroup
				ORDER BY $defSort $order", $_[0]);
		},
		fetchUsers => sub {
			$m->dbDo("SET group_concat_max_len = 32768") if $m->{mysql};
			$m->fetchAllHash("
				SELECT users.id, users.userName, GROUP_CONCAT('#' || groups.title || '#') AS groups
				FROM users AS users
					$defJoin JOIN groupMembers AS groupMembers ON groupMembers.userId = users.id
					$defJoin JOIN groups AS groups ON groups.id = groupMembers.groupId
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $defSort $order", $_[0]);
		},
		columns => [
			{ name => "Groups",
				value => sub { my $v = $_[0]{groups}; $v =~ s!#,#!, !g; $v =~ s!#!!g; $v } },
		],
	},
	{ name => "Ignored By",
		field => '_ignored',
		notes => "view-specific sorting by number of ignoring users; no searching",
		searchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'ignoreNum' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id, COUNT(ignores.userId) AS ignoreNum
				FROM users AS users
					$defJoin JOIN userIgnores AS ignores ON ignores.ignoredId = users.id
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName");
		},
		fetchUsers => sub {
			my $fldSort = $sort eq 'field' ? 'ignoreNum' : "users.$sort";
			$m->fetchAllHash("
				SELECT users.id, users.userName, 
					COUNT(ignores.userId) AS ignoreNum, GROUP_CONCAT(ignorers.userName) AS ignorerNames
				FROM users AS users
					$defJoin JOIN userIgnores AS ignores ON ignores.ignoredId = users.id
					$defJoin JOIN users AS ignorers ON ignorers.id = ignores.userId
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName", $_[0]);
		},
		columns => [ 
			{ name => "#", value => sub { $_[0]{ignoreNum} } },
			{ name => "Ignored By", value => sub { my $v = $_[0]{ignorerNames}; $v =~ s!,!, !g; $v } } 
		],
	},
	{ name => "Ignored Users",
		field => '_ignoring',
		notes => "view-specific sorting by number of ignored users; no searching",
		searchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'ignoreNum' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id, COUNT(ignores.userId) AS ignoreNum
				FROM users AS users
					$defJoin JOIN userIgnores AS ignores ON ignores.userId = users.id
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName");
		},
		fetchUsers => sub {
			my $fldSort = $sort eq 'field' ? 'ignoreNum' : "users.$sort";
			$m->fetchAllHash("
				SELECT users.id, users.userName, 
					COUNT(ignores.userId) AS ignoreNum, GROUP_CONCAT(ignoreds.userName) AS ignoredNames
				FROM users AS users
					$defJoin JOIN userIgnores AS ignores ON ignores.userId = users.id
					$defJoin JOIN users AS ignoreds ON ignoreds.id = ignores.ignoredId
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName", $_[0]);
		},
		columns => [
			{ name => "#", value => sub { $_[0]{ignoreNum} } },
			{ name => "Ignored Users", value => sub { my $v = $_[0]{ignoredNames}; $v =~ s!,!, !g; $v } } 
		],
	},
	{ name => "Watched By",
		field => '_watched',
		notes => "view-specific sorting by number of watching users; no searching",
		searchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'watchNum' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id, COUNT(watches.userId) AS watchNum
				FROM users AS users
					$defJoin JOIN watchUsers AS watches ON watches.watchedId = users.id
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName");
		},
		fetchUsers => sub {
			my $fldSort = $sort eq 'field' ? 'watchNum' : "users.$sort";
			$m->fetchAllHash("
				SELECT users.id, users.userName, 
					COUNT(watches.userId) AS watchNum, GROUP_CONCAT(watchers.userName) AS watcherNames
				FROM users AS users
					$defJoin JOIN watchUsers AS watches ON watches.watchedId = users.id
					$defJoin JOIN users AS watchers ON watchers.id = watches.userId
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName", $_[0]);
		},
		columns => [
			{ name => "#", value => sub { $_[0]{watchNum} } },
			{ name => "Watched By", value => sub { my $v = $_[0]{watcherNames}; $v =~ s!,!, !g; $v } } 
		],
	},
	{ name => "Watched Users",
		field => '_watching',
		notes => "view-specific sorting by number of watched users; no searching",
		searchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'watchNum' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id, COUNT(watches.userId) AS watchNum
				FROM users AS users
					$defJoin JOIN watchUsers AS watches ON watches.userId = users.id
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName");
		},
		fetchUsers => sub {
			my $fldSort = $sort eq 'field' ? 'watchNum' : "users.$sort";
			$m->fetchAllHash("
				SELECT users.id, users.userName, 
					COUNT(watches.userId) AS watchNum, GROUP_CONCAT(watched.userName) AS watchedNames
				FROM users AS users
					$defJoin JOIN watchUsers AS watches ON watches.userId = users.id
					$defJoin JOIN users AS watched ON watched.id = watches.watchedId
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName", $_[0]);
		},
		columns => [
			{ name => "#", value => sub { $_[0]{watchNum} } },
			{ name => "Watched Users", value => sub { my $v = $_[0]{watchedNames}; $v =~ s!,!, !g; $v } } 
		],
	},
	{ name => "Watched Words",
		field => '_words',
		notes => "view-specific sorting by number of watched words; no searching",
		searchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'watchNum' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id, COUNT(watches.word) AS watchNum
				FROM users AS users
					$defJoin JOIN watchWords AS watches ON watches.userId = users.id
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName");
		},
		fetchUsers => sub {
			my $fldSort = $sort eq 'field' ? 'watchNum' : "users.$sort";
			$m->fetchAllHash("
				SELECT users.id, users.userName, 
					COUNT(watches.word) AS watchNum, GROUP_CONCAT(watches.word) AS words
				FROM users AS users
					$defJoin JOIN watchWords AS watches ON watches.userId = users.id
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName", $_[0]);
		},
		columns => [
			{ name => "#", value => sub { $_[0]{watchNum} } },
			{ name => "Words", value => sub { my $v = $_[0]{words}; $v =~ s!,!, !g; $v } } 
		],
	},
	{ name => "Board Subscriptions",
		field => '_boardsubs',
		notes => "view-specific sorting by number of subscribed boards; no searching",
		searchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'subsNum' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id, COUNT(subs.userId) AS subsNum
				FROM users AS users
					$defJoin JOIN boardSubscriptions AS subs ON subs.userId = users.id
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName");
		},
		fetchUsers => sub {
			$m->dbDo("SET group_concat_max_len = 32768") if $m->{mysql};
			my $fldSort = $sort eq 'field' ? 'subsNum' : "users.$sort";
			$m->fetchAllHash("
				SELECT users.id, users.userName, 
					COUNT(subs.userId) AS subsNum, GROUP_CONCAT(REPLACE(boards.title, ',', '')) AS title
				FROM users AS users
					$defJoin JOIN boardSubscriptions AS subs ON subs.userId = users.id
					$defJoin JOIN boards AS boards ON boards.id = subs.boardId
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName", $_[0]);
		},
		columns => [
			{ name => "#", value => sub { $_[0]{subsNum} } },
			{ name => "Board Subscriptions", value => sub { my $v = $_[0]{title}; $v =~ s!,!, !g; $v } } 
		],
	},
	{ name => "Topic Subscriptions",
		field => '_topicsubs',
		notes => "view-specific sorting by number of subscribed topics; no searching",
		searchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'subsNum' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id, COUNT(subs.userId) AS subsNum
				FROM users AS users
					$defJoin JOIN topicSubscriptions AS subs ON subs.userId = users.id
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName");
		},
		fetchUsers => sub {
			$m->dbDo("SET group_concat_max_len = 32768") if $m->{mysql};
			my $fldSort = $sort eq 'field' ? 'subsNum' : "users.$sort";
			$m->fetchAllHash("
				SELECT users.id, users.userName, 
					COUNT(subs.userId) AS subsNum, GROUP_CONCAT(REPLACE(topics.subject, ',', '')) AS subject
				FROM users AS users
					$defJoin JOIN topicSubscriptions AS subs ON subs.userId = users.id
					$defJoin JOIN topics AS topics ON topics.id = subs.topicId
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $fldSort $order, users.userName", $_[0]);
		},
		columns => [
			{ name => "#", value => sub { $_[0]{subsNum} } },
			{ name => "Topic Subscriptions", value => sub { my $v = $_[0]{subject}; $v =~ s!,!, !g; $v } } 
		],
	},
	{ name => "Birthdate",
		field => '_birthdate',
		notes => "no searching",
		searchUsers => sub { 
			my $where = $hideEmpty ? "WHERE birthday <> ''" : "";
			$m->fetchAllArray("
				SELECT id FROM users AS users $where ORDER BY birthyear $order, birthday $order", $_[0]) 
		},
		fetchUsers => sub { $m->fetchAllHash("
			SELECT $defFields, birthyear, birthday $defFrom
			ORDER BY birthyear $order, birthday $order", $_[0]) },
		columns => [
			{ name => "Birthdate",
				value => sub { ($_[0]->{birthyear} ? $_[0]->{birthyear} : "0000") . "-$_[0]->{birthday}" } },
		],
	},
	{ name => "Active Time",
		field => '_active',
		notes => "no searching",
		searchUsers => sub { 
			my $where = $hideEmpty ? "WHERE lastOnTime - regTime > 0" : "";
			my $fldSort = $sort eq 'field' ? 'activeSeconds' : "users.$sort";
			$m->fetchAllArray("
				SELECT id, lastOnTime - regTime AS activeSeconds
				FROM users AS users 
				$where 
				ORDER BY $fldSort $order", $_[0]) 
		},
		fetchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'activeSeconds' : "users.$sort";
			$m->fetchAllHash("
				SELECT $defFields, lastOnTime - regTime AS activeSeconds, 
					ROUND((lastOnTime - regTime) / 86400) AS activeDays
				$defFrom 
				ORDER BY $fldSort $order", $_[0]) 
		},
		columns => [
			{ name => "Active Time (days)", value => sub { $_[0]->{activeDays} } },
			{ name => "Active Time (seconds)", value => sub { $_[0]->{activeSeconds} } },
		],
	},
	{ name => "Posts Existing",
		field => '_postexist',
		notes => "no searching",
		searchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'postsExist' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id, COUNT(posts.id) AS postsExist
				FROM users AS users
					$defJoin JOIN posts ON posts.userId = users.id
				GROUP BY $defGroup
				ORDER BY $fldSort $order", $_[0]) 
		},
		fetchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'postsExist' : "users.$sort";
			$m->fetchAllHash("
				SELECT $defFields, COUNT(posts.id) AS postsExist
				FROM users AS users
					$defJoin JOIN posts AS posts ON posts.userId = users.id
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $fldSort $order", $_[0]) 
		},
		columns => [
			{ name => "Posts Existing", value => sub { $_[0]->{postsExist} } },
		],
	},
	{ name => "Post Upvotes",
		field => '_upvotes',
		notes => "no searching",
		searchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'postLikes' : "users.$sort";
			$m->fetchAllArray("
				SELECT users.id, COUNT(postLikes.postId) AS postLikes
				FROM users AS users
					$defJoin JOIN posts ON posts.userId = users.id
					$defJoin JOIN postLikes ON postLikes.postId = posts.id
				GROUP BY $defGroup
				ORDER BY $fldSort $order", $_[0]) 
		},
		fetchUsers => sub { 
			my $fldSort = $sort eq 'field' ? 'postLikes' : "users.$sort";
			$m->fetchAllHash("
				SELECT $defFields, COUNT(postLikes.postId) AS postLikes
				FROM users AS users
					$defJoin JOIN posts ON posts.userId = users.id
					$defJoin JOIN postLikes ON postLikes.postId = posts.id
				WHERE users.id IN (:pageUserIds)
				GROUP BY $defGroup
				ORDER BY $fldSort $order", $_[0]) 
		},
		columns => [
			{ name => "Post Upvotes", value => sub { $_[0]->{postLikes} } },
		],
	},
	{ name => "Avatar",
		field => 'avatar',
		columns => [
			{
				name => "Avatar",
				value => sub {
					my $v = $_[0]{avatar};
					return if !$v;
					index($v, "gravatar:") == 0
						? "<img src='//gravatar.com/avatar/" . $m->md5(substr($v, 9)) . 
							"?s=$m->{cfg}{avatarWidth}' alt=''>"
						: "<img src='$m->{cfg}{attachUrlPath}/avatars/$v' alt=''>";
				},
			},
			{
				name => "Type",
				value => sub {
					my $v = $_[0]{avatar};
					return "Gravatar" if index($v, "gravatar:") == 0;
					return "Gallery" if index($v, "gallery/") == 0;
					return "Upload" if $v;
				},
			},
		],
	},
	{ name => "Email",
		field => 'email',
		columns => [
			{ name => "Email", value => sub { "<a href='mailto:$_[0]{email}'>$_[0]{email}</a>" } },
		],
	},
	{ name => "Registration Time",
		field => 'regTime',
		type => 'int',
		columns => [ { name => "Registration Time", value => $defTime } ],
	},
	{ name => "Last Online Time",
		field => 'lastOnTime',
		type => 'int',
		columns => [ { name => "Last Online Time", value => $defTime } ],
	},
	{ name => "Prev. Online Time",
		field => 'prevOnTime',
		type => 'int',
		columns => [ { name => "Prev. Online Time", value => $defTime } ],
	},
	{ name => "Website",
		field => 'homepage',
		columns => [ { name => "Website", value => $defUrl } ],
	},
	{ name => "OpenID",
		field => 'openId',
		columns => [ { name => "OpenID", value => $defUrl } ],
	},
	{ name => "Username", field => 'userName', columns => [] },
	{ name => "Administrator", field => 'admin', type => 'int' },
	{ name => "Birthyear", field => 'birthyear', type => 'int' },
	{ name => "Disable Email", field => 'dontEmail', type => 'int' },
	{ name => "Email Notifications", field => 'msgNotify', type => 'int' },
	{ name => "Reply Notifications", field => 'notify', type => 'int' },
	{ name => "Privacy", field => 'privacy', type => 'int' },
	{ name => "Temporary Login", field => 'tempLogin', type => 'int' },
	{ name => "Show Board Desc.", field => 'boardDescs', type => 'int' },
	{ name => "Show Decoration", field => 'showDeco', type => 'int' },
	{ name => "Show Avatars", field => 'showAvatars', type => 'int' },
	{ name => "Show Embed. Images", field => 'showImages', type => 'int' },
	{ name => "Show Signatures", field => 'showSigs', type => 'int' },
	{ name => "Collapse Branches", field => 'collapse', type => 'int' },
	{ name => "Font Size", field => 'fontSize', type => 'int' },
	{ name => "Threading Indent", field => 'indent', type => 'int' },
	{ name => "Posts Per Page", field => 'postsPP', type => 'int' },
	{ name => "Topics Per Page", field => 'topicsPP', type => 'int' },
	{ name => "Posts Posted", field => 'postNum', type => 'int' },
	{ name => "Bounce Counter", field => 'bounceNum', type => 'int' },
	{ name => "Policy Version", field => 'policyAccept', type => 'int' },
	{ name => "Renames Left", field => 'renamesLeft', type => 'int' },
	{ name => "Old Usernames", field => 'oldNames' },
	{ name => "Real Name", field => 'realName' },
	{ name => "Title", field => 'title' },
	{ name => "Occupation", field => 'occupation' },
	{ name => "Hobbies", field => 'hobbies' },
	{ name => "Location", field => 'location' },
	{ name => "Messenger", field => 'icq' },
	{ name => "Signature", field => 'signature' },
	{ name => "Miscellaneous", field => 'blurb' },
	{ name => "Custom 1", field => 'extra1' },
	{ name => "Custom 2", field => 'extra2' },
	{ name => "Custom 3", field => 'extra3' },
	{ name => "Birthday", field => 'birthday' },
	{ name => "Timezone", field => 'timezone' },
	{ name => "Language", field => 'language' },
	{ name => "Style", field => 'style' },
	{ name => "Font Face", field => 'fontFace' },
	{ name => "User Agent", field => 'userAgent' },
	{ name => "IP Address", field => 'lastIp' },
	{ name => "PGP Key ID", field => 'gpgKeyId' },
	{ name => "Comments", field => 'comment' },
];

my $view = (first{ $_->{field} eq $field } @$views) || $views->[1];
$field = $view->{field};

# Save options
$m->setVar('usrAdmFld', $field, $userId);
$m->setVar('usrAdmSrt', $sort, $userId);
$m->setVar('usrAdmOrd', $order, $userId);
$m->setVar('usrAdmHid', $hideEmpty, $userId);

# Searching
my $searchParam = "";
my $searchStr = "";
if (length($search)) {
	if ($view->{searchUsers}) {
		$searchParam = $view->{searchParam};
	}
	elsif ($view->{type} eq 'int') {
		$searchParam = int($search || 0);
		$searchStr = "AND $field = :search";
	}
	else {
		$searchParam = $percent . $searchLike . $percent;
		$searchStr = "AND $field $like :search";
	}
}

# Hiding empty fields
my $hideEmptyStr = "";
if ($hideEmpty && !$view->{searchUsers}) {
	if ($view->{type} eq 'int') { $hideEmptyStr = "AND $field > 0" }
	else { $hideEmptyStr = "AND $field <> ''" }
}

# Ordering
my $orderStr = "";
if ($sort eq 'id') { $orderStr = "users.id $order" }
elsif ($sort eq 'userName') { $orderStr = "users.userName $order" }
elsif ($sort eq 'lastOnTime') { $orderStr = "users.lastOnTime $order" }
elsif ($sort eq 'field') { $orderStr = "users.$field $order, users.userName" }

# Get ids of users
my $users = $view->{searchUsers} ? $view->{searchUsers}({ search => $searchParam }) : 
	$m->fetchAllArray("
		SELECT id
		FROM users AS users
		WHERE 1 = 1
			$searchStr
			$hideEmptyStr
		ORDER BY $orderStr",
		{ search => $searchParam });

# Print page bar
my $usersPP = $cfg->{usersPP} || 100;
my $pageNum = int(@$users / $usersPP) + (@$users % $usersPP != 0);
my @pageLinks = $pageNum < 2 ? () : $m->pageLinks('user_admin', [], $page, $pageNum);
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
my @adminLinks = ({ url => $m->url('user_set'), txt => "Set", ico => 'edit' });
$m->printPageBar(mainTitle => "User Administration", navLinks => \@navLinks,
	pageLinks => \@pageLinks, adminLinks => \@adminLinks);

# Get users on page
my @pageUsers = @$users[($page - 1) * $usersPP .. $m->min($page * $usersPP, scalar @$users) - 1];
my @pageUserIds = map($_->[0], @pageUsers);
$users = $view->{fetchUsers} ? $view->{fetchUsers}({ pageUserIds => \@pageUserIds }) :
	$m->fetchAllHash("
		SELECT $defFields, $field
		FROM users AS users
		WHERE id IN (:pageUserIds)
		ORDER BY $orderStr",
		{ pageUserIds => \@pageUserIds });

# Determine checkbox, radiobutton and listbox states
my $hideEmptyChk = $hideEmpty ? 'checked' : "",
my %state = ( $sort => 'selected', $order => 'selected', "field$field" => 'selected' );

# Print user list form
print
	"<form action='user_admin$m->{ext}' method='get'>\n",
	"<div class='frm'>\n",
	"<div class='hcl'><span class='htt'>List Users</span></div>\n",
	"<div class='ccl'>\n",
	"<div class='cli'>\n",
	"<label>View\n",
	"<select name='field' size='1'>\n",
	map("<option value='$_->{field}' $state{\"field$_->{field}\"}>$_->{name}</option>\n",
		sort({ $a->{name} cmp $b->{name} } @$views)),
	"</select></label>\n",
	"<label>Sort\n",
	"<select name='sort' size='1'>\n",
	"<option value='userName' $state{userName}>Username</option>\n",
	"<option value='id' $state{id}>User ID</option>\n",
	"<option value='lastOnTime' $state{lastOnTime}>Last Online</option>\n",
	"<option value='field' $state{field}>View</option>\n",
	"</select></label>\n",
	"<label>Order\n",
	"<select name='order' size='1'>\n",
	"<option value='asc' $state{asc}>Asc</option>\n",
	"<option value='desc' $state{desc}>Desc</option>\n",
	"</select></label>\n",
	"<label>Search\n",
	"<input type='text' name='search' style='width: 100px' value='$searchEsc' autofocus></label>\n",
	"<label><input type='checkbox' name='hide' value='1' $hideEmptyChk>Hide empty</label>\n",
	$m->submitButton("List", 'search'),
	"</div>\n",
	$view->{notes} ? "<div>View notes: $view->{notes}</div>" : "",
	"</div>\n",
	"</div>\n",
	"</form>\n\n";

# Print user list header
my $defColumns = [ { name => $view->{name}, value => sub { $_[0]{$field} } } ];
my $columns = $view->{columns} ? $view->{columns} : $defColumns;
print
	"<table class='tbl'>\n",
	"<tr class='hrw'>\n",
	"<th>Username</th>\n",
	map("<th>$_->{name}</th>\n", @$columns),
	"</tr>\n";

# Print user list
for my $listUser (@$users) {
	my $infUrl = $m->url('user_info', uid => $listUser->{id});
	print
		"<tr class='crw'>\n",
		"<td><a href='$infUrl'>$listUser->{userName}</a></td>\n",
		map("<td>" . $_->{value}($listUser) . "</td>\n", @$columns),
		"</tr>\n";
}

print "</table>\n\n";

# Log action and finish
$m->logAction(3, 'user', 'admin', $userId);
$m->printFooter();
$m->finish();
