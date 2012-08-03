package FS::ClientAPI::MasonComponent;

use strict;
use vars qw( $cache $DEBUG $me );
use subs qw( _cache );
use FS::Mason qw( mason_interps );
use FS::Conf;
use FS::ClientAPI_SessionCache;
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::part_pkg;

$DEBUG = 0;
$me = '[FS::ClientAPI::MasonComponent]';

my %allowed_comps = map { $_=>1 } qw(
  /elements/select-did.html
  /misc/areacodes.cgi
  /misc/exchanges.cgi
  /misc/phonenums.cgi
  /misc/states.cgi
  /misc/counties.cgi
  /misc/svc_acct-domains.cgi
  /misc/part_svc-columns.cgi
);

my %session_comps = map { $_=>1 } qw(
  /elements/location.html
  /elements/tr-amount_fee.html
  /edit/cust_main/first_pkg/select-part_pkg.html
);

my %session_callbacks = (

  '/elements/location.html' => sub {
    my( $custnum, $argsref ) = @_;
    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
      or return "unknown custnum $custnum";
    my %args = @$argsref;
    $args{object} = $cust_main->bill_location;
    @$argsref = ( %args );
    return ''; #no error
  },

  '/elements/tr-amount_fee.html' => sub {
    my( $custnum, $argsref ) = @_;

    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
      or return "unknown custnum $custnum";

    my $conf = new FS::Conf;

    my %args = @$argsref;
    %args = (
      %args,
      'process-pkgpart'    => scalar($conf->config('selfservice_process-pkgpart')),
      'process-display'    => scalar($conf->config('selfservice_process-display')),
      'process-skip-first' => $conf->exists('selfservice_process-skip_first'),
      'num_payments'       => scalar($cust_main->cust_pay), 
      'surcharge_percentage' => scalar($conf->config('credit-card-surcharge-percentage')),
    );
    @$argsref = ( %args );

    return ''; #no error
  },

  '/edit/cust_main/first_pkg/select-part_pkg.html' => sub {
    my( $custnum, $argsref ) = @_;
    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
      or return "unknown custnum $custnum";

    my $pkgpart = $cust_main->agent->pkgpart_hashref;

    #false laziness w/ edit/cust_main/first_pkg.html
    my @first_svc = ( 'svc_acct', 'svc_phone' );

    my @part_pkg =
      grep { $_->svcpart(\@first_svc)
             && ( $pkgpart->{ $_->pkgpart } 
                  || ( $_->agentnum && $_->agentnum == $cust_main->agentnum )
                )
           }
      qsearch( 'part_pkg', { 'disabled' => '' }, '', 'ORDER BY pkg' ); # case?

    my $conf = new FS::Conf;
    if ( $conf->exists('pkg-addon_classnum') ) {

      my %classnum = map  { ( $_->addon_classnum => 1 ) }
                     grep { $_->freq !~ /^0/ }
                     map  { $_->part_pkg }
                          $cust_main->ncancelled_pkgs;

      unless ( $classnum{''} || ! keys %classnum ) {
        @part_pkg = grep $classnum{ $_->classnum }, @part_pkg;
      }
    }

    my %args = @$argsref;
    $args{part_pkg} = \@part_pkg;
    $args{first_svc} = \@first_svc;
    @$argsref = ( %args );
    return ''; #no error

  },

);

my $outbuf;
my( $fs_interp, $rt_interp ) = mason_interps('standalone', 'outbuf'=>\$outbuf);

sub mason_comp {
  my $packet = shift;

  warn "$me mason_comp called on $packet\n" if $DEBUG;

  my $comp = $packet->{'comp'};
  unless ( $allowed_comps{$comp} || $session_comps{$comp} ) {
    return { 'error' => 'Illegal component' };
  }

  my @args = $packet->{'args'} ? @{ $packet->{'args'} } : ();

  if ( $session_comps{$comp} ) {

    my $session = _cache->get($packet->{'session_id'})
      or return ( 'error' => "Can't resume session" ); #better error message
    my $custnum = $session->{'custnum'};

    my $error = &{ $session_callbacks{$comp} }( $custnum, \@args );
    return { 'error' => $error } if $error;

  }

  my $conf = new FS::Conf;
  $FS::Mason::Request::FSURL = $conf->config('selfservice_server-base_url');
  $FS::Mason::Request::FSURL .= '/' unless $FS::Mason::Request::FSURL =~ /\/$/;
  $FS::Mason::Request::QUERY_STRING = $packet->{'query_string'} || '';

  $outbuf = '';
  $fs_interp->exec($comp, @args); #only FS for now alas...

  #errors? (turn off in-line error reporting?)

  return { 'output' => $outbuf };

}

#hmm
sub _cache {
  $cache ||= new FS::ClientAPI_SessionCache( {
               'namespace' => 'FS::ClientAPI::MyAccount',
             } );
}

1;
