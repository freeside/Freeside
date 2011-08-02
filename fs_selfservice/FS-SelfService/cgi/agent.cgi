#!/usr/bin/perl -T
#!/usr/bin/perl -Tw

#some false laziness w/selfservice.cgi

use strict;
use vars qw($DEBUG $me $cgi $session_id $form_max $template_dir);
use subs qw(do_template);
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Business::CreditCard;
use Text::Template;
#use HTML::Entities;
use FS::SelfService qw( agent_login agent_logout agent_info
                        agent_list_customers
                        signup_info new_customer
                        customer_info list_pkgs order_pkg
                        part_svc_info provision_acct provision_external
                        unprovision_svc
                      );

$DEBUG = 0;
$me = 'agent.cgi:';

$template_dir = '.';

$form_max = 255;

warn "$me starting\n" if $DEBUG;

warn "$me initializing CGI\n" if $DEBUG;
$cgi = new CGI;

unless ( defined $cgi->param('session') ) {
  warn "$me no session defined, sending login page\n" if $DEBUG;
  do_template('agent_login',{});
  exit;
}

if ( $cgi->param('session') eq 'login' ) {

  warn "$me processing login\n" if $DEBUG;

  $cgi->param('username') =~ /^\s*([a-z0-9_\-\.\&]{0,$form_max})\s*$/i
    or die "illegal username";
  my $username = $1;

  $cgi->param('password') =~ /^(.{0,$form_max})$/
    or die "illegal password";
  my $password = $1;

  my $rv = agent_login(
    'username' => $username,
    'password' => $password,
  );
  if ( $rv->{error} ) {
    do_template('agent_login', {
      'error'    => $rv->{error},
      'username' => $username,
    } );
    exit;
  } else {
    $cgi->param('session' => $rv->{session_id} );
    $cgi->param('action'  => 'agent_main' );
  }
}

$session_id = $cgi->param('session');

warn "$me checking action\n" if $DEBUG;
$cgi->param('action') =~
   /^(agent_main|signup|process_signup|list_customers|view_customer|agent_provision|provision_svc|process_svc_acct|process_svc_external|delete_svc|agent_order_pkg|process_order_pkg|logout)$/
  or die "unknown action ". $cgi->param('action');
my $action = $1;

warn "$me running $action\n" if $DEBUG;
my $result = eval "&$action();";
die $@ if $@;

if ( $result->{error} eq "Can't resume session" ) { #ick
  do_template('agent_login',{});
  exit;
}

warn "$me processing template $action\n" if $DEBUG;
do_template($action, {
  'session_id' => $session_id,
  %{$result}
});
warn "$me done processing template $action\n" if $DEBUG;

#-- 

sub logout {
  $action = 'agent_logout';
  agent_logout( 'session_id' => $session_id );
}

sub agent_main { agent_info( 'session_id' => $session_id ); }

sub signup { signup_info( 'session_id' => $session_id ); }

