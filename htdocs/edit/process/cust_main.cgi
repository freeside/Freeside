#!/usr/bin/perl -Tw
#
# $Id: cust_main.cgi,v 1.10 1999-04-14 07:47:53 ivan Exp $
#
# Usage: post form to:
#        http://server.name/path/cust_main.cgi
#
# ivan@voicenet.com 96-dec-04
#
# added referral check
# ivan@voicenet.com 97-jun-4
#
# rewrote for new API
# ivan@voicenet.com 97-jul-28
#
# same as above (again) and clean up some stuff ivan@sisd.com 98-feb-23
#
# Changes to allow page to work at a relative position in server
# Changed 'day' to 'daytime' because Pg6.3 reserves the day word
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: cust_main.cgi,v $
# Revision 1.10  1999-04-14 07:47:53  ivan
# i18n fixes
#
# Revision 1.9  1999/04/07 15:22:19  ivan
# don't use anchor in redirect
#
# Revision 1.8  1999/03/25 13:55:10  ivan
# one-screen new customer entry (including package and service) for simple
# packages with one svc_acct service
#
# Revision 1.7  1999/02/28 00:03:42  ivan
# removed misleading comments
#
# Revision 1.6  1999/01/25 12:10:00  ivan
# yet more mod_perl stuff
#
# Revision 1.5  1999/01/19 05:13:50  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 09:22:32  ivan
# changes to track email addresses for email invoicing
#
# Revision 1.3  1998/12/17 08:40:19  ivan
# s/CGI::Request/CGI.pm/; etc
#
# Revision 1.2  1998/11/18 08:57:36  ivan
# i18n, s/CGI-modules/CGI.pm/, FS::CGI::idiot instead of inline, FS::CGI::popurl
#

use strict;
use vars qw( $cgi $payby @invoicing_list $new $custnum $error );
use vars qw( $cust_pkg $cust_svc $svc_acct );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup getotaker);
use FS::CGI qw( popurl );
use FS::Record qw( qsearch qsearchs fields );
use FS::cust_main;
use FS::type_pkgs;
use FS::agent;

$cgi = new CGI;
&cgisuidsetup($cgi);

#unmunge stuff

$cgi->param('tax','') unless defined($cgi->param('tax'));

$cgi->param('refnum', (split(/:/, ($cgi->param('refnum'))[0] ))[0] );

$cgi->param('state') =~ /^(\w*)( \(([\w ]+)\))? ?\/ ?(\w+)$/
  or die "Oops, illegal \"state\" param: ". $cgi->param('state');
$cgi->param('state', $1);
$cgi->param('county', $3 || '');
$cgi->param('country', $4);

if ( $payby = $cgi->param('payby') ) {
  $cgi->param('payinfo', $cgi->param( $payby. '_payinfo' ) );
  $cgi->param('paydate',
  $cgi->param( $payby. '_month' ). '-'. $cgi->param( $payby. '_year' ) );
  $cgi->param('payname', $cgi->param( $payby. '_payname' ) );
}

$cgi->param('otaker', &getotaker );

@invoicing_list = split( /\s*\,\s*/, $cgi->param('invoicing_list') );
push @invoicing_list, 'POST' if $cgi->param('invoicing_list_POST');

#create new record object

$new = new FS::cust_main ( {
  map {
    $_, scalar($cgi->param($_))
#  } qw(custnum agentnum last first ss company address1 address2 city county
#       state zip daytime night fax payby payinfo paydate payname tax
#       otaker refnum)
  } fields('cust_main')
} );

#perhaps the invocing_list magic should move to cust_main.pm?
$error = $new->check_invoicing_list( \@invoicing_list );

#perhaps this stuff should go to cust_main.pm as well
$cust_pkg = '';
$svc_acct = '';
if ( $new->custnum eq '' ) {

  if ( $cgi->param('pkgpart_svcpart') ) {
    my $x = $cgi->param('pkgpart_svcpart');
    $x =~ /^(\d+)_(\d+)$/;
    my($pkgpart, $svcpart) = ($1, $2);
    #false laziness: copied from FS::cust_pkg::order (which should become a
    #FS::cust_main method)
    my(%part_pkg);
    # generate %part_pkg
    # $part_pkg{$pkgpart} is true iff $custnum may purchase $pkgpart
    my $agent = qsearchs('agent',{'agentnum'=> $new->agentnum });
    my($type_pkgs);
    foreach $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
      my($pkgpart)=$type_pkgs->pkgpart;
      $part_pkg{$pkgpart}++;
    }
    #eslaf

    $error ||= "Agent ". $new->agentnum. " (type ". $agent->typenum. ") can't".
               "purchase pkgpart ". $pkgpart
      unless $part_pkg{ $pkgpart };

    $cust_pkg = new FS::cust_pkg ( {
                            #later         'custnum' => $custnum,
                                     'pkgpart' => $pkgpart,
                                   } );
    $error ||= $cust_pkg->check;

    #$cust_svc = new FS::cust_svc ( { 'svcpart' => $svcpart } );

    #$error ||= $cust_svc->check;

    $svc_acct = new FS::svc_acct ( {
                                     'svcpart'   => $svcpart,
                                     'username'  => $cgi->param('username'),
                                     '_password' => $cgi->param('_password'),
                                     'popnum'    => $cgi->param('popnum'),
                                   } );

    my $y = $svc_acct->setdefault; # arguably should be in new method
    $error ||= $y unless ref($y);
    #and just in case you were silly
    $svc_acct->svcpart($svcpart);
    $svc_acct->username($cgi->param('username'));
    $svc_acct->_password($cgi->param('_password'));
    $svc_acct->popnum($cgi->param('popnum'));

    $error ||= $svc_acct->check;

  } elsif ( $cgi->param('username') ) { #good thing to catch
    $error = "Can't assign username without a package!";
  }

  $error ||= $new->insert;
  if ( $cust_pkg && ! $error ) {
    $cust_pkg->custnum( $new->custnum );
    $error ||= $cust_pkg->insert; 
    warn "WARNING: $error on pre-checked cust_pkg record!" if $error;
    $svc_acct->pkgnum( $cust_pkg->pkgnum );
    $error ||= $svc_acct->insert;
    warn "WARNING: $error on pre-checked svc_acct record!" if $error;
  }
} else { #create old record object
  my $old = qsearchs( 'cust_main', { 'custnum' => $new->custnum } ); 
  $error ||= "Old record not found!" unless $old;
  $error ||= $new->replace($old);
}

if ( $error ) {
  $cgi->param('error', $error);
  print $cgi->redirect(popurl(2). "cust_main.cgi?". $cgi->query_string );
} else { 
  $new->invoicing_list( \@invoicing_list );
  $custnum = $new->custnum;
  print $cgi->redirect(popurl(3). "view/cust_main.cgi?$custnum");
} 
