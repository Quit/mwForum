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
no warnings qw(uninitialized redefine);

# Imports
use MwfMain;

#------------------------------------------------------------------------------

# Init
my ($m, $cfg, $lng, $user, $userId) = MwfMain->new($_[0]);

# Check if user is admin
$user->{admin} or $m->error('errNoAccess');

# Check if admin is among admins that may edit configuration
$cfg->{cfgAdmins} =~ /\b$userId\b/ or $m->error('errNoAccess') if $cfg->{cfgAdmins};

# Get CGI parameters
my $submitted = $m->paramBool('subm');

# Process form
if ($submitted) {
	# Check request source authentication
	$m->checkSourceAuth() or $m->formError('errSrcAuth');

	# If there's no error, finish action
	if (!@{$m->{formErrors}}) {
		# Save options
		for my $opt (@$MwfDefaults::options) {
			next if $opt->{section};

			# Get values
			my $name = $opt->{name};
			my $value = $m->paramStr($name);
			$value = "" if !defined($value);
			
			# Normalize values
			if ($opt->{type} eq 'checkbox') { 
				$value = $value ? 1 : 0;
			}
			elsif ($opt->{type} eq 'number') {
				$value = int($value);
			}
			elsif ($opt->{type} eq 'text' || $opt->{type} eq 'textarea') {
				$value =~ s!\r!!g;
				$value =~ s!\t! !g;
			}
			if ($opt->{parse} =~ /^(?:array|arrayhash|hash)\z/) {
				$value =~ s!\n{2,}!\n!g;
			}

			# Save value if different from default
			if ($value ne $cfg->{$name}) {
				$m->dbDo("
					DELETE FROM config WHERE name = ?", $name);
				$m->dbDo("
					INSERT INTO config (name, value, parse) VALUES (?, ?, ?)",
					$name, $value, $opt->{parse} || "");
			}
		}

		# Replace last change time
		$m->dbDo("
			DELETE FROM config WHERE name = ?", 'lastUpdate');
		$m->dbDo("
			INSERT INTO config (name, value) VALUES (?, ?)", 'lastUpdate', $m->{now});

		# Log action and finish
		$m->logAction(1, 'forum', 'options', $userId);
		$m->redirect('forum_options');
	}
}

# Print form
if (!$submitted || @{$m->{formErrors}}) {
	# Print header
	$m->printHeader();

	# Print page bar
	my @navLinks = ({ url => $m->url('forum_show'), txt => 'comUp', ico => 'up' });
	$m->printPageBar(mainTitle => "Forum", navLinks => \@navLinks);

	# Print hints and form errors
	$m->printFormErrors();
	
	# Print form
	print
		"<form class='cfg' action='forum_options$m->{ext}' method='post' spellcheck='false'>\n",
		"<div class='frm'>\n",
		"<div class='hcl'><span class='htt'>Forum Options</span></div>\n",
		"<div class='ccl'>\n\n";

	# Print contents
	print "<ul style='column-count: 3; -moz-column-count: 3; -webkit-column-count: 3'>\n";
	for my $opt (@$MwfDefaults::options) {
		next if !$opt->{section};
		print "<li><a href='#$opt->{id}'>$opt->{section}</a></li>\n";
	}
	print "</ul>\n\n";

	# Print options
	for my $opt (@$MwfDefaults::options) {
		# Shortcuts
		my $name = $opt->{name};
		my $value = $cfg->{$name};

		# Print section title
		if ($opt->{section}) {
			print $m->submitButton("Change", 'admopt'), "\n"
				if $opt->{section} ne "Email Options";
			print "<h3 id='$opt->{id}'>$opt->{section}</h3>\n";
			next;
		}
		next if !$name;
		
		# Print title
		my $defaultEsc = !$opt->{parse} ? "Default: " . $m->escHtml($opt->{default}) : "";
		print "\n<h4>$opt->{title} <dfn title='$defaultEsc'>($name)</dfn></h4>\n";

		# Print help
		print "<p>$opt->{help}</p>\n" if $opt->{help};

		# Print examples
		if ($opt->{example} && $opt->{example}[0]) {
			print
				"<fieldset>\n",
				map("<div>Example: <code>$_</code></div>\n", @{$opt->{example}}),
				"</fieldset>\n";
		}

		# Print input elements
		if ($opt->{type} eq 'text') {
			# Print text input option
			print 
				"<fieldset><input type='text' class='fwi' name='$name' value='", 
				$m->escHtml($value), "'></fieldset>\n";
		}
		elsif ($opt->{type} eq 'number') {
			# Print number input option
			print "<fieldset><input type='number' name='$name' value='",
				int($value), "'></fieldset>\n";
		}
		elsif ($opt->{type} eq 'textarea') {
			# Print textarea options
			if (!$opt->{parse}) {
				# Print simple textarea option
				my $rows = $m->min($m->max(4, $value =~ tr/\n//), 10);
				print 
					"<fieldset><textarea name='$name' rows='$rows'>",
					$m->escHtml($value, 1), 
					"</textarea></fieldset>\n";
			}
			elsif ($opt->{parse} eq 'array') {
				# Print array textarea option
				my $rows = $m->min($m->max(4, scalar @$value), 10);
				print 
					"<fieldset><textarea name='$name' rows='$rows'>",
					$m->escHtml(join("\n", @$value), 1), 
					"</textarea></fieldset>\n";
			}
			elsif ($opt->{parse} eq 'hash') {
				# Print hash textarea option
				my $rows = $m->min($m->max(4, scalar keys %$value), 10);
				print 
					"<fieldset><textarea name='$name' rows='$rows'>",
					$m->escHtml(join("\n", map("$_=$value->{$_}", sort keys %$value)), 1), 
					"</textarea></fieldset>\n";
			}
			elsif ($opt->{parse} eq 'arrayhash') {
				# Print hash-of-arrays textarea option
				my $text = "";
				my $rows = 0;
				for my $key (sort keys %$value) { 
					$text .= join("\n", map("$key=$_", @{$value->{$key}}));
					$rows += @{$value->{$key}};
				}
				$rows = $m->min($m->max(4, $rows), 15);
				print 
					"<fieldset><textarea name='$name' rows='$rows'>", 
					$m->escHtml($text, 1), 
					"</textarea></fieldset>\n";
			}
		}
		elsif ($opt->{type} eq 'checkbox') {
			# Print checkbox option
			my $chk = $value ? 'checked' : "";
			print 
				"<fieldset><label><input type='checkbox' name='$name' $chk> Yes",
				"</label></fieldset>\n";
		}
		elsif ($opt->{type} eq 'radio') {
			# Print radio buttons option
			print "<fieldset>\n";
			for (my $i = 0; $i < @{$opt->{radio}} - 1; $i += 2) {
				my $key = $opt->{radio}[$i];
				my $chk = $key eq $value ? 'checked' : "";
				print
					"<div><label><input type='radio' name='$name' value='$key' $chk>",
					" $opt->{radio}[$i+1]</label></div>\n";
			}
			print "</fieldset>\n";
		}
	}

	# End form
	print
		$m->submitButton("Change", 'admopt'),
		$m->stdFormFields(),
		"</div>\n",
		"</div>\n",
		"</form>\n\n";

	# Log action and finish
	$m->logAction(3, 'forum', 'options', $userId);
	$m->printFooter();
}
$m->finish();
