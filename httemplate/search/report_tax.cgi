<%
#!/usr/bin/perl -Tw
#
# $Id: report_tax.cgi,v 1.1 2002-02-22 23:18:34 jeff Exp $
#
# Usage: post form to:
#        http://server.name/path/svc_domain.cgi
#
# ivan@voicenet.com 96-mar-5
#
# need to look at table in results to make it more readable
#
# ivan@voicenet.com
#
# rewrite ivan@sisd.com 98-mar-15
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# $Log: report_tax.cgi,v $
# Revision 1.1  2002-02-22 23:18:34  jeff
# add some reporting features
#
# Revision 1.1  2002/02/05 15:22:00  jeff
# preserving state prior to 1.4.0pre7 upgrade
#
# Revision 1.2  2000/09/20 19:25:19  jeff
# local modifications
#
# Revision 1.1.1.1  2000/09/18 06:26:58  jeff
# Import of Freeside 1.2.3
#
# Revision 1.10  1999/07/20 06:03:36  ivan
# s/CGI::Request/CGI/; (how'd i miss that before?)
#
# Revision 1.9  1999/04/09 04:22:34  ivan
# also table()
#
# Revision 1.8  1999/04/09 03:52:55  ivan
# explicit & for table/itable/ntable
#
# Revision 1.7  1999/02/28 00:03:56  ivan
# removed misleading comments
#
# Revision 1.6  1999/02/09 09:22:58  ivan
# visual and bugfixes
#
# Revision 1.5  1999/01/19 05:14:16  ivan
# for mod_perl: no more top-level my() variables; use vars instead
# also the last s/create/new/;
#
# Revision 1.4  1999/01/18 09:41:40  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.3  1998/12/17 09:41:11  ivan
# s/CGI::(Base|Request)/CGI.pm/;
#

use strict;
use vars qw( $conf $cgi $beginning $ending );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(popurl idiot header table);
use FS::Record qw(qsearch qsearchs);
use FS::Conf;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;

$cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/;
$beginning = $1;

$cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/;
$ending = $1;

  print $cgi->header( '-expires' => '-2m' ),
        header('Tax Report Results');

  open (REPORT, "/usr/bin/freeside-tax-report -v -s $beginning -d $ending freeside |");

  print '<PRE>';
  while(<REPORT>) {
    print $_;
  }
  print '</PRE>';

  print '</BODY></HTML>';

%>

