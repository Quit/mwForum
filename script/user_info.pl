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

# Check if access should be denied
!$cfg->{userInfoReg} || $userId or $m->error('errNoAccess');

# Get CGI parameters
my $infUserId = $m->paramInt('uid');

# Get user
my $infUser = $m->getUser($infUserId);
$infUser or $m->error('errUsrNotFnd');
my $userTitle = $infUser->{title} ? $m->formatUserTitle($infUser->{title}) : "";

# Get GeoIP data
my $countryCode = "";
my $geoLocation = "";
if ($cfg->{geoIp} && (!$infUser->{privacy} || $user->{admin})) {
	my $ip = $infUser->{lastIp}; # GeoIP doesn't like the tied hash when using Pg
	my $geoIp = undef;
	if (eval { require Geo::IP }) {
		$geoIp = Geo::IP->open($cfg->{geoIp});
	}
	elsif (eval { require Geo::IP::PurePerl }) {
		$geoIp = Geo::IP::PurePerl->open($cfg->{geoIp});
	}
	else {
		$m->error("Module required for GeoIP not available.");
	}
	$geoIp or $m->error("Creating GeoIP object failed.");
	if (index($cfg->{geoIp}, 'City') > -1) {
		my $rec = $geoIp->record_by_addr($ip);
		$rec or $m->logError("Fetching record from GeoLiteCity database failed.", 1);
		if ($rec) {
			$countryCode = lc($rec->country_code());
			$geoLocation = join(", ", grep($_, $rec->city(), $rec->region_name(), $rec->country_name()));
		}
	}
	else {
		$countryCode = lc($geoIp->country_code_by_addr($ip));
		$geoLocation = $geoIp->country_name_by_addr($ip);
	}
}

# Set Javascript parameters
my $jsParams = {};
if ($cfg->{userInfoMap}) {
	$jsParams = {
		location => $infUser->{location} || $geoLocation,
		countryCode => $countryCode,
		uaLangCode => $m->{uaLangCode},
		lng_uifMapOthrMt => $lng->{uifMapOthrMt},
	};
}

# Print header
$m->printHeader(undef, $jsParams);

# User button links
my @userLinks = ();
push @userLinks, { url => $m->url('message_add', uid => $infUserId), 
	txt => 'uifMessage', ico => 'write' }
	if $userId && $cfg->{messages};
push @userLinks, { url => $m->url('user_ignore', userId => $infUserId), 
	txt => 'uifIgnore', ico => 'ignore' }
	if $userId;
push @userLinks, { url => $m->url('user_watch', userId => $infUserId), 
	txt => 'uifWatch', ico => 'watch' }
	if $userId && $cfg->{watchUsers};
push @userLinks, { url => $m->url('forum_search', uid => $infUserId), 
	txt => 'uifListPst', ico => 'search' }
	if $cfg->{forumSearch};
push @userLinks, { url => $m->url('user_activity', uid => $infUserId), 
	txt => 'uifActiv', ico => 'poll' }
	if ($cfg->{statForumActiv} || $user->{admin}) && !$m->{sqlite};
$m->callPlugin($_, links => \@userLinks, user => $infUser)
	for @{$cfg->{includePlg}{userUserLink}};

# Admin button links
my @adminLinks = ();
if ($user->{admin}) {
	push @adminLinks, { url => $m->url('user_admopt', uid => $infUserId), 
		txt => "Admin", ico => 'admopt' }
		if $user->{admin};
	push @adminLinks, { url => $m->url('user_profile', uid => $infUserId, ori => 1), 
		txt => "Profile", ico => 'profile' };
	push @adminLinks, { url => $m->url('user_options', uid => $infUserId, ori => 1), 
		txt => "Options", ico => 'options' };
	push @adminLinks, { url => $m->url('user_groups', uid => $infUserId, ori => 1), 
		txt => "Groups", ico => 'group' };
	push @adminLinks, { url => $m->url('user_migrate', uid => $infUserId), 
		txt => "Migrate", ico => 'merge' };
	push @adminLinks, { url => $m->url('user_notify', uid => $infUserId), 
		txt => "Notify", ico => 'write' };
	push @adminLinks, { url => $m->url('user_ban', uid => $infUserId), 
		txt => "Ban", ico => 'ban' };
	push @adminLinks, { url => $m->url('user_wipe', uid => $infUserId), 
		txt => "Wipe", ico => 'wipe' };
	push @adminLinks, { url => $m->url('user_confirm', uid => $infUserId, script => 'user_delete',
		name => $infUser->{userName}), txt => "Delete", ico => 'delete' };
	$m->callPlugin($_, links => \@userLinks, user => $infUser)
		for @{$cfg->{includePlg}{userAdminLink}};
}

