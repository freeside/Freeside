<%

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

unless ( $new->ip_addr ) {
  $new->ip_addr(join('.', (map $cgi->param('ip_addr_'.$_), (a..d))));
}

unless ( $new->mac_addr) {
  $new->mac_addr(join(':', (map $cgi->param('mac_addr_'.$_), (a..f))));
}

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
  $cgi->param('mac_addr', $new->mac_addr);
  print $cgi->redirect(popurl(2). "svc_broadband.cgi?". $cgi->query_string );
} else {
  print $cgi->redirect(popurl(3). "view/svc_broadband.cgi?" . $svcnum );
}

%>
