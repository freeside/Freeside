package FS::part_export::tower_towercoverage;

use strict;
use base qw( FS::part_export );
use FS::Record qw(qsearch qsearchs dbh);
use FS::hardware_class;
use FS::hardware_type;

use vars qw( %options %info
             %frequency_id %antenna_type_id );

use Color::Scheme;
use LWP::UserAgent;
use XML::LibXML::Simple qw(XMLin);
use Data::Dumper;

# note this is not https
our $base_url = 'http://api.towercoverage.com/towercoverage.asmx/';

our $DEBUG = 0;
our $me = '[towercoverage.com]';

sub debug {
  warn "$me ".join("\n",@_)."\n"
    if $DEBUG;
}

# hardware class to use for antenna defs
my $classname = 'TowerCoverage.com antenna';

tie %options, 'Tie::IxHash', (
  'debug'       => { label => 'Enable debugging', type => 'checkbox' },

  'Account'     => { label  => 'Account ID' },
  'key'         => { label  => 'API key' },
  'use_coverage'  => { label => 'Enable coverage maps', type => 'checkbox' },
  'FrequencyID' => { label    => 'Frequency band',
                     type     => 'select',
                     options  => [ keys(%frequency_id) ],
                     option_labels => \%frequency_id,
                   },
  'MaximumRange'  => { label => 'Maximum range (miles)', default => '10' },
  '1'           => { type => 'title', label => 'Client equipment' },
  'ClientAverageAntennaHeight' => { label => 'Typical antenna height (feet)' },
  'ClientAntennaGain'   => { label => 'Antenna gain (dB)' },
  'RxLineLoss'          => { label => 'Line loss (dB)',
                             default => 0,
                           },
  '2'           => { type => 'title', label => 'Performance requirements' },
  'WeakRxThreshold'     => { label => 'Low quality (dBm)', },
  'StrongRxThreshold'   => { label => 'High quality (dBm)', },
  'RequiredReliability' => { label => 'Reliability %',
                             default => 70
                           },
);

%info = (
  'svc'     => [qw( tower_sector )],
  'desc'    => 'TowerCoverage.com coverage mapping and site qualification',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => <<'END',
Export tower/sector configurations to TowerCoverage.com for coverage map
generation.
END
);

sub insert {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  my $error = $self->SUPER::insert(@_);
  return $error if $error;

  my $hwclass = _hardware_class();
  if (!$hwclass) {

    $hwclass = FS::hardware_class->new({ classname => $classname });
    $error = $hwclass->insert;
    if ($error) {
      dbh->rollback if $oldAutoCommit;
      return "error creating hardware class for antenna types: $error";
    }

    foreach my $id (keys %antenna_type_id) {
      my $name = $antenna_type_id{$id};
      my $hardware_type = FS::hardware_type->new({
        classnum  => $hwclass->classnum,
        model     => $name,
        title     => $id,
      });
      $error = $hardware_type->insert;
      if ($error) {
        dbh->rollback if $oldAutoCommit;
        return "error creating hardware class for antenna types: $error";
      }
    }
  }
  dbh->commit if $oldAutoCommit;
  '';
}

