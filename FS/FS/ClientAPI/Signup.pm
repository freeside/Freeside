package FS::ClientAPI::Signup;

use strict;
use Tie::RefHash;
use FS::Conf;
use FS::Record qw(qsearch qsearchs dbdef);
use FS::Msgcat qw(gettext);
use FS::agent;
use FS::cust_main_county;
use FS::part_pkg;
use FS::svc_acct_pop;
use FS::cust_main;
use FS::cust_pkg;
use FS::svc_acct;
use FS::acct_snarf;
use FS::queue;

use FS::ClientAPI; #hmm
FS::ClientAPI->register_handlers(
  'Signup/signup_info'  => \&signup_info,
  'Signup/new_customer' => \&new_customer,
);

sub signup_info {
  #my $packet = shift;

  my $conf = new FS::Conf;

  use vars qw($signup_info); #cache for performance;
  $signup_info ||= {

    'cust_main_county' =>
      [ map { $_->hashref } qsearch('cust_main_county', {}) ],

    'agent' =>
      [
        map { $_->hashref }
          qsearch('agent', dbdef->table('agent')->column('disabled')
                             ? { 'disabled' => '' }
                             : {}
                 )
      ],

    'part_referral' =>
      [
        map { $_->hashref }
          qsearch('part_referral',
                    dbdef->table('part_referral')->column('disabled')
                      ? { 'disabled' => '' }
                      : {}
                 )
      ],

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
        } qsearch('agent', dbdef->table('agent')->column('disabled')
                             ? { 'disabled' => '' }
                             : {}
                 )
      },

    'svc_acct_pop' => [ map { $_->hashref } qsearch('svc_acct_pop',{} ) ],

    'security_phrase' => $conf->exists('security_phrase'),

    'payby' => [ $conf->config('signup_server-payby') ],

    'cvv_enabled' => defined dbdef->table('cust_main')->column('paycvv'),

    'msgcat' => { map { $_=>gettext($_) } qw(
      passwords_dont_match invalid_card unknown_card_type not_a
    ) },

    'statedefault' => $conf->config('statedefault') || 'CA',

    'countrydefault' => $conf->config('countrydefault') || 'US',

    'refnum' => $conf->config('signup_server-default_refnum'),

  };

  if (
    $conf->config('signup_server-default_agentnum')
    && !exists $signup_info->{'part_pkg'} #cache for performance
  ) {
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
  
  #things that aren't necessary in base class, but are for signup server
    #return "Passwords don't match"
    #  if $hashref->{'_password'} ne $hashref->{'_password2'}
  return { 'error' => gettext('empty_password') }
    unless $packet->{'_password'};
  # a bit inefficient for large numbers of pops
  return { 'error' => gettext('no_access_number_selected') }
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
      daytime night fax payby payinfo paycvv paydate payname referral_custnum
      comments
    ),

  } );

  return { 'error' => "Illegal payment type" }
    unless grep { $_ eq $packet->{'payby'} }
                $conf->config('signup_server-payby');

  $cust_main->payinfo($cust_main->daytime)
    if $cust_main->payby eq 'LECB' && ! $cust_main->payinfo;

  my @invoicing_list = split( /\s*\,\s*/, $packet->{'invoicing_list'} );

  $packet->{'pkgpart'} =~ /^(\d+)$/ or '' =~ /^()$/;
  my $pkgpart = $1;
  return { 'error' => 'Please select a package' } unless $pkgpart; #msgcat

  my $part_pkg =
    qsearchs( 'part_pkg', { 'pkgpart' => $pkgpart } )
      or return { 'error' => "WARNING: unknown pkgpart: $pkgpart" };
  my $svcpart = $part_pkg->svcpart('svc_acct');

  my $cust_pkg = new FS::cust_pkg ( {
    #later#'custnum' => $custnum,
    'pkgpart' => $packet->{'pkgpart'},
  } );
  my $error = $cust_pkg->check;
  return { 'error' => $error } if $error;

  my $svc_acct = new FS::svc_acct ( {
    'svcpart'   => $svcpart,
    map { $_ => $packet->{$_} }
      qw( username _password sec_phrase popnum ),
  } );

  my @acct_snarf;
  my $snarfnum = 1;
  while (    exists($packet->{"snarf_machine$snarfnum"})
          && length($packet->{"snarf_machine$snarfnum"}) ) {
    my $acct_snarf = new FS::acct_snarf ( {
      'machine'   => $packet->{"snarf_machine$snarfnum"},
      'protocol'  => $packet->{"snarf_protocol$snarfnum"},
      'username'  => $packet->{"snarf_username$snarfnum"},
      '_password' => $packet->{"snarf_password$snarfnum"},
    } );
    $snarfnum++;
    push @acct_snarf, $acct_snarf;
  }
  $svc_acct->child_objects( \@acct_snarf );

  my $y = $svc_acct->setdefault; # arguably should be in new method
  return { 'error' => $y } if $y && !ref($y);

  $error = $svc_acct->check;
  return { 'error' => $error } if $error;

  #setup a job dependancy to delay provisioning
  my $placeholder = new FS::queue ( {
    'job'    => 'FS::ClientAPI::Signup::__placeholder',
    'status' => 'locked',
  } );
  $error = $placeholder->insert;
  return { 'error' => $error } if $error;

  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash';
  %hash = ( $cust_pkg => [ $svc_acct ] );
  #msgcat
  $error = $cust_main->insert(
    \%hash,
    \@invoicing_list,
    'depend_jobnum' => $placeholder->jobnum,
  );
  if ( $error ) {
    my $perror = $placeholder->delete;
    $error .= " (Additionally, error removing placeholder: $perror)" if $perror;
    return { 'error' => $error };
  }

  if ( $conf->exists('signup_server-realtime') ) {

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
      $cust_main->cancel('quiet'=>1);

      my $perror = $placeholder->depended_delete;
      warn "error removing provisioning jobs after decline: $perror" if $perror;
      unless ( $perror ) {
        $perror = $placeholder->delete;
        warn "error removing placeholder after decline: $perror" if $perror;
      }

      return { 'error' => '_decline' };
    }

  }

  $error = $placeholder->delete;
  return { 'error' => $error } if $error;

  return { error => '' };

}

1;
