#!/usr/bin/perl -Tw
#
# $Id: cust_main_county-expand.cgi,v 1.5 1999-01-19 05:13:51 ivan Exp $
#
# ivan@sisd.com 97-dec-16
#
# Changes to allow page to work at a relative position in server
# Added import of datasrc from UID.pm for Pg6.3
# Default tax to 0.0 if using Pg6.3
#       bmccane@maxbaud.net     98-apr-3
#
# lose background, FS::CGI
# undo default tax to 0.0 if using Pg6.3: comes from pre-expanded record
# for that state
# ivan@sisd.com 98-sep-2
#
# $Log: cust_main_county-expand.cgi,v $
# Revision 1.5  1999-01-19 05:13:51  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 22:47:52  ivan
# s/create/new/g; and use fields('table_name')
#
# Revision 1.3  1998/12/17 08:40:20  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/18 09:01:40  ivan
# i18n! i18n!
#

use strict;
use vars qw ( $cgi $taxnum $cust_main_county @expansion $expansion );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup datasrc);
use FS::Record qw(qsearch qsearchs);
use FS::CGI qw(eidiot popurl);
use FS::cust_main_county;
use FS::cust_main;

$cgi = new CGI;

&cgisuidsetup($cgi);

$cgi->param('taxnum') =~ /^(\d+)$/ or die "Illegal taxnum!";
$taxnum = $1;
$cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum})
  or die ("Unknown taxnum!");

if ( $cgi->param('delim') eq 'n' ) {
  @expansion=split(/\n/,$cgi->param('expansion'));
} elsif ( $cgi->param('delim') eq 's' ) {
  @expansion=split(/\s+/,$cgi->param('expansion'));
} else {
  die "Illegal delim!";
}

@expansion=map {
  /^\s*([\w\- ]+)\s*$/ or eidiot("Illegal expansion");
  $1;
} @expansion;

foreach ( @expansion) {
  my(%hash)=$cust_main_county->hash;
  my($new)=new FS::cust_main_county \%hash;
  $new->setfield('taxnum','');
  if ( ! $cust_main_county->state ) {
    $new->setfield('state',$_);
  } else {
    $new->setfield('county',$_);
  }
  #if (datasrc =~ m/Pg/)
  #{
  #    $new->setfield('tax',0.0);
  #}
  my($error)=$new->insert;
  die $error if $error;
}

unless ( qsearch('cust_main',{
  'state'  => $cust_main_county->getfield('state'),
  'county' => $cust_main_county->getfield('county'),
  'country' =>  $cust_main_county->getfield('country'),
} ) ) {
  my($error)=($cust_main_county->delete);
  die $error if $error;
}

print $cgi->redirect(popurl(3). "edit/cust_main_county.cgi");