sub export_insert {
  my ($self, $sector) = @_;

  return unless $self->option('use_coverage');
  local $DEBUG = $self->option('debug') ? 1 : 0;

  my $tower = $sector->tower;
  my $height_m = sprintf('%.0f', ($sector->height || $tower->height) / 3.28);
  my $clientheight_m = sprintf('%.0f', $self->option('ClientAverageAntennaHeight') / 3.28);
  my $maximumrange_km = sprintf('%.0f', $self->option('MaximumRange') * 1.61);
  my $strongmargin = $self->option('StrongRxThreshold')
                   - $self->option('WeakRxThreshold');

  my $scheme = Color::Scheme->new->from_hex($tower->color || '00FF00');

  my $antenna = qsearchs('hardware_type', {
    typenum => $sector->hardware_typenum
  });
  return "antenna type required" unless $antenna;

  # - ALL parameters must be present (or it throws a generic 500 error).
  # - ONLY Coverageid and TowerSiteid are allowed to be empty.
  # - ALL parameter names are case sensitive.
  # - ALL numeric parameters are required to be integers, except for the
  #   coordinates, line loss factors, and center frequency.
  # - Export options (like RxLineLoss) have a problem where if they're set
  #   to numeric zero, they get removed; make sure we actually send zero.
  my $data = [
    'Account'                     => $self->option('Account'),
    'key'                         => $self->option('key'),
    'Coverageid'                  => $sector->title,
    'Coveragename'                => $sector->description,
    'TowerSiteid'                 => '',
    'Latitude'                    => $tower->latitude,
    'Longitude'                   => $tower->longitude,
    'AntennaHeight'               => $height_m,
    'ClientAverageAntennaHeight'  => $clientheight_m,
    'ClientAntennaGain'           => $self->option('ClientAntennaGain'),
    'RxLineLoss'                  => sprintf('%.1f', $self->option('RxLineLoss')),
    'AntennaType'                 => $antenna->title,
    'AntennaAzimuth'              => int($sector->direction),
    # note that TowerCoverage bases their coverage map on the antenna
    # radiation pattern, not on this number.
    'BeamwidthFilter'             => $sector->width,
    'AntennaTilt'                 => int($sector->downtilt),
    'AntennaGain'                 => int($sector->antenna_gain),
    'Frequency'                   => $self->option('FrequencyID'),
    'ExactCenterFrequency'        => $sector->freq_mhz,
    'TXPower'                     => int($sector->power),
    'TxLineLoss'                  => sprintf('%.1f', $sector->line_loss),
    'RxThreshold'                 => $self->option('WeakRxThreshold'),
    'RequiredReliability'         => $self->option('RequiredReliability'),
    'StrongSignalMargin'          => $strongmargin,
    'StrongSignalColor'           => ($scheme->colors)[0],
    'WeakSignalColor'             => ($scheme->colors)[2],
    'Opacity'                     => 50,
    'MaximumRange'                => $maximumrange_km,
    # this could be selectable but there's no reason to do that
    'RenderingQuality'            => 3,
    'UseLandCover'                => 1,
    'UseTwoRays'                  => 1,
    'CreateViewshed'              => 0,
  ];
  debug Dumper($data);
  $self->http_queue(
    'action'    => 'insert',
    'path'      => 'CoverageAPI',
    'sectornum' => $sector->sectornum,
    'data'      => $data
  );

}

sub export_replace { # do the same thing as insert
  my $self = shift;
  $self->export_insert(@_);
}

sub export_delete { '' }

=item http_queue

Queue a job to send an API request.
Takes arguments:
'action'    => what we're doing (for triggering after_* callback)
'path'      => the path under TowerCoverage.asmx/
'sectornum' => the sectornum
'data'      => arrayref/hashref of params to send 
to which it will add
'exportnum' => the exportnum

=cut
 
sub http_queue {
  my $self = shift;
  my $queue = new FS::queue { 'job' => "FS::part_export::tower_towercoverage::http" };
  return $queue->insert(
    exportnum => $self->exportnum,
    @_
  );
}

sub http {
  my %params = @_;
  my $self = FS::part_export->by_key($params{'exportnum'});
  local $DEBUG = $self->option('debug') ? 1 : 0;

  local $FS::tower_sector::noexport_hack = 1; # avoid recursion

  my $url = $base_url . $params{'path'};

  my $ua = LWP::UserAgent->new;

  # URL is the same for insert and replace.
  my $req = HTTP::Request::Common::POST( $url, $params{'data'} );
  debug("sending $url", $req->content);
  my $response = $ua->request($req);

  die $response->error_as_HTML if $response->is_error;
  debug "received ".$response->decoded_content;

  # throws exception on parse error
  my $response_data = XMLin($response->decoded_content);
  my $method = "after_" . $params{action};
  if ($self->can($method)) {
    # should be some kind of event handler, that would be sweet
    my $sector = FS::tower_sector->by_key($params{'sectornum'});
    $self->$method($sector, $response_data);
  }
}

