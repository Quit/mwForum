-------------------------------------------------------------------------------
--    mwForum - Web-based discussion forum
--    Copyright (c) 1999-2012 Markus Wichitill
--
--    This program is free software; you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation; either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
-------------------------------------------------------------------------------

-- Rename tables to prefixed names
ALTER TABLE arc_boards RENAME TO mwf_arc_boards;
ALTER TABLE arc_topics RENAME TO mwf_arc_topics;
ALTER TABLE arc_posts RENAME TO mwf_arc_posts;
ALTER TABLE attachments RENAME TO mwf_attachments;
ALTER TABLE boardAdminGroups RENAME TO mwf_boardAdminGroups;
ALTER TABLE boardHiddenFlags RENAME TO mwf_boardHiddenFlags;
ALTER TABLE boardMemberGroups RENAME TO mwf_boardMemberGroups;
ALTER TABLE boards RENAME TO mwf_boards;
ALTER TABLE boardSubscriptions RENAME TO mwf_boardSubscriptions;
ALTER TABLE categories RENAME TO mwf_categories;
ALTER TABLE chat RENAME TO mwf_chat;
ALTER TABLE config RENAME TO mwf_config;
ALTER TABLE groupAdmins RENAME TO mwf_groupAdmins;
ALTER TABLE groupMembers RENAME TO mwf_groupMembers;
ALTER TABLE groups RENAME TO mwf_groups;
ALTER TABLE log RENAME TO mwf_log;
ALTER TABLE messages RENAME TO mwf_messages;
ALTER TABLE notes RENAME TO mwf_notes;
ALTER TABLE pollOptions RENAME TO mwf_pollOptions;
ALTER TABLE polls RENAME TO mwf_polls;
ALTER TABLE pollVotes RENAME TO mwf_pollVotes;
ALTER TABLE postLikes RENAME TO mwf_postLikes;
ALTER TABLE postReports RENAME TO mwf_postReports;
ALTER TABLE posts RENAME TO mwf_posts;
ALTER TABLE tickets RENAME TO mwf_tickets;
ALTER TABLE topicReadTimes RENAME TO mwf_topicReadTimes;
ALTER TABLE topics RENAME TO mwf_topics;
ALTER TABLE topicSubscriptions RENAME TO mwf_topicSubscriptions;
ALTER TABLE userBadges RENAME TO mwf_userBadges;
ALTER TABLE userBans RENAME TO mwf_userBans;
ALTER TABLE userIgnores RENAME TO mwf_userIgnores;
ALTER TABLE users RENAME TO mwf_users;
ALTER TABLE userVariables RENAME TO mwf_userVariables;
ALTER TABLE variables RENAME TO mwf_variables;
ALTER TABLE watchUsers RENAME TO mwf_watchUsers;
ALTER TABLE watchWords RENAME TO mwf_watchWords;

-- Rename tables to unprefixed names
ALTER TABLE mwf_arc_boards RENAME TO arc_boards;
ALTER TABLE mwf_arc_topics RENAME TO arc_topics;
ALTER TABLE mwf_arc_posts RENAME TO arc_posts;
ALTER TABLE mwf_attachments RENAME TO attachments;
ALTER TABLE mwf_boardAdminGroups RENAME TO boardAdminGroups;
ALTER TABLE mwf_boardHiddenFlags RENAME TO boardHiddenFlags;
ALTER TABLE mwf_boardMemberGroups RENAME TO boardMemberGroups;
ALTER TABLE mwf_boards RENAME TO boards;
ALTER TABLE mwf_boardSubscriptions RENAME TO boardSubscriptions;
ALTER TABLE mwf_categories RENAME TO categories;
ALTER TABLE mwf_chat RENAME TO chat;
ALTER TABLE mwf_config RENAME TO config;
ALTER TABLE mwf_groupAdmins RENAME TO groupAdmins;
ALTER TABLE mwf_groupMembers RENAME TO groupMembers;
ALTER TABLE mwf_groups RENAME TO groups;
ALTER TABLE mwf_log RENAME TO log;
ALTER TABLE mwf_messages RENAME TO messages;
ALTER TABLE mwf_notes RENAME TO notes;
ALTER TABLE mwf_pollOptions RENAME TO pollOptions;
ALTER TABLE mwf_polls RENAME TO polls;
ALTER TABLE mwf_pollVotes RENAME TO pollVotes;
ALTER TABLE mwf_postLikes RENAME TO postLikes;
ALTER TABLE mwf_postReports RENAME TO postReports;
ALTER TABLE mwf_posts RENAME TO posts;
ALTER TABLE mwf_tickets RENAME TO tickets;
ALTER TABLE mwf_topicReadTimes RENAME TO topicReadTimes;
ALTER TABLE mwf_topics RENAME TO topics;
ALTER TABLE mwf_topicSubscriptions RENAME TO topicSubscriptions;
ALTER TABLE mwf_userBadges RENAME TO userBadges;
ALTER TABLE mwf_userBans RENAME TO userBans;
ALTER TABLE mwf_userIgnores RENAME TO userIgnores;
ALTER TABLE mwf_users RENAME TO users;
ALTER TABLE mwf_userVariables RENAME TO userVariables;
ALTER TABLE mwf_variables RENAME TO variables;
ALTER TABLE mwf_watchUsers RENAME TO watchUsers;
ALTER TABLE mwf_watchWords RENAME TO watchWords;

-- Move tables to PgSQL schema
ALTER TABLE arc_boards SET SCHEMA mwf;
ALTER TABLE arc_topics SET SCHEMA mwf;
ALTER TABLE arc_posts SET SCHEMA mwf;
ALTER TABLE attachments SET SCHEMA mwf;
ALTER TABLE boardAdminGroups SET SCHEMA mwf;
ALTER TABLE boardHiddenFlags SET SCHEMA mwf;
ALTER TABLE boardMemberGroups SET SCHEMA mwf;
ALTER TABLE boards SET SCHEMA mwf;
ALTER TABLE boardSubscriptions SET SCHEMA mwf;
ALTER TABLE categories SET SCHEMA mwf;
ALTER TABLE chat SET SCHEMA mwf;
ALTER TABLE config SET SCHEMA mwf;
ALTER TABLE groupAdmins SET SCHEMA mwf;
ALTER TABLE groupMembers SET SCHEMA mwf;
ALTER TABLE groups SET SCHEMA mwf;
ALTER TABLE log SET SCHEMA mwf;
ALTER TABLE messages SET SCHEMA mwf;
ALTER TABLE notes SET SCHEMA mwf;
ALTER TABLE pollOptions SET SCHEMA mwf;
ALTER TABLE polls SET SCHEMA mwf;
ALTER TABLE pollVotes SET SCHEMA mwf;
ALTER TABLE postLikes SET SCHEMA mwf;
ALTER TABLE postReports SET SCHEMA mwf;
ALTER TABLE posts SET SCHEMA mwf;
ALTER TABLE tickets SET SCHEMA mwf;
ALTER TABLE topicReadTimes SET SCHEMA mwf;
ALTER TABLE topics SET SCHEMA mwf;
ALTER TABLE topicSubscriptions SET SCHEMA mwf;
ALTER TABLE userBadges SET SCHEMA mwf;
ALTER TABLE userBans SET SCHEMA mwf;
ALTER TABLE userIgnores SET SCHEMA mwf;
ALTER TABLE users SET SCHEMA mwf;
ALTER TABLE userVariables SET SCHEMA mwf;
ALTER TABLE variables SET SCHEMA mwf;
ALTER TABLE watchUsers SET SCHEMA mwf;
ALTER TABLE watchWords SET SCHEMA mwf;
