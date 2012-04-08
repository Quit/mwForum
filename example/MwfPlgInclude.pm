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

package MwfPlgInclude;
use strict;
use warnings;
no warnings qw(uninitialized redefine once);
our $VERSION = "2.19.3";

#------------------------------------------------------------------------------
# Print additional HTTP header lines

sub httpHeader
{
	my %params = @_;
	my $m = $params{m};

	if ($MwfMain::MP) {
		$m->{ap}->headers_out->{'X-Foo'} = 'bar';
	}
	else {
		print	"X-Foo: bar\n";
	}
}

#------------------------------------------------------------------------------
# Print additional HTML header lines

sub htmlHeader
{
	my %params = @_;
	my $m = $params{m};

	print
		"<link rel='shortcut icon' href='/favicon.ico' type='image/x-icon'/>\n";
}

#------------------------------------------------------------------------------
# Print stuff at the top of the page

sub top
{
	my %params = @_;
	my $m = $params{m};

	# Print static text
	print	"<img src='/ads/annoying-ad.png' alt='Buy stuff'/>\n";
}

#------------------------------------------------------------------------------
# Print stuff below the forum's top bar

sub middle
{
	my %params = @_;
	my $m = $params{m};

	# Only on forum page
	if ($m->{env}{script} eq 'forum_show') {
		# Load text from a file
		open my $fh, "/etc/motd";
		while (<$fh>) {	print }
		close $fh;
	}
}

#------------------------------------------------------------------------------
# Print stuff at the bottom of the page

sub bottom
{
	my %params = @_;
	my $m = $params{m};

	# Load text from database
	my $adtext = $m->fetchArray("SELECT adtext FROM ads WHERE foo = bar");
	print	$adtext;
}

#-----------------------------------------------------------------------------
# Print button link for all users on the forum page

sub forumUserLink
{
	my %params = @_;
	my $m = $params{m};
	my $links = $params{links};

	push @$links, { url => $m->url('poll_list'), txt => "Polls", ico => 'poll' };
}

#-----------------------------------------------------------------------------
# Print button link for admins/mods on topic pages

sub topicAdminLink
{
	my %params = @_;
	my $m = $params{m};
	my $links = $params{links};
	my $board = $params{board};
	my $topic = $params{topic};

	push @$links, { url => $m->url('topic_nuke'), txt => "Nuke", ico => 'orbit' }
		if $topic->{signal} / $topic->{noise} < 1;
}

#-----------------------------------------------------------------------------
# Print button link for a post on the topic page
# Works a bit differently than the other button link include interfaces.

sub postLink
{
	my %params = @_;
	my $m = $params{m};
	my $lines = $params{lines};
	my $board = $params{board};
	my $topic = $params{topic};
	my $post = $params{post};
	my $boardAdmin = $params{boardAdmin};
	my $topicAdmin = $params{topicAdmin};

	# Only for post owner
	push @$lines, $m->buttonLink($m->url('post_foo', pid => $post->{id}), 'Foo', 'foo')
		if $post->{userId} == $m->{user}{id};

	# Only for moderators
	push @$lines, $m->buttonLink($m->url('post_bar', pid => $post->{id}), 'Bar', 'bar') 
		if $boardAdmin || $topicAdmin;
}

#-----------------------------------------------------------------------------
# Print additional tag insertion buttons on post forms

sub tagButton
{
	my %params = @_;
	my $m = $params{m};
	my $lines = $params{lines};

	# Print YouTube tag insertion button
	push @$lines, 
		"<button type='button' class='tbt' title='YouTube Video ID'",
		" onfocus='document.getElementsByName(\"body\")[0].focus()'",
		" onclick='mwfInsertTags(\"yt\",\"yt\")'>yt</button>\n";
}


#------------------------------------------------------------------------------
# Limit number of requests per IP and timeframe

# Table and index need to be created and maintained manually.
# Also, some kind of cronjob should empty this table daily.
#
#	CREATE TABLE requests (
#		ip         CHAR(15) NOT NULL DEFAULT '',
#		reqNum     INT NOT NULL DEFAULT 0,
#		startTime  INT NOT NULL DEFAULT 0
#	) CHARSET = ascii;
#
#	CREATE INDEX requests_ip ON requests (ip);	

sub early
{
	my %params = @_;
	my $m = $params{m};

	# Skip for admins	
	return if $m->{user}{admin};

	# Shortcuts	
	my $cfg = $m->{cfg};
	my $max = $cfg->{limitReqMax} || 30;
	my $hours = $cfg->{limitReqHrs} || 1;
	my $ip = $m->{env}{userIp};

	# Get entry
	my ($reqNum, $startTime) = $m->fetchArray("
		SELECT reqNum, startTime FROM requests WHERE ip = ?", $ip);

	if (!$reqNum) {
		# Add new entry
		$m->dbDo("
			INSERT INTO requests (ip, reqNum, startTime) VALUES (?, ?, ?)", $ip, 1, $m->{now});
	}
	elsif ($m->{now} - $startTime > $hours * 3600) {
		# Reset timed-out entry
		$m->dbDo("
			UPDATE requests SET reqNum = 1, startTime = ? WHERE ip = ?", $m->{now}, $ip);
	}
	elsif ($reqNum <= $max) {
		# Inc existing entry
		$m->dbDo("
			UPDATE requests SET reqNum = reqNum + 1 WHERE ip = ?", $ip);
	}
	else {
		# Throw exception to signal forum that it should end the request
		die MwfMain::PluginError->new("Reached max. number of $max forum requests in $hours hour(s).");
	}
}

#-----------------------------------------------------------------------------
1;
