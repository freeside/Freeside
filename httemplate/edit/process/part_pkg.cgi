<%
#<!-- $Id: part_pkg.cgi,v 1.5 2001-11-06 18:45:46 ivan Exp $ -->

use strict;
use vars qw( $cgi $pkgpart $old $new $part_svc $error $dbh );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl);
use FS::Record qw(qsearch qsearchs fields);
use FS::part_pkg;
use FS::pkg_svc;
use FS::cust_pkg;

$cgi = new CGI;
$dbh = &cgisuidsetup($cgi);

$pkgpart = $cgi->param('pkgpart');

$old = qsearchs('part_pkg',{'pkgpart'=>$pkgpart}) if $pkgpart;

#fixup plandata
my $plandata = $cgi->param('plandata');
my @plandata = split(',', $plandata);
$cgi->param('plandata', 
  join('', map { "$_=". $cgi->param($_). "\n" } @plandata )
);

$cgi->param('setuptax','') unless defined $cgi->param('setuptax');
$cgi->param('recurtax','') unless defined $cgi->param('recurtax');

$new = new FS::part_pkg ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_pkg')
} );

#warn "setuptax: ". $new->setuptax;
#warn "recurtax: ". $new->recurtax;

#most of the stuff below should move to part_pkg.pm

foreach $part_svc ( qsearch('part_svc', {} ) ) {
  my $quantity = $cgi->param('pkg_svc'. $part_svc->svcpart) || 0;
  unless ( $quantity =~ /^(\d+)$/ ) {
    $cgi->param('error', "Illegal quantity" );
    print $cgi->redirect(popurl(2). "part_pkg.cgi?". $cgi->query_string );
    exit;
  }
}

local $SIG{HUP} = 'IGNORE';
local $SIG{INT} = 'IGNORE';
local $SIG{QUIT} = 'IGNORE';
local $SIG{TERM} = 'IGNORE';
local $SIG{TSTP} = 'IGNORE';
local $SIG{PIPE} = 'IGNORE';

local $FS::UID::AutoCommit = 0;

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
  exit;
}

foreach $part_svc (qsearch('part_svc',{})) {
  my $quantity = $cgi->param('pkg_svc'. $part_svc->svcpart) || 0;
  my $old_pkg_svc = qsearchs('pkg_svc', {
    'pkgpart' => $pkgpart,
    'svcpart' => $part_svc->svcpart,
  } );
  my $old_quantity = $old_pkg_svc ? $old_pkg_svc->quantity : 0;
  next unless $old_quantity != $quantity; #!here
  my $new_pkg_svc = new FS::pkg_svc( {
    'pkgpart'  => $pkgpart,
    'svcpart'  => $part_svc->svcpart,
    'quantity' => $quantity, 
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
