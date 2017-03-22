package FS::part_export::vitelity;
use base qw( FS::part_export );

use vars qw( %info );
use Tie::IxHash;
use Geo::StreetAddress::US;
use FS::Record qw( qsearch dbh );
use FS::phone_avail;
use FS::svc_phone;

tie my %options, 'Tie::IxHash',
  'login'              => { label=>'Vitelity API login' },
  'pass'               => { label=>'Vitelity API password' },
  'routesip'           => { label=>'routesip (optional sub-account)' },
  'type'               => { label=>'type (optional DID type to order)' },
  'fax'                => { label=>'vfax service', type=>'checkbox' },
  'restrict_selection' => { type    => 'select',
                            label   => 'Restrict DID Selection', 
                            options => [ '', 'tollfree', 'non-tollfree' ],
                          },
  'dry_run'            => { label => "Test mode - don't actually provision",
                            type  => 'checkbox',
                          },
  'disable_e911'       => { label => "Disable E911 provisioning",
                            type  => 'checkbox',
                          },
;

%info = (
  'svc'        => 'svc_phone',
  'desc'       => 'Provision phone numbers to Vitelity',
  'options'    => \%options,
  'no_machine' => 1,
  'notes'      => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/Net-Vitelity">Net::Vitelity</a>
from CPAN.
<br><br>
routesip - optional Vitelity sub-account to which newly ordered DIDs will be routed
<br>type - optional DID type (perminute, unlimited, or your-pri)
END
);

sub rebless { shift; }

sub can_get_dids { 1; }
sub get_dids_can_tollfree { 1; };
sub can_lnp { 1; }

