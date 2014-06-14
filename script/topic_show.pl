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

# Get CGI parameters
my $topicId = $m->paramInt('tid');
my $targetPostId = $m->paramInt('pid');
my $page = $m->paramInt('pg');
my $showResults = $m->paramBool('results');
my $hilite = $m->paramStr('hl');
$topicId || $targetPostId or $m->error('errParamMiss');

# Get missing topicId from post
my $arcPfx = $m->{archive} ? 'arc_' : "";
if (!$topicId && $targetPostId) {
	$topicId = $m->fetchArray("
		SELECT topicId FROM ${arcPfx}posts WHERE id = ?", $targetPostId);
	$topicId or $m->error('errPstNotFnd');
}

# Get topic
my $topic = $m->fetchHash("
	SELECT topics.*, 
		topicReadTimes.lastReadTime
	FROM ${arcPfx}topics AS topics
		LEFT JOIN topicReadTimes AS topicReadTimes
			ON topicReadTimes.userId = :userId
			AND topicReadTimes.topicId = :topicId
	WHERE topics.id = :topicId",
	{ userId => $userId, topicId => $topicId });
$topic or $m->error('errTpcNotFnd');
$topic->{lastReadTime} ||= 0;
my $boardId = $topic->{boardId};
my $basePostId = $topic->{basePostId};

# Get board/category
my $board = $m->fetchHash("
	SELECT boards.*, 
		categories.id AS categId, categories.title AS categTitle
	FROM ${arcPfx}boards AS boards
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
	WHERE boards.id = ?", $boardId);
$board or $m->error('errBrdNotFnd');
my $flat = $board->{flat};

# Shortcuts
my $autoCollapsing = !$flat && $user->{collapse};
my $showAvatars = $cfg->{avatars} && $user->{showAvatars};
my $emptyPixel = "src='$cfg->{dataPath}/epx.png'";

# Check if user can see and write to topic
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $boardId);
my $topicAdmin = $board->{topicAdmins} && $m->topicAdmin($userId, $topicId);
$boardAdmin || $topicAdmin || $m->boardVisible($board) or $m->error('errNoAccess');
my $boardWritable = $boardAdmin || $topicAdmin || $m->boardWritable($board, 1);

# Get minimal version of all topic posts
my $sameTopic = $topicId == $user->{lastTopicId};
my $topicReadTime = $sameTopic ? $user->{lastTopicTime} : $topic->{lastReadTime};
my $lowestUnreadTime = $m->max($topicReadTime, $user->{fakeReadTime}, 
	$m->{now} - $cfg->{maxUnreadDays} * 86400);
my $posts = $m->fetchAllHash("
	SELECT id, parentId,
		postTime > :prevOnTime AS new,
		postTime > :lowestUnreadTime AS unread
	FROM ${arcPfx}posts
	WHERE topicId = :topicId
	ORDER BY postTime", 
	{ prevOnTime => $user->{prevOnTime}, lowestUnreadTime => $lowestUnreadTime, 
		topicId => $topicId });

# Build post lookup tables and check if there are any new or unread posts
my %postsById = map(($_->{id} => $_), @$posts);  # Posts by id - hash of hashrefs
my %postsByParent = ();  # Posts by parent id - hash of arrayrefs of hashrefs
my @rootPosts = ();
my $newPostsExist = 0;
my $unreadPostsExist = 0;
for my $post (@$posts) {
	push @{$postsByParent{$post->{parentId}}}, $post;
	push @rootPosts, $post if !$post->{parentId} && $post->{id} != $basePostId;
	$newPostsExist = 1 if $post->{new};
	$unreadPostsExist = 1 if $post->{unread};
}
unshift @rootPosts, $postsById{$basePostId};

# Determine page numbers and collect IDs of new or unread posts
my $postsPP = $m->min($user->{postsPP}, $cfg->{maxPostsPP}) || $cfg->{maxPostsPP};
my $postPos = 0;
my $firstUnrPostPage = undef;
my $firstNewPostPage = undef;
my $firstUnrPostId = undef;
my $firstNewPostId = undef;
my @newUnrPostIds = ();
my $preparePost = sub {
	my $self = shift();
	my $postId = shift();

	# Shortcuts
	my $post = $postsById{$postId};
	
	# Assign page numbers to posts
	$post->{page} = int($postPos / $postsPP) + 1;

	# Set current page to a requested post's page	
	$page = $post->{page} if $postId == $targetPostId;

	# Determine first new post and its page
	if (!$page && !$firstNewPostPage && $post->{new}) {
		$firstNewPostPage = $post->{page};
		$firstNewPostId = $postId;
	}

	# Determine first unread post and its page
	if (!$page && !$firstUnrPostPage && $post->{unread} && $userId) {
		$firstUnrPostPage = $post->{page};
		$firstUnrPostId = $postId;
	}

	# Add new/unread post ID to list
	push @newUnrPostIds, $postId if $post->{new} || ($post->{unread} && $userId);

	# Recurse through children
	$postPos++;
	for my $child (@{$postsByParent{$postId}}) {
		$child->{id} != $postId or $m->error("Post is its own parent?!");
		$self->($self, $child->{id});
	}
};
for my $rootPost (@rootPosts) {
	$preparePost->($preparePost, $rootPost->{id});
}
$page = $firstUnrPostPage || $firstNewPostPage if !$page;
my $scrollPostId = $targetPostId || $firstUnrPostId || $firstNewPostId || 0;
$scrollPostId = 0 if $scrollPostId == $basePostId || $showResults;

# Print header
$m->printHeader($topic->{subject}, {
	lng_tpcBrnExpand => $lng->{tpcBrnExpand},
	lng_tpcBrnCollap => $lng->{tpcBrnCollap},
	scrollPostId => $scrollPostId,
	boardAdmin => $boardAdmin,
});

# Get the full content of those posts that are on the current page
# Note: full posts are not copied to @$posts, @rootPosts and %postsByParent
$page ||= 1;
my @pagePostIds = map($_->{page} == $page ? $_->{id} : (), @$posts);
@pagePostIds or $m->error('errPstNotFnd');
my $ignoreStr = $userId ? ", 
		userIgnores.userId IS NOT NULL AS ignored" : "";
my $ignoreJoin = $userId ? "
		LEFT JOIN userIgnores AS userIgnores
			ON userIgnores.userId = :userId
			AND userIgnores.ignoredId = posts.userId" : "";
my $pagePosts = $m->fetchAllHash("
	SELECT posts.*, 
		posts.postTime > :prevOnTime AS new,
		posts.postTime > :lowestUnreadTime AS unread,
		users.userName, users.title AS userTitle, 
		users.postNum AS userPostNum,	users.avatar, users.signature, 
		users.openId, users.privacy
		$ignoreStr
	FROM ${arcPfx}posts AS posts
		LEFT JOIN users AS users
			ON users.id = posts.userId
		$ignoreJoin
	WHERE posts.id IN (:pagePostIds)",
	{ userId => $userId, prevOnTime => $user->{prevOnTime}, lowestUnreadTime => $lowestUnreadTime,
		pagePostIds => \@pagePostIds });
my %pageUserIds = ();
for my $post (@$pagePosts) { 
	$post->{page} = $page;
	$postsById{$post->{id}} = $post;
	$pageUserIds{$post->{userId}} = 1;
}
my $topicUserId = $postsById{$basePostId}{userId};

# Merge post likes into page posts
if ($cfg->{postLikes}) {
	my $postLikes = $m->fetchAllArray("
		SELECT posts.id,
			COUNT(postLikes.postId) AS likes,
			COUNT(postLiked.userId) > 0 AS liked
		FROM posts AS posts
			LEFT JOIN postLikes AS postLikes
				ON postLikes.postId = posts.id
			LEFT JOIN postLikes AS postLiked
				ON postLiked.postId = posts.id
				AND postLiked.userId = :userId
		WHERE posts.id IN (:pagePostIds)
		GROUP BY posts.id
		HAVING COUNT(postLikes.postId) > 0
			OR COUNT(postLiked.userId) > 0",
		{ userId => $userId, pagePostIds => \@pagePostIds });
	for my $like (@$postLikes) {
		$postsById{$like->[0]}{likes} = $like->[1];
		$postsById{$like->[0]}{liked} = $like->[2];
	}
}

# Remove ignored and base crosslink posts from @newUnrPostIds
@newUnrPostIds = grep(!$postsById{$_}{ignored}, @newUnrPostIds) if $userId;
shift @newUnrPostIds if $postsById{$newUnrPostIds[0]}{userId} == -2;

# Mark branches that shouldn't be auto-collapsed
if ($autoCollapsing) {
	for my $id (@newUnrPostIds) {
		my $post = $postsById{$id};
		while ($post = $postsById{$post->{parentId}}) {
			last if $post->{noCollapse};
			$post->{noCollapse} = 1;
		}
	}

	if ($targetPostId) {
		my $post = $postsById{$targetPostId};
		while ($post = $postsById{$post->{parentId}}) {
			last if $post->{noCollapse};
			$post->{noCollapse} = 1;
		}
	}
}

# Get poll
my $poll = undef;
my $polls = $cfg->{polls};
my $pollId = $topic->{pollId};
my $canPoll = ($polls == 1 || $polls == 2 && ($boardAdmin || $topicAdmin))
	&& ($userId && $userId == $topicUserId || $boardAdmin);
$poll = $m->fetchHash("
	SELECT * FROM polls WHERE id = ?", $pollId)
	if $polls && $pollId;

# Get attachments
if ($cfg->{attachments} && $board->{attach}) {
	my $attachments = $m->fetchAllHash("
		SELECT * 
		FROM attachments
		WHERE postId IN (:pagePostIds)
		ORDER BY webImage, id",
		{ pagePostIds => \@pagePostIds });
	push @{$postsById{$_->{postId}}{attachments}}, $_ for @$attachments;
}

# Get user badges
my @badges = ();
my %userBadges = ();
if (@{$cfg->{badges}} && $user->{showDeco}) {
	for my $line (@{$cfg->{badges}}) {
		my ($id, $smallIcon, $title) = $line =~ /(\w+)\s+\w+\s+(\S+)\s+\S+\s+"([^"]+)"/;
		push @badges, [ $id, $title, $smallIcon ] if $smallIcon ne '-';
	}
	my @pageUserIds = keys(%pageUserIds);
	my $userBadges = $m->fetchAllArray("
		SELECT userId, badge FROM userBadges WHERE userId IN (:pageUserIds)",
		{ pageUserIds => \@pageUserIds });
	push @{$userBadges{$_->[0]}}, $_->[1] for @$userBadges;
}