# Print page bar
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{uifTitle}, subTitle => "$infUser->{userName} $userTitle", 
	navLinks => \@navLinks, userLinks => \@userLinks, adminLinks => \@adminLinks);

# Notices for admins
if ($user->{admin}) {
	# Print whether user is banned
	my $ban = $m->fetchHash("
		SELECT reason, intReason FROM userBans WHERE userId = ?", $infUserId);
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'><em>Banned</em></span></div>\n",
		"<div class='ccl'>\n",
		$ban->{reason} ? "<p>Reason: $ban->{reason}</p>\n" : "",
		$ban->{intReason} ? "<p>Internal reason: $ban->{intReason}</p>\n" : "",
		"</div>\n",
		"</div>\n\n"
		if $ban;		
		
	# Print admin comments
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Administrator Comments</span></div>\n",
		"<div class='ccl'>\n",
		$infUser->{comment}, "\n",
		"</div>\n",
		"</div>\n\n"
		if $infUser->{comment};
}

# Print user profile
print
	"<table class='tbl'>\n",
	"<tr class='hrw'><th colspan='2'>$lng->{uifProfTtl}</th></tr>\n";

# Avatar
if ($cfg->{avatars} && $infUser->{avatar}) {
	my $avatarUrl = "";
	if (index($infUser->{avatar}, "gravatar:") == 0) {
		my $md5 = $m->md5(substr($infUser->{avatar}, 9));
		$avatarUrl = "//gravatar.com/avatar/$md5?s=$cfg->{avatarWidth}";
	}
	else {
		$avatarUrl = "$cfg->{attachUrlPath}/avatars/$infUser->{avatar}";
	}
	print
		"<tr class='crw'>\n",
		"<td class='hco'>$lng->{uifProfAvat}</td><td><img src='$avatarUrl' alt=''></td>\n",
		"</tr>\n"
		if $avatarUrl;
}

# Email address
if ($infUser->{email} && $user->{admin}) {
	print
		"<tr class='crw'>\n",
		"<td class='hco'>Email</td><td>$infUser->{email}</td>\n",
		"</tr>\n";
}

# Real name
print	
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifProfRName}</td><td>$infUser->{realName}</td>\n",
	"</tr>\n"
	if $infUser->{realName};

# OpenID
print
	"<tr class='crw'>\n",
	"<td class='hco'>OpenID</td>\n",
	"<td><img class='bic bic_openid' src='$cfg->{dataPath}/epx.png' title='OpenID' alt=''>",
	" <a href='$infUser->{openId}'>$infUser->{openId}</a></td>\n",
	"</tr>\n"
	if $infUser->{openId};

# Homepage
if (my $homepage = $infUser->{homepage}) {
	$homepage =~ s!(https?://[^\\\s\[\]{}<>|^)`'"]+)!<a href='$1'>$1</a>!g;
	print	
		"<tr class='crw'>\n",
		"<td class='hco'>$lng->{uifProfPage}</td><td>$homepage</td>\n",
		"</tr>\n";
}

# Birthday
my $birthdate = "";
$birthdate = $infUser->{birthyear} . "-" if $infUser->{birthyear};
$birthdate .= $infUser->{birthday};
print	
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifProfBdate}</td><td>$birthdate</td>\n",
	"</tr>\n"
	if $birthdate;

# Occupation
print	
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifProfOccup}</td><td>$infUser->{occupation}</td>\n",
	"</tr>\n"
	if $infUser->{occupation};

# Hobbies
print	
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifProfHobby}</td><td>$infUser->{hobbies}</td>\n",
	"</tr>\n"
	if $infUser->{hobbies};

# Location
print	
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifProfLocat}</td><td>$infUser->{location}</td>\n",
	"</tr>\n"
	if $infUser->{location};

# GeoIP
print
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifProfGeoIp}</td>\n",
	$cfg->{userFlags}
		? "<td>$geoLocation <img class='flg' src='$cfg->{dataPath}/flags/$countryCode.png' alt=''></td>"
		: "<td>$geoLocation</td>\n",
	"</tr>\n"
	if $countryCode;

# Messengers
print
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifProfIcq}</td><td>$infUser->{icq}</td>\n",
	"</tr>\n"
	if $infUser->{icq} && $userId;

# Former usernames
print	
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifProfOName}</td><td>$infUser->{oldNames}</td>\n",
	"</tr>\n"
	if $infUser->{oldNames};

# Custom user fields
print
	"<tr class='crw'>\n",
	"<td class='hco'>$cfg->{extra1}</td><td>$infUser->{extra1}</td>\n",
	"</tr>\n"
	if length($infUser->{extra1}) && $cfg->{extra1} && ($cfg->{showExtra1} || $user->{admin});
	
