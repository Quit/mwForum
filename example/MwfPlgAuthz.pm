#------------------------------------------------------------------------------
#    mwForum - Web-based discussion forum
#    Copyright © 1999-2012 Markus Wichitill
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

package MwfPlgAuthz;
use utf8;
use strict;
use warnings;
no warnings qw(uninitialized redefine);
our $VERSION = "2.27.0";

#------------------------------------------------------------------------------
# Parameters for all actions:
#   m => MwfMain object
#
# Additional parameters for action 'viewBoard':
#   user => user hashref
#   board => board hashref
#
# Return undef to authorize the action, any error message string to deny it.
# Exception for viewBoard: return undef to continue normal access checking, 
#   1 to deny, and 2 to grant access without further access checking.

#------------------------------------------------------------------------------
# This simple user registration example checks a code in the extra3 profile field 
# and allows registration if the code is 42.

sub regUser
{
	my %params = @_;
	my $m = $params{m};

	return undef if $m->paramInt('extra3') == 42;
	return "Invalid code";
}

#------------------------------------------------------------------------------
# This simple view-board example checks if the user paid his fees for a 
# specific board. $user->{paid} would have to be created and updated by the 
# adaptor code of an external payment system.

sub viewBoard
{
	my %params = @_;
	my $m = $params{m};
	my $user = $params{user};
	my $board = $params{board};

	return undef if $board->{id} != 6; # Ok, not a pay board
	return undef if $user->{paid};     # Ok, user paid his bills
	return 1;                          # Deny
}

#------------------------------------------------------------------------------
1;