sub after_insert {
  my ($self, $sector, $data) = @_;
  my ($png_path, $kml_path) = split("\n", $data->{content});
  die "$me no coverage map paths in response\n" unless $png_path;
  if ( $png_path =~ /(\d+).png$/ ) {
    $sector->set('title', $1);
    my $error = $sector->replace;
    die $error if $error;
  } else {
    die "$me can't parse map path '$png_path'\n";
  }
}

sub _hardware_class {
  qsearchs( 'hardware_class', { classname => $classname });
}

sub get_antenna_types {
  my $hardware_class = _hardware_class() or return;
  # return hardware typenums, not TowerCoverage IDs.
  tie my %t, 'Tie::IxHash';

  foreach my $type (qsearch({
    table     => 'hardware_type',
    hashref   => { 'classnum' => $hardware_class->classnum },
    order_by  => ' order by title::integer'
  })) {
    $t{$type->typenum} = $type->model;
  }

  return \%t;
}

sub export_links {
  my $self = shift;
  my ($sector, $arrayref) = @_;
  if ( $sector->title =~ /^\d+$/ ) {
    my $link = "http://www.towercoverage.com/En-US/Dashboard/editcoverages/".
               $sector->title;
    push @$arrayref, qq!<a href="$link" target="_blank">TowerCoverage map</a>!;
  }
}

# we can query this from them, but that requires the account id and key...
# XXX do some jquery magic in the UI to grab the account ID and key from
# those fields, and then look it up right there

