#!/usr/bin/perl -Tw
#
# $Id: agent_type.cgi,v 1.3 1998-11-15 11:20:12 ivan Exp $
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
# Revision 1.3  1998-11-15 11:20:12  ivan
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
use FS::CGI qw(header menubar);

my($cgi) = new CGI;

&cgisuidsetup($cgi);

my($agent_type,$action);
if ( $cgi->keywords =~ /^(\d+)$/ ) { #editing
  $agent_type=qsearchs('agent_type',{'typenum'=>$1});
  $action='Edit';
} else { #adding
  $agent_type=create FS::agent_type {};
  $action='Add';
}
my($hashref)=$agent_type->hashref;

print $cgi->header, header("$action Agent Type", menubar(
  'Main Menu' => '../',
  'View all agent types' => '../browse/agent_type.cgi',
)), '<FORM ACTION="process/agent_type.cgi" METHOD=POST>';

print qq!<INPUT TYPE="hidden" NAME="typenum" VALUE="$hashref->{typenum}">!,
      "Agent Type #", $hashref->{typenum} ? $hashref->{typenum} : "(NEW)";

print <<END;
<BR>Type <INPUT TYPE="text" NAME="atype" SIZE=32 VALUE="$hashref->{atype}">
<P>Select which packages agents of this type may sell to customers</P>
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
        qq!"VALUE="ON"> !,$part_pkg->getfield('pkg')
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

