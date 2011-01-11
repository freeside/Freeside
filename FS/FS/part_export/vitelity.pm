package FS::part_export::vitelity;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::Record qw(qsearch dbh);
use FS::part_export;
use FS::phone_avail;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'login'         => { label=>'Vitelity API login' },
  'pass'          => { label=>'Vitelity API password' },
  'dry_run'       => { label=>"Test mode - don't actually provision" },
  'routesip'      => { label=>'routesip (optional sub-account)' },
  'type'	  => { label=>'type (optional DID type to order)' },
  'fax'      => { label=>'vfax service', type=>'checkbox' },
  'restrict_selection' => { type=>'select',
			    label=>'Restrict DID Selection', 
			    options=>[ '', 'tollfree', 'non-tollfree' ],
			 }
			    
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision phone numbers to Vitelity',
  'options' => \%options,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/Net-Vitelity">Net::Vitelity</a>
from CPAN.
<br><br>
routesip - optional Vitelity sub-account to which newly ordered DIDs will be routed
<br>type - optional DID type (perminute, unlimited, or your-pri)
END
);

sub rebless { shift; }

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
			    'state'	  => $opt{'state'},
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

sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #we want to provision and catch errors now, not queue

  my %vparams = ( 'did' => $svc_phone->phonenum );
  $vparams{'routesip'} = $self->option('routesip') 
    if defined $self->option('routesip');
  $vparams{'type'} = $self->option('type') 
    if defined $self->option('type');

  my $command = 'getlocaldid';
  my $success = 'success';

  # this is OK as Vitelity for now is US/CA only; it's not a hack
  $command = 'gettollfree' if $vparams{'did'} =~ /^800|^888|^877|^866|^855/;

  if($self->option('fax')) {
	$command = 'getdid';
	$success = 'ok';
  }
  
  my $result = $self->vitelity_command($command,%vparams);

  if ( $result ne $success ) {
    return "Error running Vitelity $command: $result";
  }

  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  # Call Forwarding
  if( $old->forwarddst ne $new->forwarddst ) {
      my $result = $self->vitelity_command('callfw',
	'did'           => $old->phonenum,
	'forward'	=> $new->forwarddst ? $new->forwarddst : 'none',
      );
      if ( $result ne 'ok' ) {
	return "Error running Vitelity callfw: $result";
      }
  }

  # vfax forwarding emails
  if( $old->email ne $new->email && $self->option('fax') ) {
      my $result = $self->vitelity_command('changeemail',
	'did'           => $old->phonenum,
	'emails'	=> $new->email ? $new->email : '',
      );
      if ( $result ne 'ok' ) {
	return "Error running Vitelity changeemail: $result";
      }
  }

  '';
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

1;