BEGIN {
  tie our %frequency_id, 'Tie::IxHash', (
    1 => "2400 MHz",
    2 => "5700 MHz",
    3 => "5300 MHz",
    4 => "900 MHz",
    5 => "3650 MHz",
    12 => "584 MHz",
    13 => "24000 MHz",
    14 => "11000 MHz Licensed",
    15 => "815 MHz",
    16 => "860 MHz",
    17 => "1800 MHz CDMA 3G",
    18 => "18000 MHz Licensed",
    19 => "1700 MHz",
    20 => "2100 MHz AWS",
    21 => "2500-2700 MHz EBS/BRS",
    22 => "6000 MHz Licensed",
    23 => "476 MHz",
    24 => "4900 MHz - Public Safety",
    25 => "2300 MHz",
    28 => "7000 MHz 4PSK",
    29 => "12000 MHz 4PSK",
    30 => "60 MHz",
    31 => "260 MHz",
    32 => "70 MHz",
    34 => "155 MHz",
    35 => "365 MHz",
    36 => "435 MHz",
    38 => "3500 MHz",
    39 => "750 MHz",
    40 => "27 MHz",
    41 => "10000 MHz",
    42 => "10250 Mhz",
    43 => "10250 Mhz",
    44 => "160 MHz",
    45 => "700 MHz",
    46 => "722 MHz",
    47 => "38000 Mhz",
    49 => "551 MHz",
    50 => "600 MHz",
    51 => "2300 MHz",
    52 => "5100 MHz",
    53 => "1900Mhz",
  );

  # there has to be a better way to handle this. load it during upgrade?
  # provide a proxy method like get_dids?

  tie our %antenna_type_id, 'Tie::IxHash', (
    1 => 'Generic - Omni',
    5 => 'Generic - 120 Degree',
    8 => 'Generic - 45 Degree Panel',
    9 => 'Generic - 60 Degree Panel',
    10 => 'Generic - 60 Degree x 8 Sectors',
    11 => 'Generic - 90 Degree',
    12 => 'Alvarion 3.65 WiMax Base Satation',
    24 => 'Tranzeo - 3.5 GHz 17db 60 Sector',
    31 => 'Alpha - 2.3 2033 Omni',
    32 => "PMP450 - 60&deg; Sector",
    33 => "PMP450 - 90&deg; Sector",
    34 => 'PMP450 - SM Panel',
    36 => 'KPPA - 2GHZDP90S-45 17 dBi',
    37 => 'KPPA - 2GHZDP120S-45 14.2 dBi',
    38 => 'KPPA - 3GHZDP60S-45 16.3 dBi',
    39 => 'KPPA - 3GHZDP90S-45 16.7 dBi',
    40 => 'KPPA - 3GHZDP120S-45 14.8 dBi',
    41 => 'KPPA - 5GHZDP40S-17 18.2 dBi',
    42 => 'KPPA - 5GHZDP60S 17.7 dBi',
    43 => 'KPPA - 5GHZDP60S-17 18.2 dBi',
    44 => 'KPPA - 5GHZDP90S 17 dBi',
    45 => 'KPPA - 5GHZDP120S 16.3 dBi',
    46 => 'KPPA - OMNI-DP-2 13 dBi',
    47 => 'KPPA - OMNI-DP-2.4-45 10.7 dBi',
    48 => 'KPPA - OMNI-DP-3 13 dBi',
    49 => 'KPPA - OMNI-DP-3-45 11 dBi',
    51 => 'KPPA - OMNI-DP-5 14 dBi',
    53 => 'Telrad - 65 Degree 3.65 Ghz',
    54 => 'KPPA - 2GHZDP60S-17-45 15.1 dBi',
    55 => 'KPPA - 2GHZDP60S-45 17.9 dBi',
    56 => 'UBNT - AG-2G20',
    57 => 'UBNT - AG-5G23',
    58 => 'UBNT - AG-5G27',
    59 => 'UBNT - AM-2G15-120',
    60 => 'UBNT - AM-2G16-90',
    61 => 'UBNT - AM-3G18-120',
    62 => 'UBNT - AM-5G16-120',
    63 => 'UBNT - AM-5G17-90',
    64 => 'UBNT - AM-5G19-120',
    65 => 'UBNT - AM-5G20-90',
    66 => 'UBNT - AM-9G15-90',
    67 => 'UBNT - AMO-2G10',
    68 => 'UBNT - AMO-2G13',
    69 => 'UBNT - AMO-5G10',
    70 => 'UBNT - AMO-5G13',
    71 => 'UBNT - AMY-9M16',
    72 => 'UBNT - LOCOM2',
    73 => 'UBNT - LOCOM5',
    74 => 'UBNT - LOCOM9',
    75 => 'UBNT - NB-2G18',
    76 => 'UBNT - NB-5G22',
    77 => 'UBNT - NB-5G25',
    78 => 'UBNT - NBM3',
    79 => 'UBNT - NBM9',
    80 => 'UBNT - NSM2',
    81 => 'UBNT - NSM3',
    82 => 'UBNT - NSM5',
    83 => 'UBNT - NSM9',
    84 => 'UBNT - PBM3',
    85 => 'UBNT - PBM5',
    86 => 'UBNT - PBM10',
    87 => 'UBNT - RD-2G23',
    88 => 'UBNT - RD-3G25',
    89 => 'UBNT - RD-5G30',
    90 => 'UBNT - RD-5G34',
    92 => 'TerraWave - 2.3-2.7 18db 65-Degree Panel',
    93 => 'UBNT - AM-M521-60-AC',
    94 => 'UBNT - AM-M522-45-AC',
    101 => 'RF Elements - SH-TP-5-30',
    104 => 'RF Elements - SH-TP-5-40',
    105 => 'RF Elements - SH-TP-5-50',
    106 => 'RF Elements - SH-TP-5-60',
    107 => 'RF Elements - SH-TP-5-70',
    108 => 'RF Elements - SH-TP-5-80',
    109 => 'RF Elements - SH-TP-5-90',
    110 => 'UBNT - Test',
    111 => '60 Titanium',
    112 => '3.65GHz - 6x6',
    113 => 'AW3015-t0-c4(EOS)',
    114 => 'AW3035 (EOS)',
    122 => 'RF Elements - SEC-CC-5-20',
    135 => 'RF Elements - SEC-CC-2-14',
    137 => 'RF Elements - SEC-CC-5-17',
    168 => 'KPPA - Mimosa - 5GHZZHV4P65S-17',
  );
}

1;