print
	"<tr class='crw'>\n",
	"<td class='hco'>$cfg->{extra2}</td><td>$infUser->{extra2}</td>\n",
	"</tr>\n"
	if length($infUser->{extra2}) && $cfg->{extra2} && ($cfg->{showExtra2} || $user->{admin});

print
	"<tr class='crw'>\n",
	"<td class='hco'>$cfg->{extra3}</td><td>$infUser->{extra3}</td>\n",
	"</tr>\n"
	if length($infUser->{extra3}) && $cfg->{extra3} && ($cfg->{showExtra3} || $user->{admin});

# Signature
if ($infUser->{signature}) {
	my $fakePost = { body => $infUser->{signature} };
	$m->dbToDisplay({}, $fakePost);
	print
		"<tr class='crw'>\n",
		"<td class='hco'>$lng->{uifProfSig}</td><td>$fakePost->{body}</td>\n",
		"</tr>\n";
}

# Blurb
if ($infUser->{blurb}) {
	my $fakePost = { isBlurb => 1, body => $infUser->{blurb} };
	$m->dbToDisplay({}, $fakePost);
	print
		"<tr class='crw'>\n",
		"<td class='hco'>$lng->{uifProfBlurb}</td><td>$fakePost->{body}</td>\n",
		"</tr>\n";
}

print "</table>\n\n";

# Call user info include plugin
$m->callPlugin($_, user => $infUser) for @{$cfg->{includePlg}{userInfo}};

# Google map
if ($cfg->{userInfoMap} && ($infUser->{location} || $geoLocation)) {
	print
		"<div class='frm'>\n",
		"<div class='hcl'>\n",
		"<span class='htt'>$lng->{uifMapTtl}</span>\n",
		"<a class='clk' id='loc'></a>\n",
		"</div>\n",
		"<div class='ccl'>\n",
		"<div id='map' style='width: 98%; height: 350px; max-width: 600px'></div>\n",
		"</div>\n",
		"</div>\n\n",
		"<script src='//maps.googleapis.com/maps/api/js?v=3&amp;sensor=false'></script>\n",
		"<script src='$cfg->{dataPath}/google.js'></script>\n\n";
}

# Print public user stats	
print
	"<table class='tbl'>\n",
	"<tr class='hrw'><th colspan='2'>$lng->{uifStatTtl}</th></tr>\n";

# Number of posts
my $postExistNum = $m->fetchArray("
	SELECT COUNT(*) FROM posts WHERE userId = ?", $infUserId);
print	
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifStatPNum}</td>\n",
	"<td>$infUser->{postNum} $lng->{uifStatPONum}, $postExistNum $lng->{uifStatPENum}", 
	@{$cfg->{userRanks}} ? $m->formatUserRank($infUser->{postNum}) : "", "</td>\n",
	"</tr>\n";

# Registration time
my $regTimeStr = $m->formatTime($infUser->{regTime}, $user->{timezone});
print
	"<tr class='crw'>\n",
	"<td class='hco'>$lng->{uifStatRegTm}</td><td>$regTimeStr</td>\n",
	"</tr>\n";
	
# Last-on and previous-on time
if ($userId == $infUserId || $user->{admin}) {
	my $lastOnTimeStr = $infUser->{lastOnTime}
		? $m->formatTime($infUser->{lastOnTime}, $user->{timezone}) : " - ";
	my $prevOnTimeStr = $infUser->{prevOnTime}
		? $m->formatTime($infUser->{prevOnTime}, $user->{timezone}) : " - ";
	print
		"<tr class='crw'>\n",
		"<td class='hco'>$lng->{uifStatLOTm}</td><td>$lastOnTimeStr</td>\n",
		"</tr>\n",
		"<tr class='crw'>\n",
		"<td class='hco'>$lng->{uifStatLRTm}</td><td>$prevOnTimeStr</td>\n",
		"</tr>\n";
}

