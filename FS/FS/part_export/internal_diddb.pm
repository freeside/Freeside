package FS::part_export::internal_diddb;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::Record qw(qsearch qsearchs);
use FS::part_export;
use FS::phone_avail;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'countrycode' => { label => 'Country code', 'default' => '1', },
;

%info = (
  'svc'     => 'svc_phone',
  'desc'    => 'Provision phone numbers from the internal DID database',
  'notes'   => 'After adding the export, DIDs may be imported under Tools -> Importing -> Import phone numbers (DIDs)',
  'options' => \%options,
);

sub rebless { shift; }

sub get_dids {
  my $self = shift;
  my %opt = ref($_[0]) ? %{$_[0]} : @_;

  my %hash = ( 'countrycode' => $self->option('countrycode'),
               'exportnum'   => $self->exportnum,
               'svcnum'      => '',
             );

  if ( $opt{'areacode'} && $opt{'exchange'} ) { #return numbers

    $hash{npa} = $opt{areacode};
    $hash{nxx} = $opt{exchange};

    return [ map { $_->npa. '-'. $_->nxx. '-'. $_->station }
                 qsearch({ 'table'    => 'phone_avail',
                           'hashref'  => \%hash,
                           'order_by' => 'ORDER BY station',
                        })
           ];

  } elsif ( $opt{'areacode'} ) { #return city (npa-nxx-XXXX)

    $hash{npa} = $opt{areacode};

    return [ map { '('. $_->npa. '-'. $_->nxx. '-XXXX)' }
                 qsearch({ 'select'   => 'DISTINCT npa, nxx',
                           'table'    => 'phone_avail',
                           'hashref'  => \%hash,
                           'order_by' => 'ORDER BY nxx',
                        })
           ];

  } elsif ( $opt{'state'} ) { #return aracodes

    $hash{state} = $opt{state};

    return [ map { $_->npa }
                 qsearch({ 'select'   => 'DISTINCT npa',
                           'table'    => 'phone_avail',
                           'hashref'  => \%hash,
                           'order_by' => 'ORDER BY npa',
                        })
           ];

  } else { 
    die "FS::part_export::internal_diddb::get_dids called without options\n";
  }

}

sub _export_insert   { #link phone_avail to svcnum
  my( $self, $svc_phone ) = (shift, shift);

  $svc_phone->phonenum =~ /^(\d{3})(\d{3})(\d+)$/
    or return "unparsable phone number: ". $svc_phone->phonenum;
  my( $npa, $nxx, $station ) = ($1, $2, $3);

  my $phone_avail = qsearchs('phone_avail', {
    'countrycode' => $self->option('countrycode'),
    'exportnum'   => $self->exportnum,
    'svcnum'      => '',
    'npa'         => $npa,
    'nxx'         => $nxx,
    'station'     => $station,
  });

  return "number not available: ". $svc_phone->phonenum
    unless $phone_avail;

  $phone_avail->svcnum($svc_phone->svcnum);

  $phone_avail->replace;

}

sub _export_delete   { #unlink phone_avail from svcnum
  my( $self, $svc_phone ) = (shift, shift);

  $svc_phone =~ /^(\d{3})(\d{3})(\d+)$/
    or return "unparsable phone number: ". $svc_phone->phonenum;
  my( $npa, $nxx, $station ) = ($1, $2, $3);

  my $phone_avail = qsearchs('phone_avail', {
    'countrycode' => $self->option('countrycode'),
    'exportnum'   => $self->exportnum,
    'svcnum'      => $svc_phone->svcnum,
    #these too?
    'npa'         => $npa,
    'nxx'         => $nxx,
    'station'     => $station,
  });

  unless ( $phone_avail ) {
    warn "WARNING: can't find number to return to availability: ".
         $svc_phone->phonenum;
    return;
  }

  $phone_avail->svcnum('');

  $phone_avail->replace;

}

sub _export_replace  { ''; }
sub _export_suspend  { ''; }
sub _export_unsuspend  { ''; }

1;