# Create or reuse GeoIP object
my $geoIp;
if (!$geoIp && $cfg->{geoIp} && $cfg->{userFlags} && $user->{showDeco}) {
	if (eval { require Geo::IP }) {
		$geoIp = Geo::IP->open($cfg->{geoIp}, 
			defined($cfg->{geoIpCacheMode}) ? $cfg->{geoIpCacheMode} : 1);
	}
	elsif (eval { require Geo::IP::PurePerl }) {
		$geoIp = Geo::IP::PurePerl->open($cfg->{geoIp});
	}
	else {
		$m->error("Geo::IP or Geo::IP::PurePerl modules not available.");
	}
}

# Highlighting
my @hiliteWords = ();
if ($hilite) {
	# Split string and weed out stuff that could break entities
	my $hiliteRxEsc = $hilite;
	$hiliteRxEsc =~ s!([\\\$\[\](){}.*+?^|-])!\\$1!g;
	@hiliteWords = split(' ', $hiliteRxEsc);
	@hiliteWords = grep(length > 2, @hiliteWords);
	@hiliteWords = grep(!/^(?:amp|quot|quo|uot|160)\z/, @hiliteWords);
}

# Page links
my $postNum = $topic->{postNum};
my $pageNum = int($postNum / $postsPP) + ($postNum % $postsPP != 0);
my @pageLinks = $pageNum < 2 ? ()
	: $m->pageLinks('topic_show', [ tid => $topicId ], $page, $pageNum);

