#!/usr/bin/perl -T
#!/usr/bin/perl -Tw
#
# $Id: signup.cgi,v 1.54 2004-12-01 18:38:22 ivan Exp $

use strict;
use vars qw( @payby $cgi $locales $packages
             $pops %pop %popnum2pop
             $init_data $error

             $last $first $ss $company $address1
             $address2 $city $state $county
             $country $zip $daytime $night $fax

             $ship_last $ship_first $ship_ss $ship_company $ship_address1
             $ship_address2 $ship_city $ship_state $ship_county
             $ship_country $ship_zip $ship_daytime $ship_night $ship_fax

             $invoicing_list $payby $payinfo
             $paycvv $paydate $payname $referral_custnum $init_popstate
             $pkgpart $username $password $password2 $sec_phrase $popnum
             $agentnum $refnum
             $ieak_file $ieak_template
             $signup_html $signup_template
             $success_html $success_template
             $decline_html $decline_template
             $ac $exch $loc
             $email_name $pkg
             $self_url
           );
use subs qw( print_form print_okay print_decline
             success_default decline_default
           );
use CGI;
#use CGI::Carp qw(fatalsToBrowser);
use Text::Template;
use Business::CreditCard;
use HTTP::BrowserDetect;
use FS::SelfService qw( signup_info new_customer expselect );

#acceptable payment methods
#
#@payby = qw( CARD BILL COMP );
#@payby = qw( CARD BILL );
#@payby = qw( CARD );
@payby = qw( CARD PREPAY );

$ieak_file = '/usr/local/freeside/ieak.template';
$signup_html = -e 'signup.html'
                 ? 'signup.html'
                 : '/usr/local/freeside/signup.html';
$success_html = -e 'success.html'
                  ? 'success.html'
                  : '/usr/local/freeside/success.html';
$decline_html = -e 'decline.html'
                  ? 'decline.html'
                  : '/usr/local/freeside/decline.html';


if ( -e $ieak_file ) {
  my $ieak_txt = Text::Template::_load_text($ieak_file)
    or die $Text::Template::ERROR;
  $ieak_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $ieak_txt = $1;
  $ieak_txt =~ s/\r//g; # don't double \r on old templates
  $ieak_txt =~ s/\n/\r\n/g;
  $ieak_template = new Text::Template ( TYPE => 'STRING', SOURCE => $ieak_txt )
    or die $Text::Template::ERROR;
} else {
  $ieak_template = '';
}

