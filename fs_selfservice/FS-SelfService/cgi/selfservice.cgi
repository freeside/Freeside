#!/usr/bin/perl -Tw

use strict;
use vars qw($cgi $session_id $form_max $template_dir);
use subs qw(do_template);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Text::Template;
use HTML::Entities;
use FS::SelfService qw( login customer_info invoice
                        payment_info process_payment 
                        process_prepay
                        list_pkgs
                        part_svc_info provision_acct provision_external
                        unprovision_svc
                      );

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

#order|pw_list XXX ???
$cgi->param('action') =~
    /^(myaccount|view_invoice|make_payment|payment_results|recharge_prepay|recharge_results|logout|change_bill|change_ship|provision|provision_svc|process_svc_acct|process_svc_external|delete_svc)$/
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

warn "processing template $action\n";
do_template($action, {
  'session_id' => $session_id,
  'action'     => $action, #so the menu knows what tab we're on...
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
  payment_info( 'session_id' => $session_id );
}

sub payment_results {

  use Business::CreditCard;

  $cgi->param('amount') =~ /^\s*(\d+(\.\d{2})?)\s*$/
    or die "illegal amount"; #!!!
  my $amount = $1;

  my $payinfo = $cgi->param('payinfo');
  $payinfo =~ s/\D//g;
  $payinfo =~ /^(\d{13,16})$/
    #or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
    or die "illegal card"; #!!!
  $payinfo = $1;
  validate($payinfo)
    #or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
    or die "invalid card"; #!!!
  cardtype($payinfo) eq $cgi->param('card_type')
    #or $error ||= $init_data->{msgcat}{not_a}. $cgi->param('CARD_type');
    or die "not a ". $cgi->param('card_type');

  $cgi->param('month') =~ /^(\d{2})$/ or die "illegal month";
  my $month = $1;
  $cgi->param('year') =~ /^(\d{4})$/ or die "illegal year";
  my $year = $1;

  $cgi->param('payname') =~ /^(.{0,80})$/ or die "illegal payname";
  my $payname = $1;

  $cgi->param('address1') =~ /^(.{0,80})$/ or die "illegal address1";
  my $address1 = $1;

  $cgi->param('address2') =~ /^(.{0,80})$/ or die "illegal address2";
  my $address2 = $1;

  $cgi->param('city') =~ /^(.{0,80})$/ or die "illegal city";
  my $city = $1;

  $cgi->param('state') =~ /^(.{2})$/ or die "illegal state";
  my $state = $1;

  $cgi->param('zip') =~ /^(.{0,10})$/ or die "illegal zip";
  my $zip = $1;

  my $save = 0;
  $save = 1 if $cgi->param('save');

  my $auto = 0;
  $auto = 1 if $cgi->param('auto');

  $cgi->param('paybatch') =~ /^([\w\-\.]+)$/ or die "illegal paybatch";
  my $paybatch = $1;

  process_payment(
    'session_id' => $session_id,
    'amount'     => $amount,
    'payinfo'    => $payinfo,
    'month'      => $month,
    'year'       => $year,
    'payname'    => $payname,
    'address1'   => $address1,
    'address2'   => $address2,
    'city'       => $city,
    'state'      => $state,
    'zip'        => $zip,
    'save'       => $save,
    'auto'       => $auto,
    'paybatch'   => $paybatch,
  );

}

sub recharge_prepay {
  customer_info( 'session_id' => $session_id );
}

sub recharge_results {

  my $prepaid_cardnum = $cgi->param('prepaid_cardnum');
  $prepaid_cardnum =~ s/\W//g;
  $prepaid_cardnum =~ /^(\w*)$/ or die "illegal prepaid card number";
  $prepaid_cardnum = $1;

  process_prepay ( 'session_id'     => $session_id,
                   'prepaid_cardnum' => $prepaid_cardnum,
                 );
}

sub logout {
  FS::SelfService::logout( 'session_id' => $session_id );
}

sub provision {
  my $result = list_pkgs( 'session_id' => $session_id );
  die $result->{'error'} if exists $result->{'error'} && $result->{'error'};
  $result;
}

sub provision_svc {

  my $result = part_svc_info(
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw( pkgnum svcpart ),
  );
  die $result->{'error'} if exists $result->{'error'} && $result->{'error'};

  $result->{'svcdb'} =~ /^svc_(.*)$/
    #or return { 'error' => 'Unknown svcdb '. $result->{'svcdb'} };
    or die 'Unknown svcdb '. $result->{'svcdb'};
  $action .= "_$1";

  $result;
}

sub process_svc_acct {

  my $result = provision_acct (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw(
      pkgnum svcpart username _password _password2 sec_phrase popnum )
  );

  if ( exists $result->{'error'} && $result->{'error'} ) { 
    #warn "$result $result->{'error'}"; 
    $action = 'provision_svc_acct';
    return {
      $cgi->Vars,
      %{ part_svc_info( 'session_id' => $session_id,
                        map { $_ => $cgi->param($_) } qw( pkgnum svcpart )
                      )
      },
      'error' => $result->{'error'},
    };
  } else {
    #warn "$result $result->{'error'}"; 
    return $result;
  }

}

sub process_svc_external {
  provision_external (
    'session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw( pkgnum svcpart )
  );
}

sub delete_svc {
  unprovision_svc(
    'session_id' => $session_id,
    'svcnum'     => $cgi->param('svcnum'),
  );
}

#--

sub do_template {
  my $name = shift;
  my $fill_in = shift;

  $cgi->delete_all();
  $fill_in->{'selfurl'} = $cgi->self_url;
  $fill_in->{'cgi'} = \$cgi;

  my $template = new Text::Template( TYPE    => 'FILE',
                                     SOURCE  => "$template_dir/$name.html",
                                     DELIMITERS => [ '<%=', '%>' ],
                                     UNTAINT => 1,                    )
    or die $Text::Template::ERROR;

  print $cgi->header( '-expires' => 'now' ),
        $template->fill_in( PACKAGE => 'FS::SelfService::_selfservicecgi',
                            HASH    => $fill_in
                          );
}

#*FS::SelfService::_selfservicecgi::include = \&Text::Template::fill_in_file;

package FS::SelfService::_selfservicecgi;

#use FS::SelfService qw(regionselector expselect popselector);
use HTML::Entities;
use FS::SelfService qw(popselector);

#false laziness w/agent.cgi
sub include {
  my $name = shift;
  my $template = new Text::Template( TYPE   => 'FILE',
                                     SOURCE => "$main::template_dir/$name.html",
                                     DELIMITERS => [ '<%=', '%>' ],
                                     UNTAINT => 1,                   
                                   )
    or die $Text::Template::ERROR;

  $template->fill_in( PACKAGE => 'FS::SelfService::_selfservicecgi',
                      #HASH    => $fill_in
                    );

}

