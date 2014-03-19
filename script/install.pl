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
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
require MwfMain;

#------------------------------------------------------------------------------

# Get arguments
my %opts = ();
Getopt::Std::getopts('if:e:', \%opts);
my $citext = $opts{i};
my $forumId = $opts{f};

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId, allowCgi => 1, upgrade => 1);
my $dbh = $m->{dbh};
my $pfx = $cfg->{dbPrefix};

# Autoflush stdout
$| = 1;
print "mwForum installation running...\n";
print "Creating tables...\n";

#------------------------------------------------------------------------------
# Schema

my $sql = "
CREATE TABLE config (
	name         VARCHAR(14) PRIMARY KEY,            -- Forum option name
	value        TEXT NOT NULL DEFAULT '',           -- Forum option value
	parse        VARCHAR(10) NOT NULL DEFAULT ''     -- ''=scalar, 'hash', 'array'
) TABLEOPT;

CREATE TABLE users (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- User id
	userName     VARCHAR(150) NOT NULL,              -- Account name
	realName     VARCHAR(255) NOT NULL DEFAULT '',   -- Real name
	email        VARCHAR(255) NOT NULL DEFAULT '',   -- Email address
	openId       VARCHAR(255) NOT NULL DEFAULT '',   -- OpenID URL
	title        TEXT NOT NULL DEFAULT '',           -- Title displayed after username in some places
	admin        TINYINT NOT NULL DEFAULT 0,         -- Is user a forum admin?
	dontEmail    TINYINT NOT NULL DEFAULT 0,         -- Don't send email to this user?
	notify       TINYINT NOT NULL DEFAULT 0,         -- Notify of post replies?
	msgNotify    TINYINT NOT NULL DEFAULT 0,         -- Send important notification by email?
	tempLogin    TINYINT NOT NULL DEFAULT 0,         -- Use temporary cookies?
	privacy      TINYINT NOT NULL DEFAULT 0,         -- Don't show name on online-users list
	homepage     VARCHAR(255) NOT NULL DEFAULT '',   -- Homepage URL
	occupation   VARCHAR(255) NOT NULL DEFAULT '',   -- Job
	hobbies      VARCHAR(255) NOT NULL DEFAULT '',   -- Hobbies
	location     VARCHAR(255) NOT NULL DEFAULT '',   -- Geographical location
	icq          VARCHAR(255) NOT NULL DEFAULT '',   -- Instant messenger IDs
	avatar       VARCHAR(255) NOT NULL DEFAULT '',   -- Avatar filename or gravatar:emailaddr
	signature    TEXT NOT NULL DEFAULT '',           -- Signature
	blurb        TEXT NOT NULL DEFAULT '',           -- Intro/bio etc.
	extra1       TEXT NOT NULL DEFAULT '',           -- Configurable profile field
	extra2       TEXT NOT NULL DEFAULT '',           -- Configurable profile field
	extra3       TEXT NOT NULL DEFAULT '',           -- Configurable profile field
	birthyear    SMALLINT NOT NULL DEFAULT 0,        -- Birthyear
	birthday     VARCHAR(5) NOT NULL DEFAULT '',     -- Birthday, format MM-DD
	timezone     VARCHAR(10) NOT NULL DEFAULT '',    -- Timezone for time display localization
	language     VARCHAR(80) NOT NULL DEFAULT '',    -- Language name
	style        VARCHAR(80) NOT NULL DEFAULT '',    -- CSS design name
	fontFace     VARCHAR(80) NOT NULL DEFAULT '',    -- Font face name
	fontSize     TINYINT NOT NULL DEFAULT 0,         -- Font size in points
	boardDescs   TINYINT NOT NULL DEFAULT 0,         -- Show board descriptions?
	showDeco     TINYINT NOT NULL DEFAULT 0,         -- Show user titles, ranks, smileys, topic tags?
	showAvatars  TINYINT NOT NULL DEFAULT 0,         -- Show avatar images?
	showImages   TINYINT NOT NULL DEFAULT 0,         -- Show embedded images?
	showSigs     TINYINT NOT NULL DEFAULT 0,         -- Show signatures?
	collapse     TINYINT NOT NULL DEFAULT 0,         -- Auto-collapse topic branches?
	indent       TINYINT NOT NULL DEFAULT 0,         -- Threading indent in percent
	topicsPP     SMALLINT NOT NULL DEFAULT 0,        -- Topics per board page
	postsPP      SMALLINT NOT NULL DEFAULT 0,        -- Posts per topic page
	regTime      INT NOT NULL DEFAULT 0,             -- Registration timestamp
	lastOnTime   INT NOT NULL DEFAULT 0,             -- New calc: last visit to any page
	prevOnTime   INT NOT NULL DEFAULT 0,             -- New calc: lastOnTime from previous session
	fakeReadTime INT NOT NULL DEFAULT 0,             -- Read calc: set to curr time when forcing read
	lastTopicId  INT NOT NULL DEFAULT 0,             -- Read calc: Last visited topic
	lastTopicTime INT NOT NULL DEFAULT 0,            -- Read calc: Last visited topic timestamp
	chatReadTime INT NOT NULL DEFAULT 0,             -- Read calc (chat): set to curr time in chat_show
	lastIp       VARCHAR(39) NOT NULL DEFAULT '',    -- IP user had when hitting main page
	userAgent    VARCHAR(255) NOT NULL DEFAULT '',   -- Browser used when hitting main page
	postNum      INT NOT NULL DEFAULT 0,             -- Number of posts made
	bounceNum    INT NOT NULL DEFAULT 0,             -- Number of email bounces received * factor
	bounceAuth   VARCHAR(22) NOT NULL DEFAULT '',    -- Bounced email authentication token
	password     VARCHAR(22) NOT NULL DEFAULT '',    -- Password hash
	salt         VARCHAR(22) NOT NULL DEFAULT '',    -- Password salt
	loginAuth    VARCHAR(22) NOT NULL DEFAULT '',    -- Login authentication token
	sourceAuth   VARCHAR(22) NOT NULL DEFAULT '',    -- CSRF protection token
	sourceAuth2  VARCHAR(22) NOT NULL DEFAULT '',    -- Previous sourceAuth
	gpgKeyId     VARCHAR(18) NOT NULL DEFAULT '',    -- OpenPGP key id
	policyAccept TINYINT NOT NULL DEFAULT 0,         -- Version of accepted forum policy
	renamesLeft  TINYINT NOT NULL DEFAULT 0,         -- Remaining times user can rename self
	oldNames     TEXT NOT NULL DEFAULT '',           -- Former usernames
	comment      TEXT NOT NULL DEFAULT ''            -- Comment field visible to admins only
) TABLEOPT;
CREATE UNIQUE INDEX users_userName ON users (userName);

