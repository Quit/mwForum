-------------------------------------------------------------------------------
--    mwForum - Web-based discussion forum
--    Copyright (c) 1999-2015 Markus Wichitill
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

-- Rename tables to original case if lost under MySQL (Windows, InnoDB)
ALTER TABLE boardadmingroups RENAME TO tmp_boardAdminGroups;
ALTER TABLE boardhiddenflags RENAME TO tmp_boardHiddenFlags;
ALTER TABLE boardmembergroups RENAME TO tmp_boardMemberGroups;
ALTER TABLE boardsubscriptions RENAME TO tmp_boardSubscriptions;
ALTER TABLE groupadmins RENAME TO tmp_groupAdmins;
ALTER TABLE groupmembers RENAME TO tmp_groupMembers;
ALTER TABLE polloptions RENAME TO tmp_pollOptions;
ALTER TABLE pollvotes RENAME TO tmp_pollVotes;
ALTER TABLE postlikes RENAME TO tmp_postLikes;
ALTER TABLE postreports RENAME TO tmp_postReports;
ALTER TABLE topicreadtimes RENAME TO tmp_topicReadTimes;
ALTER TABLE topicsubscriptions RENAME TO tmp_topicSubscriptions;
ALTER TABLE userbadges RENAME TO tmp_userBadges;
ALTER TABLE userbans RENAME TO tmp_userBans;
ALTER TABLE userignores RENAME TO tmp_userIgnores;
ALTER TABLE uservariables RENAME TO tmp_userVariables;
ALTER TABLE watchusers RENAME TO tmp_watchUsers;
ALTER TABLE watchwords RENAME TO tmp_watchWords;

ALTER TABLE tmp_boardAdminGroups RENAME TO boardAdminGroups;
ALTER TABLE tmp_boardHiddenFlags RENAME TO boardHiddenFlags;
ALTER TABLE tmp_boardMemberGroups RENAME TO boardMemberGroups;
ALTER TABLE tmp_boardSubscriptions RENAME TO boardSubscriptions;
ALTER TABLE tmp_groupAdmins RENAME TO groupAdmins;
ALTER TABLE tmp_groupMembers RENAME TO groupMembers;
ALTER TABLE tmp_pollOptions RENAME TO pollOptions;
ALTER TABLE tmp_pollVotes RENAME TO pollVotes;
ALTER TABLE tmp_postLikes RENAME TO postLikes;
ALTER TABLE tmp_postReports RENAME TO postReports;
ALTER TABLE tmp_topicReadTimes RENAME TO topicReadTimes;
ALTER TABLE tmp_topicSubscriptions RENAME TO topicSubscriptions;
ALTER TABLE tmp_userBadges RENAME TO userBadges;
ALTER TABLE tmp_userBans RENAME TO userBans;
ALTER TABLE tmp_userIgnores RENAME TO userIgnores;
ALTER TABLE tmp_userVariables RENAME TO userVariables;
ALTER TABLE tmp_watchUsers RENAME TO watchUsers;
ALTER TABLE tmp_watchWords RENAME TO watchWords;
