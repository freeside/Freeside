<%

my $svcpart = $cgi->param('svcpart');

my $old = qsearchs('part_svc',{'svcpart'=>$svcpart}) if $svcpart;

my $new = new FS::part_svc ( {
  map {
    $_, scalar($cgi->param($_));
#  } qw(svcpart svc svcdb)
  } fields('part_svc')
} );

my $error;
if ( $svcpart ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcpart=$new->getfield('svcpart');
}

if ( $error ) {
  $cgi->param('error', $error);
  $Response->Redirect(popurl(2). "part_svc.cgi?". $cgi->query_string );
} else {
  warn "redirecting to ". popurl(3)."browse/part_svc.cgi via $Response";
  $Response->Redirect(popurl(3)."browse/part_svc.cgi");
}

%>
