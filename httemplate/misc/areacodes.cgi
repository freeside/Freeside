<% objToJson(\@areacodes) %>
<%init>

my( $state, $svcpart ) = $cgi->param('arg');

my $part_svc = qsearchs('part_svc', { 'svcpart'=>$svcpart } );
die "unknown svcpart $svcpart" unless $part_svc;

my @areacodes = ();
if ( $state ) {

  my @exports = $part_svc->part_export_did;
  if ( scalar(@exports) > 1 ) {
    die "more than one DID-providing export attached to svcpart $svcpart";
  } elsif ( ! @exports ) {
    die "no DID providing export attached to svcpart $svcpart";
  }
  my $export = $exports[0];

  my $something = $export->get_dids('state'=>$state);

  @areacodes = @{ $something };

}

</%init>