# User button links
my @userLinks = ();
if (!$m->{archive}) {
	push @userLinks, { url => $m->url('post_add', tid => $topicId), 
		txt => 'tpcTpcRepl', ico => 'write' }
		if $boardWritable && !$topic->{locked} || $boardAdmin || $topicAdmin;
	push @userLinks, { url => $m->url('poll_add', tid => $topicId), 
		txt => 'tpcPolAdd', ico => 'poll' }
		if !$poll && $canPoll && (!$topic->{locked} || $boardAdmin || $topicAdmin);
	push @userLinks, { url => $m->url('topic_tag', tid => $topicId), 
		txt => 'tpcTag', ico => 'tag' }
		if ($userId && $userId == $topicUserId || $boardAdmin || $topicAdmin)
		&& ($cfg->{allowTopicTags} == 2 || $cfg->{allowTopicTags} == 1 && ($boardAdmin || $topicAdmin));
	push @userLinks, { url => $m->url('topic_subscribe', tid => $topicId), 
		txt => 'tpcSubs', ico => 'subscribe' }
		if $userId && ($cfg->{subsInstant} || $cfg->{subsDigest});
	push @userLinks, { url => $m->url('forum_overview', act => 'new', tid => $topicId), 
		txt => 'comShowNew', ico => 'shownew' }
		if $userId && $newPostsExist;
	push @userLinks, { url => $m->url('forum_overview', act => 'unread', tid => $topicId, 
		time => $lowestUnreadTime), txt => 'comShowUnr', ico => 'showunread' }
		if $userId && $unreadPostsExist;
	for my $plugin (@{$cfg->{includePlg}{topicUserLink}}) {
		$m->callPlugin($plugin, links => \@userLinks, board => $board, topic => $topic);
	}
}
	
