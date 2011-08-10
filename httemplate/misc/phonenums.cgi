<% objToJson(\@phonenums) %>
<%init>

my( $exchangestring, $svcpart ) = $cgi->param('arg');

my $part_svc = qsearchs('part_svc', { 'svcpart'=>$svcpart } );
die "unknown svcpart $svcpart" unless $part_svc;

my @phonenums = ();

if ( $exchangestring ) {

  my @exports = $part_svc->part_export_did;
  if ( scalar(@exports) > 1 ) {
    die "more than one DID-providing export attached to svcpart $svcpart";
  } elsif ( ! @exports ) {
    die "no DID providing export attached to svcpart $svcpart";
  }
  my $export = $exports[0];
    
  my %opts = ();
  if ( $exchangestring eq 'tollfree' ) {
      $opts{'tollfree'} = 1;
  }
  elsif ( $exchangestring =~ /^([\w\s]+), ([A-Z][A-Z])$/ ) {
      $opts{'ratecenter'} = $1;
      $opts{'state'} = $2;
  }
  else {
      $exchangestring =~ /\((\d{3})-(\d{3})-XXXX\)\s*$/i
        or die "unparsable exchange: $exchangestring";
      my( $areacode, $exchange ) = ( $1, $2 );
      $opts{'areacode'} = $areacode;
      $opts{'exchange'} = $exchange;
  }

  my $something = $export->get_dids(%opts);
  @phonenums = @{ $something };

}

</%init>
