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

-- MySQL: make text fields accept > 64k
ALTER TABLE arc_boards MODIFY longDesc MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE arc_posts MODIFY body MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE arc_topics MODIFY subject MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE boards MODIFY longDesc MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE chat MODIFY body MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE messages MODIFY body MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE messages MODIFY subject MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE notes MODIFY body MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE pollOptions MODIFY title MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE polls MODIFY title MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE postReports MODIFY reason MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE posts MODIFY body MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE topics MODIFY subject MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE userBans MODIFY intReason MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE userBans MODIFY reason MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE users MODIFY blurb MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE users MODIFY comment MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE users MODIFY extra1 MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE users MODIFY extra2 MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE users MODIFY extra3 MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE users MODIFY oldNames MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE users MODIFY signature MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE users MODIFY title MEDIUMTEXT NOT NULL DEFAULT '';
ALTER TABLE users MODIFY userName MEDIUMTEXT NOT NULL DEFAULT '';
