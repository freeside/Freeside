<% $pay_batch->export_batch(%opt) %><%init>

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

</%init>