CREATE TABLE userVariables (
	userId       INT NOT NULL,                       -- User id
	name         VARCHAR(10) NOT NULL,               -- Variable name
	value        TEXT NOT NULL DEFAULT '',           -- Value
	PRIMARY KEY (userId, name)
) TABLEOPT;

CREATE TABLE userBadges (
	userId       INT NOT NULL,                       -- User id
	badge        VARCHAR(20) NOT NULL,               -- Badge id
	PRIMARY KEY (userId, badge)
) TABLEOPT;

CREATE TABLE userBans (
	userId       INT PRIMARY KEY,
	banTime      INT NOT NULL,                       -- Ban timestamp
	duration     SMALLINT NOT NULL DEFAULT 0,        -- Duration in days
	reason       TEXT NOT NULL DEFAULT '',           -- Reason shown in ban error message
	intReason    TEXT NOT NULL DEFAULT ''            -- Internal reason only shown to admins
) TABLEOPT;

CREATE TABLE userIgnores (
	userId       INT NOT NULL,                       -- Ignoring user
	ignoredId    INT NOT NULL,                       -- Ignored user
	PRIMARY KEY (userId, ignoredId)
) TABLEOPT;

CREATE TABLE groups (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Group id
	title        VARCHAR(255) NOT NULL,              -- Group name
	badge        VARCHAR(20) NOT NULL DEFAULT '',    -- User badge given to members
	public       TINYINT NOT NULL DEFAULT 0,         -- Group info visible to non-members?
	open         TINYINT NOT NULL DEFAULT 0          -- Can users join themselves?
) TABLEOPT;

