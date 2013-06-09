#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright © 1999-2013 Markus Wichitill
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

package MwfPlgMsgDisplay;
use utf8;
use strict;
use warnings;
no warnings qw(uninitialized redefine);
our $VERSION = "2.29.1";

#------------------------------------------------------------------------------
# Replace text with image smileys

sub smileys
{
	my %params = @_;
	my $m = $params{m};
	my $board = $params{board};
	my $post = $params{post};

	# Replace smileys
	if ($m->{user}{showDeco}) {
		my $text = \$post->{body};
		$$text =~ s~(?<!\w):-?\)~<img class='sml' src='/foo/bar' alt=':-)'>~g;
		$$text =~ s~(?<!\w);-?\)~<img class='sml' src='/foo/bar' alt=';-)'>~g;
		$$text =~ s~(?<!\w):-?\(~<img class='sml' src='/foo/bar' alt=':-('>~g;
		$$text =~ s~(?<!\w):-?[pP]~<img class='sml' src='/foo/bar' alt=':-p'>~g;
		$$text =~ s~(?<!\w):-?[oO]~<img class='sml' src='/foo/bar' alt=':-o'>~g;
		$$text =~ s~(?<!\w):-?D~<img class='sml' src='/foo/bar' alt=':-D'>~g;
	}

	return 0;
}

#------------------------------------------------------------------------------
# Embed attached audio files

sub audio
{
	my %params = @_;
	my $m = $params{m};
	my $board = $params{board};
	my $post = $params{post};

	# Shortcuts
	my $cfg = $m->{cfg};
	my $lng = $m->{lng};
	my $text = \$post->{body};
	my $attachments = $post->{attachments};
	
	# Set translated strings
	if (!exists($lng->{audioTagUnsup})) {
		if ($m->{lngModule} eq 'MwfGerman') {
			$lng->{audioTagUnsup} = "Ihr Browser unterstützt das Audio-Element nicht.";
		}
		else {
			$lng->{audioTagUnsup} = "Your browser doesn't support the audio element.";
		}
	}
	
	# Embed attached wav and ogg audio
	if ($attachments && @$attachments) {
		for my $attach (@$attachments) {
			if ($attach->{fileName} =~ /\.(?:ogg|aac|mp3|wav)\z/i) {
				my $postIdMod = $attach->{postId} % 100;
				my $url = "$cfg->{attachUrlPath}/$postIdMod/$attach->{postId}/$attach->{fileName}";
				$$text .= "\n<br><br>\n"
					. "<audio src='$url' title='$attach->{fileName}' controls>"
					. "<p>$lng->{audioTagUnsup}</p></audio>";
				$attach->{drop} = 1;
			}
		}
		@$attachments = grep(!$_->{drop}, @$attachments);
	}

	return 0;
}

#------------------------------------------------------------------------------
1;
