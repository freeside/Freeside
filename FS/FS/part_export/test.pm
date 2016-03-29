package FS::part_export::test;

use strict;
use vars qw(%options %info);
use Tie::IxHash;
use base qw(FS::part_export);

tie %options, 'Tie::IxHash',
  'result'  => { label    => 'Result',
                 type     => 'select',
                 options  => [ 'success', 'failure', 'exception' ],
                 default  => 'success',
               },
  'errormsg'=> { label    => 'Error message',
                 default  => 'Test export' },
  'insert'  => { label    => 'Insert', type => 'checkbox', default => 1, },
  'delete'  => { label    => 'Delete', type => 'checkbox', default => 1, },
  'replace' => { label    => 'Replace',type => 'checkbox', default => 1, },
  'suspend' => { label    => 'Suspend',type => 'checkbox', default => 1, },
  'unsuspend'=>{ label => 'Unsuspend', type => 'checkbox', default => 1, },
  'get_dids_npa_select' => { label => 'DIDs by NPA', type => 'checkbox' },
;

%info = (
  'svc'     => [ qw(svc_acct svc_broadband svc_phone svc_domain) ],
  'desc'    => 'Test export for development',
  'options' => \%options,
  'notes'   => <<END,
<P>Test export.  Do not use this in production systems.</P>
<P>This export either always succeeds, always fails (returning an error),
or always dies, according to the "Result" option.  It does nothing else; the
purpose is purely to simulate success or failure within an export module.</P>
<P>The checkbox options can be used to turn the export off for certain
actions, if this is needed.</P>
<P>This export will produce a small set of DIDs, in either Alabama (if the
"DIDs by NPA" option is on) or California (if not).</P>
END
);

sub export_insert {
  my $self = shift;
  $self->run(@_) if $self->option('insert');
}

sub export_delete {
  my $self = shift;
  $self->run(@_) if $self->option('delete');
}

sub export_replace {
  my $self = shift;
  $self->run(@_) if $self->option('replace');
}

sub export_suspend {
  my $self = shift;
  $self->run(@_) if $self->option('suspend');
}

sub export_unsuspend {
  my $self = shift;
  $self->run(@_) if $self->option('unsuspend');
}

sub run {
  my $self = shift;
  my $svc_x = shift;
  my $result = $self->option('result');
  if ( $result eq 'failure' ) {
    return $self->option('errormsg');
  } elsif ( $result eq 'exception' ) {
    die $self->option('errormsg');
  } else {
    return '';
  }
}

sub can_get_dids { 1 }

sub get_dids_npa_select {
  my $self = shift;
  $self->option('get_dids_npa_select') ? 1 : 0;
}

# we don't yet have tollfree

my $dids_by_npa = {
  'states' => [ 'AK', 'AL' ],
  # states
  'AK' => [],
  'AL' => [ '205', '998', '999' ],
  # NPAs
  '205' => [ 'ALABASTER (205-555-XXXX)', # an NPA-NXX
             'EMPTY (205-998-XXXX)',
             'INVALID (205-999-XXXX)',
             'ALBERTVILLE, AL', # a ratecenter
           ],
  '998' => [],
  '999' => undef,
  # exchanges
  '205555' => 
    [
      '2055550101',
      '2055550102'
    ],
  '205998' => [],
  '205999' => undef,
  # ratecenters
  'ALBERTVILLE' => [
    '2055550111',
    '2055550112',
  ],
},

my $dids_by_region = {
  'states' => [ 'CA', 'CO' ],
  'CA' => [ 'CALIFORNIA',
            'EMPTY',
            'INVALID'
          ],
  'CO' => [],
  # regions
  'CALIFORNIA' => [
    '4155550200',
    '4155550201',
  ],
  'EMPTY' => [],
  'INVALID' => undef,
};

sub get_dids {
  my $self = shift;
  my %opt = @_;
  my $data = $self->get_dids_npa_select ? $dids_by_npa : $dids_by_region;

  my $key;
  if ( $opt{'exchange'} ) {
    $key = $opt{'areacode'} . $opt{'exchange'};
  } else {
    $key =    $opt{'ratecenter'}
          ||  $opt{'areacode'}
          ||  $opt{'region'}
          ||  $opt{'state'}
          ||  'states';
  }
  if ( defined $data->{ $key } ) {
    return $data->{ $key };
  } else {
    die "[test] '$key' is invalid\n";
  }
}

1;
