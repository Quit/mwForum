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
$m->cacheUserStatus() if $userId;

# Check if search is enabled
$cfg->{forumSearch} == 1 || $cfg->{forumSearch} == 2 && $userId 
	|| $cfg->{googleSearch} || $user->{admin} 
	or $m->error('errNoAccess');

# Print header
my ($siteSearch) = $cfg->{baseUrl} =~ m!https?://(.+)!;
$siteSearch .= $m->{env}{scriptUrlPath};
$siteSearch = "rybkaforum.net/cgi-bin/rybkaforum" if $siteSearch =~ /mwforum\.org/;
$m->printHeader(undef, {
	http => $m->{http},
	siteSearch => $siteSearch,
	uaLangCode => $m->{uaLangCode},
	cfg_seoRewrite => $cfg->{seoRewrite},
});

# Get CGI parameters
my $page = $m->paramInt('pg') || 1;
my $categBoardIdStr = $m->paramStrId('board');
my $words = $m->paramStr('words');
my $userName = $m->paramStr('user');
my $searchUserId = $m->paramInt('uid');
my $minAge = $m->paramInt('min');
my $maxAge = $m->paramInt('max');
my $field = $m->paramStrId('field') || 'body';
my $order = $m->paramStrId('order') || 'desc';
my $submitted = $m->paramDefined('words') || $searchUserId || $userName;

# Check HTTP method and request source authentication
if ($cfg->{blockExtSearch} && $submitted && length($words)) {
	$m->{env}{method} eq 'POST' || $m->paramDefined('pg') or $m->error('errNoAccess');
	$m->checkSourceAuth() or $m->error('errNoAccess') if $cfg->{forumSearch} == 2;
}

