package FS::part_export::pbxware;

use base qw( FS::part_export );
use strict;

use Tie::IxHash;
use LWP::UserAgent;
use JSON;
use HTTP::Request::Common;
use Digest::MD5 qw(md5_hex);
use FS::Record qw(dbh);
use FS::cdr_batch;

our $me = '[pbxware]';
our $DEBUG = 0;
# our $DEBUG = 1; # log requests
# our $DEBUG = 2; # log requests and content of replies

tie my %options, 'Tie::IxHash',
  'apikey'  => { label => 'API key' },
  'debug'   => { label => 'Enable debugging', type => 'checkbox', value => 1 },
; # best. API. ever.

our %info = (
  'svc'         => [qw(svc_phone)],
  'desc'        => 'Retrieve CDRs from Bicom PBXware',
  'options'     => \%options,
  'notes' => <<'END'
<P>Export to <a href="www.bicomsystems.com/pbxware-3-8">Bicom PBXware</a> 
softswitch.</P>
<P><I>This export does not provision services.</I> Currently you will need
to provision trunks and extensions through PBXware. The export only downloads 
CDRs.</P>
<P>Set the export machine to the name or IP address of your PBXware server,
and the API key to your alphanumeric key.</P>
END
);

sub export_insert {}
sub export_delete {}
sub export_replace {}
sub export_suspend {}
sub export_unsuspend {}

################
# CALL DETAILS #
################

=item import_cdrs START, END

Retrieves CDRs for calls in the date range from START to END and inserts them
as a new CDR batch. On success, returns a new cdr_batch object. On failure,
returns an error message. If there are no new CDRs, returns nothing.

=cut

# map their column names to cdr fields
# (warning: API docs are not quite accurate here)
our %column_map = (
  'Tenant'      => 'subscriber',
  'From'        => 'src',
  'To'          => 'dst',
  'Date/Time'   => 'startdate',
  'Duration'    => 'duration',
  'Billing'     => 'billsec',
  'Cost'        => 'upstream_price', # might not be used
  'Status'      => 'disposition',
);

sub import_cdrs {
  my ($self, $start, $end) = @_;
  $start ||= 0; # all CDRs ever
  $end ||= time;
  $DEBUG ||= $self->option('debug');

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  my $sd = DateTime->from_epoch(epoch => $start)->set_time_zone('local');
  my $ed = DateTime->from_epoch(epoch => $end)->set_time_zone('local');

  my $error;

  # Send a query.
  #
  # Other options supported:
  # - trunk, ext: filter by source trunk and extension
  # - trunkdst, extdst: filter by dest trunk and extension
  # - server: filter by server id
  # - status: filter by call status (answered, unanswered, busy, failed)
  # - cdrtype: filter by call direction

  my %opt = (
    start     => $sd->strftime('%b-%d-%Y'),
    starttime => $sd->strftime('%H:%M:%S'),
    end       => $ed->strftime('%b-%d-%Y'),
    endtime   => $ed->strftime('%H:%M:%S'),
  );
  # unlike Certain Other VoIP providers, this one does proper pagination if
  # the result set is too big to fit in a single chunk.
  my $page = 1;
  my $more = 1;
  my $cdr_batch;

  do {
    my $result = $self->api_request('pbxware.cdr.download', \%opt);
    if ($result->{success} !~ /^success/i) {
      dbh->rollback if $oldAutoCommit;
      return "$me $result->{success} (downloading CDRs)";
    }

    if ($result->{records} > 0 and !$cdr_batch) {
      # then create one
      my $cdrbatchname = 'pbxware-' . $self->exportnum . '-' . $ed->epoch;
      $cdr_batch = FS::cdr_batch->new({ cdrbatch => $cdrbatchname });
      $error = $cdr_batch->insert;
      if ( $error ) {
        dbh->rollback if $oldAutoCommit;
        return "$me $error (creating batch)";
      }
    }

    my @names = map { $column_map{$_} } @{ $result->{header} };
    my $rows = $result->{csv}; # not really CSV
    CDR: while (my $row = shift @$rows) {
      # Detect duplicates. Pages are returned most-recent first, so if a 
      # new CDR comes in between page fetches, the last row from the previous
      # page will get duplicated. This is normal; we just need to skip it.
      #
      # if this turns out to be too slow, we can keep a cache of the last 
      # page's IDs or something.
      my $uniqueid = md5_hex(join(',',@$row));
      if ( FS::cdr->row_exists('uniqueid = ?', $uniqueid) ) {
        warn "skipped duplicate row in page $page\n" if $DEBUG > 1;
        next CDR;
      }

      my %hash = (
        cdrbatchnum => $cdr_batch->cdrbatchnum,
        uniqueid    => $uniqueid,
      );
      @hash{@names} = @$row;

      my $cdr = FS::cdr->new(\%hash);
      $error = $cdr->insert;
      if ( $error ) {
        dbh->rollback if $oldAutoCommit;
        return "$me $error (inserting CDR: $row)";
      }
    }

    $more = $result->{next_page};
    $page++;
    $opt{page} = $page;

  } while ($more);

  dbh->commit if $oldAutoCommit;
  return $cdr_batch;
}

sub api_request {
  my $self = shift;
  my ($method, $content) = @_;
  $DEBUG ||= 1 if $self->option('debug');
  my $url = 'https://' . $self->machine;
  my $request = POST($url,
    [ %$content,
      'apikey' => $self->option('apikey'),
      'action' => $method
    ]
  );
  warn "$me $method\n" if $DEBUG;
  warn $request->as_string."\n" if $DEBUG > 1;

  my $ua = LWP::UserAgent->new;
  my $response = $ua->request($request);
  if ( !$response->is_success ) {
    return { success => $response->content };
  } 
  
  local $@;
  my $decoded_response = eval { decode_json($response->content) };
  if ( $@ ) {
    die "Error parsing response:\n" . $response->content . "\n\n";
  } 
  return $decoded_response;
} 

1;
