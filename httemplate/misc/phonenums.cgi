%# [ <% join(', ', map { qq("$_") } @exchanges) %> ]
<% objToJson(\@exchanges) %>
<%init>

my( $exchangestring, $svcpart ) = $cgi->param('arg');

$exchangestring =~ /\((\d{3})-(\d{3})-XXXX\)\s*$/i
  or die "unparsable exchange: $exchangestring";
my( $areacode, $exchange ) = ( $1, $2 );
my $part_svc = qsearchs('part_svc', { 'svcpart'=>$svcpart } );
die "unknown svcpart $svcpart" unless $part_svc;

my @exports = $part_svc->part_export_did;
if ( scalar(@exports) > 1 ) {
  die "more than one DID-providing export attached to svcpart $svcpart";
} elsif ( ! @exports ) {
  die "no DID providing export attached to svcpart $svcpart";
}
my $export = $exports[0];

my $something = $export->get_dids('areacode'=>$areacode,
                                  'exchange'=>$exchange,
                                 );

#warn Dumper($something);

my @exchanges = @{ $something };

</%init>
