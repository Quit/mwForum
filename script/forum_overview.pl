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

# Get CGI parameters
my $action = $m->paramStrId('act');
my $onlyBoardId = $m->paramInt('bid');
my $onlyTopicId = $m->paramInt('tid');
my $onlyTopicTime = $m->paramInt('time');
my $firstPostIdx = $m->paramInt('first');
$action or $m->error('errParamMiss');

# Shortcuts
my $newMode = $action eq 'new';
my $unreadMode = $action eq 'unread';

# Check if access should be denied
!$unreadMode || $userId or $m->error('errNoAccess');

# Print header
$m->printHeader();

# Print page bar
my $title = $newMode ? $lng->{ovwTitleNew} : $lng->{ovwTitleUnr};
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $title, navLinks => \@navLinks);

# Get board id if only one topic is displayed
$onlyBoardId = $m->fetchArray("
	SELECT boardId FROM topics WHERE id = ?", $onlyTopicId)
	if $onlyTopicId;

# Get boards
my $onlyBoardStr = $onlyBoardId ? "AND boards.id = :onlyBoardId" : "";
my $boards = $m->fetchAllHash("
	SELECT boards.*
	FROM boards AS boards
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
		LEFT JOIN boardHiddenFlags AS boardHiddenFlags
			ON boardHiddenFlags.userId = :userId
			AND boardHiddenFlags.boardId = boards.id
	WHERE boardHiddenFlags.boardId IS NULL
		$onlyBoardStr
	ORDER BY categories.pos, boards.pos",
	{ userId => $userId, onlyBoardId => $onlyBoardId });

# Prepare values
my $emptyPixel = "src='$cfg->{dataPath}/epx.png'";
my $lowestUnreadTime = $m->max($user->{fakeReadTime}, $m->{now} - $cfg->{maxUnreadDays} * 86400);
my $maxPagePosts = $cfg->{maxPostsOvw} || $cfg->{maxPostsPP};
my $maxTopicPosts = 500;
my $postIdx = -1;
my $unfinished = 0;
my $board = undef;
my $topic = undef;
my %postsById = ();
my %postsByParent = ();
my %boardPrinted = ();
my %topicPrinted = ();

# Print post sub
my $printPost = sub {
	my $self = shift();
	my $post = shift();
	my $depth = shift();

	# Shortcuts
	my $boardId = $board->{id};
	my $topicId = $topic->{id};
	my $postId = $post->{id};
	my $postUserId = $post->{userId};

	# Print board bar
	if (!$boardPrinted{$boardId}) {
		$boardPrinted{$boardId} = 1;
		my $boardUrl = $m->url('board_show', bid => $boardId);
		print
			"<div class='frm'>\n",
			"<div class='hcl'>\n",
			"<span class='htt'>$lng->{brdTitle}</span> <a href='$boardUrl'>$board->{title}</a>\n",
			"</div>\n",
			"</div>\n\n";
	}

	# Print topic bar
	if (!$topicPrinted{$topicId}) {
		$topicPrinted{$topicId} = 1;
		my $filterStr = "";
		if (!$onlyTopicId) {
			my $topicOvwUrl = $m->url('forum_overview', act => $action, tid => $topicId,
				time => ($unreadMode ? $topic->{lowestUnreadTime} : ()));
			$filterStr =
				"<span class='nav'><a href='$topicOvwUrl'><img class='sic sic_nav_prev' $emptyPixel" .
				" title='$lng->{ovwFltTpcTT}' alt='$lng->{ovwFltTpc}'></a></span>\n";
		}
		my $topicUrl = $m->url('topic_show', tid => $topicId);
		print
			"<div class='frm' style='margin-left: $user->{indent}%'>\n",
			"<div class='hcl'>\n",
			$filterStr,
			"<span class='htt'>$lng->{tpcTitle}</span> <a href='$topicUrl'>$topic->{subject}</a>\n",
			"</div>\n",
			"</div>\n\n";
	}

	# Print post
	my $indent = $board->{flat} ? $user->{indent} * 2 : $m->min(70, $user->{indent} * $depth);
	if (!$post->{ignored}) {
		# Format output
		$m->dbToDisplay($board, $post);
		my $postTimeStr = $m->formatTime($post->{postTime}, $user->{timezone});
		my $invisImg = !$post->{approved} ? " <img class='sic sic_post_i' $emptyPixel"
			. " title='$lng->{tpcInvisTT}' alt='$lng->{brdInvis}'> " : "";

		# Format username
		my $userUrl = $m->url('user_info', uid => $postUserId);
		my $userNameStr = $post->{userName} || $post->{userNameBak} || " - ";
		$userNameStr = "<a href='$userUrl'>$userNameStr</a>" if $postUserId > 0;

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

		# Print post
		my $topicUrl = $m->url('topic_show', pid => $postId);
		print
			"<div class='frm pst' id='pid$postId' style='margin-left: $indent%'>\n",
			"<div class='hcl'>\n",
			"<a href='$topicUrl'>\n<img $emptyPixel $imgAttr></a>\n",
			$invisImg,
			"<span class='usr'><span class='htt'>$lng->{tpcBy}</span> $userNameStr</span>\n",
			"<span class='htt'>$lng->{tpcOn}</span> $postTimeStr\n",
			"</div>\n",
			"<div class='ccl'>\n",
			"$post->{body}\n",
			"</div>\n",
			"</div>\n\n";
	}
	else {
		# Print hidden post bar
		print
			"<div class='frm hps' style='margin-left: $indent%'>\n",
			"<div class='hcl'>$lng->{tpcHidTtl} $lng->{tpcHidIgnore}</div>\n",
			"</div>\n\n";
	}

	# Print children
	for my $child (@{$postsByParent{$postId}}) {
		$child->{id} != $postId or $m->error("Post is its own parent?!");
		$self->($self, $postsById{$child->{id}}, $depth + 1);
	}
};

# For each board
BOARD: for (@$boards) { $board = $_;
	# Skip if no access
	my $boardId = $board->{id};
	my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $board->{id});
	next BOARD if !($boardAdmin || $m->boardVisible($board));
	
	# Get topics
	my $onlyTopicStr = $onlyTopicId ? "AND topics.id = :onlyTopicId" : "";
	my $onlyTopicTimeStr = $onlyTopicTime ? $onlyTopicTime : "topicReadTimes.lastReadTime";
	my $topics = undef;
	if ($newMode) {
		# Get topics with new posts
		$topics = $m->fetchAllHash("
			SELECT topics.*,
				topicReadTimes.lastReadTime
			FROM topics AS topics
				LEFT JOIN topicReadTimes AS topicReadTimes
					ON topicReadTimes.userId = :userId
					AND topicReadTimes.topicId = topics.id
			WHERE topics.boardId = :boardId
				$onlyTopicStr
				AND topics.lastPostTime > :prevOnTime
			ORDER BY topics.lastPostTime",
			{ userId => $userId, boardId => $boardId, onlyTopicId => $onlyTopicId,
				prevOnTime => $user->{prevOnTime} });
	}
	else {
		# Get topics with unread posts
		$topics = $m->fetchAllHash("
			SELECT topics.*,
				topicReadTimes.lastReadTime
			FROM topics AS topics
				LEFT JOIN topicReadTimes AS topicReadTimes
					ON topicReadTimes.userId = :userId
					AND topicReadTimes.topicId = topics.id
			WHERE topics.boardId = :boardId
				$onlyTopicStr
				AND topics.lastPostTime > :lowestUnreadTime
				AND (topics.lastPostTime > $onlyTopicTimeStr
					OR topicReadTimes.topicId IS NULL)
			ORDER BY topics.lastPostTime",
			{ userId => $userId, boardId => $boardId, onlyTopicId => $onlyTopicId,
				lowestUnreadTime => $lowestUnreadTime });
	}
	next BOARD if !@$topics;

	# For each topic
	TOPIC: for (@$topics) {	$topic = $_;
		# Get posts
		my $topicId = $topic->{id};
		my $apprvStr = $boardAdmin || !$board->{approve} ? "" : "AND posts.approved = 1";
		$topic->{lowestUnreadTime} = $m->max($lowestUnreadTime,
			$onlyTopicTime ? $onlyTopicTime : $topic->{lastReadTime});
		my $posts = undef;
		if ($newMode) {
			# Get new posts
			$posts = $m->fetchAllHash("
				SELECT posts.*, posts.postTime > :lowestUnreadTime AS unread,
					users.userName, 
					userIgnores.userId IS NOT NULL AS ignored,
					1 AS new
				FROM posts AS posts
					LEFT JOIN users AS users
						ON users.id = posts.userId
					LEFT JOIN userIgnores AS userIgnores
						ON userIgnores.userId = :userId
						AND userIgnores.ignoredId = posts.userId
				WHERE posts.topicId = :topicId
					AND posts.postTime > :prevOnTime
					$apprvStr
				ORDER BY posts.postTime
				LIMIT :maxTopicPosts",
				{ lowestUnreadTime => $topic->{lowestUnreadTime}, userId => $userId, topicId => $topicId, 
					prevOnTime => $user->{prevOnTime}, maxTopicPosts => $maxTopicPosts });
		}
		else {
			# Get unread posts
			$posts = $m->fetchAllHash("
				SELECT posts.*, posts.postTime > :prevOnTime AS new,
					users.userName, 
					userIgnores.userId IS NOT NULL AS ignored,
					1 AS unread
				FROM posts AS posts
					LEFT JOIN users	AS users
						ON users.id = posts.userId
					LEFT JOIN userIgnores AS userIgnores
						ON userIgnores.userId = :userId
						AND userIgnores.ignoredId = posts.userId
				WHERE posts.topicId = :topicId
					AND posts.postTime > :lowestUnreadTime
					$apprvStr
				ORDER BY posts.postTime
				LIMIT :maxTopicPosts",
				{ prevOnTime => $user->{prevOnTime}, userId => $userId, topicId => $topicId,
					lowestUnreadTime => $topic->{lowestUnreadTime}, maxTopicPosts => $maxTopicPosts });
		}
		next TOPIC if !@$posts;

		# Build post lookup tables and snip skipped posts
		my $postNum = @$posts;
		my $skipPostNum = 0;
		for (my $i = 0; $i < $postNum; $i++) {
			my $post = $posts->[$i];
			$postIdx++;
			if ($postIdx < $firstPostIdx) {
				$skipPostNum = $i + 1;
				next;
			}
			$postsById{$post->{id}} = $post;
			push @{$postsByParent{$post->{parentId}}}, $post;
		}
		next TOPIC if $skipPostNum == $postNum;
		splice @$posts, 0, $skipPostNum if $skipPostNum;

		# Get attachments for posts
		if ($board->{attach}) {
			my @postIds = map($_->{id}, @$posts);
			my $attachments = $m->fetchAllHash("
				SELECT * FROM attachments WHERE postId IN (:postIds)", 
				{ postIds => \@postIds });
			push @{$postsById{$_->{postId}}{attachments}}, $_ for @$attachments;
		}

		# Recursively print branches
		for my $post (@$posts) {
			$printPost->($printPost, $post, 2) if !$postsById{$post->{parentId}};
		}

		# Print note if reached posts per topic hard-limit
		if (@$posts == $maxTopicPosts) {
			my $indent = $user->{indent} * 2;
			print	
				"<div class='frm' style='margin-left: $indent%'>\n",
				"<div class='ccl'>$lng->{ovwMaxCutoff}</div>\n",
				"</div>\n\n";
		}

		# Stop if reached or exceeded posts per page soft-limit
		if ($postIdx >= $firstPostIdx + $maxPagePosts - 1) {
			$unfinished = 1;
			last BOARD;
		}
	}
}

