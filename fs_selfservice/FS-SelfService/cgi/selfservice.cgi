#!/usr/bin/perl -Tw

use strict;
use vars qw($cgi $session_id $form_max $template_dir);
use subs qw(do_template);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Text::Template;
use FS::SelfService qw(login customer_info invoice);

$template_dir = '.';

$form_max = 255;

$cgi = new CGI;

unless ( defined $cgi->param('session') ) {
  do_template('login',{});
  exit;
}

if ( $cgi->param('session') eq 'login' ) {

  $cgi->param('username') =~ /^\s*([a-z0-9_\-\.\&]{0,$form_max})\s*$/i
    or die "illegal username";
  my $username = $1;

  $cgi->param('domain') =~ /^\s*([\w\-\.]{0,$form_max})\s*$/
    or die "illegal domain";
  my $domain = $1;

  $cgi->param('password') =~ /^(.{0,$form_max})$/
    or die "illegal password";
  my $password = $1;

  my $rv = login(
    'username' => $username,
    'domain'   => $domain,
    'password' => $password,
  );
  if ( $rv->{error} ) {
    do_template('login', {
      'error'    => $rv->{error},
      'username' => $username,
      'domain'   => $domain,
    } );
    exit;
  } else {
    $cgi->param('session' => $rv->{session_id} );
    $cgi->param('action'  => 'myaccount' );
  }
}

$session_id = $cgi->param('session');

$cgi->param('action') =~ /^(myaccount|view_invoice|make_payment)$/
  or die "unknown action ". $cgi->param('action');
my $action = $1;

my $result = eval "&$action();";
die $@ if $@;

if ( $result->{error} eq "Can't resume session" ) { #ick
  do_template('login',{});
  exit;
}

#warn $result->{'open_invoices'};
#warn scalar(@{$result->{'open_invoices'}});

do_template($action, {
  'session_id' => $session_id,
  %{$result}
});

#--

sub myaccount { customer_info( 'session_id' => $session_id ); }

sub view_invoice {

  $cgi->param('invnum') =~ /^(\d+)$/ or die "illegal invnum";
  my $invnum = $1;

  invoice( 'session_id' => $session_id,
           'invnum'     => $invnum,
         );

}

sub make_payment {

}

#--

sub do_template {
  my $name = shift;
  my $fill_in = shift;

  $cgi->delete_all();
  $fill_in->{'selfurl'} = $cgi->self_url;

  my $template = new Text::Template( TYPE    => 'FILE',
                                     SOURCE  => "$template_dir/$name.html",
                                     DELIMITERS => [ '<%=', '%>' ],
                                     UNTAINT => 1,                    )
    or die $Text::Template::ERROR;

  print $cgi->header( '-expires' => 'now' ),
        $template->fill_in( HASH => $fill_in );
}

