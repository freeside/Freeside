<%

# If it's stupid but it works, it's not stupid.
# -- U.S. Army

local $FS::UID::AutoCommit = 0;
my $dbh = FS::UID::dbh;

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum = $1;

my $old;
if ( $svcnum ) {
  $old = qsearchs('svc_broadband', { 'svcnum' => $svcnum } )
    or die "fatal: can't find broadband service (svcnum $svcnum)!";
} else {
  $old = '';
}

my $new = new FS::svc_broadband ( {
  map {
    ($_, scalar($cgi->param($_)));
  } ( fields('svc_broadband'), qw( pkgnum svcpart ) )
} );

my $error;
if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->svcnum;
}


if ( $error ) {
  $cgi->param('error', $error);
  $cgi->param('ip_addr', $new->ip_addr);
  $dbh->rollback;
  print $cgi->redirect(popurl(2). "svc_broadband.cgi?". $cgi->query_string );
} else {
  $dbh->commit or die $dbh->errstr;
  print $cgi->redirect(popurl(3). "view/svc_broadband.cgi?" . $svcnum );
}

%>