sub process_signup {

  my $init_data = signup_info( 'session_id' => $session_id );
  if ( $init_data->{'error'} ) {
    if ( $init_data->{'error'} eq "Can't resume session" ) { #ick
      do_template('agent_login',{});
      exit;
    } else { #?
      die $init_data->{'error'};
    }
  }

  my $error = '';

  #false laziness w/signup.cgi, identical except for agentnum vs session_id
  my $payby = $cgi->param('payby');
  if ( $payby eq 'CHEK' || $payby eq 'DCHK' ) {
    #$payinfo = join('@', map { $cgi->param( $payby. "_payinfo$_" ) } (1,2) );
    $cgi->param('payinfo' => $cgi->param($payby. '_payinfo1'). '@'. 
                             $cgi->param($payby. '_payinfo2')
               );
  } else {
    $cgi->param('payinfo' => $cgi->param( $payby. '_payinfo' ) );
  }
  $cgi->param('paydate' => $cgi->param( $payby. '_month' ). '-'.
                           $cgi->param( $payby. '_year' )
             );
  $cgi->param('payname' => $cgi->param( $payby. '_payname' ) );
  $cgi->param('paycvv' => defined $cgi->param( $payby. '_paycvv' )
                            ? $cgi->param( $payby. '_paycvv' )
                            : ''
             );

  if ( $cgi->param('invoicing_list') ) {
    $cgi->param('invoicing_list' => $cgi->param('invoicing_list'). ', POST')
      if $cgi->param('invoicing_list_POST');
  } else {
    $cgi->param('invoicing_list' => 'POST' );
  }

  if ( $cgi->param('_password') ne $cgi->param('_password2') ) {
    $error = $init_data->{msgcat}{passwords_dont_match}; #msgcat
    $cgi->param('_password', '');
    $cgi->param('_password2', '');
  }

  if ( $payby =~ /^(CARD|DCRD)$/ && $cgi->param('CARD_type') ) {
    my $payinfo = $cgi->param('payinfo');
    $payinfo =~ s/\D//g;

    $payinfo =~ /^(\d{13,16}|\d{8,9})$/
      or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
    $payinfo = $1;
    validate($payinfo)
      or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
    cardtype($payinfo) eq $cgi->param('CARD_type')
      or $error ||= $init_data->{msgcat}{not_a}. $cgi->param('CARD_type');
  }

  unless ( $error ) {
    my $rv = new_customer ( {
      'session_id'       => $session_id,
      map { $_ => scalar($cgi->param($_)) }
        qw( last first ss company
            address1 address2 city county state zip country
            daytime night fax

            ship_last ship_first ship_company
            ship_address1 ship_address2 ship_city ship_county ship_state
              ship_zip ship_country
            ship_daytime ship_night ship_fax

            payby payinfo paycvv paydate payname invoicing_list
            referral_custnum promo_code reg_code
            pkgpart username sec_phrase _password popnum refnum
          ),
        grep { /^snarf_/ } $cgi->param
    } );
    $error = $rv->{'error'};
  }
  #eslaf

  if ( $error ) { 
    $action = 'signup';
    my $r = { 
      $cgi->Vars,
      %{$init_data},
      'error' => $error,
    };
    #warn join('\n', map "$_ => $r->{$_}", keys %$r )."\n";
    $r;
  } else {
    $action = 'agent_main';
    my $agent_info = agent_info( 'session_id' => $session_id );
    $agent_info->{'message'} = 'Signup successful';
    $agent_info;
  }

}

sub list_customers {

  my $results = 
    agent_list_customers( 'session_id' => $session_id,
                          map { $_ => $cgi->param($_) }
                            grep defined($cgi->param($_)),
                                 qw(prospect active susp cancel),
                                 'search',
                        );

  if ( scalar( @{$results->{'customers'}} ) == 1 ) {
    $action = 'view_customer';
    customer_info (
      'agent_session_id' => $session_id,
      'custnum'          => $results->{'customers'}[0]{'custnum'},
    );
  } else {
    $results;
  }

}

sub view_customer {

  #my $init_data = signup_info( 'session_id' => $session_id );
  #if ( $init_data->{'error'} ) {
  #  if ( $init_data->{'error'} eq "Can't resume session" ) { #ick
  #    do_template('agent_login',{});
  #    exit;
  #  } else { #?
  #    die $init_data->{'error'};
  #  }
  #}
  #
  #my $customer_info =
  customer_info (
    'agent_session_id' => $session_id,
    'custnum'          => $cgi->param('custnum'),
  );
  #
  #return {
  #  ( map { $_ => $init_data->{$_} }
  #        qw( part_pkg security_phrase svc_acct_pop ),
  #  ),
  #  %$customer_info,
  #};
}

sub agent_order_pkg {

  my $init_data = signup_info( 'session_id' => $session_id );
  if ( $init_data->{'error'} ) {
    if ( $init_data->{'error'} eq "Can't resume session" ) { #ick
      do_template('agent_login',{});
      exit;
    } else { #?
      die $init_data->{'error'};
    }
  }

  my $customer_info = customer_info (
    'agent_session_id' => $session_id,
    'custnum'          => $cgi->param('custnum'),
  );

  return {
    ( map { $_ => $init_data->{$_} }
          qw( part_pkg security_phrase svc_acct_pop ),
    ),
    %$customer_info,
  };

}

sub agent_provision {
  my $result = list_pkgs(
    'agent_session_id' => $session_id,
    'custnum'          => $cgi->param('custnum'),
  );
  die $result->{'error'} if exists $result->{'error'} && $result->{'error'};
  $result;
}

sub provision_svc {

  my $result = part_svc_info(
    'agent_session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw( pkgnum svcpart custnum ),
  );
  die $result->{'error'} if exists $result->{'error'} && $result->{'error'};

  $result->{'svcdb'} =~ /^svc_(.*)$/
    #or return { 'error' => 'Unknown svcdb '. $result->{'svcdb'} };
    or die 'Unknown svcdb '. $result->{'svcdb'};
  $action .= "_$1";
  $action = "agent_$action";

  $result;
}

