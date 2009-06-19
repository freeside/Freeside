#!/usr/bin/perl -T
#!/usr/bin/perl -Tw

use strict;
use vars qw( $cgi $self_url $error
             $verify_html $verify_template
             $success_html $success_template
             $decline_html $decline_template
           );

use subs qw( print_verify print_okay print_decline
             verify_default success_default decline_default
           );
use CGI;
use Text::Template;
use FS::SelfService qw( capture_payment );

$verify_html =  -e 'verify.html'
                  ? 'verify.html'
                  : '/usr/local/freeside/verify.html';
$success_html = -e 'verify_success.html'
                  ? 'success.html'
                  : '/usr/local/freeside/success.html';
$decline_html = -e 'verify_decline.html'
                  ? 'decline.html'
                  : '/usr/local/freeside/decline.html';


if ( -e $verify_html ) {
  my $verify_txt = Text::Template::_load_text($verify_html)
    or die $Text::Template::ERROR;
  $verify_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $verify_txt = $1;
  $verify_template = new Text::Template ( TYPE => 'STRING',
                                          SOURCE => $verify_txt,
                                          DELIMITERS => [ '<%=', '%>' ],
                                        )
    or die $Text::Template::ERROR;
} else {
  $verify_template = new Text::Template ( TYPE => 'STRING',
                                          SOURCE => &verify_default,
                                          DELIMITERS => [ '<%=', '%>' ],
                                        )
    or die $Text::Template::ERROR;
}

if ( -e $success_html ) {
  my $success_txt = Text::Template::_load_text($success_html)
    or die $Text::Template::ERROR;
  $success_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $success_txt = $1;
  $success_template = new Text::Template ( TYPE => 'STRING',
                                           SOURCE => $success_txt,
                                           DELIMITERS => [ '<%=', '%>' ],
                                         )
    or die $Text::Template::ERROR;
} else {
  $success_template = new Text::Template ( TYPE => 'STRING',
                                           SOURCE => &success_default,
                                           DELIMITERS => [ '<%=', '%>' ],
                                         )
    or die $Text::Template::ERROR;
}

if ( -e $decline_html ) {
  my $decline_txt = Text::Template::_load_text($decline_html)
    or die $Text::Template::ERROR;
  $decline_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $decline_txt = $1;
  $decline_template = new Text::Template ( TYPE => 'STRING',
                                           SOURCE => $decline_txt,
                                           DELIMITERS => [ '<%=', '%>' ],
                                         )
    or die $Text::Template::ERROR;
} else {
  $decline_template = new Text::Template ( TYPE => 'STRING',
                                           SOURCE => &decline_default,
                                           DELIMITERS => [ '<%=', '%>' ],
                                         )
    or die $Text::Template::ERROR;
}

$cgi = new CGI;

my $rv = capture_payment(
           data => { 'manual' => 1,
                     map { $_ => scalar($cgi->param($_)) } $cgi->param
                   },
           url  => $cgi->self_url,
);

$error = $rv->{error};
  
if ( $error eq '_decline' ) {
  print_decline();
} elsif ( $error ) {
  print_verify();
} else {
  print_okay(%$rv);
}


sub print_verify {

  $error = "Error: $error" if $error;

  my $r = { $cgi->Vars, 'error' => $error };

  $r->{self_url} = $cgi->self_url;

  print $cgi->header( '-expires' => 'now' ),
        $verify_template->fill_in( PACKAGE => 'FS::SelfService::_signupcgi',
                                   HASH    => $r
                                 );
}

sub print_decline {
  print $cgi->header( '-expires' => 'now' ),
        $decline_template->fill_in();
}

sub print_okay {
  my %param = @_;

  my @success_url = split '/', $cgi->url(-path);
  pop @success_url;

  my $success_url  = join '/', @success_url;
  if ($param{session_id}) {
    my $session_id = lc($param{session_id});
    $success_url .= "/selfservice.cgi?action=myaccount&session=$session_id";
  } else {
    $success_url .= '/signup.cgi?action=success';
  }

  print $cgi->header( '-expires' => 'now' ),
        $success_template->fill_in( HASH => { success_url => $success_url } );
}

sub success_default { #html to use if you don't specify a success file
  <<'END';
<HTML><HEAD><TITLE>Signup successful</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=7>Signup successful</FONT><BR><BR>
Thanks for signing up!
<BR><BR>
<SCRIPT TYPE="text/javascript">
  window.top.location="<%= $success_url %>";
</SCRIPT>
</BODY></HTML>
END
}

sub verify_default { #html to use for verification response
  <<'END';
<HTML><HEAD><TITLE>Processing error</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=7>Processing error</FONT><BR><BR>
There has been an error processing your account.  Please contact customer
support.
</BODY></HTML>
END
}

sub decline_default { #html to use if there is a decline
  <<'END';
<HTML><HEAD><TITLE>Processing error</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=7>Processing error</FONT><BR><BR>
There has been an error processing your account.  Please contact customer
support.
</BODY></HTML>
END
}

# subs for the templates...

package FS::SelfService::_signupcgi;
use HTML::Entities;