sub get_dids {
  my $self = shift;
  my %opt = ref($_[0]) ? %{$_[0]} : @_;

  if ( $opt{'tollfree'} ) {
    my $command = 'listtollfree';
    $command = 'listdids' if $self->option('fax');
    my @tollfree = $self->vitelity_command($command);
    my @ret = ();

    return [] if ( $tollfree[0] eq 'noneavailable' || $tollfree[0] eq 'none');

    foreach my $did ( @tollfree ) {
        $did =~ /^(\d{3})(\d{3})(\d{4})/ or die "unparsable did $did\n";
        push @ret, $did;
    }

    my @sorted_ret = sort @ret;
    return \@sorted_ret;

  } elsif ( $opt{'ratecenter'} && $opt{'state'} ) { 

    my %flushopts = ( 'state' => $opt{'state'}, 
                    'ratecenter' => $opt{'ratecenter'},
                    'exportnum' => $self->exportnum
                  );
    FS::phone_avail::flush( \%flushopts );
      
    local $SIG{HUP} = 'IGNORE';
    local $SIG{INT} = 'IGNORE';
    local $SIG{QUIT} = 'IGNORE';
    local $SIG{TERM} = 'IGNORE';
    local $SIG{TSTP} = 'IGNORE';
    local $SIG{PIPE} = 'IGNORE';

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;

    my $errmsg = 'WARNING: error populating phone availability cache: ';

    my $command = 'listlocal';
    $command = 'listdids' if $self->option('fax');
    my @dids = $self->vitelity_command( $command,
                                        'state'      => $opt{'state'},
                                        'ratecenter' => $opt{'ratecenter'},
                                      );
    # XXX: Options: type=unlimited OR type=pri

    next if ( $dids[0] eq 'unavailable'  || $dids[0] eq 'noneavailable' );
    die "missingdata error running Vitelity API" if $dids[0] eq 'missingdata';

    foreach my $did ( @dids ) {
      $did =~ /^(\d{3})(\d{3})(\d{4})/ or die "unparsable did $did\n";
      my($npa, $nxx, $station) = ($1, $2, $3);

      my $phone_avail = new FS::phone_avail {
          'exportnum'   => $self->exportnum,
          'countrycode' => '1', # vitelity is US/CA only now
          'state'       => $opt{'state'},
          'npa'         => $npa,
          'nxx'         => $nxx,
          'station'     => $station,
          'name'        => $opt{'ratecenter'},
      };

      my $error = $phone_avail->insert();
      if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          die $errmsg.$error;
      }

    }
    $dbh->commit or warn $errmsg.$dbh->errstr if $oldAutoCommit;

    return [
      map { join('-', $_->npa, $_->nxx, $_->station ) }
          qsearch({
            'table'    => 'phone_avail',
            'hashref'  => { 'exportnum'   => $self->exportnum,
                            'countrycode' => '1', # vitelity is US/CA only now
                            'name'         => $opt{'ratecenter'},
                            'state'          => $opt{'state'},
                          },
            'order_by' => 'ORDER BY npa, nxx, station',
          })
    ];

  } elsif ( $opt{'areacode'} ) { 

    my @rc = map { $_->{'Hash'}->{name}.", ".$_->state } 
          qsearch({
            'select'   => 'DISTINCT name, state',
            'table'    => 'phone_avail',
            'hashref'  => { 'exportnum'   => $self->exportnum,
                            'countrycode' => '1', # vitelity is US/CA only now
                            'npa'         => $opt{'areacode'},
                          },
          });

    my @sorted_rc = sort @rc;
    return [ @sorted_rc ];

  } elsif ( $opt{'state'} ) { #and not other things, then return areacode

    my @avail = qsearch({
      'select'   => 'DISTINCT npa',
      'table'    => 'phone_avail',
      'hashref'  => { 'exportnum'   => $self->exportnum,
                      'countrycode' => '1', # vitelity is US/CA only now
                      'state'       => $opt{'state'},
                    },
      'order_by' => 'ORDER BY npa',
    });

    return [ map $_->npa, @avail ] if @avail; #return cached area codes instead

    #otherwise, search for em

    my $command = 'listavailratecenters';
    $command = 'listratecenters' if $self->option('fax');
    my @ratecenters = $self->vitelity_command( $command,
                                                 'state' => $opt{'state'}, 
                                             );
    # XXX: Options: type=unlimited OR type=pri

    if ( $ratecenters[0] eq 'unavailable' || $ratecenters[0] eq 'none' ) {
      return [];
    } elsif ( $ratecenters[0] eq 'missingdata' ) {
      die "missingdata error running Vitelity API"; #die?
    }

    local $SIG{HUP} = 'IGNORE';
    local $SIG{INT} = 'IGNORE';
    local $SIG{QUIT} = 'IGNORE';
    local $SIG{TERM} = 'IGNORE';
    local $SIG{TSTP} = 'IGNORE';
    local $SIG{PIPE} = 'IGNORE';

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;

    my $errmsg = 'WARNING: error populating phone availability cache: ';

    my %npa = ();
    foreach my $ratecenter (@ratecenters) {

     my $command = 'listlocal';
      $command = 'listdids' if $self->option('fax');
      my @dids = $self->vitelity_command( $command,
                                            'state'      => $opt{'state'},
                                            'ratecenter' => $ratecenter,
                                        );
    # XXX: Options: type=unlimited OR type=pri

      if ( $dids[0] eq 'unavailable'  || $dids[0] eq 'noneavailable' ) {
        next;
      } elsif ( $dids[0] eq 'missingdata' ) {
        die "missingdata error running Vitelity API"; #die?
      }

      foreach my $did ( @dids ) {
        $did =~ /^(\d{3})(\d{3})(\d{4})/ or die "unparsable did $did\n";
        my($npa, $nxx, $station) = ($1, $2, $3);
        $npa{$npa}++;

        my $phone_avail = new FS::phone_avail {
          'exportnum'   => $self->exportnum,
          'countrycode' => '1', # vitelity is US/CA only now
          'state'       => $opt{'state'},
          'npa'         => $npa,
          'nxx'         => $nxx,
          'station'     => $station,
          'name'        => $ratecenter,
        };

        my $error = $phone_avail->insert();
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          die $errmsg.$error;
        }

      }

    }

    $dbh->commit or warn $errmsg.$dbh->errstr if $oldAutoCommit;

    my @return = sort { $a <=> $b } keys %npa;
    return \@return;

  } else {
    die "get_dids called without state or areacode options";
  }

}

