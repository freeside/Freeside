#!/usr/bin/perl -Tw

#false-laziness hack w login.cgi

use strict;
use vars qw( $cgi $username $password $error $ip $portnum );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::SessionClient qw( logout portnum );

$cgi = new CGI;

if ( defined $cgi->param('magic') ) {
  $cgi->param('username') =~ /^\s*(\w{1,255})\s*$/ or do {
    $error = "Illegal username";
    &print_form;
    exit;
  };
  $username = $1;
  $cgi->param('password') =~ /^([^\n]{0,255})$/ or die "guru meditation #420";
  $password = $1;
  #$ip = $cgi->remote_host;
  $ip = $ENV{REMOTE_ADDR};
  $ip =~ /^([\d\.]+)$/ or die "illegal ip: $ip";
  $ip = $1;
  $portnum = portnum( { 'ip' => $1 } ) or do {
    $error = "You appear to be coming from an unknown IP address.  Verify ".
             "that your computer is set to obtain an IP address automatically ".
             "via DHCP.";
    &print_form;
    exit;
  };

  ( $error = logout ( {
    'username' => $username,
    'portnum'  => $portnum,
    'password' => $password,
  } ) )
    ? &print_form()
    : &print_okay();

} else {
  $username = '';
  $password = '';
  $error = '';
  &print_form;
}

sub print_form {
  my $self_url = $cgi->self_url;

  print $cgi->header( '-expires' => 'now' ), <<END;
<HTML><HEAD><TITLE>logout</TITLE></HEAD>
<BODY>
END

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: $error</FONT>! if $error;

print <<END;
<FORM ACTION="$self_url" METHOD=POST>
<INPUT TYPE="hidden" NAME="magic" VALUE="process">
Username <INPUT TYPE="text" NAME="username" VALUE="$username"><BR>
Password <INPUT TYPE="password" NAME="password"><BR>
<INPUT TYPE="submit">
</FORM>
</BODY>
</HTML>
END

}

sub print_okay {
  print $cgi->header( '-expires' => 'now' ), <<END;
<HTML><HEAD><TITLE>logout sucessful</TITLE></HEAD>
<BODY>logout successful, etc.
</BODY>
</HTML>
END
}

sub usage {
  die "Usage:\n\n  freeside-logout username ( portnum | ip | nasnum nasport )";
}
