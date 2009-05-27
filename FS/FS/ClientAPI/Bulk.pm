package FS::ClientAPI::Bulk;

use strict;

use vars qw( $DEBUG $cache );
use Date::Parse;
use FS::Record qw( qsearchs );
use FS::Conf;
use FS::ClientAPI_SessionCache;
use FS::cust_main;
use FS::cust_pkg;
use FS::cust_svc;
use FS::svc_acct;
use FS::svc_external;
use FS::cust_recon;
use Data::Dumper;

$DEBUG = 1;

sub _cache {
  $cache ||= new FS::ClientAPI_SessionCache ( {
               'namespace' => 'FS::ClientAPI::Agent', #yes, share session_ids
             } );
}

sub _izoom_ftp_row_fixup {
  my $hash = shift;

  my @addr_fields = qw( address1 address2 city state zip );
  my @fields = ( qw( agent_custid username _password first last ),
                 @addr_fields,
                 map { "ship_$_" } @addr_fields );

  $hash->{$_} =~ s/[&\/\*'"]/_/g foreach @fields;

  #$hash->{action} = '' if $hash->{action} eq 'R'; #unsupported for ftp

  $hash->{refnum} = 1;  #ahem
  $hash->{country} = 'US';
  $hash->{ship_country} = 'US';
  $hash->{payby} = 'LECB';
  $hash->{payinfo} = $hash->{daytime};
  $hash->{ship_fax} = '' if ( !$hash->{sms} ||  $hash->{sms} eq 'F' );

  my $has_ship =
    grep { $hash->{"ship_$_"} &&
           (! $hash->{$_} || $hash->{"ship_$_"} ne $hash->{$_} )
         }
    ( @addr_fields, 'fax' );

  if ( $has_ship )  {
    foreach ( @addr_fields, qw( first last ) ) {
      $hash->{"ship_$_"} = $hash->{$_} unless $hash->{"ship_$_"};
    }
  }
    
  delete $hash->{sms};

  '';

};

sub _izoom_ftp_result {
  my ($hash, $error) = @_;
  my $cust_main =
      qsearchs( 'cust_main', { 'agent_custid' => $hash->{agent_custid},
                               'agentnum'     => $hash->{agentnum}
                             }
              );

  my $custnum = $cust_main ? $cust_main->custnum : '';
  my @response = ( $hash->{action}, $hash->{agent_custid}, $custnum );

  if ( $error ) {
    push @response, ( 'ERROR', $error );
  } else {
    push @response, ( 'OK', 'OK' );
  }

  join( ',', @response );

}

sub _izoom_ftp_badaction {
  "Invalid action: $_[0] record: @_ ";
}

sub _izoom_soap_row_fixup { _izoom_ftp_row_fixup(@_) };

sub _izoom_soap_result {
  my ($hash, $error) = @_;

  if ( $hash->{action} eq 'R' ) {
    if ( $error ) {
      return "Please check errors:\n $error"; # odd extra space
    } else {
      return join(' ', "Everything ok.", $hash->{pkg}, $hash->{adjourn} );
    }
  }

  my $pkg = $hash->{pkg} || $hash->{saved_pkg} || '';
  if ( $error ) {
    return join(' ', $hash->{agent_custid}, $error );
  } else {
    return join(' ', $hash->{agent_custid}, $pkg, $hash->{adjourn} );
  }

}

sub _izoom_soap_badaction {
  "Unknown action '$_[13]' ";
}

my %format = (
  'izoom-ftp'  => {
                    'fields' => [ qw ( action agent_custid username _password
                                       daytime ship_fax sms first last
                                       address1 address2 city state zip
                                       pkg adjourn ship_address1 ship_address2
                                       ship_city ship_state ship_zip ) ],
                    'fixup'  =>  sub { _izoom_ftp_row_fixup(@_) },
                    'result' =>  sub { _izoom_ftp_result(@_) },
                    'action' =>  sub { _izoom_ftp_badaction(@_) },
                  },
  'izoom-soap' => {
                    'fields' => [ qw ( agent_custid username _password
                                       daytime first last address1 address2
                                       city state zip pkg action adjourn
                                       ship_fax sms ship_address1 ship_address2
                                       ship_city ship_state ship_zip ) ],
                    'fixup'  =>  sub { _izoom_soap_row_fixup(@_) },
                    'result' =>  sub { _izoom_soap_result(@_) },
                    'action' =>  sub { _izoom_soap_badaction(@_) },
                  },
);

sub processrow {
  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $conf = new FS::Conf;
  my $format = $conf->config('selfservice-bulk_format', $session->{agentnum})
               || 'izoom-soap';
  my ( @row ) = @{ $p->{row} };

  warn "processrow called with '". join("' '", @row). "'\n" if $DEBUG;

  return { 'error' => "unknown format: $format" }
    unless exists $format{$format};

  return { 'error' => "Invalid record record length: ". scalar(@row).
                      "record: @row " #sic
         }
    unless scalar(@row) == scalar(@{$format{$format}{fields}});

  my %hash = ( 'agentnum' => $session->{agentnum} );
  my $error;

  foreach my $field ( @{ $format{ $format }{ fields } } ) {
    $hash{$field} = shift @row;
  }

  $error ||= &{ $format{ $format }{ fixup } }( \%hash );
  
  # put in the fixup routine?
  if ( 'R' eq $hash{action} ) {
    warn "processing reconciliation\n" if $DEBUG;
    $error ||= process_recon($hash{agentnum}, $hash{agent_custid});
  } elsif ( 'P' eq $hash{action} ) {
    #  do nothing
  } elsif( 'D' eq $hash{action} ) {
    $hash{promo_pkg} = 'disk-1-'. $session->{agent};
  } elsif ( 'S' eq $hash{action} ) {
    $hash{promo_pkg} = 'disk-2-'. $session->{agent};
    $hash{saved_pkg} = $hash{pkg};
    $hash{pkg} = '';
  } else {
    $error ||= &{ $format{ $format }{ action } }( @row );
  }

  warn "processing provision\n" if ($DEBUG && !$error && $hash{action} ne 'R');
  $error ||= provision( %hash ) unless $hash{action} eq 'R';

  my $result =  &{ $format{ $format }{ result } }( \%hash, $error );

  warn "processrow returning '". join("' '", $result, $error). "'\n"
    if $DEBUG;

  return { 'error' => $error, 'message' => $result };

}

sub provision {
  my %args = ( @_ );

  delete $args{action};

  my $cust_main =
    qsearchs( 'cust_main',
              { map { $_ => $args{$_} } qw ( agent_custid agentnum ) },
            );

  unless ( $cust_main ) {
    $cust_main = new FS::cust_main { %args };
    my $error = $cust_main->insert;
    return $error if $error;
  }

  my @pkgs = grep { $_->part_pkg->freq } $cust_main->ncancelled_pkgs;
  if ( scalar(@pkgs) > 1 ) {
    return "Invalid account, should not be more then one active package ". #sic
           "but found: ". scalar(@pkgs). " packages.";
  }

  my $part_pkg = qsearchs( 'part_pkg', { 'pkg' => $args{pkg} } ) 
    or return "Unknown pkgpart: $args{pkg}"
    if $args{pkg};


  my $create_package = $args{pkg};        
  if ( scalar(@pkgs) && $create_package ) {        
    my $pkg = pop(@pkgs);
        
    if ( $part_pkg->pkgpart != $pkg->pkgpart ) {
      my @cust_bill_pkg = $pkg->cust_bill_pkg();
      if ( 1 == scalar(@cust_bill_pkg) ) {
        my $cbp= pop(@cust_bill_pkg);
        my $cust_bill = $cbp->cust_bill;
        $cust_bill->delete();  #really?  wouldn't a credit be better?
      }
      $pkg->cancel();
    } else {
      $create_package = '';
      $pkg->setfield('adjourn', str2time($args{adjourn}));
      my $error = $pkg->replace();
      return $error if $error;
    }
  }

  if ( $create_package ) {
    my $cust_pkg = new FS::cust_pkg ( {
        'pkgpart' => $part_pkg->pkgpart,
        'adjourn' => str2time( $args{adjourn} ),
    } );

    my $svcpart = $part_pkg->svcpart('svc_acct');

    my $svc_acct = new FS::svc_acct ( {
        'svcpart'   => $svcpart,
        'username'  => $args{username},
        '_password' => $args{_password},
    } );

    my $error = $cust_main->order_pkg( cust_pkg => $cust_pkg,
                                       svcs     => [ $svc_acct ],
    );
    return $error if $error;
  }
    
  if ( $args{promo_pkg} ) {
    my $part_pkg =
    qsearchs( 'part_pkg', { 'promo_code' =>  $args{promo_pkg} } )
      or return "unknown pkgpart: $args{promo_pkg}";
            
    my $svcpart = $part_pkg->svcpart('svc_external')
      or return "unknown svcpart: svc_external";

    my $cust_pkg = new FS::cust_pkg ( {
      'svcpart' => $svcpart,
      'pkgpart' => $part_pkg->pkgpart,
    } );

    my $svc_ext = new FS::svc_external ( { 'svcpart'   => $svcpart } );
    
    my $ticket_subject = 'Send setup disk to customer '. $cust_main->custnum;
    my $error = $cust_main->order_pkg ( cust_pkg       => $cust_pkg,
                                        svcs           => [ $svc_ext ],
                                        noexport       => 1,
                                        ticket_subject => $ticket_subject,
                                        ticket_queue   => "disk-$args{agentnum}",
    );
    return $error if $error;
  }

  my $error = $cust_main->bill();
  return $error if $error;
}

sub process_recon {
  my ( $agentnum, $id ) = @_;
  my @recs = split /;/, $id;
  my $err = '';
  foreach my $rec ( @recs ) {
    my @record = split /,/, $rec;
    my $result = process_recon_record(@record, $agentnum);
    $err .= "$result\n" if $result;
  }
  return $err;
}

sub process_recon_record {
  my ( $agent_custid, $username, $_password, $daytime, $first, $last, $address1, $address2, $city, $state, $zip, $pkg, $adjourn, $agentnum) = @_;

  warn "process_recon_record called with '". join("','", @_). "'\n" if $DEBUG;

  my ($cust_pkg, $package);

  my $cust_main =
    qsearchs( 'cust_main',
              { 'agent_custid' => $agent_custid, 'agentnum' => $agentnum },
            );

  my $comments = '';
  if ( $cust_main ) {
    my @cust_pkg = grep { $_->part_pkg->freq } $cust_main->ncancelled_pkgs;
    if ( scalar(@cust_pkg) == 1) {
      $cust_pkg = pop(@cust_pkg);
      $package = $cust_pkg->part_pkg->pkg;
      $comments = "$agent_custid wrong package, expected: $pkg found: $package"
        if ( $pkg ne $package );
    } else {
      $comments = "invalid account, should be one active package but found: ".
                 scalar(@cust_pkg). " packages.";
    }
  } else {
    $comments =
      "Customer not found agent_custid=$agent_custid, agentnum=$agentnum";
  }

  my $cust_recon = new FS::cust_recon( {
    'recondate'     => time,
    'agentnum'      => $agentnum,
    'first'         => $first,
    'last'          => $last,
    'address1'      => $address1,
    'address2'      => $address2,
    'city'          => $city,
    'state'         => $state,
    'zip'           => $zip,
    'custnum'       => $cust_main ? $cust_main->custnum : '', #really?
    'status'        => $cust_main ? $cust_main->status : '',
    'pkg'           => $package,
    'adjourn'       => $cust_pkg ? $cust_pkg->adjourn : '',
    'agent_custid'  => $agent_custid, # redundant?
    'agent_pkg'     => $pkg,
    'agent_adjourn' => str2time($adjourn),
    'comments'      => $comments,
  } );

  warn Dumper($cust_recon) if $DEBUG;
  my $error = $cust_recon->insert;
  return $error if $error;

  warn "process_recon_record returning $comments\n" if $DEBUG;

  $comments;

}

sub check_username {
  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $svc_domain = qsearchs( 'svc_domain', { 'domain' => $p->{domain} } )
    or return { 'error' => 'Unknown domain '. $p->{domain} };

  my $svc_acct = qsearchs( 'svc_acct', { 'username' => $p->{user},
                                         'domsvc'   => $svc_domain->svcnum,
                                       },
                         );

  return { 'error' => $p->{user}. '@'. $p->{domain}. " alerady in use" } # sic
    if $svc_acct;

  return { 'error'   => '',
           'message' => $p->{user}. '@'. $p->{domain}. " is free"
  };
}

1;
