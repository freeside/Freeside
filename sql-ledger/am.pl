#!/usr/bin/perl
#
######################################################################
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#######################################################################
#
# this script is the frontend called from bin/$terminal/$script
# all the accounting modules are linked to this script which in
# turn execute the same script in bin/$terminal/
#
#######################################################################

# setup defaults, DO NOT CHANGE
$userspath = "users";
$spool = "spool";
$templates = "templates";
$memberfile = "users/members";
$sendmail = "| /usr/sbin/sendmail -t";
%printer = ( Printer => 'lpr' );
########## end ###########################################


$| = 1;

use SL::Form;

eval { require "sql-ledger.conf"; };


$form = new Form;

# name of this script
$0 =~ tr/\\/\//;
$pos = rindex $0, '/';
$script = substr($0, $pos + 1);

# we use $script for the language module
$form->{script} = $script;
# strip .pl for translation files
$script =~ s/\.pl//;

# pull in DBI
use DBI qw(:sql_types);


# check for user config file, could be missing or ???
eval { require("$userspath/$form->{login}.conf"); };
if ($@) {
  $locale = new Locale "$language", "$script";
  
  $form->{callback} = "";
  $msg1 = $locale->text('You are logged out!');
  $msg2 = $locale->text('Login');
  $form->redirect("$msg1 <p><a href=login.pl target=_top>$msg2</a>");
}


# send warnings and errors to browser
$SIG{__WARN__} = sub { $form->info($_[0]) };
$SIG{__DIE__} = sub { $form->error($_[0]) };

$myconfig{dbpasswd} = unpack 'u', $myconfig{dbpasswd};
map { $form->{$_} = $myconfig{$_} } qw(stylesheet charset timeout) unless ($form->{type} eq 'preferences');

# locale messages
$locale = new Locale "$myconfig{countrycode}", "$script";

$form->{path} =~ s/\.\.\///g;
if ($form->{path} !~ /^bin\//) {
  $form->error($locale->text('Invalid path!')."\n");
}

# did sysadmin lock us out
if (-f "$userspath/nologin") {
  $form->error($locale->text('System currently down for maintenance!'));
}

# pull in the main code
require "$form->{path}/$form->{script}";

# customized scripts
if (-f "$form->{path}/custom_$form->{script}") {
  eval { require "$form->{path}/custom_$form->{script}"; };
}

# customized scripts for login
if (-f "$form->{path}/$form->{login}_$form->{script}") {
  eval { require "$form->{path}/$form->{login}_$form->{script}"; };
}

  
if ($form->{action}) {
  # window title bar, user info
  $form->{titlebar} = "SQL-Ledger ".$locale->text('Version'). " $form->{version} - $myconfig{name} - $myconfig{dbname}";

  &check_password;
  
  if (substr($form->{action}, 0, 1) =~ /( |\.)/) {
    &{ $form->{nextsub} };
  } else {
    &{ $locale->findsub($form->{action}) };
  }
} else {
  $form->error($locale->text('action= not defined!'));
}

1;
# end


sub check_password {
  
  if ($myconfig{password}) {

    require "$form->{path}/pw.pl";

    if ($form->{password}) {
      if ((crypt $form->{password}, substr($form->{login}, 0, 2)) ne $myconfig{password}) {
	&getpassword;
	exit;
      }
    } else {
      if ($ENV{HTTP_USER_AGENT}) {
	$ENV{HTTP_COOKIE} =~ s/;\s*/;/g;
	%cookie = split /[=;]/, $ENV{HTTP_COOKIE};
	
	if ($form->{action} ne 'display') {
	  if ((! $cookie{"SQL-Ledger-$form->{login}"}) || $cookie{"SQL-Ledger-$form->{login}"} ne $form->{sessionid}) {
	    &getpassword(1);
	    exit;
	  }
	}
      }
    }
  }
}


