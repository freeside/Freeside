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
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision phone numbers to Vitelity',
  'options' => \%options,
  'notes'   => <<'END'
Requires installation of
<a href="http://search.cpan.org/dist/Net-Vitelity">Net::Vitelity</a>
from CPAN.
END
);

sub rebless { shift; }

sub get_dids {
  my $self = shift;
  my %opt = ref($_[0]) ? %{$_[0]} : @_;

  my %search = ();
  #  'orderby' => 'npa', #but it doesn't seem to work :/

  my $method = '';

  if ( $opt{'areacode'} && $opt{'exchange'} ) { #return numbers

    return [
      map { join('-', $_->npx, $_->nxx, $_->station ) }
          qsearch({
            'table'    => 'phone_avail',
            'hashref'  => { 'exportnum'   => $self->exportnum,
                            'countrycode' => '1',
                            'state'       => $opt{'state'},
                            'npa'         => $opt{'areacode'},
                            'nxx'         => $opt{'exchange'},
                          },
            'order_by' => 'ORDER BY name', #?
          })
    ];

  } elsif ( $opt{'areacode'} ) { #return city (npa-nxx-XXXX)

    return [
      map { $_->name. ' ('. $_->npa. '-'. $_->nxx. '-XXXX)' } 
          qsearch({
            'select'   => 'DISTINCT ON ( name, npa, nxx ) *',
            'table'    => 'phone_avail',
            'hashref'  => { 'exportnum'   => $self->exportnum,
                            'countrycode' => '1',
                            'state'       => $opt{'state'},
                            'npa'         => $opt{'areacode'},
                          },
            'order_by' => 'ORDER BY name', #?
          })
    ];

  } elsif ( $opt{'state'} ) { #and not other things, then return areacode

    #XXX need to flush the cache at some point :/

    my @avail = qsearch({
      'select'   => 'DISTINCT npa',
      'table'    => 'phone_avail',
      'hashref'  => { 'exportnum'   => $self->exportnum,
                      'countrycode' => '1', #don't hardcode me when gp goes intl
                      'state'       => $opt{'state'},
                    },
      'order_by' => 'ORDER BY npa',
    });

    return [ map $_->npa, @avail ] if @avail; #return cached area codes instead

    #otherwise, search for em

    my @ratecenters = $self->vitelity_command( 'listavailratecenters',
                                                 'state' => $opt{'state'}, 
                                             );

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
          'countrycode' => '1', #don't hardcode me when vitelity goes int'l
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

  my $result = $self->vitelity_command('getlocaldid',
    'did'           => $svc_phone->phonenum,
#XXX
#Options: type=perminute OR type=unlimited OR type=your-pri OR
#               routesip=route_to_this_subaccount
  );

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

