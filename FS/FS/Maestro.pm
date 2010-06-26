package FS::Maestro;

use Date::Format;
use FS::Conf;
use FS::Record qw( qsearchs );
use FS::cust_main;

sub customer_status {
  my( $custnum ) = shift; #@_;

  my $cust_main = qsearchs( 'cust_main' => { 'custnum' => $custnum } )
   or return { 'status' => 'E',
               'error'  => "$custnum not found" };

  my @cust_pkg = $cust_main->cust_pkg;

  my @cust_svc = map $_->cust_svc, @cust_pkg;

  ###
  # find $svc_pbx
  ##

  my @cust_svc_pbx =
    grep { my($n,$l,$t) = $_->label; $t eq 'svc_pbx' }
    @cust_svc;

  #i tried sofa king hard to explain to them why passing a custnum instead
  #of a conference id was a bad idea, but i can't make them understand...
  if ( ! @cust_svc_pbx ) {
    return { 'status' => 'E',
             'error'  => "customer $custnum has no conference service" };
  } elsif ( scalar(@cust_svc_pbx) > 1 ) {
    return { 'status' => 'E',
             'error'  => "customer $custnum has more than one conference service; there should be a way to specify which one you want",
           }; #maybe list them...  and work with a pkgnum
  }

  my $cust_svc_pbx = $cust_svc_pbx[0];

  my $svc_pbx = $cust_svc_pbx->svc_x;

  ###
  # find "outbound service" y/n
  ###

  my $conf = new FS::Conf;
  my %outbound_pkgs = map { $_=>1 } $conf->config('mc-outbound_packages');
  my $outbound_service =
    scalar( grep { $outbound_pkgs{ $_->pkgpart }
                     && !$_->get('cancel')
                 }
                 @cust_pkg
          )
    ? 1 : 0;

  ###
  # find "good till" date/time stamp
  ###

  my @active_cust_pkg =
    sort { $a->bill <=> $b->bill }
    grep { !$_->get('cancel') && $_->part_pkg->freq ne '0' }
    @cust_pkg;
  my $good_till =time2str('%c', $active_cust_pkg[0]->bill || time );

  ###
  # return the info
  ###

  { 
    'status' => substr($cust_main->ucfirst_status,0,1), #what they asked for..
    'name'   => $cust_main->name,
    'email'  => $cust_main->invoicing_list_emailonly_scalar,
    'max_lines'        => $svc_pbx ? $svc_pbx->max_extensions : '',
    'max_simultaneous' => $svc_pbx ? $svc_pbx->max_simultaneous : '',
    'outbound_service' => $outbound_service,
    'good_till' => $good_till,
    'products'  => [ map $_->pkgpart, grep !$_->get('cancel'), @cust_pkg ],
  };

}

1;
