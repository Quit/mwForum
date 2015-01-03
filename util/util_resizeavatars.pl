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

# Resize gallery avatar images to configured width/height.
# Uses same method as manual upload resizing, i.e. saves as PNG with 
# padding as necessary to maintain aspect ratios.

use strict;
use warnings;
no warnings qw(uninitialized);

# Imports
use Getopt::Std ();
use File::Glob ();
require MwfMain;

# Get arguments
my %opts = ();
Getopt::Std::getopts('?hf:', \%opts);
my $help = $opts{'?'} || $opts{h};
#my $forumId = $opts{f};
my $forumId = "/forum";
usage() if $help;

# Init
my ($m, $cfg, $lng) = MwfMain->newShell(forumId => $forumId, allowCgi => 1);
$m->dbBegin();
print "Resizing gallery avatars...\n";

# Load modules
my $module;
if (!$cfg->{noGd} && eval { require GD }) { $module = 'GD' }
elsif (!$cfg->{noImager} && eval { require Imager }) { $module = 'Imager' }
elsif (!$cfg->{noGMagick} && eval { require Graphics::Magick }) { $module = 'Graphics::Magick' }
elsif (!$cfg->{noIMagick} && eval { require Image::Magick }) { $module = 'Image::Magick' }
else { print "GD, Imager or Magick modules not available.\n" }

# Shortcuts
my $avaW = $cfg->{avatarWidth};
my $avaH = $cfg->{avatarHeight};

# Process all image files in gallery
for my $oldFileEnc (File::Glob::bsd_glob("$cfg->{attachFsPath}/avatars/gallery/*.{jpg,png,gif}",
	File::Glob::GLOB_NOCASE() | File::Glob::GLOB_BRACE())) {

	# Get image info
	my ($imgW, $imgH, $oldImg, $err);
	if ($module eq 'GD') {
		GD::Image->trueColor(1);
		$oldImg = GD::Image->new($oldFileEnc) or print "Image loading failed.\n", next;
		$imgW = $oldImg->width();
		$imgH = $oldImg->height();
		$imgW && $imgH or print "Image size check failed.\n", next;
	}
	elsif ($module eq 'Imager') {
		$oldImg = Imager->new(file => $oldFileEnc) 
			or print "Image loading failed. " . Imager->errstr(), next;
		$imgW = $oldImg->getwidth();
		$imgH = $oldImg->getheight();
		$imgW && $imgH or print "Image size check failed.\n", next;
	}
	elsif ($module eq 'Graphics::Magick' || $module eq 'Image::Magick') {
		my $magick = $module->new() or print "Magick creation failed.\n", next;
		($imgW, $imgH) = $magick->Ping($oldFileEnc);
		$imgW && $imgH or print "Image size check failed.\n", next;
	}

	# Skip if conforming
	next if $imgW == $avaW && $imgH == $avaH;
	
	# Determine values
	my $shrW = $avaW / $imgW;
	my $shrH = $avaH / $imgH;
	my $shrF = $m->min($shrW, $shrH, 1);
	my $dstW = int($imgW * $shrF + .5);
	my $dstH = int($imgH * $shrF + .5);
	my $dstX = int($m->max($avaW - $dstW, 0) / 2 + .5);
	my $dstY = int($m->max($avaH - $dstH, 0) / 2 + .5);
	my $newFileEnc = $oldFileEnc;
	$newFileEnc =~ s!\.(?:jpg|png|gif)\z!.png!i;
	
	# Resize image
	if ($module eq 'GD') {
		GD::Image->trueColor(1);
		my $newImg = GD::Image->new($avaW, $avaH, 1) or print "Avatar creation failed.\n";
		$newImg->alphaBlending(0);
		$newImg->saveAlpha(1);
		$newImg->fill(0, 0, $newImg->colorAllocateAlpha(255,255,255, 127));
		$newImg->copyResampled($oldImg, $dstX, $dstY, 0, 0, $dstW, $dstH, $imgW, $imgH);
		open my $fh, ">:raw", $newFileEnc or print "Avatar opening failed. $!\n";
		print $fh $newImg->png() or print "Avatar storing failed. $!\n";
		close $fh;
	}
	elsif ($module eq 'Imager') {
		$oldImg = $oldImg->scale(xpixels => $dstW, ypixels => $dstH,
			qtype => 'mixing', type => 'nonprop')
			or print "Avatar scaling failed. " . Imager->errstr() . "\n";
		my $newImg = Imager->new(xsize => $avaW, ysize => $avaH, channels => 4)
			or print "Avatar creation failed. " . Imager->errstr() . "\n";
		$newImg->paste(img => $oldImg, left => $dstX, top => $dstY)
			or print "Avatar pasting failed. " . $newImg->errstr() . "\n";
		$newImg->write(file => $newFileEnc) 
			or print "Avatar storing failed. " . $newImg->errstr() . "\n";
	}
	elsif ($module eq 'Graphics::Magick' || $module eq 'Image::Magick') {
		my $oldImg = $module->new()
			or print "Image creation failed\n";
		my $err = $oldImg->Read($oldFileEnc . "[0]")
			and unlink($oldFileEnc), print "Avatar loading failed\n";
		$err = $oldImg->Scale(width => $dstW, height => $dstH)
			and print "Avatar scaling failed. $err\n";
		my $newImg = $module->new(size => "${avaW}x${avaH}")
			or print "Avatar creation failed.\n";
		$err = $newImg->Read("xc:transparent")
			and print "Avatar filling failed. $err\n";
		$err = $newImg->Composite(image => $oldImg, x => $dstX, y => $dstY)
			and print "Avatar compositing failed. $err\n";
		$err = $newImg->Write(filename => $newFileEnc)
			and print "Avatar storing failed. $err\n";
	}

	# Delete old file and chmod new file
	unlink($oldFileEnc);
	$m->setMode($newFileEnc, 'file');

	# Print info
	my $oldFileName = $m->decFsPath($oldFileEnc);
	$oldFileName =~ s!.*[\\/]!!;
	my $newFileName = $m->decFsPath($newFileEnc);
	$newFileName =~ s!.*[\\/]!!;
	print "$oldFileName -> $newFileName\n";

	# Update users
	$m->dbDo("
		UPDATE users SET avatar = ? WHERE avatar = ?", 
		"gallery/$oldFileName", "gallery/$newFileName");
}

# Log action and finish
$m->logAction(1, 'util', 'rszava');
$m->dbCommit();

#------------------------------------------------------------------------------

sub usage
{
	print
		"Resize gallery avatar images to configured width/height.\n",
		"Usage: util_resizeavatars.pl [-f forum]\n",
		"  -f   Forum hostname or URL path when using a multi-forum installation.\n",
	;

	exit 1;
}