CREATE TABLE groupMembers (
	userId       INT NOT NULL,                       -- Member id
	groupId      INT NOT NULL,                       -- Group id
	PRIMARY KEY (userId, groupId)
) TABLEOPT;

CREATE TABLE groupAdmins (
	userId       INT NOT NULL,                       -- Admin id
	groupId      INT NOT NULL,                       -- Group id
	PRIMARY KEY (userId, groupId)
) TABLEOPT;

CREATE TABLE categories (
	id           INT PRIMARY KEY AUTO_INCREMENT,
	title        VARCHAR(255) NOT NULL,              -- Category name
	pos          SMALLINT NOT NULL                   -- Position in list
) TABLEOPT;

CREATE TABLE boards (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Board id
	title        VARCHAR(255) NOT NULL,              -- Board name
	categoryId   INT NOT NULL,                       -- Parent category
	pos          SMALLINT NOT NULL,                  -- Position in list (category local)
	expiration   SMALLINT NOT NULL DEFAULT 0,        -- Topics expire x days after last post
	locking      SMALLINT NOT NULL DEFAULT 0,        -- Topics are locked x days after last post
	topicAdmins  TINYINT NOT NULL DEFAULT 0,         -- Are topic creators mods for that topic?
	approve      TINYINT NOT NULL DEFAULT 0,         -- Approval moderation active?
	private      TINYINT NOT NULL DEFAULT 0,         -- Contents visible to? 0=all, 1=m&m, 2=reg.
	list         TINYINT NOT NULL DEFAULT 0,         -- List board even if contents not visible?
	unregistered TINYINT NOT NULL DEFAULT 0,         -- Can unregistered visitors post?
	announce     TINYINT NOT NULL DEFAULT 0,         -- Who can post? 0=all, 1=m&m, 2=all can reply
	flat         TINYINT NOT NULL DEFAULT 0,         -- Flatmode, no threading/indenting?
	attach       TINYINT NOT NULL DEFAULT 0,         -- Enable file attachments?
	shortDesc    VARCHAR(255) NOT NULL DEFAULT '',   -- Short description for forum page
	longDesc     TEXT NOT NULL DEFAULT '',           -- Long description for board info page
	postNum      INT NOT NULL DEFAULT 0,             -- Number of posts (cached)
	lastPostTime INT NOT NULL DEFAULT 0              -- Time of latest post (cached)
) TABLEOPT;

CREATE TABLE boardMemberGroups (
	groupId      INT NOT NULL,                       -- Group id
	boardId      INT NOT NULL,                       -- Board id
	PRIMARY KEY (groupId, boardId)
) TABLEOPT;

CREATE TABLE boardAdminGroups (
	groupId      INT NOT NULL,                       -- Group id
	boardId      INT NOT NULL,                       -- Board id
	PRIMARY KEY (groupId, boardId)
) TABLEOPT;

CREATE TABLE boardHiddenFlags (
	userId       INT NOT NULL,                       -- User id
	boardId      INT NOT NULL,                       -- Board id
	manual       TINYINT NOT NULL DEFAULT 0,         -- Man. added, no remove during categ toggle
	PRIMARY KEY (userId, boardId)
) TABLEOPT;

