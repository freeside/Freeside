#!/usr/bin/perl -Tw
#
# $Id: agent_type.cgi,v 1.8 1999-01-18 09:41:22 ivan Exp $
#
# agent_type.cgi: Add/Edit agent type (output form)
#
# ivan@sisd.com 97-dec-10
#
# Changes to allow page to work at a relative position in server
# Changed 'type' to 'atype' because Pg6.3 reserves the type word
#	bmccane@maxbaud.net	98-apr-3
#
# use FS::CGI, added inline documentation ivan@sisd.com 98-jul-12
#
# $Log: agent_type.cgi,v $
# Revision 1.8  1999-01-18 09:41:22  ivan
# all $cgi->header calls now include ( '-expires' => 'now' ) for mod_perl
# (good idea anyway)
#
# Revision 1.7  1999/01/18 09:22:29  ivan
# changes to track email addresses for email invoicing
#
# Revision 1.6  1998/12/17 06:16:58  ivan
# fix double // in relative URLs, s/CGI::Base/CGI/;
#
# Revision 1.5  1998/11/21 07:58:27  ivan
# package names link to them
#
# Revision 1.4  1998/11/21 07:45:19  ivan
# visual, use FS::table_name when doing qsearch('table_name')
#
# Revision 1.3  1998/11/15 11:20:12  ivan
# s/CGI-Base/CGI.pm/ causes s/QUERY_STRING/keywords/;
#
# Revision 1.2  1998/11/13 09:56:46  ivan
# change configuration file layout to support multiple distinct databases (with
# own set of config files, export, etc.)
#

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearch qsearchs);
use FS::agent_type;
use FS::CGI qw(header menubar popurl);
use FS::agent_type;
use FS::part_pkg;
use FS::type_pkgs;

my($cgi) = new CGI;

&cgisuidsetup($cgi);

my($agent_type,$action);
if ( $cgi->keywords ) { #editing
  my( $query ) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $agent_type=qsearchs('agent_type',{'typenum'=>$1});
  $action='Edit';
} else { #adding
  $agent_type=create FS::agent_type {};
  $action='Add';
}
my($hashref)=$agent_type->hashref;

my($p)=popurl(2);
print $cgi->header( '-expires' => 'now' ), header("$action Agent Type", menubar(
  'Main Menu' => "$p",
  'View all agent types' => "${p}browse/agent_type.cgi",
)), '<FORM ACTION="', popurl(1), 'process/agent_type.cgi" METHOD=POST>';

print qq!<INPUT TYPE="hidden" NAME="typenum" VALUE="$hashref->{typenum}">!,
      "Agent Type #", $hashref->{typenum} ? $hashref->{typenum} : "(NEW)";

print <<END;
<BR><BR>Agent Type <INPUT TYPE="text" NAME="atype" SIZE=32 VALUE="$hashref->{atype}">
<BR><BR>Select which packages agents of this type may sell to customers<BR>
END

my($part_pkg);
foreach $part_pkg ( qsearch('part_pkg',{}) ) {
  print qq!<BR><INPUT TYPE="checkbox" NAME="pkgpart!,
        $part_pkg->getfield('pkgpart'), qq!" !,
       # ( 'CHECKED 'x scalar(
        qsearchs('type_pkgs',{
          'typenum' => $agent_type->getfield('typenum'),
          'pkgpart'  => $part_pkg->getfield('pkgpart'),
        })
          ? 'CHECKED '
          : '',
        qq!"VALUE="ON"> !,
    qq!<A HREF="${p}edit/part_pkg.cgi?!, $part_pkg->pkgpart, 
    '">', $part_pkg->getfield('pkg'), '</A>',
  ;
}

print qq!<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{typenum} ? "Apply changes" : "Add agent type",
      qq!">!;

print <<END;
    </FORM>
  </BODY>
</HTML>
END

