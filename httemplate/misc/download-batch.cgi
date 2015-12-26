<% $exporttext %><%init>

#http_header('Content-Type' => 'text/comma-separated-values' ); #IE chokes
http_header('Content-Type' => 'text/plain' ); # not necessarily correct...

my $batchnum;
if ( $cgi->param('batchnum') =~ /^(\d+)$/ ) {
  $batchnum = $1;
} else {
  die "No batch number (bad URL) \n";
}

my %opt;
if ( $cgi->param('gatewaynum') =~ /^(\d+)$/ ) {
  my $gateway = FS::payment_gateway->by_key($1);
  die "gatewaynum $1 not found" unless $gateway;
  $opt{'gateway'} = $gateway;
}
elsif ( $cgi->param('format') =~ /^([\w\- ]+)$/ ) {
  $opt{'format'} = $1;
}

my $pay_batch = qsearchs('pay_batch', { batchnum => $batchnum } );
die "Batch not found: '$batchnum'" if !$pay_batch;

my $exporttext = $pay_batch->export_batch(%opt);
unless ($exporttext) {
  http_header('Content-Type' => 'text/html' );
  $exporttext = <<EOF;
<SCRIPT>
alert('Batch was empty, and has been resolved');
window.top.location.href = '${p}search/pay_batch.cgi?magic=_date;open=1;intransit=1;resolved=1';
</SCRIPT>
EOF
}

</%init>
