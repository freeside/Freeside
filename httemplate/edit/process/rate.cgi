<%

my $ratenum = $cgi->param('ratenum');

my $old = qsearchs('rate', { 'ratenum' => $ratenum } ) if $ratenum;

my @rate_detail = map {
  my $regionnum = $_->regionnum;
  new FS::rate_detail {
    'dest_regionnum'  => $regionnum,
    map { $_ => $cgi->param("$_$regionnum") }
        qw( min_included min_charge sec_granularity )
  };
} qsearch('rate_region', {} );

my $new = new FS::rate ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('rate')
} );

my $error;
if ( $ratenum ) {
  $error = $new->replace($old, 'rate_detail' => \@rate_detail );
} else {
  $error = $new->insert( 'rate_detail' => \@rate_detail );
  $ratenum = $new->getfield('ratenum');
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "rate.cgi?". $cgi->query_string );
} else { 
  print $cgi->redirect(popurl(3). "browse/rate.cgi");
}

%>
