package FS::ClientAPI::Signup;

use strict;
use Tie::RefHash;
use FS::Conf;
use FS::Record qw(qsearch qsearchs);
use FS::agent;
use FS::cust_main_county;
use FS::part_pkg;
use FS::svc_acct_pop;
use FS::cust_main;
use FS::cust_pkg;
use FS::Msgcat qw(gettext);

use FS::ClientAPI; #hmm
FS::ClientAPI->register_handlers(
  'Signup/signup_info'  => \&signup_info,
  'Signup/new_customer' => \&new_customer,
);

sub signup_info {
  #my $packet = shift;

  my $conf = new FS::Conf;

  my $signup_info = {

    'cust_main_county' =>
      [ map { $_->hashref } qsearch('cust_main_county', {}) ],

    'agentnum2part_pkg' =>
      {
        map {
          my $href = $_->pkgpart_hashref;
          $_->agentnum =>
            [
              map { { 'payby' => [ $_->payby ], %{$_->hashref} } }
                grep { $_->svcpart('svc_acct') && $href->{ $_->pkgpart } }
                  qsearch( 'part_pkg', { 'disabled' => '' } )
            ];
        } qsearch('agent', {} )
      },

    'svc_acct_pop' => [ map { $_->hashref } qsearch('svc_acct_pop',{} ) ],

    'security_phrase' => $conf->exists('security_phrase'),

    'payby' => [ $conf->config('signup_server-payby') ],

    'msgcat' => { map { $_=>gettext($_) } qw(
      passwords_dont_match invalid_card unknown_card_type not_a
    ) },

    'statedefault' => $conf->config('statedefault') || 'CA',

    'countrydefault' => $conf->config('countrydefault') || 'US',

  };

  if ( $conf->config('signup_server-default_agentnum') ) {
    my $agentnum = $conf->config('signup_server-default_agentnum');
    my $agent = qsearchs( 'agent', { 'agentnum' => $agentnum } )
      or die "fatal: signup_server-default_agentnum $agentnum not found\n";
    my $pkgpart_href = $agent->pkgpart_hashref;

    $signup_info->{'part_pkg'} = [
      #map { $_->hashref }
      map { { 'payby' => [ $_->payby ], %{$_->hashref} } }
        grep { $_->svcpart('svc_acct') && $pkgpart_href->{ $_->pkgpart } }
          qsearch( 'part_pkg', { 'disabled' => '' } )
    ];
  }

  $signup_info;

}

sub new_customer {
  my $packet = shift;

  my $conf = new FS::Conf;
  my $error = '';
  
  #things that aren't necessary in base class, but are for signup server
    #return "Passwords don't match"
    #  if $hashref->{'_password'} ne $hashref->{'_password2'}
  $error ||= gettext('empty_password') unless $packet->{'_password'};
  # a bit inefficient for large numbers of pops
  $error ||= gettext('no_access_number_selected')
    unless $packet->{'popnum'} || !scalar(qsearch('svc_acct_pop',{} ));

  #shares some stuff with htdocs/edit/process/cust_main.cgi... take any
  # common that are still here and library them.
  my $cust_main = new FS::cust_main ( {
    #'custnum'          => '',
    'agentnum'      => $packet->{agentnum}
                       || $conf->config('signup_server-default_agentnum'),
    'refnum'        => $packet->{refnum}
                       || $conf->config('signup_server-default_refnum'),

    map { $_ => $packet->{$_} } qw(
      last first ss company address1 address2 city county state zip country
      daytime night fax payby payinfo paydate payname referral_custnum comments
    ),

  } );

  $error ||= "Illegal payment type"
    unless grep { $_ eq $packet->{'payby'} }
                $conf->config('signup_server-payby');

  $cust_main->payinfo($cust_main->daytime)
    if $cust_main->payby eq 'LECB' && ! $cust_main->payinfo;

  my @invoicing_list = split( /\s*\,\s*/, $packet->{'invoicing_list'} );

  $packet->{'pkgpart'} =~ /^(\d+)$/ or '' =~ /^()$/;
  my $pkgpart = $1;

  my $part_pkg =
    qsearchs( 'part_pkg', { 'pkgpart' => $pkgpart } )
      or $error ||= "WARNING: unknown pkgpart: $pkgpart";
  my $svcpart = $part_pkg->svcpart('svc_acct') unless $error;

  my $cust_pkg = new FS::cust_pkg ( {
    #later#'custnum' => $custnum,
    'pkgpart' => $packet->{'pkgpart'},
  } );
  $error ||= $cust_pkg->check;

  my $svc_acct = new FS::svc_acct ( {
    'svcpart'   => $svcpart,
    map { $_ => $packet->{$_} }
      qw( username _password sec_phrase popnum ),
  } );

  my $y = $svc_acct->setdefault; # arguably should be in new method
  $error ||= $y unless ref($y);

  $error ||= $svc_acct->check;

  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash';
  %hash = ( $cust_pkg => [ $svc_acct ] );
  #msgcat
  $error ||= $cust_main->insert( \%hash, \@invoicing_list, 'noexport' => 1 );

  if ( ! $error && $conf->exists('signup_server-realtime') ) {

    #warn "[fs_signup_server] Billing customer...\n" if $Debug;

    my $bill_error = $cust_main->bill;
    #warn "[fs_signup_server] error billing new customer: $bill_error"
    #  if $bill_error;

    $cust_main->apply_payments;
    $cust_main->apply_credits;

    $bill_error = $cust_main->collect;
    #warn "[fs_signup_server] error collecting from new customer: $bill_error"
    #  if $bill_error;

    if ( $cust_main->balance > 0 ) {

      #this makes sense.  credit is "un-doing" the invoice
      $cust_main->credit( $cust_main->balance, 'signup server decline' );
      $cust_main->apply_credits;

      #should check list for errors...
      #$cust_main->suspend;
      local $FS::svc_Common::noexport_hack = 1;
      $cust_main->cancel;

      $error = '_decline';
    }

  }
  $cust_main->reexport unless $error;

  return { error => $error };

}