sub process_svc_acct {

  my $result = provision_acct (
    'agent_session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw(
      custnum pkgnum svcpart username _password _password2 sec_phrase popnum )
  );

  if ( exists $result->{'error'} && $result->{'error'} ) { 
    #warn "$result $result->{'error'}"; 
    $action = 'provision_svc_acct';
    $action = "agent_$action";
    return {
      $cgi->Vars,
      %{ part_svc_info( 'agent_session_id' => $session_id,
                        map { $_ => $cgi->param($_) } qw(pkgnum svcpart custnum)
                      )
      },
      'error' => $result->{'error'},
    };
  } else {
    #warn "$result $result->{'error'}"; 
    $action = 'agent_provision';
    return {
      %{agent_provision()},
      'message' => $result->{'svc'}. ' setup successfully.',
    };
  }

}

sub process_svc_external {

  my $result = provision_external (
    'agent_session_id' => $session_id,
    map { $_ => $cgi->param($_) } qw( custnum pkgnum svcpart )
  );

  #warn "$result $result->{'error'}"; 
  $action = 'agent_provision';
  return {
    %{agent_provision()},
    'message' => $result->{'error'}
                   ? '<FONT COLOR="#FF0000">'. $result->{'error'}. '</FONT>'
                   : $result->{'svc'}. ' setup successfully'.
                     ': serial number '.
                     sprintf('%010d', $result->{'id'}). '-'. $result->{'title'}
  };

}

sub delete_svc {
  my $result = unprovision_svc(
    'agent_session_id' => $session_id,
    'custnum'          => $cgi->param('custnum'),
    'svcnum'           => $cgi->param('svcnum'),
  );

  $action = 'agent_provision';

  return {
    %{agent_provision()},
    'message' => $result->{'error'}
                   ? '<FONT COLOR="#FF0000">'. $result->{'error'}. '</FONT>'
                   : $result->{'svc'}. ' removed.'
  };

}

sub process_order_pkg {

  my $results = '';

  unless ( length($cgi->param('_password')) ) {
    my $init_data = signup_info( 'session_id' => $session_id );
    #die $init_data->{'error'} if $init_data->{'error'};
    $results = { 'error' => $init_data->{msgcat}{empty_password} };
  }
  if ( $cgi->param('_password') ne $cgi->param('_password2') ) {
    my $init_data = signup_info( 'session_id' => $session_id );
    $results = { 'error' => $init_data->{msgcat}{passwords_dont_match} };
    $cgi->param('_password', '');
    $cgi->param('_password2', '');
  }

  $results ||= order_pkg (
    'agent_session_id' => $session_id,
    map { $_ => $cgi->param($_) }
        qw( custnum pkgpart username _password _password2 sec_phrase popnum )
  );

  if ( $results->{'error'} ) {
    $action = 'agent_order_pkg';
    return {
      $cgi->Vars,
      %{agent_order_pkg()},
      #'message' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
      'error' => '<FONT COLOR="#FF0000">'. $results->{'error'}. '</FONT>',
    };
  } else {
    $action = 'view_customer';
    #$cgi->delete( grep { $_ ne 'custnum' } $cgi->param );
    return {
      %{view_customer()},
      'message' => 'Package order successful.',
    };
  }

}

#--

sub do_template {
  my $name = shift;
  my $fill_in = shift;
  #warn join(' / ', map { "$_=>".$fill_in->{$_} } keys %$fill_in). "\n";

  $cgi->delete_all();
  $fill_in->{'selfurl'} = $cgi->self_url; #OLD
  $fill_in->{'self_url'} = $cgi->self_url;
  $fill_in->{'cgi'} = \$cgi;

  my $template = new Text::Template( TYPE    => 'FILE',
                                     SOURCE  => "$template_dir/$name.html",
                                     DELIMITERS => [ '<%=', '%>' ],
                                     UNTAINT => 1,                    )
    or die $Text::Template::ERROR;

  local $^W = 0;
  print $cgi->header( '-expires' => 'now' ),
        $template->fill_in( PACKAGE => 'FS::SelfService::_agentcgi',
                            HASH    => $fill_in
                          );
}

package FS::SelfService::_agentcgi;

use HTML::Entities;
use FS::SelfService qw(regionselector expselect popselector);

#false laziness w/selfservice.cgi
sub include {
  my $name = shift;
  my $template = new Text::Template( TYPE   => 'FILE',
                                     SOURCE => "$main::template_dir/$name.html",
                                     DELIMITERS => [ '<%=', '%>' ],
                                     UNTAINT => 1,                   
                                   )
    or die $Text::Template::ERROR;

  $template->fill_in( PACKAGE => 'FS::SelfService::_agentcgi',
                      #HASH    => $fill_in
                    );

}

