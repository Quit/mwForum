-------------------------------------------------------------------------------
--    mwForum - Web-based discussion forum
--    Copyright (c) 1999-2014 Markus Wichitill
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

-- Find orphaned boards/topics/posts

SELECT boards.id FROM boards
LEFT JOIN categories ON categories.id = boards.categoryId
WHERE categories.id IS NULL;

SELECT topics.id FROM topics
LEFT JOIN boards ON boards.id = topics.boardId
LEFT JOIN posts ON posts.id = topics.basePostId
WHERE boards.id IS NULL OR posts.id IS NULL;

SELECT posts.id FROM posts
LEFT JOIN boards ON boards.id = posts.boardId
LEFT JOIN topics ON topics.id = posts.topicId
WHERE boards.id IS NULL OR topics.id IS NULL;

SELECT posts.id FROM posts
LEFT JOIN users ON users.id = posts.userId
WHERE users.id IS NULL
  AND posts.userId > 0;

SELECT posts.id FROM posts
LEFT JOIN posts AS parents ON parents.id = posts.parentId
WHERE parents.id IS NULL
  AND posts.parentId <> 0;

-- Find less important orphaned rows and dangling references

SELECT userVariables.userId, userVariables.name FROM userVariables
LEFT JOIN users ON users.id = userVariables.userId
WHERE users.id IS NULL;

SELECT userBadges.userId, userBadges.badge FROM userBadges
LEFT JOIN users ON users.id = userBadges.userId
WHERE users.id IS NULL;

SELECT userBans.userId FROM userBans
LEFT JOIN users ON users.id = userBans.userId
WHERE users.id IS NULL;

SELECT userIgnores.userId, userIgnores.ignoredId FROM userIgnores
LEFT JOIN users AS ignorers ON ignorers.id = userIgnores.userId
LEFT JOIN users AS ignored ON ignored.id = userIgnores.ignoredId
WHERE ignorers.id IS NULL OR ignored.id IS NULL;

SELECT groupMembers.userId, groupMembers.groupId FROM groupMembers
LEFT JOIN users ON users.id = groupMembers.userId
LEFT JOIN groups ON groups.id = groupMembers.groupId
WHERE users.id IS NULL OR groups.id IS NULL;

SELECT groupAdmins.userId, groupAdmins.groupId FROM groupAdmins
LEFT JOIN users ON users.id = groupAdmins.userId
LEFT JOIN groups ON groups.id = groupAdmins.groupId
WHERE users.id IS NULL OR groups.id IS NULL;

SELECT boardMemberGroups.groupId, boardMemberGroups.boardId FROM boardMemberGroups
LEFT JOIN groups ON groups.id = boardMemberGroups.groupId
LEFT JOIN boards ON boards.id = boardMemberGroups.boardId
WHERE groups.id IS NULL OR boards.id IS NULL;

SELECT boardAdminGroups.groupId, boardAdminGroups.boardId FROM boardAdminGroups
LEFT JOIN groups ON groups.id = boardAdminGroups.groupId
LEFT JOIN boards ON boards.id = boardAdminGroups.boardId
WHERE groups.id IS NULL OR boards.id IS NULL;

SELECT boardHiddenFlags.userId, boardHiddenFlags.boardId FROM boardHiddenFlags
LEFT JOIN users ON users.id = boardHiddenFlags.userId
LEFT JOIN boards ON boards.id = boardHiddenFlags.boardId
WHERE users.id IS NULL OR boards.id IS NULL;

SELECT boardSubscriptions.userId, boardSubscriptions.boardId FROM boardSubscriptions
LEFT JOIN users ON users.id = boardSubscriptions.userId
LEFT JOIN boards ON boards.id = boardSubscriptions.boardId
WHERE users.id IS NULL OR boards.id IS NULL;

SELECT topicSubscriptions.userId, topicSubscriptions.topicId FROM topicSubscriptions
LEFT JOIN users ON users.id = topicSubscriptions.userId
LEFT JOIN topics ON topics.id = topicSubscriptions.topicId
WHERE users.id IS NULL OR topics.id IS NULL;

SELECT postReports.userId, postReports.postId FROM postReports
LEFT JOIN users ON users.id = postReports.userId
LEFT JOIN posts ON posts.id = postReports.postId
WHERE users.id IS NULL OR posts.id IS NULL;

SELECT attachments.id FROM attachments
LEFT JOIN posts ON posts.id = attachments.postId
WHERE posts.id IS NULL;

SELECT polls.id FROM polls
LEFT JOIN topics ON topics.pollId = polls.id
WHERE topics.id IS NULL;

SELECT topics.id FROM topics
LEFT JOIN polls ON polls.id = topics.pollId
WHERE polls.id IS NULL
  AND topics.pollId <> 0;

SELECT pollOptions.id FROM pollOptions
LEFT JOIN polls ON polls.id = pollOptions.pollId
WHERE polls.id IS NULL;

SELECT pollVotes.pollId, pollVotes.userId, pollVotes.optionId FROM pollVotes
LEFT JOIN polls ON polls.id = pollVotes.pollId
LEFT JOIN users ON users.id = pollVotes.userId
LEFT JOIN pollOptions ON pollOptions.id = pollVotes.optionId
WHERE polls.id IS NULL OR users.id IS NULL OR pollOptions.id IS NULL;

SELECT messages.id FROM messages
LEFT JOIN users AS senders ON senders.id = messages.senderId
LEFT JOIN users AS receivers ON receivers.id = messages.receiverId
WHERE senders.id IS NULL OR receivers.id IS NULL;

SELECT notes.userId FROM notes
LEFT JOIN users ON users.id = notes.userId
WHERE users.id IS NULL;

SELECT chat.userId FROM chat
LEFT JOIN users ON users.id = chat.userId
WHERE users.id IS NULL;

SELECT watchWords.userId FROM watchWords
LEFT JOIN users ON users.id = watchWords.userId
WHERE users.id IS NULL;

SELECT watchUsers.userId FROM watchUsers
LEFT JOIN users AS watchers ON watchers.id = watchUsers.userId
LEFT JOIN users AS watched ON watched.id = watchUsers.watchedId
WHERE watchers.id IS NULL OR watched.id IS NULL;
