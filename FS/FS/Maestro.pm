package FS::Maestro;

use strict;
use Date::Format;
use FS::Conf;
use FS::Record qw( qsearchs );
use FS::cust_main;
use FS::cust_pkg;
use FS::part_svc;

#i guess this is kind of deprecated in favor of service_status, but keeping it
#around until they say they don't need it.
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

  return service_status($svcnum) if $svcnum;

  ###
  # regular customer to maestro (single package)
  ###

  my %result = ();

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

  my $svc_pbx = $cust_svc_pbx->svc_x;

  # find "outbound service" y/n

  my $conf = new FS::Conf;
  my %outbound_pkgs = map { $_=>1 } $conf->config('mc-outbound_packages');
  $result{'outbound_service'} =
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
  $result{'good_till'} = time2str('%c', $active_cust_pkg[0]->bill || time );

  return { 
    'name'    => $cust_main->name,
    'email'   => $cust_main->invoicing_list_emailonly_scalar,
    #'agentnum' => $cust_main->agentnum,
    #'agent'    => $cust_main->agent->agent,
    'max_lines'        => $svc_pbx ? $svc_pbx->max_extensions : '',
    'max_simultaneous' => $svc_pbx ? $svc_pbx->max_simultaneous : '',
    %result,
  };

}

sub service_status {
  my $svcnum = shift;

  my $svc_pbx = qsearchs({
    'table'      => 'svc_pbx',
    'addl_from'  => ' LEFT JOIN cust_svc USING ( svcnum ) '.
                    ' LEFT JOIN cust_pkg USING ( pkgnum ) ',
    'hashref'   => { 'svcnum' => $svcnum },
    #'extra_sql' => " AND custnum = $custnum",
  })
    or return { 'status' => 'E',
                'error'  => "svcnum $svcnum not found" };

  my $cust_pkg = $svc_pbx->cust_svc->cust_pkg;
  my $cust_main = $cust_pkg->cust_main;

  my %result = ();

  #status in the reseller scenario
  $result{'status'} = substr($cust_pkg->ucfirst_status,0,1);
  $result{'status'} = 'A' if $result{'status'} eq 'N';

  # find "outbound service" y/n
  my @cust_pkg = $cust_main->cust_pkg;
  #XXX what about outbound service per-reseller ?
  my $conf = new FS::Conf;
  my %outbound_pkgs = map { $_=>1 } $conf->config('mc-outbound_packages');
  $result{'outbound_service'} =
    scalar( grep { $outbound_pkgs{ $_->pkgpart }
                     && !$_->get('cancel')
                 }
                 @cust_pkg
          )
    ? 1 : 0;

  # find "good till" date/time stamp (this package)
  $result{'good_till'} = time2str('%c', $cust_pkg->bill || time );

  return { 
    'custnum' => $cust_main->custnum,
    'name'    => ( $svc_pbx->title || $cust_main->name ),
    'email'   => $cust_main->invoicing_list_emailonly_scalar,
    #'agentnum' => $cust_main->agentnum,
    #'agent'    => $cust_main->agent->agent,
    'max_lines'        => $svc_pbx->max_extensions,
    'max_simultaneous' => $svc_pbx->max_simultaneous,
    %result,
  };

}

#some false laziness w/ MyAccount order_pkg
sub order_pkg {
  my $opt = ref($_[0]) ? shift : { @_ };

  $opt->{'title'} = delete $opt->{'name'}
    if !exists($opt->{'title'}) && exists($opt->{'name'});

  my $custnum = $opt->{'custnum'};

  my $curuser = $FS::CurrentUser::CurrentUser;

  my $cust_main = qsearchs({
    'table'     => 'cust_main',
    'hashref'   => { 'custnum' => $custnum },
    'extra_sql' => ' AND '. $curuser->agentnums_sql,
  })
    or return { 'error'  => "custnum $custnum not found" };

  my $status = $cust_main->status;
  #false laziness w/ClientAPI/Signup.pm

  my $cust_pkg = new FS::cust_pkg ( {
    'custnum' => $custnum,
    'pkgpart' => $opt->{'pkgpart'},
  } );
  my $error = $cust_pkg->check;
  return { 'error' => $error } if $error;

  my @svc = ();
  unless ( $opt->{'svcpart'} eq 'none' ) {

    my $svcpart = '';
    if ( $opt->{'svcpart'} =~ /^(\d+)$/ ) {
      $svcpart = $1;
    } else {
      $svcpart = $cust_pkg->part_pkg->svcpart; #($svcdb);
    }

    my $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
    return { 'error' => "Unknown svcpart $svcpart" } unless $part_svc;

    my $svcdb = $part_svc->svcdb;

    my %fields = (
      'svc_acct'     => [ qw( username domsvc _password sec_phrase popnum ) ],
      'svc_domain'   => [ qw( domain ) ],
      'svc_phone'    => [ qw( phonenum pin sip_password phone_name ) ],
      'svc_external' => [ qw( id title ) ],
      'svc_pbx'      => [ qw( id title ) ],
    );
  
    my $svc_x = "FS::$svcdb"->new( {
      'svcpart'   => $svcpart,
      map { $_ => $opt->{$_} } @{$fields{$svcdb}}
    } );
    
    #snarf processing not necessary here (or probably at all, anymore)
    
    my $y = $svc_x->setdefault; # arguably should be in new method
    return { 'error' => $y } if $y && !ref($y);
  
    $error = $svc_x->check;
    return { 'error' => $error } if $error;

    push @svc, $svc_x;

  }

  use Tie::RefHash;
  tie my %hash, 'Tie::RefHash';
  %hash = ( $cust_pkg => \@svc );
  #msgcat
  $error = $cust_main->order_pkgs( \%hash, 'noexport' => 1 );
  return { 'error' => $error } if $error;

# currently they're using this in the reseller scenario, so don't
# bill the package immediately
#  my $conf = new FS::Conf;
#  if ( $conf->exists('signup_server-realtime') ) {
#
#    my $bill_error = _do_bop_realtime( $cust_main, $status );
#
#    if ($bill_error) {
#      $cust_pkg->cancel('quiet'=>1);
#      return $bill_error;
#    } else {
#      $cust_pkg->reexport;
#    }
#
#  } else {
    $cust_pkg->reexport;
#  }

  my $svcnum = $svc[0] ? $svc[0]->svcnum : '';

  return { error=>'', pkgnum=>$cust_pkg->pkgnum, svcnum=>$svcnum };

}

1;
