-------------------------------------------------------------------------------
--    mwForum - Web-based discussion forum
--    Copyright (c) 1999-2013 Markus Wichitill
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

-- Add foreign keys to PgSQL
ALTER TABLE boards ADD CONSTRAINT boards_category_fk FOREIGN KEY (categoryId) REFERENCES categories DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE topics ADD CONSTRAINT topics_board_fk FOREIGN KEY (boardId) REFERENCES boards DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE topics ADD CONSTRAINT topics_post_fk FOREIGN KEY (basePostId) REFERENCES posts DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE posts ADD CONSTRAINT posts_topic_fk FOREIGN KEY (topicId) REFERENCES topics DEFERRABLE INITIALLY DEFERRED;
ALTER TABLE posts ADD CONSTRAINT posts_board_fk FOREIGN KEY (boardId) REFERENCES boards DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE userVariables ADD CONSTRAINT userVariables_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE userBadges ADD CONSTRAINT userBadges_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE userBans ADD CONSTRAINT userBans_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE userIgnores ADD CONSTRAINT userIgnores_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE userIgnores ADD CONSTRAINT userIgnores_ignored_fk FOREIGN KEY (ignoredId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE groupMembers ADD CONSTRAINT groupMembers_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE groupMembers ADD CONSTRAINT groupMembers_group_fk FOREIGN KEY (groupId) REFERENCES groups ON DELETE CASCADE;
ALTER TABLE groupAdmins ADD CONSTRAINT groupAdmins_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE groupAdmins ADD CONSTRAINT groupAdmins_group_fk FOREIGN KEY (groupId) REFERENCES groups ON DELETE CASCADE;
ALTER TABLE boardMemberGroups ADD CONSTRAINT boardMemberGroups_group_fk FOREIGN KEY (groupId) REFERENCES groups ON DELETE CASCADE;
ALTER TABLE boardMemberGroups ADD CONSTRAINT boardMemberGroups_board_fk FOREIGN KEY (boardId) REFERENCES boards ON DELETE CASCADE;
ALTER TABLE boardAdminGroups ADD CONSTRAINT boardAdminGroups_group_fk FOREIGN KEY (groupId) REFERENCES groups ON DELETE CASCADE;
ALTER TABLE boardAdminGroups ADD CONSTRAINT boardAdminGroups_board_fk FOREIGN KEY (boardId) REFERENCES boards ON DELETE CASCADE;
ALTER TABLE boardHiddenFlags ADD CONSTRAINT boardHiddenFlags_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE boardHiddenFlags ADD CONSTRAINT boardHiddenFlags_board_fk FOREIGN KEY (boardId) REFERENCES boards ON DELETE CASCADE;
ALTER TABLE boardSubscriptions ADD CONSTRAINT boardSubscriptions_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE boardSubscriptions ADD CONSTRAINT boardSubscriptions_board_fk FOREIGN KEY (boardId) REFERENCES boards ON DELETE CASCADE;
ALTER TABLE topicSubscriptions ADD CONSTRAINT topicSubscriptions_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE topicSubscriptions ADD CONSTRAINT topicSubscriptions_topic_fk FOREIGN KEY (topicId) REFERENCES topics ON DELETE CASCADE;
ALTER TABLE postLikes ADD CONSTRAINT postLikes_post_fk FOREIGN KEY (postId) REFERENCES posts ON DELETE CASCADE;
ALTER TABLE postLikes ADD CONSTRAINT postLikes_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE postReports ADD CONSTRAINT postReports_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE postReports ADD CONSTRAINT postReports_post_fk FOREIGN KEY (postId) REFERENCES posts ON DELETE CASCADE;
ALTER TABLE attachments ADD CONSTRAINT attachments_post_fk FOREIGN KEY (postId) REFERENCES posts ON DELETE CASCADE;
ALTER TABLE pollOptions ADD CONSTRAINT pollOptions_poll_fk FOREIGN KEY (pollId) REFERENCES polls ON DELETE CASCADE;
ALTER TABLE pollVotes ADD CONSTRAINT pollVotes_poll_fk FOREIGN KEY (pollId) REFERENCES polls ON DELETE CASCADE;
ALTER TABLE pollVotes ADD CONSTRAINT pollVotes_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE pollVotes ADD CONSTRAINT pollVotes_option_fk FOREIGN KEY (optionId) REFERENCES pollOptions ON DELETE CASCADE;
ALTER TABLE messages ADD CONSTRAINT messages_sender_fk FOREIGN KEY (senderId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE messages ADD CONSTRAINT messages_receiver_fk FOREIGN KEY (receiverId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE notes ADD CONSTRAINT notes_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE chat ADD CONSTRAINT chat_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE watchWords ADD CONSTRAINT watchWords_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE watchUsers ADD CONSTRAINT watchUsers_user_fk FOREIGN KEY (userId) REFERENCES users ON DELETE CASCADE;
ALTER TABLE watchUsers ADD CONSTRAINT watchUsers_watched_fk FOREIGN KEY (watchedId) REFERENCES users ON DELETE CASCADE;

-- Drop foreign keys
ALTER TABLE boards DROP CONSTRAINT boards_category_fk;
ALTER TABLE topics DROP CONSTRAINT topics_board_fk;
ALTER TABLE topics DROP CONSTRAINT topics_post_fk;
ALTER TABLE posts DROP CONSTRAINT posts_topic_fk;
ALTER TABLE posts DROP CONSTRAINT posts_board_fk;

ALTER TABLE userVariables DROP CONSTRAINT userVariables_user_fk;
ALTER TABLE userBadges DROP CONSTRAINT userBadges_user_fk;
ALTER TABLE userBans DROP CONSTRAINT userBans_user_fk;
ALTER TABLE userIgnores DROP CONSTRAINT userIgnores_user_fk;
ALTER TABLE userIgnores DROP CONSTRAINT userIgnores_ignored_fk;
ALTER TABLE groupMembers DROP CONSTRAINT groupMembers_user_fk;
ALTER TABLE groupMembers DROP CONSTRAINT groupMembers_group_fk;
ALTER TABLE groupAdmins DROP CONSTRAINT groupAdmins_user_fk;
ALTER TABLE groupAdmins DROP CONSTRAINT groupAdmins_group_fk;
ALTER TABLE boardMemberGroups DROP CONSTRAINT boardMemberGroups_group_fk;
ALTER TABLE boardMemberGroups DROP CONSTRAINT boardMemberGroups_board_fk;
ALTER TABLE boardAdminGroups DROP CONSTRAINT boardAdminGroups_group_fk;
ALTER TABLE boardAdminGroups DROP CONSTRAINT boardAdminGroups_board_fk;
ALTER TABLE boardHiddenFlags DROP CONSTRAINT boardHiddenFlags_user_fk;
ALTER TABLE boardHiddenFlags DROP CONSTRAINT boardHiddenFlags_board_fk;
ALTER TABLE boardSubscriptions DROP CONSTRAINT boardSubscriptions_user_fk;
ALTER TABLE boardSubscriptions DROP CONSTRAINT boardSubscriptions_board_fk;
ALTER TABLE topicSubscriptions DROP CONSTRAINT topicSubscriptions_user_fk;
ALTER TABLE topicSubscriptions DROP CONSTRAINT topicSubscriptions_topic_fk;
ALTER TABLE postLikes DROP CONSTRAINT postLikes_post_fk;
ALTER TABLE postLikes DROP CONSTRAINT postLikes_user_fk;
ALTER TABLE postReports DROP CONSTRAINT postReports_user_fk;
ALTER TABLE postReports DROP CONSTRAINT postReports_post_fk;
ALTER TABLE attachments DROP CONSTRAINT attachments_post_fk;
ALTER TABLE pollOptions DROP CONSTRAINT pollOptions_poll_fk;
ALTER TABLE pollVotes DROP CONSTRAINT pollVotes_poll_fk;
ALTER TABLE pollVotes DROP CONSTRAINT pollVotes_user_fk;
ALTER TABLE pollVotes DROP CONSTRAINT pollVotes_option_fk;
ALTER TABLE messages DROP CONSTRAINT messages_sender_fk;
ALTER TABLE messages DROP CONSTRAINT messages_receiver_fk;
ALTER TABLE notes DROP CONSTRAINT notes_user_fk;
ALTER TABLE chat DROP CONSTRAINT chat_user_fk;
ALTER TABLE watchWords DROP CONSTRAINT watchWords_user_fk;
ALTER TABLE watchUsers DROP CONSTRAINT watchUsers_user_fk;
ALTER TABLE watchUsers DROP CONSTRAINT watchUsers_watched_fk;
