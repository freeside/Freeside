<%

my $dbh = dbh;

my $pkgpart = $cgi->param('pkgpart');

my $old = qsearchs('part_pkg',{'pkgpart'=>$pkgpart}) if $pkgpart;

#fixup plandata
my $plandata = $cgi->param('plandata');
my @plandata = split(',', $plandata);
$cgi->param('plandata', 
  join('', map { "$_=". join(', ', $cgi->param($_)). "\n" } @plandata )
);

foreach (qw( setuptax recurtax disabled )) {
  $cgi->param($_, '') unless defined $cgi->param($_);
}

my $new = new FS::part_pkg ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_pkg')
} );

my %pkg_svc = map { $_ => $cgi->param("pkg_svc$_") }
              map { $_->svcpart }
              qsearch('part_svc', {} );

my $error;
my $custnum = '';
if ( $pkgpart ) {
  $error = $new->replace( $old,
                          pkg_svc     => \%pkg_svc,
                          primary_svc => scalar($cgi->param('pkg_svc_primary')),
                        );
} else {
  $error = $new->insert(  pkg_svc     => \%pkg_svc,
                          primary_svc => scalar($cgi->param('pkg_svc_primary')),
                          cust_pkg    => $cgi->param('pkgnum'),
                          custnum_ref => \$custnum,
                       );
  $pkgpart = $new->pkgpart;
}
if ( $error ) {
  $cgi->param('error', $error );
  print $cgi->redirect(popurl(2). "part_pkg.cgi?". $cgi->query_string );
} elsif ( $custnum )  {
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
} else {
  print $cgi->redirect(popurl(3). "browse/part_pkg.cgi");
}

%>