# Admin-only user stats
if ($user->{admin}) {
	my $lastIpStr = $infUser->{lastIp}? $infUser->{lastIp} : " - ";
	$lastIpStr .= " (" . $m->escHtml($infUser->{host}) . ")" if $infUser->{host};
	my $ignoredNum = $m->fetchArray("
		SELECT COUNT(*) FROM userIgnores WHERE ignoredId = ?", $infUserId);
	my $watchedNum = $m->fetchArray("
		SELECT COUNT(*) FROM watchUsers WHERE watchedId = ?", $infUserId);
	my $userAgentStr = $infUser->{userAgent} ? $infUser->{userAgent} : " - ";
	print
		"<tr class='crw'>\n",
		"<td class='hco'>$lng->{uifStatLIp}</td><td>$lastIpStr</td>\n",
		"</tr>\n",
		"<tr class='crw'>\n",
		"<td class='hco'>User Agent</td><td>$userAgentStr</td>\n",
		"</tr>\n",
		"<tr class='crw'>\n",
		"<td class='hco'>Ignored By</td><td>$ignoredNum users</td>\n",
		"</tr>\n",
		"<tr class='crw'>\n",
		"<td class='hco'>Watched By</td><td>$watchedNum users</td>\n",
		"</tr>\n",
		"<tr class='crw'>\n",
		"<td class='hco'>Bounce Counter</td><td>$infUser->{bounceNum}</td>\n",
		"</tr>\n";
}

print "</table>\n\n";

# Print badges
if (@{$cfg->{badges}}) {
	my $userBadges = $m->fetchAllArray("
		SELECT badge FROM userBadges WHERE userId = ?", $infUserId);
	if (@$userBadges) {
		my @badges = ();
		for my $line (@{$cfg->{badges}}) {
			my ($id, $bigIcon, $title, $desc) = 
				$line =~ /(\w+)\s+\w+\s+\S+\s+(\S+)\s+"([^"]+)"\s+"([^"]+)/;
			push @badges, [ $id, $title, $bigIcon, $desc ];
		}
		print
			"<table class='tbl'>\n",
			"<tr class='hrw'>\n",
			"<th colspan='2'>$lng->{uifBadges}</th>\n",
			"</tr>\n";
		for my $badge (@badges) {
			for my $userBadge (@$userBadges) {
				if ($userBadge->[0] eq $badge->[0]) {
					my $url = "$cfg->{dataPath}/$badge->[2]";
					print
						"<tr class='crw'>\n",
						"<td class='hco'><img class='uba' src='$url' alt=''> $badge->[1]</td>\n",
						"<td>$badge->[3]</td>\n",
						"</tr>\n";
				}
			}
		}
		print "</table>\n\n";
	}
}

# Print non-public admin and member status info
if ($userId == $infUserId || $user->{admin}) {
	# Get groups
	my $groups = $m->fetchAllArray("
		SELECT groups.id, groups.title, 
			CASE WHEN groupAdmins.userId IS NOT NULL THEN '\@' ELSE '' END
		FROM groups AS groups
			INNER JOIN groupMembers AS groupMembers
				ON groupMembers.userId = :infUserId
				AND groupMembers.groupId = groups.id
			LEFT JOIN groupAdmins AS groupAdmins
				ON groupAdmins.userId = :infUserId
				AND groupAdmins.groupId = groups.id
		ORDER BY groups.title",
		{ infUserId => $infUserId });
	
	# Print groups
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{uifGrpMbrTtl}</span></div>\n",
		"<div class='ccl'>\n",
		join(",\n", map("<a href='" . $m->url('group_info', gid => $_->[0]) . "'>$_->[2]$_->[1]</a>", 
			@$groups)) || " - ", "\n",
		"</div>\n",
		"</div>\n\n";

	# Get subscribed boards
	my $boards = $m->fetchAllArray("
		SELECT boards.id, boards.title 
		FROM boardSubscriptions AS boardSubscriptions
			INNER JOIN boards AS boards
				ON boards.id = boardSubscriptions.boardId
			INNER JOIN categories AS categories
				ON categories.id = boards.categoryId
		WHERE boardSubscriptions.userId = :infUserId
		ORDER BY categories.pos, boards.pos",
		{ infUserId => $infUserId });

	# Print subscribed boards
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{uifBrdSubTtl}</span></div>\n",
		"<div class='ccl'>\n",
		join(",\n", map("<a href='" . $m->url('board_info', bid => $_->[0]) . "'>$_->[1]</a>", 
			@$boards)) || " - ", "\n",
		"</div>\n",
		"</div>\n\n";

	# Get subscribed topics
	my $topics = $m->fetchAllArray("
		SELECT topics.id, topics.subject 
		FROM topicSubscriptions AS topicSubscriptions
			INNER JOIN topics AS topics
				ON topics.id = topicSubscriptions.topicId
		WHERE topicSubscriptions.userId = :infUserId
		ORDER BY topics.id DESC",
		{ infUserId => $infUserId });

	# Print subscribed topics
	print
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{uifTpcSubTtl}</span></div>\n",
		"<div class='ccl'>\n",
		join(",\n", map("<a href='" . $m->url('topic_show', tid => $_->[0]) . "'>$_->[1]</a>", 
			@$topics)) || " - ", "\n",
		"</div>\n",
		"</div>\n\n";
}

# Log action and finish
$m->logAction(3, 'user', 'info', $userId, 0, 0, 0, $infUserId);
$m->printFooter();
$m->finish();