CREATE TABLE boardSubscriptions (
	userId       INT NOT NULL,                       -- User id
	boardId      INT NOT NULL,                       -- Board id
	instant      TINYINT NOT NULL DEFAULT 0,         -- Digest or instant
	unsubAuth    VARCHAR(22) NOT NULL DEFAULT '',    -- Direct unsubscribe code
	PRIMARY KEY (userId, boardId)
) TABLEOPT;

CREATE TABLE topics (
	id           INT PRIMARY KEY AUTO_INCREMENT,
	subject      TEXT NOT NULL,                      -- Subject text
	tag          VARCHAR(20) NOT NULL DEFAULT '',    -- Tag key
	boardId      INT NOT NULL,                       -- Parent board id
	basePostId   INT NOT NULL DEFAULT 0,             -- First post id
	pollId       INT NOT NULL DEFAULT 0,             -- Poll id
	locked       TINYINT NOT NULL DEFAULT 0,         -- No new posts allowed?
	sticky       TINYINT NOT NULL DEFAULT 0,         -- Put at top of topic list?
	postNum      INT NOT NULL DEFAULT 0,             -- Number of posts (cached)
	lastPostTime INT NOT NULL DEFAULT 0              -- Time of latest post (cached)
) TABLEOPT;
CREATE INDEX topics_lastPostTime ON topics (lastPostTime);

CREATE TABLE topicReadTimes (
	userId       INT NOT NULL,                       -- User id
	topicId      INT NOT NULL,                       -- Topic id
	lastReadTime INT NOT NULL,                       -- Timestamp of last visit
	PRIMARY KEY (userId, topicId)
) TABLEOPT;

CREATE TABLE topicSubscriptions (
	userId       INT NOT NULL,                       -- User id
	topicId      INT NOT NULL,                       -- Topic id
	instant      TINYINT NOT NULL DEFAULT 0,         -- Digest or instant
	unsubAuth    VARCHAR(22) NOT NULL DEFAULT '',    -- Direct unsubscribe code
	PRIMARY KEY (userId, topicId)
) TABLEOPT;

CREATE TABLE posts (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Post id
	userId       INT NOT NULL DEFAULT 0,             -- Poster id, -2=xlink, -1=unreg, 0=del
	userNameBak  VARCHAR(60) NOT NULL DEFAULT '',    -- Copy of poster username at post-time
	boardId      INT NOT NULL,                       -- Parent board
	topicId      INT NOT NULL,                       -- Parent topic
	parentId     INT NOT NULL DEFAULT 0,             -- Parent post
	approved     TINYINT NOT NULL DEFAULT 0,         -- Approved by mod or by default?
	locked       TINYINT NOT NULL DEFAULT 0,         -- Locked against edit/reply etc.
	ip           VARCHAR(39) NOT NULL DEFAULT '',    -- IP of user at post-time
	postTime     INT NOT NULL,                       -- Posting timestamp
	editTime     INT NOT NULL DEFAULT 0,             -- Edit timestamp
	body         TEXT NOT NULL,                      -- Post text
	rawBody      TEXT NOT NULL DEFAULT ''            -- Additional raw content like code
) TABLEOPT;
CREATE INDEX posts_userId   ON posts (userId);
CREATE INDEX posts_topicId  ON posts (topicId);
CREATE INDEX posts_postTime ON posts (postTime);

CREATE TABLE postLikes (
	postId       INT NOT NULL,                       -- Liked post id
	userId       INT NOT NULL,                       -- Liking user id
	PRIMARY KEY (postId, userId)
) TABLEOPT;

CREATE TABLE postReports (
	userId       INT NOT NULL,                       -- Reporting user id
	postId       INT NOT NULL,                       -- Reported post id
	reason       TEXT NOT NULL,                      -- Reason for appeal
	PRIMARY KEY (userId, postId)
) TABLEOPT;

CREATE TABLE attachments (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Attachment id
	postId       INT NOT NULL,                       -- Post id
	webImage     TINYINT NOT NULL DEFAULT 0,         -- 0=no, 1=web image, 2=embedded
	fileName     VARCHAR(255) NOT NULL,              -- Filename
	caption      VARCHAR(255) NOT NULL DEFAULT ''    -- Description
) TABLEOPT;
CREATE INDEX attachments_postId ON attachments (postId);