# Print note if no posts found
print	"<div class='frm'><div class='ccl'>$lng->{ovwEmpty}</div></div>\n\n" if !%topicPrinted;

# Print bottom page bar
my @userLinks = ();
push @userLinks, { url => $m->url('forum_overview', act => $action,
	$onlyBoardId ? (bid => $onlyBoardId) : (), $onlyTopicId ? (tid => $onlyTopicId) : ()),
	txt => 'ovwRefresh', ico => 'refresh' }
	if !$unfinished;
push @userLinks, { url => $m->url('forum_overview', act => $action, 
	$onlyBoardId ? (bid => $onlyBoardId) : (), $onlyTopicId ? (tid => $onlyTopicId) : (),
	$newMode ? (first => $postIdx + 1) : ()), 
	txt => 'ovwMore', ico => 'move' }
	if $unfinished;
push @userLinks, { url => $m->url('user_mark', act => 'old', time => $m->{now},
	auth => 1, ori => 1), 
	txt => 'ovwMarkOld', ico => 'markold' }
	if $newMode && %topicPrinted && !$onlyBoardId && !$onlyTopicId;
$m->printPageBar(mainTitle => $title, navLinks => \@navLinks, userLinks => \@userLinks);

# Update topic read times
if ($userId && %topicPrinted) {
	my $now = $m->{now};
	if ($m->{mysql}) {
		my $valuesStr = "";
		$valuesStr .= "($userId,$_,$now)," for keys %topicPrinted;
		chop $valuesStr;
		$m->dbDo("
			INSERT INTO topicReadTimes (userId, topicId, lastReadTime)
			VALUES $valuesStr
			ON DUPLICATE KEY UPDATE lastReadTime = VALUES(lastReadTime)");
	}
	elsif ($m->{pgsql}) {
		my $attr = { pg_server_prepare => 1 };
		my $delSth = $m->dbPrepare("
			DELETE FROM topicReadTimes WHERE userId = ? AND topicId = ?", $attr);
		my $insSth = $m->dbPrepare("
			INSERT INTO topicReadTimes (userId, topicId, lastReadTime) VALUES (?, ?, ?)", $attr);
		for (keys %topicPrinted) {
			$m->dbExecute($delSth, $userId, $_);
			$m->dbExecute($insSth, $userId, $_, $now);
		}
	}
	elsif ($m->{sqlite}) {
		my $updSth = $m->dbPrepare("
			REPLACE INTO topicReadTimes (userId, topicId, lastReadTime)	VALUES (?, ?, ?)");
		$m->dbExecute($updSth, $userId, $_, $now) for keys %topicPrinted;
	}
}

# Log action and finish
$m->logAction(2, 'overvw', $action, $userId, $onlyBoardId, $onlyTopicId);
$m->printFooter();
$m->finish();