# Get userName if only userId was specified
$userName = $m->fetchArray("
	SELECT userName FROM users WHERE id = ?", $searchUserId)
	if $searchUserId;

# Enforce valid options
$field = 'body' if $field !~ /^(?:body|raw|subject)\z/;
$order = 'desc' if $order !~ /^(?:asc|desc)\z/;

# Limit age values
$minAge = $m->min($minAge, 24855);
$maxAge = $m->min($maxAge, 24855);
$maxAge = $cfg->{searchMaxAge} 
	if $cfg->{searchMaxAge} && (!$maxAge || $maxAge > $cfg->{searchMaxAge});

# Shortcuts
my $mysqlFts = $cfg->{advSearch} && $field eq 'body' && $m->{mysql};
my $pgsqlFts = $cfg->{advSearch} && $field eq 'body' && $m->{pgsql};

# Using bound param for config would disable index use
my $pgsqlFtsCfg = $cfg->{pgFtsConfig};
$pgsqlFtsCfg = 'english' if $pgsqlFtsCfg !~ /^[a-z_0-9]+\z/i;

# Make copy of original search string, but normalize its whitespace
my $orgWords = $words;
$orgWords =~ s!\s+! !g;

# When using indexed search, give feedback about what is actually searched for
my @words = ();
my $wordsChanged = 0;
if ($mysqlFts) {
	# Split and rejoin string, discarding stuff that can't be searched for
	$words =~ s![+*()<>~]+! !g;
	@words = $words =~ /-?"[^"]+"|-?[^\\\/\s\$\@\[\]+*(){}<>~^#%?|.&=,;:`"']+/g;
	@words = grep(length > 2, @words);
	my $stopwordRx = join('\z|^', defined($cfg->{stopWords}) ? @{$cfg->{stopWords}} : qw(able about above according accordingly across actually after afterwards again against ain't all allow allows almost alone along already also although always am among amongst an and another any anybody anyhow anyone anything anyway anyways anywhere apart appear appreciate appropriate are aren't around as aside ask asking associated at available away awfully be became because become becomes becoming been before beforehand behind being believe below beside besides best better between beyond blockquote both brief but by c'mon c's came can can't cannot cant cause causes certain certainly changes clearly co com come comes concerning consequently consider considering contain containing contains corresponding could couldn't course currently definitely described despite did didn't different do does doesn't doing don't done down downwards during each edu eg eight either else elsewhere enough entirely especially et etc even ever every everybody everyone everything everywhere ex exactly example except far few fifth first five followed following follows for former formerly forth four from further furthermore get gets getting given gives go goes going gone got gotten greetings had hadn't happens hardly has hasn't have haven't having he he's hello help hence her here here's hereafter hereby herein hereupon hers herself hi him himself his hither hopefully how howbeit however i'd i'll i'm i've ie if ignored immediate in inasmuch inc indeed indicate indicated indicates inner insofar instead into inward is isn't it it'd it'll it's its itself just keep keeps kept know knows known last lately later latter latterly least less lest let let's like liked likely little look looking looks ltd mainly many may maybe me mean meanwhile merely might more moreover most mostly much must my myself name namely nd near nearly necessary need needs neither never nevertheless new next nine no nobody non none noone nor normally not nothing novel now nowhere obviously of off often oh ok okay old on once one ones only onto or other others otherwise ought our ours ourselves out outside over overall own particular particularly per perhaps placed please plus possible presumably probably provides que quite qv rather rd re really reasonably regarding regardless regards relatively respectively right said same saw say saying says second secondly see seeing seem seemed seeming seems seen self selves sensible sent serious seriously seven several shall she should shouldn't since six so some somebody somehow someone something sometime sometimes somewhat somewhere soon sorry specified specify specifying still sub such sup sure t's take taken tell tends th than thank thanks thanx that that's thats the their theirs them themselves then thence there there's thereafter thereby therefore therein theres thereupon these they they'd they'll they're they've think third this thorough thoroughly those though three through throughout thru thus to together too took toward towards tried tries truly try trying twice two un under unfortunately unless unlikely until unto up upon us use used useful uses using usually value various very via viz vs want wants was wasn't way we we'd we'll we're we've welcome well went were weren't what what's whatever when whence whenever where where's whereafter whereas whereby wherein whereupon wherever whether which while whither who who's whoever whole whom whose why will willing wish with within without won't wonder would would wouldn't yes yet you you'd you'll you're you've your yours yourself yourselves zero));
	@words = grep(!/^$stopwordRx\z/io, @words);
	$words = join(" ", @words);
	$wordsChanged = 1 if $orgWords ne $words;
}
elsif ($pgsqlFts) {
	# With PgSQL show user the result of plainto_tsquery()
	$words = $m->fetchArray("SELECT plainto_tsquery('$pgsqlFtsCfg', ?)", $words);
	$words =~ s![&']!!g;
	$words =~ s!\s+! !g;
	$wordsChanged = 1 if lc($orgWords) ne lc($words);
}

# Preserve parameters in links
my @params = (words => $orgWords, user => $userName, min => $minAge, max => $maxAge,
	board => $categBoardIdStr, field => $field, order => $order);

# Get visible boards
my $arcPfx = $m->{archive} ? 'arc_' : '';
my $boards = $m->fetchAllHash("
	SELECT boards.*, categories.title AS categTitle
	FROM ${arcPfx}boards AS boards
		INNER JOIN categories AS categories
			ON categories.id = boards.categoryId
		LEFT JOIN boardHiddenFlags AS boardHiddenFlags
			ON boardHiddenFlags.userId = :userId
			AND boardHiddenFlags.boardId = boards.id
	WHERE boardHiddenFlags.boardId IS NULL
	ORDER BY categories.pos, boards.pos",
	{ userId => $userId });
@$boards = grep($m->boardVisible($_), @$boards);
@$boards or $m->error('errNoAccess');
my @boardIds = map($_->{id}, @$boards);

# Search
my $boardId = 0;
my $postNum = 0;
my $posts = [];
my $postsPP = $m->min($user->{postsPP}, $cfg->{maxPostsPP}) || $cfg->{maxPostsPP};
my %attachments = ();
if ($submitted && !($wordsChanged && !$words)) {
	# Limit to user(s)
	my $userStr = "";
	my $groupTitle = "";
	my @userIds = ();
	if ($searchUserId) {
		$userStr = "AND posts.userId = :searchUserId";
	}
	elsif ($userName) {
		if (substr($userName, 0, 1) eq '!') {
			# Limit to group members
			@userIds = $m->getMemberIds($userName);
			@userIds or $m->error('errGrpNotFnd');
			$userStr = "AND posts.userId IN (:userIds)";
		}
		else {
			# Limit to single user
			$searchUserId = $m->fetchArray("
				SELECT id FROM users WHERE userName = ?", $userName);
			$searchUserId or $m->error('errUsrNotFnd');
			$userStr = "AND posts.userId = :searchUserId";
		}
	}
	
	# Limit to category or board
	my $boardStr = "";
	my @categBoardIds = ();
	if ($categBoardIdStr =~ /^bid([0-9]+)\z/) {
		$boardStr = "AND posts.boardId = :boardId";
		$boardId = $1;
	} 
	elsif ($categBoardIdStr =~ /^cid([0-9]+)\z/) {
		my @categBoards = grep($_->{categoryId} == $1, @$boards);
		@categBoardIds = map($_->{id}, @categBoards);
		$boardStr = "AND posts.boardId IN (:categBoardIds)";
	}

	# Search raw text or subject
	my $fieldStr = "posts.body";
	my $subjectStr = "";
	my $topicJoinStr = "";
	if ($field eq 'raw') {
		$fieldStr = "posts.rawBody";
		$subjectStr = "AND posts.rawBody <> ''";
	}
	elsif ($field eq 'subject' && $words) {
		$fieldStr = "topics.subject";
		$subjectStr = "AND posts.id = topics.basePostId";
		$topicJoinStr = "INNER JOIN ${arcPfx}topics AS topics ON topics.id = posts.topicId";
	}

	# Search words
	my $wordStr = "";
	my @wordValues = ();
	if ($mysqlFts && $words) {
		# Search with MySQL fulltext search
		for (@words) { 
			$_ = "$_*" if !/^"/;
			$_ = "+$_" if !/^-/;
		}
		$wordStr = "AND (MATCH posts.body AGAINST (:word0 IN BOOLEAN MODE))";
		push @wordValues, "word0" => join(" ", @words);
	}
	elsif ($pgsqlFts && $words) {
		# Search with PgSQL fulltext search
		$wordStr = "AND to_tsvector('$pgsqlFtsCfg', posts.body) @@ plainto_tsquery(:word0)";
		push @wordValues, 'word0' => $orgWords;
	}
	elsif ($words) {
		# Search with LIKE
		my $like = $m->{pgsql} ? 'ILIKE' : 'LIKE';
		my $wordsLike = $m->dbEscLike($words);
		my $percent = $m->{sqlite} && $cfg->{sqliteLike} ? "" : "%";
		@words = $wordsLike =~ /"[^"]+"|[^"\s]+/g;
		splice(@words, 10) if @words > 10;
		my @wordPreds = ();
		for (my $i = 0; $i < @words; $i++) {
			$words[$i] =~ s/"//g;
			$words[$i] = $m->escHtml($words[$i]);
			push @wordPreds, "$fieldStr $like :word$i";
			push @wordValues, "word$i" => "$percent$words[$i]$percent";
		}
		$wordStr = "AND (" . join(" AND ", @wordPreds) . ")";
	}

	# Limit to age
	my $minAgeStr = $minAge ? "AND posts.postTime < :now - :minAge * 86400" : "";
	my $maxAgeStr = $maxAge ? "AND posts.postTime > :now - :maxAge * 86400" : "";

	#	Install case-i LIKE function for SQLite
	$m->{dbh}->func('LIKE', 2, sub { my $a = shift(); my $b = shift();
		utf8::decode($a); utf8::decode($b); index(lc($a), lc($b)) > -1 }, 'create_function')
		if $m->{sqlite} && $cfg->{sqliteLike};

	# Get ids of posts matching criteria
	$posts = $m->fetchAllArray("
		SELECT posts.id
		FROM ${arcPfx}posts AS posts
			$topicJoinStr
		WHERE posts.boardId IN (:boardIds)
			AND posts.approved = 1
			$wordStr
			$subjectStr
			$userStr 
			$minAgeStr
			$maxAgeStr
			$boardStr 
		ORDER BY posts.postTime $order
		LIMIT 500",
		{ searchUserId => $searchUserId, groupTitle => $groupTitle, userIds => \@userIds,
			boardId => $boardId, categBoardIds => \@categBoardIds, now => $m->{now},
			minAge => $minAge, maxAge => $maxAge, boardIds => \@boardIds, @wordValues });
	$postNum = @$posts;
			
	if (@$posts) {
		# Get posts on page
		my @pagePostIds = @$posts[($page-1) * $postsPP .. $m->min($page * $postsPP, $postNum) - 1];
		@pagePostIds = map($_->[0], @pagePostIds);
		$posts = $m->fetchAllHash("
			SELECT posts.*, topics.subject
			FROM ${arcPfx}posts AS posts
				INNER JOIN ${arcPfx}topics AS topics
					ON topics.id = posts.topicId
			WHERE posts.id IN (:pagePostIds)
			ORDER BY posts.postTime $order",
			{ pagePostIds => \@pagePostIds });
	
		# Get attachments for posts on page
		my $attachments = $m->fetchAllHash("
			SELECT * FROM attachments WHERE postId IN (:pagePostIds)",
			{ pagePostIds => \@pagePostIds });
		for my $post (@$posts) {
			for my $attach (@$attachments) {
				push @{$post->{attachments}}, $attach	if $attach->{postId} == $post->{id};
			}
		}
	}
}

