#!/usr/bin/perl -Tw
#
# $Id: delete-customer.cgi,v 1.1 1999-04-15 16:44:36 ivan Exp $
#
# $Log: delete-customer.cgi,v $
# Revision 1.1  1999-04-15 16:44:36  ivan
# delete customers
#

use strict;
use vars qw( $cgi $conf $query $custnum $new_custnum $cust_main );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl);
use FS::Record qw(qsearch qsearchs);
use FS::cust_main;

$cgi = new CGI;
cgisuidsetup($cgi);

$conf = new FS::Conf;
die "Customer deletions not enabled" unless $conf->exists('deletecustomers');

if ( $cgi->param('error') ) {
  $custnum = $cgi->param('custnum');
  $new_custnum = $cgi->param('new_custnum');
} else {
  ($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "Illegal query: $query";
  $custnum = $1;
  $new_custnum = '';
}
$cust_main = qsearchs( 'cust_main', { 'custnum' => $custnum } )
  or die "Customer not found: $custnum";

print $cgi->header ( '-expires' => 'now' ), header('Delete customer');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print 
  qq!<form action="!, popurl(1), qq!process/delete-customer.cgi" method=post>!,
  qq!<input type="hidden" name="custnum" value="$custnum">!;

if ( qsearch('cust_pkg', { 'custnum' => $custnum, 'cancel' => '' } ) ) {
  print "Move uncancelled packages to customer number ",
        qq!<input type="text" name="new_custnum" value="$new_custnum"><br><br>!;
}

print <<END;
This will <b>completely remove</b> all traces of this customer record.
<br>Are you <b>absolutely sure</b> you want to delete this customer?
<br><input type="submit" value="Yes">
</form></body></html>
END