# Admin button links	
my @adminLinks = ();
if (($boardAdmin || $topicAdmin) && !$m->{archive}) {
	push @adminLinks, { url => $m->url('topic_stick', tid => $topicId, 
		act => $topic->{sticky} ? 'unstick' : 'stick', auth => 1), 
		txt => $topic->{sticky} ? 'tpcAdmUnstik' : 'tpcAdmStik', ico => 'stick' }
		if $boardAdmin;
	push @adminLinks, { url => $m->url('topic_lock', tid => $topicId, 
		act => $topic->{locked} ? 'unlock' : 'lock', auth => 1), 
		txt => $topic->{locked} ? 'tpcAdmUnlock' : 'tpcAdmLock', ico => 'lock' };
	push @adminLinks, { url => $m->url('topic_move', tid => $topicId), 
		txt => 'tpcAdmMove', ico => 'move' }
		if $boardAdmin;
	push @adminLinks, { url => $m->url('topic_merge', tid => $topicId), 
		txt => 'tpcAdmMerge', ico => 'merge' }
		if $boardAdmin;
	push @adminLinks, { url => $m->url('user_confirm', script => 'topic_delete', tid => $topicId,
		notify => ($topicUserId != $userId ? 1 : 0), name => $topic->{subject}), 
		txt => 'tpcAdmDelete', ico => 'delete' };
	for my $plugin (@{$cfg->{includePlg}{topicAdminLink}}) {
		$m->callPlugin($plugin, links => \@adminLinks, board => $board, topic => $topic);
	}
}

# Print page bar
my $categUrl = $m->url('forum_show', tgt => "bid$boardId");
my $categStr = "<a href='$categUrl'>$board->{categTitle}</a> / ";
my $boardUrl = $m->url('board_show', tid => $topicId, tgt => "tid$topicId");
my $boardStr = "<a href='$boardUrl'>$board->{title}</a> / ";
my $lockStr = $topic->{locked} ? " $lng->{tpcLocked}" : "";
my @navLinks = ({ url => $m->url('board_show', tid => $topicId, tgt => "tid$topicId"), 
	txt => 'comUp', ico => 'up' });
$m->printPageBar(
	mainTitle => $lng->{tpcTitle}, 
	subTitle => $categStr . $boardStr . $topic->{subject} . $lockStr, 
	navLinks => \@navLinks, pageLinks => \@pageLinks, userLinks => \@userLinks, 
	adminLinks => \@adminLinks);