sub vitelity_command {
  my( $self, $command, @args ) = @_;

  eval "use Net::Vitelity;";
  die $@ if $@;

  my $vitelity = Net::Vitelity->new(
    'login' => $self->option('login'),
    'pass'  => $self->option('pass'),
    'apitype' => $self->option('fax') ? 'fax' : 'api',
    #'debug'    => $debug,
  );

  $vitelity->$command(@args);
}

sub vitelity_lnp_command {
  my( $self, $command, @args ) = @_;

  eval "use Net::Vitelity 0.04;";
  die $@ if $@;

  my $vitelity = Net::Vitelity->new(
    'login'   => $self->option('login'),
    'pass'    => $self->option('pass'),
    'apitype' => 'lnp',
    #'debug'   => $debug,
  );

  $vitelity->$command(@args);
}

sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #we want to provision and catch errors now, not queue

  #porting a number in?  different code path
  if ( $svc_phone->lnp_status eq 'portingin' ) {

    my %location = $svc_phone->location_hash;
    my $sa = Geo::StreetAddress::US->parse_location( $location{'address1'} );

    my $result = $self->vitelity_lnp_command('addport',
      'portnumber'    => $svc_phone->phonenum,
      'partial'       => 'no',
      'wireless'      => 'no',
      'carrier'       => $svc_phone->lnp_other_provider,
      'company'       => $svc_phone->cust_svc->cust_pkg->cust_main->company,
      'accnumber'     => $svc_phone->lnp_other_provider_account,
      'name'          => $svc_phone->phone_name_or_cust,
      'streetnumber'  => $sa->{number},
      'streetprefix'  => $sa->{prefix},
      'streetname'    => $sa->{street}. ' '. $street{type},
      'streetsuffix'  => $sa->{suffix},
      'unit'          => ( $sa->{sec_unit_num}
                             ? $sa->{sec_unit_type}. ' '. $sa->{sec_unit_num}
                             : ''
                         ),
      'city'          => $location{'city'},
      'state'         => $location{'state'},
      'zip'           => $location{'zip'},
      'billnumber'    => $svc_phone->phonenum, #?? do we need a new field for this?
      'contactnumber' => $svc_phone->cust_svc->cust_pkg->cust_main->daytime,
    );

    if ( $result =~ /^ok:/i ) {
      my($ok, $portid, $sig, $bill) = split(':', $result);
      $svc_phone->lnp_portid($portid);
      $svc_phone->lnp_signature('Y') if $sig  =~ /y/i;
      $svc_phone->lnp_bill('Y')      if $bill =~ /y/i;
      return $svc_phone->replace;
    } else {
      return "Error initiating Vitelity port: $result";
    }

  }

  ###
  # 1. provision the DID
  ###

  my %vparams = ( 'did' => $svc_phone->phonenum );
  $vparams{'routesip'} = $self->option('routesip') 
    if defined $self->option('routesip');
  $vparams{'type'} = $self->option('type') 
    if defined $self->option('type');

  my $command = 'getlocaldid';
  my $success = 'success';

  # this is OK as Vitelity for now is US/CA only; it's not a hack
  $command = 'gettollfree' if $vparams{'did'} =~ /^800|^888|^877|^866|^855/;

  if ($self->option('fax')) {
    $command = 'getdid';
    $success = 'ok';
  }
  
  my $result = $self->vitelity_command($command,%vparams);

  if ( $result ne $success ) {
    return "Error running Vitelity $command: $result";
  }

  ###
  # 2. Provision CNAM
  ###

  my $cnam_result = $self->vitelity_command('cnamenable',
                                              'did'=>$svc_phone->phonenum,
                                           );
  if ( $result ne 'ok' ) {
    #we already provisioned the DID, so...
    warn "Vitelity error enabling CNAM for ". $svc_phone->phonenum. ": $result";
  }

  ###
  # 3. Provision E911
  ###

  my $e911_error = $self->e911_send($svc_phone);

  if ( $e911_error =~ /^(missingdata|invalid)/i ) {
    #but we already provisioned the DID, so:
    $self->vitelity_command('removedid', 'did'=> $svc_phone->phonenum,);
    #and check the results?  if it failed, then what?

    return $e911_error;
  }

  '';
}

