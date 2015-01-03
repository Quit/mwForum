#!/usr/bin/perl
#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright (c) 1999-2015 Markus Wichitill
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

# Check if access should be denied
$cfg->{polls} or $m->error('errNoAccess');
$userId or $m->error('errNoAccess');

# Get CGI parameters
my $optionId = $m->paramInt('option');
my $topicId = $m->paramInt('tid');

# Check request source authentication
$m->checkSourceAuth() or $m->error('errSrcAuth');

# Get topic
my ($boardId, $pollId, $locked) = $m->fetchArray("
	SELECT boardId, pollId, locked FROM topics WHERE id = ?", $topicId);
$boardId or $m->error('errTpcNotFnd');

# Get board
my $board = $m->fetchHash("
	SELECT * FROM boards WHERE id = ?", $boardId);
$board or $m->error('errBrdNotFnd');

# Check if user can see and write to board
my $boardAdmin = $user->{admin} || $m->boardAdmin($userId, $board->{id});
$boardAdmin || $m->boardVisible($board) or $m->error('errNoAccess');
$boardAdmin || $m->boardWritable($board, 1) or $m->error('errNoAccess');

# Get poll
my $poll = $m->fetchHash("
	SELECT locked, multi FROM polls WHERE id = ?", $pollId);
$poll or $m->error('errPolNotFnd');

# Check if topic or poll is locked
!$locked or $m->error('errTpcLocked');
!$poll->{locked} or $m->error('errPolLocked');

# Multi-vote polls
if ($poll->{multi}) {
	# Get options
	my $options = $m->fetchAllArray("
		SELECT id FROM pollOptions WHERE pollId = ?", $pollId);
	
	for my $option (@$options) {
		# Check if user has voted for this option
		if ($m->paramBool("option_$option->[0]")) {
			# Check if user has already voted for this option before
			my $votedThis = $m->fetchArray("
				SELECT 1 
				FROM pollVotes 
				WHERE pollId = :pollId 
					AND userId = :userId
					AND optionId = :optionId",
				{ pollId => $pollId, userId => $userId, optionId => $option->[0] });

			# Insert vote if it's not a dupe
			if (!$votedThis) {
				$m->dbDo("
					INSERT INTO pollVotes (pollId, userId, optionId) VALUES (?, ?, ?)",
					$pollId, $userId, $option->[0]);
			}
		}
	}
}
# Single-vote polls
else {
	# Check if an option has been selected
	$optionId or $m->error('errPolNoOpt');

	# Check if option exists, and is part of this poll
	$m->fetchArray("
		SELECT id FROM pollOptions WHERE id = ? AND pollId = ?", $optionId, $pollId) 
		or $m->error('errPolOpNFnd');
	
	# Check if user has already voted
	!$m->fetchArray("
		SELECT 1 FROM pollVotes WHERE pollId = ? AND userId = ?", $pollId, $userId)
		or $m->error('errPolVotedP');
	
	# Insert vote
	$m->dbDo("
		INSERT INTO pollVotes (pollId, userId, optionId) VALUES (?, ?, ?)",
		$pollId, $userId, $optionId);
	
	# Double check votes to make sure no parallel thread inserted votes in single-vote polls
	# The PKey (pollId, userId, optionId) takes care of multi-vote polls
	my $votes = $m->fetchArray("
		SELECT COUNT(*)
		FROM pollVotes
		WHERE pollId = :pollId
			AND userId = :userId
			AND optionId = :optionId",
		{ pollId => $pollId, userId => $userId, optionId => $optionId });
	
	# Delete all votes if poll got more than one vote
	if ($votes > 1) {
		$m->dbDo("
			DELETE FROM pollVotes WHERE pollId = ? AND userId = ?", $pollId, $userId);
		$m->error('errPolVotedP');
	}
}

# Log action and finish
$m->logAction(1, 'poll', 'vote', $userId, $boardId, $topicId, undef, $pollId);
$m->redirect('topic_show', tid => $topicId, msg => 'PollVote');
