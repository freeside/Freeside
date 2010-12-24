<% $pay_batch->export_batch($format) %><%init>

#http_header('Content-Type' => 'text/comma-separated-values' ); #IE chokes
http_header('Content-Type' => 'text/plain' ); # not necessarily correct...

my $batchnum;
if ( $cgi->param('batchnum') =~ /^(\d+)$/ ) {
  $batchnum = $1;
} else {
  die "No batch number (bad URL) \n";
}

my $format;
if ( $cgi->param('format') =~ /^([\w\- ]+)$/ ) {
  $format = $1;
}

my $pay_batch = qsearchs('pay_batch', { batchnum => $batchnum } );
die "Batch not found: '$batchnum'" if !$pay_batch;

</%init>
