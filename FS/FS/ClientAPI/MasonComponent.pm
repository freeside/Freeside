package FS::ClientAPI::MasonComponent;

use strict;
use vars qw( $cache $DEBUG $me );
use subs qw( _cache );
use FS::Mason qw( mason_interps );
use FS::Conf;
use FS::ClientAPI_SessionCache;
use FS::Record qw(qsearchs);
use FS::cust_main;

$DEBUG = 0;
$me = '[FS::ClientAPI::MasonComponent]';

my %allowed_comps = map { $_=>1 } qw(
  /elements/select-did.html
  /misc/areacodes.cgi
  /misc/exchanges.cgi
  /misc/phonenums.cgi
  /misc/states.cgi
  /misc/counties.cgi
);

my %session_comps = map { $_=>1 } qw(
  /elements/location.html
);

my %session_callbacks = (
  '/elements/location.html' => sub {
    my( $custnum, $argsref ) = @_;
    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
      or return "unknown custnum $custnum";
    my %args = @$argsref;
    $args{object} = $cust_main;
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
