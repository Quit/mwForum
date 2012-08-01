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

-- MySQL: convert tables to different engine
ALTER TABLE arc_boards ENGINE = XXXX;
ALTER TABLE arc_topics ENGINE = XXXX;
ALTER TABLE arc_posts ENGINE = XXXX;
ALTER TABLE attachments ENGINE = XXXX;
ALTER TABLE boardAdminGroups ENGINE = XXXX;
ALTER TABLE boardHiddenFlags ENGINE = XXXX;
ALTER TABLE boardMemberGroups ENGINE = XXXX;
ALTER TABLE boards ENGINE = XXXX;
ALTER TABLE boardSubscriptions ENGINE = XXXX;
ALTER TABLE categories ENGINE = XXXX;
ALTER TABLE chat ENGINE = XXXX;
ALTER TABLE config ENGINE = XXXX;
ALTER TABLE groupAdmins ENGINE = XXXX;
ALTER TABLE groupMembers ENGINE = XXXX;
ALTER TABLE groups ENGINE = XXXX;
ALTER TABLE log ENGINE = XXXX;
ALTER TABLE messages ENGINE = XXXX;
ALTER TABLE notes ENGINE = XXXX;
ALTER TABLE pollOptions ENGINE = XXXX;
ALTER TABLE polls ENGINE = XXXX;
ALTER TABLE pollVotes ENGINE = XXXX;
ALTER TABLE postReports ENGINE = XXXX;
ALTER TABLE posts ENGINE = XXXX;
ALTER TABLE tickets ENGINE = XXXX;
ALTER TABLE topicReadTimes ENGINE = XXXX;
ALTER TABLE topics ENGINE = XXXX;
ALTER TABLE topicSubscriptions ENGINE = XXXX;
ALTER TABLE userBadges ENGINE = XXXX;
ALTER TABLE userBans ENGINE = XXXX;
ALTER TABLE userIgnores ENGINE = XXXX;
ALTER TABLE users ENGINE = XXXX;
ALTER TABLE userVariables ENGINE = XXXX;
ALTER TABLE variables ENGINE = XXXX;
ALTER TABLE watchUsers ENGINE = XXXX;
ALTER TABLE watchWords ENGINE = XXXX;
