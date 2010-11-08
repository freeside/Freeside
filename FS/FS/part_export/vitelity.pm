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

# currently one of three cases: areacode+exchange, areacode, state
# name == ratecenter

  my %search = ();

  my $method = '';

  if ( $opt{'areacode'} && $opt{'exchange'} ) { #return numbers in format NPA-NXX-XXXX

    return [
      map { join('-', $_->npa, $_->nxx, $_->station ) }
          qsearch({
            'table'    => 'phone_avail',
            'hashref'  => { 'exportnum'   => $self->exportnum,
                            'countrycode' => '1', # vitelity is US/CA only now
                            'state'       => $opt{'state'},
                            'npa'         => $opt{'areacode'},
                            'nxx'         => $opt{'exchange'},
                          },
            'order_by' => 'ORDER BY station',
          })
    ];

  } elsif ( $opt{'areacode'} ) { #return exchanges in format NPA-NXX- literal 'XXXX'

    return [
      map { $_->name. ' ('. $_->npa. '-'. $_->nxx. '-XXXX)' } 
          qsearch({
            'select'   => 'DISTINCT ON ( name, npa, nxx ) *',
            'table'    => 'phone_avail',
            'hashref'  => { 'exportnum'   => $self->exportnum,
                            'countrycode' => '1', # vitelity is US/CA only now
                            'state'       => $opt{'state'},
                            'npa'         => $opt{'areacode'},
                          },
            'order_by' => 'ORDER BY nxx',
          })
    ];

  } elsif ( $opt{'state'} ) { #and not other things, then return areacode

    #XXX need to flush the cache at some point :/

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

    my @ratecenters = $self->vitelity_command( 'listavailratecenters',
                                                 'state' => $opt{'state'}, 
                                             );
    # XXX: Options: type=unlimited OR type=pri

    if ( $ratecenters[0] eq 'unavailable' ) {
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

      my @dids = $self->vitelity_command( 'listlocal',
                                            'state'      => $opt{'state'},
                                            'ratecenter' => $ratecenter,
                                        );
    # XXX: Options: type=unlimited OR type=pri

      if ( $dids[0] eq 'unavailable' ) {
        next;
      } elsif ( $dids[0] eq 'missingdata' ) {
        die "missingdata error running Vitelity API"; #die?
      }

      foreach my $did ( @dids ) {
        $did =~ /^(\d{3})(\d{3})(\d{4})$/ or die "unparsable did $did\n";
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

        $error = $phone_avail->insert();
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          die $errmsg.$error;
        }

      }

    }

    $dbh->commit or warn $errmsg.$dbh->errstr if $oldAutoCommit;

    my @return = sort { $a <=> $b } keys %npa;
    #@return = sort { (split(' ', $a))[0] <=> (split(' ', $b))[0] } @return;

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
    #'debug'    => $debug,
  );

  $vitelity->$command(@args);
}

sub _export_insert {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #we want to provision and catch errors now, not queue

  %vparams = ( 'did' => $svc_phone->phonenum );
  $vparams{'routesip'} = $self->option('routesip') 
    if defined $self->option('routesip');
  $vparams{'type'} = $self->option('type') 
    if defined $self->option('type');

  my $result = $self->vitelity_command('getlocaldid',%vparams);

  if ( $result ne 'success' ) {
    return "Error running Vitelity getlocaldid: $result";
  }

  '';
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  #hmm, what's to change?
  '';
}

sub _export_delete {
  my( $self, $svc_phone ) = (shift, shift);

  return '' if $self->option('dry_run');

  #probably okay to queue the deletion...?
  #but hell, let's do it inline anyway, who wants phone numbers hanging around

  my $result = $self->vitelity_command('removedid',
    'did'           => $svc_phone->phonenum,
  );

  if ( $result ne 'success' ) {
    return "Error running Vitelity getlocaldid: $result";
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

