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

package MwfPlgAuthen;
use utf8;
use strict;
use warnings;
no warnings qw(uninitialized redefine once);
our $VERSION = "2.27.3";

#------------------------------------------------------------------------------
# Authenticate user via HTTP authentication on every request.
# Create account if necessary.
# The actual name/pwd verification is done by the webserver.

sub authenRequestHttp
{
	my %params = @_;
	my $m = $params{m};
	
	# Shortcuts
	my $cfg = $m->{cfg};

	# Get user's authenticated name from $m->{env}, 
	# where mwForum copies it from REMOTE_USER or the mod_perl equivalent
	my $userName = $m->{env}{userAuth};

	# Get user
	my $dbUser = $m->fetchHash("
		SELECT * FROM users WHERE userName = ?", $userName);
	
	# If there's no user account for that name, create one
	if (!$dbUser) {
		# Insert user
		my $userId = $m->createUser(userName => $userName);
		
		# Get freshly created user
		$dbUser = $m->getUser($userId);
	}
	
	# Return user
	return $dbUser;
}

#------------------------------------------------------------------------------
# Authenticate user by email field in SSL client certificate on every request.
# Create account if necessary.
# The actual certificate verification is done by mod_ssl, the rest is similar
# to HTTP authentication.

sub authenRequestSsl
{
	my %params = @_;
	my $m = $params{m};
	
	# Shortcuts
	my $cfg = $m->{cfg};

	# Get user's email address and common name from certificate
	my $email;
	my $userName;
	if ($MwfMain::MP) {
		$email = $m->{ap}->subprocess_env->{SSL_CLIENT_S_DN_Email};
		$userName = $m->{ap}->subprocess_env->{SSL_CLIENT_S_DN_CN} || $email;
	}
	else {
		$email = $ENV{SSL_CLIENT_S_DN_Email};
		$userName = $ENV{SSL_CLIENT_S_DN_CN} || $email;
	}

	# Return undef if cert is valid but email is empty
	return undef if !$email;
	
	# Get user
	my $dbUser = $m->fetchHash("
		SELECT * FROM users WHERE email = ?", $email);
	
	# If there's no user account for that email address, create one
	if (!$dbUser) {
		# Insert user
		my $userId = $m->createUser(userName => $userName, email => $email);
		
		# Get freshly created user
		$dbUser = $m->getUser($userId);
	}
	
	# Return user
	return $dbUser;
}

#------------------------------------------------------------------------------
# Authenticate user against LDAP on login, use normal cookie authentication after that.
# Create account and update forum password if necessary.

sub authenLoginLdap
{
	my %params = @_;
	my $m = $params{m};
	my $userName = $params{userName};
	my $password = $params{password};
	
	# Shortcuts
	my $cfg = $m->{cfg};
	
	# Check name/password against LDAP
	require Net::LDAP;
	$cfg->{ldapHost}      = "ldap.itd.umich.edu";
	$cfg->{ldapBindDn}    = "";
	$cfg->{ldapBindPwd}   = "";
	$cfg->{ldapBaseDn}    = "dc=umich,dc=edu";
	$cfg->{ldapSearch}    = "uid=[[userName]]";
	$cfg->{ldapPwdAttr}   = "sn";
	$cfg->{ldapNameAttr}  = "cn";
	$cfg->{ldapEmailAttr} = "mail";
	my $filter = $cfg->{ldapSearch};
	$filter =~ s!\[\[userName\]\]!$userName!;
	my $ldap = Net::LDAP->new($cfg->{ldapHost});
	my $mesg = $ldap->bind($cfg->{ldapBindDn} 
		? ($cfg->{ldapBindDn}, password => $cfg->{ldapBindPwd}) : ());
	$mesg->code() and return "LDAP: bind failed.";
	$mesg = $ldap->search(
		base => $cfg->{ldapBaseDn}, 
		filter => $filter, 
		attrs => [ $cfg->{ldapPwdAttr}, $cfg->{ldapNameAttr}, $cfg->{ldapEmailAttr} ],
		sizelimit => 1,
	);
	$mesg->count() or return "LDAP: user not found.";
	my $entry = $mesg->entry(0);
	length($password) && $password eq $entry->get_value($cfg->{ldapPwdAttr}) 
		or return "LDAP: password is wrong.";
	
	# Get local user
	my $dbUser = $m->fetchHash("
		SELECT * FROM users WHERE userName = ?", $userName);

	if ($dbUser) {		
		# If the password from LDAP changed, update mwForum password since the 
		# mwForum cookies will be checked against that in future requests
		my $passwordHash = $m->hashPassword($password, $dbUser->{salt});
		$m->dbDo("
			UPDATE users SET password = ? WHERE id = ?", $passwordHash, $dbUser->{id})
			if $passwordHash ne $dbUser->{password};
	}
	else {
		# If there's no mwForum user for that name yet, create one
		my $userId = $m->createUser(
			userName => $userName,
			password => $password,
			realName => $m->escHtml(scalar $entry->get_value($cfg->{ldapNameAttr})),
			email => $m->escHtml(scalar $entry->get_value($cfg->{ldapEmailAttr})),
		);
		
		# Get freshly created user
		$dbUser = $m->getUser($userId);
	}

	# Return user
	$ldap->unbind();
	return $dbUser;
}

#------------------------------------------------------------------------------
1;