# Print poll
if ($poll && $polls && !$m->{archive}) {
	# Check if user can vote
	my $voted = $m->fetchArray("
		SELECT 1 FROM pollVotes WHERE pollId = ? AND userId = ?", $pollId, $userId) ? 1 : 0;
	my $canVote = (!$voted || $poll->{multi}) && (!$showResults && $userId && $boardWritable 
		&& !$topic->{locked} && !$poll->{locked});

	# Print poll header
	my $lockedStr = $poll->{locked} ? $lng->{tpcPolLocked} : "";
	print
		$canVote ? "<form action='poll_vote$m->{ext}' method='post'>\n" : "",
		"<div class='frm pol'>\n",
		"<div class='hcl'>\n",
		"<span class='htt'>$lng->{tpcPolTtl}</span>\n",
		"$poll->{title} $lockedStr\n",
		"</div>\n";

	# Print results
	if ($voted || $poll->{multi} || $showResults || !$userId || !$boardWritable 
		|| $topic->{locked} || $poll->{locked}) {

		my $options = undef;
		my $voteSum = undef;
		if ($poll->{locked}) {
			# Get consolidated results
			$options = $m->fetchAllHash("
				SELECT id, title, votes FROM pollOptions WHERE pollId = ? ORDER BY id", $pollId);

			# Get sum of votes
			$voteSum = $m->fetchArray("
				SELECT SUM(votes) FROM pollOptions WHERE pollId = ?", $pollId) || 1;
		}
		else {
			# Get results from votes
			$options = $m->fetchAllHash("
				SELECT pollOptions.id, pollOptions.title,
					COUNT(pollVotes.optionId) AS votes
				FROM pollOptions AS pollOptions
					LEFT JOIN pollVotes AS pollVotes
						ON pollVotes.pollId = :pollId
						AND pollVotes.optionId = pollOptions.id
				WHERE pollOptions.pollId = :pollId
				GROUP BY pollOptions.id, pollOptions.title
				ORDER BY pollOptions.id",
				{ pollId => $pollId });

			# Get sum of votes
			$voteSum = $m->fetchArray("
				SELECT COUNT(*) FROM pollVotes WHERE pollId = ?", $pollId) || 1;
		}

		# Print results
		print	"<div class='ccl'>\n<table class='plr'>\n";
		for my $option (@$options) {
			my $votes = $option->{votes};
			my $percent = int($votes / $voteSum * 100 + .5);
			my $width = $percent * 4;
			print	
				"<tr>\n",
				"<td class='plo'>$option->{title}</td>\n",
				"<td class='plv'>$votes</td>\n",
				"<td class='plp'>$percent\%</td>\n",
				"<td class='plg'><div class='plb' style='width: ${width}px'></div></td>\n",
				"</tr>\n";
		}
		print	"</table>\n</div>\n";
	}
	
	# Print poll form
	if ($canVote) {
		# Get poll options
		my $options = $m->fetchAllHash("
			SELECT id, title FROM pollOptions WHERE pollId = ? ORDER BY id", $pollId);
		
		# Get user's votes to disable options in multi-vote polls
		my $votes = $m->fetchAllArray("
			SELECT optionId FROM pollVotes WHERE pollId = ? AND userId = ?", $pollId, $userId);

		# Print poll options
		print "<div class='ccl'>\n";
		for my $option (@$options) {
			my $votedAttr = "";
			for my $vote (@$votes) { 
				$votedAttr = "disabled checked", last if $vote->[0] == $option->{id} 
			}
			print $poll->{multi} 
				? "<div><label><input type='checkbox' name='option_$option->{id}' $votedAttr> "
					. "$option->{title}</label></div>\n"
				: "<div><label><input type='radio' name='option' value='$option->{id}'> "
					. "$option->{title}</label></div>\n";
		}

		my $topicUrl = $m->url('topic_show', tid => $topicId, results => 1);	
		print
			$m->submitButton('tpcPolVote', 'poll'),
			$poll->{multi} ? "" : "<a href='$topicUrl'>$lng->{tpcPolShwRes}</a>\n",
			"<input type='hidden' name='tid' value='$topicId'>\n",
			$m->stdFormFields(),
			"</div>\n",
	}

	# Print lock poll button
	my @btlLines = ();
	if ($canPoll && !$poll->{locked}) {
		my $url = $m->url('poll_lock', tid => $topicId, auth => 1);
		push @btlLines, "<a href='$url' title='$lng->{tpcPolLockTT}'>$lng->{tpcPolLock}</a>\n";
	}

	# Print delete poll button
	if ($canPoll && (!$poll->{locked} || $boardAdmin || $topicAdmin)) {
		my $url = $m->url('user_confirm', tid => $topicId, pollId => $pollId, script => 'poll_delete',
			auth => 1, name => $poll->{title});
		push @btlLines, "<a href='$url' title='$lng->{tpcPolDelTT}'>$lng->{tpcPolDel}</a>\n";
	}

	# Print button cell if not empty
	print "<div class='bcl'>\n", @btlLines, "</div>\n" if @btlLines;
	print "</div>\n";
	print	"</form>\n\n" if $canVote;
}

# Determine position number of first and last posts on current page
my $firstPostPos = $postsPP * ($page - 1);
my $lastPostPos = $postsPP ? $postsPP * $page - 1 : @$posts - 1;

# Call plugin that can process data for various purposes
for my $plugin (@{$cfg->{includePlg}{topicData}}) {
	$m->callPlugin($plugin, board => $board, topic => $topic, pagePosts => $pagePosts, 
		postsById => \%postsById, boardAdmin => $boardAdmin, topicAdmin => $topicAdmin);
}

# Recursively print posts
$postPos = 0;
my $printPost = sub {
	my $self = shift();
	my $postId = shift();
	my $depth = shift();

	# Shortcuts
	my $post = $postsById{$postId};
	my $postUserId = $post->{userId};
	my $ip = $post->{ip};
	my $childNum = @{$postsByParent{$postId}};

	# Branch collapsing flags
	my $printBranchToggle = !$flat && $childNum && $post->{page} == $page;
	my $collapsed = $autoCollapsing && @newUnrPostIds && !$post->{noCollapse} ? 1 : 0;

	# Print if on current page
	if ($post->{page} == $page) {
		# Shortcuts
		my $parentId = $post->{parentId};
		my $indent = $flat ? 0 : $m->min(70, $user->{indent} * $depth);

		# Print post
		if ($post->{approved} || $boardAdmin || $topicAdmin || $userId && $userId == $postUserId) {
			# Format times
			my $postTimeStr = $m->formatTime($post->{postTime}, $user->{timezone});
			my $editTimeStr = undef;
			if ($post->{editTime}) {
				$editTimeStr = $m->formatTime($post->{editTime}, $user->{timezone});
				$editTimeStr = "<em>$editTimeStr</em>" if $post->{editTime} > $user->{prevOnTime};
				$editTimeStr = "<span class='htt'>$lng->{tpcEdited}</span> $editTimeStr\n";
			}
			
			# Format username
			my $userUrl = $m->url('user_info', uid => $postUserId);
			my $userNameStr = $post->{userName} || $post->{userNameBak} || " - ";
			my $openIdStr = $post->{openId} ? "title='OpenID: $post->{openId}'" : "";
			$userNameStr = "<a href='$userUrl' $openIdStr>$userNameStr</a>" if $postUserId > 0;
			$userNameStr .= " " . $m->formatUserTitle($post->{userTitle})
				if $post->{userTitle} && $user->{showDeco};
			$userNameStr .= " " . $m->formatUserRank($post->{userPostNum})
				if @{$cfg->{userRanks}} && !$post->{userTitle} && $user->{showDeco};
			
			# Format user badges
			if (@badges && $userBadges{$postUserId} && $user->{showDeco}) {
				for my $badge (@badges) {
					for my $userBadge (@{$userBadges{$postUserId}}) {
						if ($userBadge eq $badge->[0]) {
							$userNameStr .= " <img class='ubs' src='$cfg->{dataPath}/$badge->[2]'"
								. " title='$badge->[1]' alt=''>";
							last;
						}
					}
				}
			}
			
			# Format GeoIP country name and flag
			if ($geoIp && $user->{showDeco} && (!$post->{privacy} || $user->{admin})) {
				my ($code, $name);
				if (index($cfg->{geoIp}, 'City') > -1) {
					my $rec = $geoIp->record_by_addr($ip);
					if ($rec) {
						$code = lc($rec->country_code());
						$name = $rec->country_name();
					}
				}
				else {
					$code = lc($geoIp->country_code_by_addr($ip));
					$name = $geoIp->country_name_by_addr($ip);
				}
				if ($code && $code ne $cfg->{userFlagSkip}) {
					$userNameStr .= " <img class='flg' src='$cfg->{dataPath}/flags/$code.png'"
						. " alt='[$code]' title='$name'>";
				}
			}

			# Format misc values
			$m->dbToDisplay($board, $post);
			my $pstClasses = "frm pst" . $post->{classes};
			$pstClasses .= " new" if $post->{new};
			$pstClasses .= " unr" if $post->{unread} && $userId;
			$pstClasses .= " ign" if $post->{ignored};

			# Format invisible and locked post icons
			my $invisImg = !$post->{approved} ? " <img class='sic sic_post_i' $emptyPixel"
				. " title='$lng->{tpcInvisTT}' alt='$lng->{tpcInvis}'> " : "";
			my $lockImg = $post->{locked} ? " <img class='sic sic_topic_l' $emptyPixel"
				. " title='$lng->{tpcLockdTT}' alt='$lng->{tpcLockd}'> " : "";
				
			# Highlight search keywords
			if (@hiliteWords) {
				my $body = ">$post->{body}<";
				$body =~ s|>(.*?)<|
					my $text = $1;
					eval { $text =~ s!($_)!<em>$1</em>!gi } for @hiliteWords;
					">$text<";
				|egs;
				$post->{body} = substr($body, 1, -1);
			}

			# Determine variable post icon attributes
			my ($imgName, $imgTitle, $imgAlt);
			if ($userId) {
				if ($post->{new} && $post->{unread}) { 
					$imgName = "post_nu"; $imgTitle = $lng->{comNewUnrdTT}; $imgAlt = $lng->{comNewUnrd};
				}
				elsif ($post->{new}) { 
					$imgName = "post_nr"; $imgTitle = $lng->{comNewReadTT}; $imgAlt = $lng->{comNewRead};
				}
				elsif ($post->{unread}) { 
					$imgName = "post_ou"; $imgTitle = $lng->{comOldUnrdTT}; $imgAlt = $lng->{comOldUnrd};
				}
				else { 
					$imgName = "post_or"; $imgTitle = $lng->{comOldReadTT}; $imgAlt = $lng->{comOldRead};
				}
			}
			else {
				if ($post->{new}) { 
					$imgName = "post_nu"; $imgTitle = $lng->{comNewTT}; $imgAlt = $lng->{comNew};
				}
				else { 
					$imgName = "post_ou"; $imgTitle = $lng->{comOldTT}; $imgAlt = $lng->{comOld};
				}
			}
			my $imgAttr = "class='sic sic_$imgName' title='$imgTitle' alt='$imgAlt'";

			# Print post header
			print
				"<div class='$pstClasses' id='pid$postId' style='margin-left: $indent%'>\n",
				"<div class='hcl'>\n",
				"<span class='nav'>\n";

			# Print navigation buttons
			if (!$flat) {
				if (($post->{unread} || $post->{new} || $postPos == $firstPostPos) 
					&& @newUnrPostIds && @newUnrPostIds < $postNum && $postNum > 2 
					&& $postId != $newUnrPostIds[-1]) {
						
					# Print goto next new/unread post button
					my $nextPostId;
					if ($postPos == 0) { $nextPostId = $newUnrPostIds[0] }
					else {
						for my $i (0 .. @newUnrPostIds) { 
							if ($newUnrPostIds[$i] == $postId) {
								$nextPostId = $newUnrPostIds[$i+1];
								last;
							}
						}
					}
					if ($nextPostId) {
						my $url = $postsById{$nextPostId}{page} == $page 
							? "#pid$nextPostId" : $m->url('topic_show', pid => $nextPostId);
						print
							"<a class='nnl' href='$url'><img class='sic sic_post_nn' $emptyPixel",
							" title='$lng->{tpcNxtPstTT}' alt='$lng->{tpcNxtPst}'></a>\n";
					}
				}

				# Print jump to parent post button or alignment dummy
				if (!$parentId) {
					print "<img class='sic sic_nav_up' $emptyPixel style='visibility: hidden' alt=''>\n";
				}
				else {
					my $url = $postsById{$parentId}{page} == $page 
						? "#pid$parentId" : $m->url('topic_show', pid => $parentId);
					print
						"<a class='prl' href='$url'><img class='sic sic_nav_up' $emptyPixel",
						" title='$lng->{tpcParentTT}' alt='$lng->{tpcParent}'></a>\n";
				}
			}
			elsif ($postPos == 0 && @newUnrPostIds && @newUnrPostIds < $postNum && $postNum > 2) {
				# Print one goto new/unread post button in non-threaded boards
				my ($nextPostId) = @newUnrPostIds;
				my $url = $postsById{$nextPostId}{page} == $page 
					? "#pid$nextPostId" : $m->url('topic_show', pid => $nextPostId);
				print
					"<a href='$url'><img class='sic sic_post_nn' $emptyPixel",
					" title='$lng->{tpcNxtPstTT}' alt='$lng->{tpcNxtPst}'></a>\n";
			}

			print "</span>\n";

			# Print branch toggle icon
			if ($printBranchToggle) {
				my $img = $collapsed ? 'nav_plus' : 'nav_minus';
				my $alt = $collapsed ? '+' : '-';
				print 
					"<img class='tgl clk sic sic_$img' id='tgl$postId' $emptyPixel",
					" title='$lng->{tpcBrnCollap}' alt='$alt'>\n";
			}

			# Print icon and main header items
			my $postUrl = $m->url('topic_show', pid => $postId, tgt => "pid$postId");
			print
				"<a class='psl' href='$postUrl'><img $emptyPixel $imgAttr></a>\n",
				$lockImg,
				$invisImg,
				$postUserId > -2 ? "<span class='htt'>$lng->{tpcBy}</span> $userNameStr\n" : "",
				"<span class='htt'>$lng->{tpcOn}</span> $postTimeStr\n", 
				$editTimeStr,
				$post->{likes} ? "<span class='htt'>$lng->{tpcLikes}</span> $post->{likes}\n" : "";
			
			# Print IP
			print "<span class='htt'>IP</span> $ip\n" if $boardAdmin && $cfg->{showPostIp};
			
			# Print include plugin header items
			for my $plugin (@{$cfg->{includePlg}{postHeader}}) {
				$m->callPlugin($plugin, board => $board, topic => $topic, post => $post, 
					boardAdmin => $boardAdmin, topicAdmin => $topicAdmin);
			}
			
			print "</div>\n<div class='ccl'>\n";

			# Print avatar
			if ($showAvatars && index($post->{avatar}, "gravatar:") == 0) {
				my $md5 = $m->md5(substr($post->{avatar}, 9));
				my $url = "//gravatar.com/avatar/$md5?s=$cfg->{avatarWidth}";
				print "<img class='ava' src='$url' alt=''>\n";
			}
			elsif ($showAvatars && $post->{avatar}) {
				print	"<img class='ava' src='$cfg->{attachUrlPath}/avatars/$post->{avatar}' alt=''>\n";
			}

			# Print body
			print $post->{body}, "\n</div>\n";

			# Print reply button
			my @btlLines = ();
			if (($boardWritable && !$topic->{locked} && !$post->{locked} || $boardAdmin || $topicAdmin) 
				&& $postUserId != -2) {
				my $url = $m->url('post_add', pid => $postId);
				push @btlLines, $m->buttonLink($url, 'tpcReply', 'write');
			}

			# Print reply with quote button
			if (($boardWritable && !$topic->{locked} && !$post->{locked} || $boardAdmin || $topicAdmin)
				&& $cfg->{quote} && ($flat || $cfg->{quote} == 2)
				&& $postUserId != -2) {
				my $url = $m->url('post_add', pid => $postId, quote => 1);
				push @btlLines, $m->buttonLink($url, 'tpcQuote', 'write');
			}

			# Print edit button
			if ($userId 
				&& ($userId == $postUserId && !$topic->{locked} 
				&& !$post->{locked} || $boardAdmin || $topicAdmin)
				&& !($postUserId == -2 && $postId != $basePostId)) {
				my $url = $m->url('post_edit', pid => $postId);
				push @btlLines, $m->buttonLink($url, 'tpcEdit', 'edit');
			}

			# Print attach button
			if ($cfg->{attachments} && $userId && $postUserId != -2
				&& ($userId == $postUserId && !$topic->{locked} 
				&& !$post->{locked} || $boardAdmin || $topicAdmin)
				&& ($board->{attach} == 1 || $board->{attach} == 2 && $boardAdmin)) {
				my $url = $m->url('post_attach', pid => $postId);
				push @btlLines, $m->buttonLink($url, 'tpcAttach', 'attach');
			}

			# Print notify button
			if ($userId) {
				my $url = $m->url('report_add', pid => $postId);
				push @btlLines, $m->buttonLink($url, 'tpcReport', 'report');
			}

			# Print like buttons
			if ($cfg->{postLikes} && $userId && $userId != $postUserId && $postUserId != -2) {
				if ($post->{liked}) {
					my $url = $m->url('post_like', pid => $postId, act => 'unlike', auth => 1);
					push @btlLines, $m->buttonLink($url, 'tpcUnlike', 'rate');
				}
				else {
					my $url = $m->url('post_like', pid => $postId, act => 'like', auth => 1);
					push @btlLines, $m->buttonLink($url, 'tpcLike', 'rate');
				}
			}

			# Print approve button
			if (!$post->{approved} && ($boardAdmin || $topicAdmin)) {
				my $url = $m->url('post_approve', pid => $postId, auth => 1);
				push @btlLines, $m->buttonLink($url, 'tpcApprv', 'approve');
			}

			# Print lock/unlock button
			if (($boardAdmin || $topicAdmin) && $postUserId != -2) {
				if ($post->{locked}) {
					my $url = $m->url('post_lock', pid => $postId, act => 'unlock', auth => 1);
					push @btlLines, $m->buttonLink($url, 'tpcUnlock', 'lock');
				}
				else {
					my $url = $m->url('post_lock', pid => $postId, act => 'lock', auth => 1);
					push @btlLines, $m->buttonLink($url, 'tpcLock', 'lock');
				}
			}

			# Print branch button
			if ($postId != $basePostId && $postUserId != -2 && ($boardAdmin || $topicAdmin)) {
				my $url = $m->url('branch_admin', pid => $postId);
				push @btlLines, $m->buttonLink($url, 'tpcBranch', 'branch');
			}

			# Print delete button
			if ($userId
				&& ($userId == $postUserId && !$topic->{locked} 
				&& !$post->{locked} || $boardAdmin || $topicAdmin)
				&& ($postId != $basePostId || @$posts == 1)
				&& !@{$postsByParent{$postId}}) {
				my $url = $m->url('user_confirm', script => 'post_delete', pid => $postId, 
					notify => ($postUserId != $userId ? 1 : 0), name => $postId);
				push @btlLines, $m->buttonLink($url, 'tpcDelete', 'delete');
			}

			# Print include plugin buttons
			for my $plugin (@{$cfg->{includePlg}{postLink}}) {
				$m->callPlugin($plugin, lines => \@btlLines, board => $board, topic => $topic, post => $post, 
					boardAdmin => $boardAdmin, topicAdmin => $topicAdmin);
			}

			# Print button cell if there're button links
			print "<div class='bcl'>\n", @btlLines, "</div>\n" if @btlLines && !$m->{archive};
			print "</div>\n\n";
		}
		else {
			# Print unapproved post bar
			print
				"<div class='frm hps' style='margin-left: $indent%'>\n",
				"<div class='hcl'>\n",
				"<a id='pid$postId'></a>\n",
				"$lng->{tpcHidTtl} $lng->{tpcHidUnappr}\n",
				"</div>\n",
				"</div>\n\n";
		}
	}

	# Print div for branch collapsing
	if ($printBranchToggle) {
		my $class = $collapsed ? "brn clp" : "brn";
		print "<div class='$class' id='brn$postId'>\n";
	}
	
	# Print children recursively
	$postPos++;
	for my $child (@{$postsByParent{$postId}}) {
		return if $postPos > $lastPostPos && !$printBranchToggle;
		$child->{id} != $postId or $m->error("Post is its own parent?!");
		$self->($self, $child->{id}, $depth + 1);
	}

	print "</div>\n" if $printBranchToggle;
};
for my $rootPost (@rootPosts) {
	$printPost->($printPost, $rootPost->{id}, 0);
}

# Repeat page bar
$m->printPageBar(repeat => 1);

# Update topic read data
if ($userId && !$sameTopic && !$m->{archive}) {
	if ($topic->{lastPostTime} > $lowestUnreadTime) {
		# Replace topic's last read time
		if ($m->{mysql}) {
			$m->dbDo("
				INSERT INTO topicReadTimes (userId, topicId, lastReadTime) VALUES (?, ?, ?)
				ON DUPLICATE KEY UPDATE lastReadTime = VALUES(lastReadTime)",
				$userId, $topicId, $m->{now});
		}
		else {
			$m->dbDo("
				DELETE FROM topicReadTimes WHERE userId = ? AND topicId = ?", $userId, $topicId);
			$m->dbDo("
				INSERT INTO topicReadTimes (userId, topicId, lastReadTime) VALUES (?, ?, ?)",
				$userId, $topicId, $m->{now});
		}
	}

	# Update user stats
	$m->{userUpdates}{lastTopicId} = $topicId;
	$m->{userUpdates}{lastTopicTime} = $topic->{lastReadTime} || 0;
}

# Log action and finish
$m->logAction(2, 'topic', 'show', $userId, $boardId, $topicId);
$m->printFooter(undef, $boardId);
$m->finish();
