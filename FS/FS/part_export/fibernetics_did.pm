package FS::part_export::fibernetics_did;
use base qw( FS::part_export );

use strict;
use vars qw( %info $DEBUG );
use Data::Dumper;
use URI::Escape;
#use Locale::SubCountry;
#use FS::Record qw(qsearch dbh);
use XML::Simple;
#use Net::HTTPS::Any qw( 0.10 https_get );
use LWP::UserAgent;
use HTTP::Request::Common;

$DEBUG = 0;

tie my %options, 'Tie::IxHash',
  'country' => { 'label' => 'Country', 'default' => 'CA', size=>2, },
;

%info = (
  'svc'        => 'svc_phone',
  'desc'       => 'Provision phone numbers to Fibernetics web services API',
  'options'    => \%options,
  'notes'      => '',
);

sub rebless { shift; }

sub get_dids_can_tollfree { 0; };
sub get_dids_npa_select   { 0; };

# i guess we could get em from the API, but since its returning states without
#  availability, there's no advantage
    # not really needed, we maintain our own list of provinces, but would
    #  help to hide the ones without availability (need to fix the selector too)
our @states = (
  'Alberta',
  'British Columbia',
  'Ontario',
  'Quebec',
  #'Saskatchewan',
  #'The Territories',
  #'PEI/Nova Scotia',
  #'Manitoba',
  #'Newfoundland',
  #'New Brunswick',
);

sub get_dids {
  my $self = shift;
  my %opt = ref($_[0]) ? %{$_[0]} : @_;

  if ( $opt{'tollfree'} ) {
    warn 'Fibernetics DID provisioning does not yet support toll-free numbers';
    return [];
  }

  my %query_hash = ();

  #ratecenter + state: return numbers (more structured names, npa selection)
  #areacode + exchange: return numbers
  #areacode: return city/ratecenter/whatever
  #state: return areacodes

  #region + state: return numbers (arbitrary names, no npa selection)
  #state: return regions

#  if ( $opt{'areacode'} && $opt{'exchange'} ) { #return numbers
#
#    $query_hash{'region'} = $opt{'exchange'};
#
#  } elsif ( $opt{'areacode'} ) {
#
#    $query_hash{'npa'} = $opt{'areacode'};

  #if ( $opt{'state'} && $opt{'region'} ) { #return numbers
  if ( $opt{'region'} ) { #return numbers

    #$query_hash{'province'} = $country->full_name($opt{'state'});
    $query_hash{'region'}   = $opt{'region'}

  } elsif ( $opt{'state'} ) { #return regions

    #my $country = new Locale::SubCountry( $self->option('country') );
    #$query_hash{'province'}   = $country->full_name($opt{'state'});
    $query_hash{'province'}   = $opt{'state'};
    $query_hash{'listregion'} = 1;

  } else { #nothing passed, return states (provinces)

    return \@states;

  }


  my $url = 'http://'. $self->machine. '/porta/cgi-bin/porta_query.cgi';
  if ( keys %query_hash ) {
    $url .= '?'. join('&', map "$_=". uri_escape($query_hash{$_}),
                             keys %query_hash
                     );
  }
  warn $url if $DEBUG;

  #my( $page, $response, %reply_headers) = https_get(
  #  'host' => $self->machine,
  #);

  my $ua = LWP::UserAgent->new;
  #my $response = $ua->$method(
  #  $url, \%data,
  #  'Content-Type'=>'application/x-www-form-urlencoded'
  #);
  my $req = HTTP::Request::Common::GET( $url );
  my $response = $ua->request($req);

  die $response->error_as_HTML if $response->is_error;

  my $page = $response->content;

  my $data = XMLin( $page );

  warn Dumper($data) if $DEBUG;

#  if ( $opt{'areacode'} && $opt{'exchange'} ) { #return numbers
#
#    [ map $_->{'number'}, @{ $data->{'item'} } ];
#
#  } elsif ( $opt{'areacode'} ) {
#
#    [ map $_->{'region'}, @{ $data->{'item'} } ];
#
#  } elsif ( $opt{'state'} ) { #return areacodes
#
#    [ map $_->{'npa'}, @{ $data->{'item'} } ];

  #if ( $opt{'state'} && $opt{'region'} ) { #return numbers
  if ( $opt{'region'} ) { #return numbers

    [ map { $_ =~ /^(\d?)(\d{3})(\d{3})(\d{4})$/
              ? ($1 ? "$1 " : ''). "$2 $3 $4"
              : $_;
          }
        sort { $a <=> $b }
          map $_->{'phone'},
            @{ $data->{'item'} }
    ];

  } elsif ( $opt{'state'} ) { #return regions

    #[ map $_->{'region'}, @{ $data->{'item'} } ];
    my %regions = map { $_ => 1 } map $_->{'region'}, @{ $data->{'item'} };
    [ sort keys %regions ];

  #} else { #nothing passed, return states (provinces)
    # not really needed, we maintain our own list of provinces, but would
    #  help to hide the ones without availability (need to fix the selector too)
  }


}

#insert, delete, etc... handled with shellcommands

sub _export_insert {
  #my( $self, $svc_phone ) = (shift, shift);
}
sub _export_delete {
  #my( $self, $svc_phone ) = (shift, shift);
}

sub _export_replace  { ''; }
sub _export_suspend  { ''; }
sub _export_unsuspend  { ''; }

1;
