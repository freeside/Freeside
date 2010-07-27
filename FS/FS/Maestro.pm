package FS::Maestro;

use Date::Format;
use FS::Conf;
use FS::Record qw( qsearchs );
use FS::cust_main;

sub customer_status {
  my( $custnum ) = shift; #@_;
  my $svcnum = @_ ? shift : '';

  my $curuser = $FS::CurrentUser::CurrentUser;

  my $cust_main = qsearchs({
    'table'     => 'cust_main',
    'hashref'   => { 'custnum' => $custnum },
    'extra_sql' => ' AND '. $curuser->agentnums_sql,
  })
    or return { 'status' => 'E',
                'error'  => "custnum $custnum not found" };

  my( $svc_pbx, $good_till, $outbound_service ) = ( '', '', '' );
  my %result = ();
  if ( $svcnum ) {
   
    ###
    # reseller scenario to maestro (customer w/ multiple packages)
    ###

    # find $svc_pbx

    $svc_pbx = qsearchs({
      'table'      => 'svc_pbx',
      'addl_from'  => ' LEFT JOIN cust_svc USING ( svcnum ) '.
                      ' LEFT JOIN cust_pkg USING ( pkgnum ) ',
      'hashref'   => { 'svcnum' => $svcnum },
      'extra_sql' => " AND custnum = $custnum",
    })
      or return { 'status' => 'E',
                  'error'  => "svcnum $svcnum not found" };

    #status in the reseller scenario

    my $cust_pkg = $svc_pbx->cust_svc->cust_pkg;

    $result{'status'} = substr($cust_pkg->ucfirst_status,0,1);

    # find "outbound service" y/n

    #XXX outbound service per-reseller ?
    #my @cust_pkg = $cust_main->cust_pkg;
    #
    #my $conf = new FS::Conf;
    #my %outbound_pkgs = map { $_=>1 } $conf->config('mc-outbound_packages');
    #my $outbound_service =
    #  scalar( grep { $outbound_pkgs{ $_->pkgpart }
    #                   && !$_->get('cancel')
    #               }
    #               @cust_pkg
    #        )
    #  ? 1 : 0;

    # find "good till" date/time stamp (this package)

    $good_till  = time2str('%c', $cust_pkg->bill || time );

  } else {

    ###
    # regular customer to maestro (single package)
    ###

    my @cust_pkg = $cust_main->cust_pkg;

    #things specific to the non-reseller scenario

    $result{'status'} = substr($cust_main->ucfirst_status,0,1);

    $result{'products'} =
      [ map $_->pkgpart, grep !$_->get('cancel'), @cust_pkg ];

    #find svc_pbx

    my @cust_svc = map $_->cust_svc, @cust_pkg;

    my @cust_svc_pbx =
      grep { my($n,$l,$t) = $_->label; $t eq 'svc_pbx' }
      @cust_svc;

    if ( ! @cust_svc_pbx ) {
      return { 'status' => 'E',
               'error'  => "customer $custnum has no conference service" };
    } elsif ( scalar(@cust_svc_pbx) > 1 ) {
      return { 'status' => 'E',
               'error'  =>
                 "customer $custnum has more than one conference".
                 " service (reseller?); specify a svcnum as a second argument",
             };
    }

    my $cust_svc_pbx = $cust_svc_pbx[0];

    $svc_pbx = $cust_svc_pbx->svc_x;

    # find "outbound service" y/n

    my $conf = new FS::Conf;
    my %outbound_pkgs = map { $_=>1 } $conf->config('mc-outbound_packages');
    $outbound_service =
      scalar( grep { $outbound_pkgs{ $_->pkgpart }
                       && !$_->get('cancel')
                   }
                   @cust_pkg
            )
      ? 1 : 0;

    # find "good till" date/time stamp

    my @active_cust_pkg =
      sort { $a->bill <=> $b->bill }
      grep { !$_->get('cancel') && $_->part_pkg->freq ne '0' }
      @cust_pkg;
    $good_till = time2str('%c', $active_cust_pkg[0]->bill || time );

  }

  return { 
    'name'   => $cust_main->name,
    'email'  => $cust_main->invoicing_list_emailonly_scalar,
    'max_lines'        => $svc_pbx ? $svc_pbx->max_extensions : '',
    'max_simultaneous' => $svc_pbx ? $svc_pbx->max_simultaneous : '',
    'outbound_service' => $outbound_service,
    'good_till' => $good_till,
    %result,
  };

}

1;