sub e911send {
  my($self, $svc_phone) = (shift, shift);

  return '' if $self->option('disable_e911');

  my %location = $svc_phone->location_hash;
  my %e911send = (
    'did'     => $svc_phone->phonenum,
    'name'    => $svc_phone->phone_name_or_cust,
    'address' => $location{'address1'},
    'city'    => $location{'city'},
    'state'   => $location{'state'},
    'zip'     => $location{'zip'},
  );
  if ( $location{address2} =~ /^\s*(\w+)\W*(\d+)\s*$/ ) {
    $e911send{'unittype'} = $1;
    $e911send{'unitnumber'} = $2;
  }

  my $e911_result = $self->vitelity_command('e911send', %e911send);

  return '' unless $result =~ /^(missingdata|invalid)/i;

  return "Vitelity error provisioning E911 for". $svc_phone->phonenum.
           ": $result";
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  # Call Forwarding
  if( $old->forwarddst ne $new->forwarddst ) {
      my $result = $self->vitelity_command('callfw',
        'did'           => $old->phonenum,
        'forward'        => $new->forwarddst ? $new->forwarddst : 'none',
      );
      if ( $result ne 'ok' ) {
        return "Error running Vitelity callfw: $result";
      }
  }

  # vfax forwarding emails
  if( $old->email ne $new->email && $self->option('fax') ) {
      my $result = $self->vitelity_command('changeemail',
        'did'           => $old->phonenum,
        'emails'        => $new->email ? $new->email : '',
      );
      if ( $result ne 'ok' ) {
        return "Error running Vitelity changeemail: $result";
      }
  }

  $self->e911_send($new);
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #probably okay to queue the deletion...?
  #but hell, let's do it inline anyway, who wants phone numbers hanging around

  return 'Deleting vfax DIDs is unsupported by Vitelity API' if $self->option('fax');

  my $result = $self->vitelity_command('removedid',
    'did'           => $svc_phone->phonenum,
  );

  if ( $result ne 'success' ) {
    return "Error running Vitelity removedid: $result";
  }

  return '' if $self->option('disable_e911');

  '';
}

sub _export_suspend {
  my( $self, $svc_phone ) = (shift, shift);
  #nop for now
  '';
}

sub _export_unsuspend {
  my( $self, $svc_phone ) = (shift, shift);
  #nop for now
  '';
}

sub check_lnp {
  my $self = shift;

  my $in_svcpart = 'IN ('. join( ',', map $_->svcpart, $self->export_svc). ')';

  foreach my $svc_phone (
    qsearch({ 'table'     => 'svc_phone',
              'hashref'   => {lnp_status=>'portingin'},
              'extra_sql' => "AND svcpart $in_svcpart",
           })
  ) {

    my $result = $self->vitelity_lnp_command('checkstatus',
                                               'portid'=>$svc_phone->lnp_portid,
                                            );

    if ( $result =~ /^Complete/i ) {

      $svc_phone->lnp_status('portedin');
      my $error = $self->_export_insert($svc_phone);
      if ( $error ) {
        #XXX log this using our internal log instead, so we can alert on it
        # properly
        warn "ERROR provisioning ported-in DID ". $svc_phone->phonenum. ": $error";
      } else {
        $error = $svc_phone->replace; #to set the lnp_status
        #XXX log this using our internal log instead, so we can alert on it
        warn "ERROR setting lnp_status for DID ". $svc_phone->phonenum. ": $error" if $error;
      }

    } elsif ( $result ne $svc_phone->lnp_reject_reason ) {
      $svc_phone->lnp_reject_reason($result);
      $error = $svc_phone->replace;
      #XXX log this using our internal log instead, so we can alert on it
      warn "ERROR setting lnp_reject_reason for DID ". $svc_phone->phonenum. ": $error" if $error;

    }

  }

}

1;

