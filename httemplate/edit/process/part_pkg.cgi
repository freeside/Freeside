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

#warn "setuptax: ". $new->setuptax;
#warn "recurtax: ". $new->recurtax;

#most of the stuff below should move to part_pkg.pm

foreach my $part_svc ( qsearch('part_svc', {} ) ) {
  my $quantity = $cgi->param('pkg_svc'. $part_svc->svcpart) || 0;
  unless ( $quantity =~ /^(\d+)$/ ) {
    $cgi->param('error', "Illegal quantity" );
    print $cgi->redirect(popurl(2). "part_pkg.cgi?". $cgi->query_string );
    myexit();
  }
}

local $SIG{HUP} = 'IGNORE';
local $SIG{INT} = 'IGNORE';
local $SIG{QUIT} = 'IGNORE';
local $SIG{TERM} = 'IGNORE';
local $SIG{TSTP} = 'IGNORE';
local $SIG{PIPE} = 'IGNORE';

local $FS::UID::AutoCommit = 0;

my $error;
if ( $pkgpart ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $pkgpart=$new->pkgpart;
}
if ( $error ) {
  $dbh->rollback;
  $cgi->param('error', $error );
  print $cgi->redirect(popurl(2). "part_pkg.cgi?". $cgi->query_string );
  myexit();
}

foreach my $part_svc (qsearch('part_svc',{})) {
  my $quantity = $cgi->param('pkg_svc'. $part_svc->svcpart) || 0;
  my $primary_svc =
    $cgi->param('pkg_svc_primary') == $part_svc->svcpart ? 'Y' : '';
  my $old_pkg_svc = qsearchs('pkg_svc', {
    'pkgpart' => $pkgpart,
    'svcpart' => $part_svc->svcpart,
  } );
  my $old_quantity = $old_pkg_svc ? $old_pkg_svc->quantity : 0;
  my $old_primary_svc =
    ( $old_pkg_svc && $old_pkg_svc->dbdef_table->column('primary_svc') )
      ? $old_pkg_svc->primary_svc
      : '';
  next unless $old_quantity != $quantity || $old_primary_svc ne $primary_svc;

  my $new_pkg_svc = new FS::pkg_svc( {
    'pkgpart'     => $pkgpart,
    'svcpart'     => $part_svc->svcpart,
    'quantity'    => $quantity, 
    'primary_svc' => $primary_svc,
  } );
  if ( $old_pkg_svc ) {
    my $myerror = $new_pkg_svc->replace($old_pkg_svc);
    if ( $myerror ) {
      $dbh->rollback;
      die $myerror;
    }
  } else {
    my $myerror = $new_pkg_svc->insert;
    if ( $myerror ) {
      $dbh->rollback;
      die $myerror;
    }
  }
}

unless ( $cgi->param('pkgnum') && $cgi->param('pkgnum') =~ /^(\d+)$/ ) {
  $dbh->commit or die $dbh->errstr;
  print $cgi->redirect(popurl(3). "browse/part_pkg.cgi");
} else {
  my($old_cust_pkg) = qsearchs( 'cust_pkg', { 'pkgnum' => $1 } );
  my %hash = $old_cust_pkg->hash;
  $hash{'pkgpart'} = $pkgpart;
  my($new_cust_pkg) = new FS::cust_pkg \%hash;
  my $myerror = $new_cust_pkg->replace($old_cust_pkg);
  if ( $myerror ) {
    $dbh->rollback;
    die "Error modifying cust_pkg record: $myerror\n";
  }

  $dbh->commit or die $dbh->errstr;
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?". $new_cust_pkg->custnum);
}

%>
