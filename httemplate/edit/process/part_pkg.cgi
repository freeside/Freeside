<%
#
# $Id: part_pkg.cgi,v 1.1 2001-07-30 07:36:04 ivan Exp $
#
# process/part_pkg.cgi: Edit package definitions (process form)
#
# ivan@sisd.com 97-dec-10
#
# don't update non-changing records in part_svc (causing harmless but annoying
# "Records identical" errors). ivan@sisd.com 98-feb-19
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# Added `|| 0 ' when getting quantity off web page ivan@sisd.com 98-jun-4
#
# lose background, FS::CGI ivan@sisd.com 98-sep-2
#
# $Log: part_pkg.cgi,v $
# Revision 1.1  2001-07-30 07:36:04  ivan
# templates!!!
#
# Revision 1.9  2001/04/09 23:05:16  ivan
# Transactions Part I!!!
#
# Revision 1.8  1999/02/07 09:59:27  ivan
# more mod_perl fixes, and bugfixes Peter Wemm sent via email
#
# Revision 1.7  1999/01/19 05:13:55  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.6  1999/01/18 22:47:56  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.5  1998/12/30 23:03:29  ivan
# bugfixes; fields isn't exported by derived classes
#
# Revision 1.4  1998/12/17 08:40:24  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.3  1998/11/21 07:17:58  ivan
# bugfix to work for regular aswell as custom pricing
#
# Revision 1.2  1998/11/15 13:16:15  ivan
# first pass as per-user custom pricing
#

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

$new = new FS::part_pkg ( {
  map {
    $_, scalar($cgi->param($_));
  } fields('part_pkg')
} );

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
