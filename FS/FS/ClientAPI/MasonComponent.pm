package FS::ClientAPI::MasonComponent;

use strict;
use vars qw($DEBUG $me);
use FS::Mason qw( mason_interps );
use FS::Conf;

$DEBUG = 0;
$me = '[FS::ClientAPI::MasonComponent]';

my %allowed_comps = map { $_=>1 } qw(
  /elements/select-did.html
  /misc/areacodes.cgi
  /misc/exchanges.cgi
  /misc/phonenums.cgi
);

my $outbuf;
my( $fs_interp, $rt_interp ) = mason_interps('standalone', 'outbuf'=>\$outbuf);

sub mason_comp {
  my $packet = shift;

  warn "$me mason_comp called on $packet\n" if $DEBUG;

  my $comp = $packet->{'comp'};
  unless ( $allowed_comps{$comp} ) {
    return { 'error' => 'Illegal component' };
  }

  my @args = $packet->{'args'} ? @{ $packet->{'args'} } : ();

  my $conf = new FS::Conf;
  $FS::Mason::Request::FSURL = $conf->config('selfservice_server-base_url');
  $FS::Mason::Request::QUERY_STRING = $packet->{'query_string'} || '';

  $outbuf = '';
  $fs_interp->exec($comp, @args); #only FS for now alas...

  #errors? (turn off in-line error reporting?)

  return { 'output' => $outbuf };

}

1;
