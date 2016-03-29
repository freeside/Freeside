<% encode_json({ error => $error, areacodes => \@areacodes}) %>\
<%init>

my( $state, $svcpart ) = $cgi->param('arg');

my $part_svc = qsearchs('part_svc', { 'svcpart'=>$svcpart } );
die "unknown svcpart $svcpart" unless $part_svc;

my @areacodes = ();
my $error;

if ( $state ) {

  my @exports = $part_svc->part_export_did;
  if ( scalar(@exports) > 1 ) {
    die "more than one DID-providing export attached to svcpart $svcpart";
  } elsif ( ! @exports ) {
    die "no DID providing export attached to svcpart $svcpart";
  }
  my $export = $exports[0];

  local $@;
  local $SIG{__DIE__};
  my $something = eval { $export->get_dids('state'=>$state) };
  $error = $@;

  @areacodes = @{ $something } if $something;

}

</%init>