CREATE TABLE log (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Line id
	level        TINYINT NOT NULL,                   -- Log level
	entity       VARCHAR(6) NOT NULL,                -- Entity name
	action       VARCHAR(8) NOT NULL,                -- Action name
	userId       INT NOT NULL DEFAULT 0,             -- Executive user id
	boardId      INT NOT NULL DEFAULT 0,             -- Board id
	topicId      INT NOT NULL DEFAULT 0,             -- Topic id
	postId       INT NOT NULL DEFAULT 0,             -- Post id
	extraId      INT NOT NULL DEFAULT 0,             -- Action-dependent (usually target id)
	logTime      INT NOT NULL,                       -- Logging timestamp
	ip           VARCHAR(39) NOT NULL DEFAULT '',    -- IP
	string       TEXT NOT NULL DEFAULT ''            -- Additional info
) TABLEOPT;

CREATE TABLE polls (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Poll id
	title        TEXT NOT NULL,                      -- Poll title/question
	locked       TINYINT NOT NULL DEFAULT 0,         -- Poll ended and votes consolidated?
	multi        TINYINT NOT NULL DEFAULT 0          -- Allow one vote per option?
) TABLEOPT;

CREATE TABLE pollOptions (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Poll option id
	pollId       INT NOT NULL,                       -- Poll id
	title        TEXT NOT NULL,                      -- Option title
	votes        INT NOT NULL DEFAULT 0              -- Sum of votes when poll locked
) TABLEOPT;
CREATE INDEX pollOptions_pollId ON pollOptions (pollId);

CREATE TABLE pollVotes (
	pollId       INT NOT NULL,                       -- Poll id
	userId       INT NOT NULL,                       -- Voter id
	optionId     INT NOT NULL,                       -- Poll option id
	PRIMARY KEY (pollId, userId, optionId)
) TABLEOPT;

CREATE TABLE messages (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Message id
	senderId     INT NOT NULL,                       -- Sender id
	receiverId   INT NOT NULL,                       -- Recipient id
	sendTime     INT NOT NULL,                       -- Posting timestamp
	hasRead      TINYINT NOT NULL DEFAULT 0,         -- Did user read message?
	inbox        TINYINT NOT NULL DEFAULT 0,         -- Is in inbox?
	sentbox      TINYINT NOT NULL DEFAULT 0,         -- Is in sentbox?
	subject      TEXT NOT NULL,                      -- Message subject
	body         TEXT NOT NULL                       -- Message text
) TABLEOPT;
CREATE INDEX messages_senderId ON messages (senderId);
CREATE INDEX messages_receiverId ON messages (receiverId);

CREATE TABLE notes (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Notification id
	userId       INT NOT NULL,                       -- Recipient id
	sendTime     INT NOT NULL,                       -- Sending timestamp
	type         VARCHAR(6) NOT NULL DEFAULT '',     -- Type
	body         TEXT NOT NULL                       -- Message text
) TABLEOPT;
CREATE INDEX notes_userId ON notes (userId);

CREATE TABLE chat (
	id           INT PRIMARY KEY AUTO_INCREMENT,     -- Entry id
	userId       INT NOT NULL,                       -- Poster id
	postTime     INT NOT NULL,                       -- Timestamp
	body         TEXT NOT NULL                       -- Chat text
) TABLEOPT;

CREATE TABLE tickets (
	id           VARCHAR(22) PRIMARY KEY,            -- Ticket id
	userId       INT NOT NULL,                       -- User id
	issueTime    INT NOT NULL,                       -- Creation timestamp
	type         VARCHAR(6) NOT NULL,                -- Type
	data         VARCHAR(255) NOT NULL DEFAULT ''    -- Type-dependent data
) TABLEOPT;

