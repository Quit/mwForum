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

# Get CGI parameters
my $boardId = $m->paramStr('bid');  # int() later
my $jumpTopicId = $m->paramInt('tid');
my $page = $m->paramInt('pg') || 1;

# Redirect if board ID is special
$m->redirect('forum_show', tgt => $boardId) if $boardId =~ /^cid[0-9]+\z/;
$m->redirect('forum_show') if $boardId eq '0';
$boardId = int($boardId || 0);

# Get boardId and stickyness from topic
my $arcPfx = $m->{archive} ? 'arc_' : "";
my $jumpTopicSticky = 0;
($boardId, $jumpTopicSticky) = $m->fetchArray("
	SELECT boardId, sticky FROM ${arcPfx}topics WHERE id = ?", $jumpTopicId)
	if $jumpTopicId;
$boardId or $m->error('errParamMiss');

# Get board/category
my $board = $m->fetchHash("
	SELECT boards.*,
		categories.id AS categId, categories.title AS categTitle
	FROM ${arcPfx}boards AS boards
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
	WHERE boards.id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Check if user can see and write to board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $board->{id});
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');
my $boardWritable = $boardAdmin || $m->boardWritable($board);

# Print header
$m->printHeader($board->{title});

# Set current page to a requested topic's page	
my $topicsPP = $m->min($user->{topicsPP}, $cfg->{maxTopicsPP}) || $cfg->{maxTopicsPP};
if ($jumpTopicSticky) { $page = 1 }
elsif ($jumpTopicId) {
	my $jumpTopicTime = $m->fetchArray("
		SELECT lastPostTime FROM ${arcPfx}topics WHERE id = ?", $jumpTopicId);
	$page = $m->fetchArray("
		SELECT COUNT(*) / :topicsPP + 1
		FROM ${arcPfx}topics
		WHERE boardId = :boardId
			AND (sticky = 1 OR lastPostTime > :jumpTopicTime)",
		{ topicsPP => $topicsPP, boardId => $boardId, jumpTopicTime => $jumpTopicTime })
		if $jumpTopicTime;
	$page = int($page);
}

# Get topics
my $offset = ($page - 1) * $topicsPP;
my $stickyInnerStr = $cfg->{skipStickySort} ? "" : "sticky DESC,";
my $stickyOuterStr = $cfg->{skipStickySort} ? "" : "topics.sticky DESC,";
my $topics = $m->fetchAllHash("
	SELECT topics.id, topics.subject, topics.tag, topics.pollId, 
		topics.locked, topics.sticky, topics.postNum, topics.lastPostTime,
		posts.userId, posts.approved, posts.userNameBak
	FROM 
		( SELECT id, basePostId, subject, tag, pollId, locked, sticky, postNum, lastPostTime
			FROM ${arcPfx}topics
			WHERE boardId = :boardId
			ORDER BY $stickyInnerStr lastPostTime DESC
			LIMIT :topicsPP OFFSET :offset
		) AS topics
		INNER JOIN ${arcPfx}posts AS posts
			ON posts.id = topics.basePostId
	ORDER BY $stickyOuterStr topics.lastPostTime DESC",
	{ boardId => $boardId, topicsPP => $topicsPP, offset => $offset });

# Put visible topics in by-id lookup table and collect IDs for the next query
@$topics = grep($_->{approved} || $userId && $userId == $_->{userId}, @$topics) if !$boardAdmin;
my %topics = map(($_->{id} => $_), @$topics);
my @topicIds = map($_->{id}, @$topics);

# Get new post and unread numbers for topics on page
my $newPostsExist = 0;
my $unreadPostsExist = 0;
if ($user->{prevOnTime} < 2147483647 && !$m->{archive} && @topicIds) {
	my $approvedStr = $user->{admin} ? "" : "AND approved = 1";
	my $newTopics = $m->fetchAllArray("
		SELECT topicId, COUNT(*) AS newNum
		FROM posts 
		WHERE topicId IN (:topicIds)
			AND postTime > :prevOnTime
			$approvedStr
		GROUP BY topicId",
		{ topicIds => \@topicIds, prevOnTime => $user->{prevOnTime} });
	for my $topic (@$newTopics) {
		$topics{$topic->[0]}{newNum} = $topic->[1];
		$newPostsExist = 1;
	}
	
	# Check whether there's at least one unread topic
	if ($userId) {
		my $lowestUnreadTime = $m->max($user->{fakeReadTime}, 
			$m->{now} - $cfg->{maxUnreadDays} * 86400);
		my $unreadTopics = $m->fetchAllArray("
			SELECT topics.id
			FROM topics AS topics
				LEFT JOIN topicReadTimes AS topicReadTimes
					ON topicReadTimes.userId = :userId
					AND topicReadTimes.topicId = topics.id 
			WHERE topics.id IN (:topicIds)
				AND topics.lastPostTime > :lowestUnreadTime
				AND (topics.lastPostTime > topicReadTimes.lastReadTime 
					OR topicReadTimes.topicId IS NULL)",
			{ userId => $userId, topicIds => \@topicIds, lowestUnreadTime => $lowestUnreadTime });
		for my $topic (@$unreadTopics) {
			$topics{$topic->[0]}{hasUnread} = 1;
			$unreadPostsExist = 1;
		}
	}
}

# Page links
my $topicNum = $m->fetchArray("
	SELECT COUNT(*) FROM ${arcPfx}topics WHERE boardId = ?", $boardId);
my $pageNum = int($topicNum / $topicsPP) + ($topicNum % $topicsPP != 0);
my @pageLinks = $pageNum < 2 ? ()
	: $m->pageLinks('board_show', [ bid => $boardId ], $page, $pageNum);

# User button links
my @userLinks = ();
if (!$m->{archive}) {
	push @userLinks, { url => $m->url('board_info', bid => $boardId), 
		txt => 'brdInfo', ico => 'info' };
	push @userLinks, { url => $m->url('topic_add', bid => $boardId), 
		txt => 'brdNewTpc', ico => 'write' } 
		if $boardWritable;
	push @userLinks, { url => $m->url('user_mark', act => 'read', bid => $boardId, 
		time => $m->{now}, auth => 1), txt => 'brdMarkRd', ico => 'markread' }
		if $userId && $unreadPostsExist;
	push @userLinks, { url => $m->url('forum_overview', act => 'new', bid => $boardId), 
		txt => 'comShowNew', ico => 'shownew' } 
		if $userId && $newPostsExist;
	push @userLinks, { url => $m->url('forum_overview', act => 'unread', bid => $boardId), 
		txt => 'comShowUnr', ico => 'showunread' }
		if $userId && $unreadPostsExist;
	$m->callPlugin($_, links => \@userLinks, board => $board)
		for @{$cfg->{includePlg}{boardUserLink}};
}

# Admin button links
my @adminLinks = ();
if ($boardAdmin && !$m->{archive}) {
	my $reportNum = 0;
	$reportNum = $m->fetchArray("
		SELECT COUNT(*)
		FROM postReports AS postReports
			INNER JOIN posts AS posts
				ON posts.id = postReports.postId
			INNER JOIN boards AS boards
				ON boards.id = posts.boardId
		WHERE boards.id = ?", $boardId)
		if $cfg->{reports};
	push @adminLinks, { url => $m->url('report_list', bid => $boardId), 
		txt => "<em class='eln'>$lng->{brdAdmRep} ($reportNum)</em>", ico => 'report' }
		if $reportNum;
}

# Print page bar
my $categUrl = $m->url('forum_show', tgt => "bid$boardId");
my $categStr = "<a href='$categUrl'>$board->{categTitle}</a> / ";
my @navLinks = ({ url => $m->url('forum_show', tgt => "bid$boardId"), txt =>'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{brdTitle}, subTitle => $categStr . $board->{title}, 
	navLinks => \@navLinks, pageLinks => \@pageLinks, userLinks => \@userLinks, 
	adminLinks => \@adminLinks);

# Print long description
print "<div class='frm dsc'><div class='ccl'>$board->{longDesc}</div></div>\n\n"
	if $cfg->{boardPageDesc} && $board->{longDesc} && $user->{boardDescs};

# Print table header
print 
	"<table class='tbl'>\n",
	"<tr class='hrw'>\n",
	"<th>$lng->{brdTopic}</th>\n",
	"<th class='shr'>$lng->{brdPoster}</th>\n",
	"<th class='shr'>$lng->{brdPosts}</th>\n",
	"<th class='shr'>$lng->{brdLastPost}</th>\n",
	"</tr>\n";

# Print topics
my $emptyPixel = "src='$cfg->{dataPath}/epx.png'";
for my $topic (@$topics) {
	# Format output
	my $topicId = $topic->{id};
	my $topicUrl = $m->url('topic_show', tid => $topicId);
	my $lastPostTimeStr = $m->formatTime($topic->{lastPostTime}, $user->{timezone});
	my $userNameStr = $topic->{userName} || $topic->{userNameBak} || " - ";
	my $userUrl = $m->url('user_info', uid => $topic->{userId});
	$userNameStr = "<a href='$userUrl'>$userNameStr</a>" if $topic->{userId} > 0;
	my $subject = $topic->{sticky} ? "<span class='stk'>$topic->{subject}</span>" : $topic->{subject};
	my $ovwUrl = $m->url('forum_overview', act => 'new', tid => $topicId);
	my $newNumStr = $topic->{newNum} ? "<a href='$ovwUrl'>($topic->{newNum} $lng->{brdNew})</a>" : "";
	my $lockImg = $topic->{locked} ? " <img class='sic sic_topic_l' $emptyPixel"
		. " title='$lng->{brdLockedTT}' alt='$lng->{brdLocked}'>" : "";
	my $invisImg = !$topic->{approved} ? " <img class='sic sic_post_i' $emptyPixel"
		. " title='$lng->{brdInvisTT}' alt='$lng->{brdInvis}'>" : "";
	my $pollImg = $topic->{pollId} ? " <img class='sic sic_topic_poll' $emptyPixel"
		. " title='$lng->{brdPollTT}' alt='$lng->{brdPoll}'>" : "";
	my $tag = $topic->{tag} && $cfg->{allowTopicTags} && $user->{showDeco} 
		? " " . $m->formatTopicTag($topic->{tag}) : "";
	my $tpcClasses = "crw tpc";
	$tpcClasses .= " new" if $userId && $topic->{newNum};
	$tpcClasses .= " unr" if $userId && $topic->{hasUnread};
	$tpcClasses .= " tgt" if $topicId == $jumpTopicId;
	
	# Determine variable topic icon attributes
	my ($imgName, $imgTitle, $imgAlt);
	if ($userId) {
		if ($topic->{newNum} && $topic->{hasUnread}) { 
			$imgName = "topic_nu"; $imgTitle = $lng->{comNewUnrdTT}; $imgAlt = $lng->{comNewUnrd};
		}
		elsif ($topic->{newNum}) { 
			$imgName = "topic_nr"; $imgTitle = $lng->{comNewReadTT}; $imgAlt = $lng->{comNewRead};
		}
		elsif ($topic->{hasUnread}) { 
			$imgName = "topic_ou"; $imgTitle = $lng->{comOldUnrdTT}; $imgAlt = $lng->{comOldUnrd};
		}
		else { 
			$imgName = "topic_or"; $imgTitle = $lng->{comOldReadTT}; $imgAlt = $lng->{comOldRead};
		}
	}
	else {
		if ($topic->{newNum}) { 
			$imgName = "topic_nu"; $imgTitle = $lng->{comNewTT}; $imgAlt = $lng->{comNew};
		}
		else { 
			$imgName = "topic_ou"; $imgTitle = $lng->{comOldTT}; $imgAlt = $lng->{comOld};
		}
	}
	my $imgAttr = "class='sic sic_$imgName' title='$imgTitle' alt='$imgAlt'";

	# Print topic
	print 
		"<tr class='$tpcClasses'>\n",
		"<td>\n",
		"<a id='tid$topicId' href='$topicUrl'>\n",
		"<img $emptyPixel $imgAttr>$lockImg$invisImg$pollImg\n",
		"$subject</a>$tag\n",
		"</td>\n",
		"<td class='shr'>$userNameStr</td>\n",
		"<td class='shr'>$topic->{postNum} $newNumStr</td>\n",
		"<td class='shr'>$lastPostTimeStr</td>\n",
		"</tr>\n";
}

print "</table>\n\n";

# Log action and finish
$m->logAction(2, 'board', 'show', $userId, $boardId);
$m->printFooter(undef, $boardId);
$m->finish();