# Print page bar
my $pageNum = int($postNum / $postsPP) + ($postNum % $postsPP != 0);
my @pageLinks = $pageNum < 2 ? () : $m->pageLinks('forum_search', \@params, $page, $pageNum);
my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
$m->printPageBar(mainTitle => $lng->{seaTitle}, navLinks => \@navLinks, pageLinks => \@pageLinks);

# Determine checkbox and listbox states
my %state = (
	$categBoardIdStr => "selected='selected'",
	$field => "selected='selected'",
	$order => "selected='selected'",
);

# Display age 0 as empty string
$minAge = $minAge ? $minAge : "";
$maxAge = $maxAge ? $maxAge : "";

# Escape submitted values
my $wordsEsc = $m->escHtml($words);
my $orgWordsEsc = $m->escHtml($orgWords);
my $userNameEsc = $m->escHtml($userName);

# Print forum search form
if ($cfg->{forumSearch} == 1 || $cfg->{forumSearch} == 2 && $userId || $user->{admin}) {
	my $method = $cfg->{blockExtSearch} ? 'post' : 'get';
	print
		"<form action='forum_search$m->{ext}' method='$method'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{seaTtl}</span></div>\n",
		"<div class='ccl'>\n",
		!$cfg->{forumSearch} ? "<p>Forum search is currently only enabled for admins.</p>" : "",
		"<div class='cli'>\n",
		"<label>$lng->{seaWords}\n",
		"<input type='text' class='fcs' name='words' size='25' maxlength='100'",
		" autofocus='autofocus' value='$orgWordsEsc'/></label>\n",
		"<label>$lng->{seaUser}\n",
		"<input type='text' name='user' size='15' maxlength='$cfg->{maxUserNameLen}'",
		" value='$userNameEsc'/></label>\n",
		"<label>$lng->{seaBoard}\n",
		"<select name='board' size='1'>\n",
		"<option value='0'>$lng->{seaBoardAll}</option>\n";
	
	my $lastCategoryId = 0;
	for my $board (@$boards) {
		if ($lastCategoryId != $board->{categoryId}) {
			$lastCategoryId = $board->{categoryId};
			my $sel = $state{"cid$board->{categoryId}"};
			print "<option value='cid$board->{categoryId}' $sel>$board->{categTitle}</option>\n";
		}
		my $sel = $state{"bid$board->{id}"};
		print "<option value='bid$board->{id}' $sel>- $board->{title}</option>\n";
	}
	
	print
		"</select></label>\n",
		"</div>\n",
		"<div class='cli'>\n",
		"<label>$lng->{seaField}\n",
		"<select name='field' size='1'>\n",
		"<option value='body' $state{body}>$lng->{seaFieldBody}</option>\n",
		$cfg->{rawBody} ? "<option value='raw' $state{raw}>$lng->{seaFieldRaw}</option>\n" : "",
		"<option value='subject' $state{subject}>$lng->{seaFieldSubj}</option>\n",
		"</select></label>\n",
		"<label>$lng->{seaMinAge}\n",
		"<input type='text' name='min' size='3' maxlength='4' value='$minAge'/></label>\n",
		"<label>$lng->{seaMaxAge}\n",
		"<input type='text' name='max' size='3' maxlength='4' value='$maxAge'/></label>\n",
		"<label>$lng->{seaOrder}\n",
		"<select name='order' size='1'>\n",
		"<option value='desc' $state{desc}>$lng->{seaOrderDesc}</option>\n",
		"<option value='asc' $state{asc}>$lng->{seaOrderAsc}</option>\n",
		"</select></label>\n",
		$m->submitButton('seaB', 'search'),
		"</div>\n",
		$m->{archive} ? "<input type='hidden' name='arc' value='1'/>\n" : "",
		$m->{sessionId} ? "<input type='hidden' name='sid' value='$m->{sessionId}'/>\n" : "",
		$cfg->{blockExtSearch} ? "<input type='hidden' name='auth' value='$user->{sourceAuth}'/>\n" : "",
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
}

