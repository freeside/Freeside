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

my $credit_transactions = "EXISTS (SELECT 1 FROM cust_pay_batch WHERE batchnum = $batchnum AND paycode = 'C') AS arecredits";
my $pay_batch = qsearchs({ 'select'    => "*, $credit_transactions",
                           'table'     => 'pay_batch',
                           'hashref'   => { batchnum => $batchnum },
                         });
die "Batch not found: '$batchnum'" if !$pay_batch;

if ($pay_batch->{Hash}->{arecredits}) {
  my $export_format = "FS::pay_batch::".$opt{'format'};
  die "You are trying to download a credit (batch refund) batch and The format ".$opt{'format'}." can not handle refunds.\n" unless $export_format->can('can_handle_credits');
}

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