$agentnum = '';
if ( -e $signup_html ) {
  my $signup_txt = Text::Template::_load_text($signup_html)
    or die $Text::Template::ERROR;
  $signup_txt =~ /^(.*)$/s; #untaint the template source - it's trusted
  $signup_txt = $1;
  $signup_template = new Text::Template ( TYPE => 'STRING',
                                          SOURCE => $signup_txt,
                                          DELIMITERS => [ '<%=', '%>' ]
                                        )
    or die $Text::Template::ERROR;
  if ( $signup_txt =~
         /<\s*INPUT TYPE="?hidden"?\s+NAME="?agentnum"?\s+VALUE="?(\d+)"?\s*>/si
  ) {
    $agentnum = $1;
  }
} else {
  #too much maintenance hassle to keep in this file
  die "can't find ./signup.html or /usr/local/freeside/signup.html";
  #$signup_template = new Text::Template ( TYPE => 'STRING',
  #                                        SOURCE => &signup_default,
  #                                        DELIMITERS => [ '<%=', '%>' ]
  #                                      )
  #  or die $Text::Template::ERROR;
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

$init_data = signup_info( 'promo_code' => $cgi->param('promo_code') );
$error = $init_data->{'error'};
$locales = $init_data->{'cust_main_county'};
$packages = $init_data->{'part_pkg'};
$pops = $init_data->{'svc_acct_pop'};
@payby = @{$init_data->{'payby'}} if @{$init_data->{'payby'}};
$packages = $init_data->{agentnum2part_pkg}{$agentnum} if $agentnum;
%pop = ();
%popnum2pop = ();
foreach (@$pops) {
  push @{ $pop{ $_->{state} }->{ $_->{ac} } }, $_;
  $popnum2pop{$_->{popnum}} = $_;
}

if ( defined $cgi->param('magic') ) {
  if ( $cgi->param('magic') eq 'process' ) {

    if ( $cgi->param('state') =~ /^(\w*)( \(([\w ]+)\))? ?\/ ?(\w+)$/ ) {
      $state = $1;
      $county = $3 || '';
      $country = $4;
    } elsif ( $cgi->param('state') =~ /^(\w*)$/ ) {
      $state = $1;
      $cgi->param('county') =~ /^([\w ]*)$/
        or die "illegal county: ". $cgi->param('county');
      $county = $1;
      $cgi->param('country') =~ /^(\w+)$/
        or die "illegal country: ". $cgi->param('country');
      $country = $1;
    } else {
      die "illegal state: ". $cgi->param('state');
    }
    if ( $cgi->param('ship_state') =~ /^(\w*)( \(([\w ]+)\))? ?\/ ?(\w+)$/ ) {
      $ship_state = $1;
      $ship_county = $3 || '';
      $ship_country = $4;
    } elsif ( $cgi->param('ship_state') =~ /^(\w*)$/ ) {
      $ship_state = $1;
      $cgi->param('ship_county') =~ /^([\w ]*)$/
        or die "illegal county: ". $cgi->param('ship_county');
      $ship_county = $1;
      $cgi->param('ship_country') =~ /^(\w+)$/
        or die "illegal ship_country: ". $cgi->param('ship_country');
      $ship_country = $1;
    #} else {
    #  die "illegal ship_state: ". $cgi->param('ship_state');
    }

    $payby = $cgi->param('payby');
    if ( $payby eq 'CHEK' || $payby eq 'DCHK' ) {
      #$payinfo = join('@', map { $cgi->param( $payby. "_payinfo$_" ) } (1,2) );
      $payinfo = $cgi->param($payby. '_payinfo1'). '@'. 
                 $cgi->param($payby. '_payinfo2');
    } else {
      $payinfo = $cgi->param( $payby. '_payinfo' );
    }
    $paydate =
      $cgi->param( $payby. '_month' ). '-'. $cgi->param( $payby. '_year' );
    $payname = $cgi->param( $payby. '_payname' );
    $paycvv = defined $cgi->param( $payby. '_paycvv' )
                ? $cgi->param( $payby. '_paycvv' )
                : '';

    if ( $invoicing_list = $cgi->param('invoicing_list') ) {
      $invoicing_list .= ', POST' if $cgi->param('invoicing_list_POST');
    } else {
      $invoicing_list = 'POST';
    }

    $error = '';

    $last             = $cgi->param('last');
    $first            = $cgi->param('first');
    $ss               = $cgi->param('ss');
    $company          = $cgi->param('company');
    $address1         = $cgi->param('address1');
    $address2         = $cgi->param('address2');
    $city             = $cgi->param('city');
    #$county,
    #$state,
    $zip              = $cgi->param('zip');
    #$country,
    $daytime          = $cgi->param('daytime');
    $night            = $cgi->param('night');
    $fax              = $cgi->param('fax');

    $ship_last        = $cgi->param('ship_last');
    $ship_first       = $cgi->param('ship_first');
    $ship_ss          = $cgi->param('ship_ss');
    $ship_company     = $cgi->param('ship_company');
    $ship_address1    = $cgi->param('ship_address1');
    $ship_address2    = $cgi->param('ship_address2');
    $ship_city        = $cgi->param('ship_city');
    #$ship_county,
    #$ship_state,
    $ship_zip         = $cgi->param('ship_zip');
    #$ship_country,
    $ship_daytime     = $cgi->param('ship_daytime');
    $ship_night       = $cgi->param('ship_night');
    $ship_fax         = $cgi->param('ship_fax');

    #$payby,
    #$payinfo,
    #$paydate,
    #$payname,
    #$invoicing_list,
    $referral_custnum = $cgi->param('ref');
    $pkgpart          = $cgi->param('pkgpart');
    $username         = $cgi->param('username');
    $sec_phrase       = $cgi->param('sec_phrase');
    $password         = $cgi->param('_password');
    $popnum           = $cgi->param('popnum');
    #$agentnum, #         = $cgi->param('agentnum'),
    $agentnum         ||= $cgi->param('agentnum');
    $init_popstate    = $cgi->param('init_popstate');
    $refnum           = $cgi->param('refnum');

    if ( $cgi->param('_password') ne $cgi->param('_password2') ) {
      $error = $init_data->{msgcat}{passwords_dont_match}; #msgcat
      $password  = '';
      $password2 = '';
    } else {
      $password2 = $cgi->param('_password2');

      if ( $payby =~ /^(CARD|DCRD)$/ && $cgi->param('CARD_type') ) {
        $payinfo =~ s/\D//g;

        $payinfo =~ /^(\d{13,16})$/
          or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
        $payinfo = $1;
        validate($payinfo)
          or $error ||= $init_data->{msgcat}{invalid_card}; #. $self->payinfo;
        cardtype($payinfo) eq $cgi->param('CARD_type')
          or $error ||= $init_data->{msgcat}{not_a}. $cgi->param('CARD_type');
      }

      unless ( $error ) {

        my $r = new_customer ( {
          'last'             => $last,
          'first'            => $first,
          'ss'               => $ss,
          'company'          => $company,
          'address1'         => $address1,
          'address2'         => $address2,
          'city'             => $city,
          'county'           => $county,
          'state'            => $state,
          'zip'              => $zip,
          'country'          => $country,
          'daytime'          => $daytime,
          'night'            => $night,
          'fax'              => $fax,
          'ship_last'        => $ship_last,
          'ship_first'       => $ship_first,
          'ship_company'     => $ship_company,
          'ship_address1'    => $ship_address1,
          'ship_address2'    => $ship_address2,
          'ship_city'        => $ship_city,
          'ship_county'      => $ship_county,
          'ship_state'       => $ship_state,
          'ship_zip'         => $ship_zip,
          'ship_country'     => $ship_country,
          'ship_daytime'     => $ship_daytime,
          'ship_night'       => $ship_night,
          'ship_fax'         => $ship_fax,
          'payby'            => $payby,
          'payinfo'          => $payinfo,
          'paycvv'           => $paycvv,
          'paydate'          => $paydate,
          'payname'          => $payname,
          'invoicing_list'   => $invoicing_list,
          'referral_custnum' => $referral_custnum,
          'promo_code'       => $cgi->param('promo_code'),
          'pkgpart'          => $pkgpart,
          'username'         => $username,
          'sec_phrase'       => $sec_phrase,
          '_password'        => $password,
          'popnum'           => $popnum,
          'agentnum'         => $agentnum,
          'refnum'           => $refnum,
          map { $_ => $cgi->param($_) } grep { /^snarf_/ } $cgi->param
        } );
        $error ||= $r->{'error'};

      }

    }
    
    if ( $error eq '_decline' ) {
      print_decline();
    } elsif ( $error ) {
      #fudge the snarf info
      no strict 'refs';
      ${$_} = $cgi->param($_) foreach grep { /^snarf_/ } $cgi->param;
      print_form();
    } else {
      print_okay();
    }

  } else {
    die "unrecognized magic: ". $cgi->param('magic');
  }
} else {
  #$error = '';
  $last = '';
  $first = '';
  $ss = '';
  $company = '';
  $address1 = '';
  $address2 = '';
  $city = '';
  $state = $init_data->{statedefault};
  $county = '';
  $country = $init_data->{countrydefault};
  $zip = '';
  $daytime = '';
  $night = '';
  $fax = '';
  $ship_last = '';
  $ship_first = '';
  $ship_company = '';
  $ship_address1 = '';
  $ship_address2 = '';
  $ship_city = '';
  $ship_state = $init_data->{statedefault};
  $ship_county = '';
  $ship_country = $init_data->{countrydefault};
  $ship_zip = '';
  $ship_daytime = '';
  $ship_night = '';
  $ship_fax = '';
  $invoicing_list = '';
  $payby = '';
  $payinfo = '';
  $paydate = '';
  $payname = '';
  $pkgpart = '';
  $username = '';
  $password = '';
  $password2 = '';
  $sec_phrase = '';
  $popnum = '';
  $referral_custnum = $cgi->param('ref') || '';
  $init_popstate = $cgi->param('init_popstate') || '';
  $refnum = $init_data->{'refnum'};
  print_form;
}

sub print_form {

  $cgi->delete('ref');
  $cgi->delete('init_popstate');
  $self_url = $cgi->self_url;

  $error = "Error: $error" if $error;

  print $cgi->header( '-expires' => 'now' ),
        $signup_template->fill_in();

}

sub print_decline {
  print $cgi->header( '-expires' => 'now' ),
        $decline_template->fill_in();
}

sub print_okay {
  my $user_agent = new HTTP::BrowserDetect $ENV{HTTP_USER_AGENT};

  $cgi->param('username') =~ /^(.+)$/
    or die "fatal: invalid username got past FS::SelfService::new_customer";
  my $username = $1;
  $cgi->param('_password') =~ /^(.+)$/
    or die "fatal: invalid password got past FS::SelfService::new_customer";
  my $password = $1;
  ( $cgi->param('first'). ' '. $cgi->param('last') ) =~ /^(.*)$/
    or die "fatal: invalid email_name got past FS::SelfService::new_customer";
  $email_name = $1; #global for template

  my $pop = $popnum2pop{$cgi->param('popnum')};
    #or die "fatal: invalid popnum got past FS::SelfService::new_customer";
  if ( $pop ) {
    ( $ac, $exch, $loc ) = ( $pop->{'ac'}, $pop->{'exch'}, $pop->{'loc'} );
  } else {
    ( $ac, $exch, $loc ) = ( '', '', ''); #presumably you're not using them.
  }

  #global for template
  $pkg = ( grep { $_->{'pkgpart'} eq $pkgpart } @$packages )[0]->{'pkg'};

  if ( $ieak_template && $user_agent->windows && $user_agent->ie ) {
    #send an IEAK config
    print $cgi->header('application/x-Internet-signup'),
          $ieak_template->fill_in();
  } else { #send a simple confirmation
    print $cgi->header( '-expires' => 'now' ),
          $success_template->fill_in();
  }
}

sub success_default { #html to use if you don't specify a success file
  <<'END';
<HTML><HEAD><TITLE>Signup successful</TITLE></HEAD>
<BODY BGCOLOR="#e8e8e8"><FONT SIZE=7>Signup successful</FONT><BR><BR>
Thanks for signing up!
<BR><BR>
Signup information for <%= $email_name %>:
<BR><BR>
Username: <%= $username %><BR>
Password: <%= $password %><BR>
Access number: (<%= $ac %>) / <%= $exch %> - <%= $local %><BR>
Package: <%= $pkg %><BR>
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

=item regionselector SELECTED_COUNTY, SELECTED_STATE, SELECTED_COUNTRY, PREFIX, ONCHANGE

=cut

sub regionselector {
  my ( $selected_county, $selected_state, $selected_country,
       $prefix, $onchange ) = @_;
  signup_info() unless $init_data;
  FS::SelfService::regionselector({
    selected_county  => $selected_county,
    selected_state   => $selected_state,
    selected_country => $selected_country,
    prefix           => $prefix,
    onchange         => $onchange,
    default_country  => $init_data->{countrydefault},
    locales          => $init_data->{cust_main_county},
  });
    #default_state    => $init_data->{statedefault},
}

=item popselector 

=cut

sub popselector {
  my( $popnum ) = @_;
  signup_info() unless $init_data;
  FS::SelfService::popselector({
    popnum => $popnum,
    pops   => $init_data->{svc_acct_pop},
  });
    #popac =>
    #acstate =>
}