# Print hint
$m->printHints([$m->formatStr($lng->{seaWordsFtsT}, { expr => $wordsEsc })])
	if $wordsChanged && ($mysqlFts || $pgsqlFts);

# Print Google search form
my $autofocus = !$cfg->{forumSearch} ? "autofocus='autofocus'" : "";
if ($cfg->{googleSearch}) {
	# Search with results on Google page
	print
		"<form action='$m->{http}://www.google.com/search' method='get'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>$lng->{seaGglTtl}</span></div>\n",
		"<div class='ccl'>\n",
		"<div class='cli'>\n",
		"<input type='text' class='fcs' name='q' size='40' $autofocus/>\n",
		$m->submitButton('seaB', 'search'),
		"<input type='hidden' name='num' value='100'/>\n",
		"<input type='hidden' name='sitesearch' value='$siteSearch'/>\n",
		"</div>\n",
		"</div>\n",
		"</div>\n",
		"</form>\n\n";
}

# Print results
if ($submitted && !($wordsChanged && !$words)) {
	# Prepare strings for local highlighting and hl link parameters
	my $hilite = "";
	if ($mysqlFts) { 
		$hilite = $words;
		$hilite =~ s!"!!g;
	}
	elsif ($pgsqlFts) { 
		# Highlight unstemmed words, too
		$hilite = "$orgWords $words";
	}
	else {
		# LIKE search can find entities, so let's also hilight them
		$hilite = $wordsEsc;
		$hilite =~ s!&quot;!!g;
	}

	# Highlighting of post bodies shown on this page
	my @hiliteWords = ();
	if ($hilite) {
		# Split string and weed out stuff that could break entities
		my %h = ();
		my $hiliteRxEsc = $hilite;
		$hiliteRxEsc =~ s!([\\\$\[\](){}.*+?^|-])!\\$1!g;
		@hiliteWords = split(' ', $hiliteRxEsc);
		@hiliteWords = grep(length > 2 && !/^(?:amp|quot|quo|uot|160)\z/, @hiliteWords);
		@hiliteWords = map($h{$_}++ == 0 ? $_ : (), @hiliteWords);
		$hilite = join(" ", @hiliteWords);
	}

	# Print found posts	
	for my $post (@$posts) {
		# Format output
		my $postId = $post->{id};
		my $timeStr = $m->formatTime($post->{postTime}, $user->{timezone});
		my $userNameStr = $post->{userNameBak} || " - ";
		my $url = $m->url('user_info', uid => $post->{userId});
		$userNameStr = "<a href='$url'>$userNameStr</a>" if $post->{userId} > 0;
		$m->dbToDisplay({}, $post);
		$url = $m->url('topic_show', pid => $postId, $hilite ? (hl => $hilite) : ());

		# Highlight keywords
		if (@hiliteWords) {
			my $body = ">$post->{body}<";
			$body =~ s|>(.*?)<|
				my $text = $1;
				eval { $text =~ s!($_)!<em>$1</em>!gi } for @hiliteWords;
				">$text<";
			|egs;
			$post->{body} = substr($body, 1, -1);
		}
	
		# Print post
		print
			"<div class='frm pst'>\n",
			"<div class='hcl'>\n",
			"<span class='htt'>$lng->{serTopic}</span> <a href='$url'>$post->{subject}</a>\n",
			"<span class='htt'>$lng->{tpcBy}</span> $userNameStr\n",
			"<span class='htt'>$lng->{tpcOn}</span> $timeStr\n",
			"</div>\n",
			"<div class='ccl'>\n",
			$post->{body}, "\n",
			"</div>\n",
			"</div>\n\n";
	}
	
	# If nothing found, display notification
	print
		"<div class='frm'>\n",
		"<div class='ccl'>\n",
		"$lng->{serNotFound}\n",
		"</div>\n",
		"</div>\n\n"
		if !@$posts;
}

# Log action and finish
$m->logAction($submitted ? 1 : 3, 'forum', 'search', $userId, $boardId, 0, 0, 0, $orgWordsEsc);
$m->printFooter();
$m->finish();