CREATE TABLE watchWords (
	userId       INT NOT NULL,                       -- Watcher id
	word         VARCHAR(30) NOT NULL                -- Word to look for
) TABLEOPT;

CREATE TABLE watchUsers (
	userId       INT NOT NULL,                       -- Watcher id
	watchedId    INT NOT NULL                        -- Watched user id
) TABLEOPT;
CREATE INDEX watchUsers_watchedId ON watchUsers (watchedId);

CREATE TABLE variables (
	name         VARCHAR(10) PRIMARY KEY,            -- Variable name
	value        TEXT NOT NULL DEFAULT ''            -- Value
) TABLEOPT;

INSERT INTO variables (name, value) VALUES ('version', '2.29.1');
";

my $arcSql = "";
if ($m->{mysql}) {
	$arcSql = "
		CREATE TABLE ${pfx}arc_boards LIKE ${pfx}boards;
		CREATE TABLE ${pfx}arc_topics LIKE ${pfx}topics;
		CREATE TABLE ${pfx}arc_posts  LIKE ${pfx}posts;
	";
}
elsif ($m->{pgsql}) {
	my ($version) = $m->fetchArray("SELECT VERSION()") =~ /PostgreSQL (\d+\.\d+)/;
	my $indexes = $version >= 8.3 ? "INCLUDING INDEXES" : "";
	$arcSql = "
		CREATE TABLE ${pfx}arc_boards (LIKE ${pfx}boards $indexes INCLUDING DEFAULTS);
		CREATE TABLE ${pfx}arc_topics (LIKE ${pfx}topics $indexes INCLUDING DEFAULTS);
		CREATE TABLE ${pfx}arc_posts  (LIKE ${pfx}posts  $indexes INCLUDING DEFAULTS);
	";
}

#------------------------------------------------------------------------------

# Add prefix to table names
$sql =~ s! TABLE ! TABLE ${pfx}!g;
$sql =~ s! LIKE ! LIKE ${pfx}!g;
$sql =~ s! ON ! ON ${pfx}!g;
$sql =~ s! INTO ! INTO ${pfx}!g;

# Make SQL compatible with chosen DBMS
if ($m->{mysql}) {
	my $tableOpt = $cfg->{dbTableOpt} || "CHARSET=utf8";
	$sql =~ s! TABLEOPT! $tableOpt!g;
	$sql =~ s! TEXT ! MEDIUMTEXT !g;
}
elsif ($m->{pgsql}) {
	$citext ||= $cfg->{dbCitext};
	$sql =~ s! TABLEOPT! $cfg->{dbTableOpt}!g;
	$sql =~ s! INT PRIMARY KEY AUTO_INCREMENT! SERIAL PRIMARY KEY!g;
	$sql =~ s! TINYINT! SMALLINT!g;
	$sql =~ s! VARCHAR\((\d+)\)| TEXT! citext!g if $citext && $1 != 22;
}
elsif ($m->{sqlite}) {
	$sql =~ s! TABLEOPT! $cfg->{dbTableOpt}!g;
	$sql =~ s! PRIMARY KEY AUTO_INCREMENT! NOT NULL PRIMARY KEY AUTOINCREMENT!g;
	$sql =~ s! INT ! INTEGER !g;
	$sql =~ s! VARCHAR\(\d+\)| TEXT! TEXT COLLATE mwforum!g if $cfg->{sqliteCollate};
	$sql =~ s!\s+-- .+!!g;
	$sql = "PRAGMA encoding = 'utf-8';\n" . $sql;	
}

# Execute separate queries
for (grep(/\w/, split(";", $sql))) { 
	$dbh->do($_) or print "$DBI::errstr ($_)";
}
if ($m->{mysql} || $m->{pgsql}) {
	for (grep(/\w/, split(";", $arcSql))) { 
		$dbh->do($_) or print "$DBI::errstr ($_)";
	}
}

print "mwForum installation done.\n";

#------------------------------------------------------------------------------
