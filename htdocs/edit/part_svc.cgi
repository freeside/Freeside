#!/usr/bin/perl -Tw
#
# part_svc.cgi: Add/Edit service (output form)
#
# ivan@sisd.com 97-nov-14
#
# Changes to allow page to work at a relative position in server
#       bmccane@maxbaud.net     98-apr-3
#
# use FS::CGI, added inline documentation ivan@sisd.com 98-jul-12

use strict;
use CGI::Base;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::Record qw(qsearchs);
use FS::part_svc qw(fields);
use FS::CGI qw(header menubar);

my($cgi) = new CGI::Base;
$cgi->get;

&cgisuidsetup($cgi);

SendHeaders(); # one guess.

my($part_svc,$action);
if ( $cgi->var('QUERY_STRING') =~ /^(\d+)$/ ) { #editing
  $part_svc=qsearchs('part_svc',{'svcpart'=>$1});
  $action='Edit';
} else { #adding
  $part_svc=create FS::part_svc {};
  $action='Add';
}
my($hashref)=$part_svc->hashref;

print header("$action Service Definition", menubar(
  'Main Menu' => '../',
  'View all services' => '../browse/part_svc.cgi',
)), '<FORM ACTION="process/part_svc.cgi" METHOD=POST>';



print qq!<INPUT TYPE="hidden" NAME="svcpart" VALUE="$hashref->{svcpart}">!,
      "Service Part #", $hashref->{svcpart} ? $hashref->{svcpart} : "(NEW)";

print <<END;
<PRE>
Service  <INPUT TYPE="text" NAME="svc" VALUE="$hashref->{svc}">
Table    <SELECT NAME="svcdb" SIZE=1>
END

print map '<OPTION'. ' SELECTED'x($_ eq $hashref->{svcdb}). ">$_\n", qw(
  svc_acct svc_domain svc_acct_sm svc_charge svc_wo
);

print <<END;
</SELECT></PRE>
Services are items you offer to your customers.
<UL><LI>svc_acct - Shell accounts, POP mailboxes, SLIP/PPP and ISDN accounts
    <LI>svc_domain - Virtual domains
    <LI>svc_acct_sm - Virtual domain mail aliasing
    <LI>svc_charge - One-time charges (Partially unimplemented)
    <LI>svc_wo - Work orders (Partially unimplemented)
</UL>
For the columns in the table selected above, you can set default or fixed 
values.  For example, a SLIP/PPP account may have a default (or perhaps fixed)
<B>slipip</B> of <B>0.0.0.0</B>, while a POP mailbox will probably have a fixed
blank <B>slipip</B> as well as a fixed shell something like <B>/bin/true</B> or
<B>/usr/bin/passwd</B>.
<BR><BR>
<TABLE BORDER CELLPADDING=4><TR><TH>Table</TH><TH>Field</TH>
<TH COLSPAN=2>Modifier</TH></TR>
END

#these might belong somewhere else for other user interfaces 
#pry need to eventually create stuff that's shared amount UIs
my(%defs)=(
  'svc_acct' => {
    'dir'       => 'Home directory',
    'uid'       => 'UID (set to fixed and blank for dial-only)',
    'slipip'    => 'IP address',
    'popnum'    => '<A HREF="../browse/svc_acct_pop.cgi/">POP number</A>',
    'username'  => 'Username',
    'quota'     => '(unimplemented)',
    '_password' => 'Password',
    'gid'       => 'GID (when blank, defaults to UID)',
    'shell'     => 'Shell',
    'finger'    => 'GECOS',
  },
  'svc_domain' => {
    'domain'    => 'Domain',
  },
  'svc_acct_sm' => {
    'domuser'   => 'domuser@virtualdomain.com',
    'domuid'    => 'UID where domuser@virtualdomain.com mail is forwarded',
    'domsvc'    => 'svcnum from svc_domain for virtualdomain.com',
  },
  'svc_charge' => {
    'amount'    => 'amount',
  },
  'svc_wo' => {
    'worker'    => 'Worker',
    '_date'      => 'Date',
  },
);

my($svcdb);
foreach $svcdb ( qw(
  svc_acct svc_domain svc_acct_sm svc_charge svc_wo
) ) {

  my(@rows)=map { /^${svcdb}__(.*)$/; $1 }
    grep ! /_flag$/,
      grep /^${svcdb}__/,
        fields('part_svc');
  my($rowspan)=scalar(@rows);

  my($ptmp)="<TD ROWSPAN=$rowspan>$svcdb</TD>";
  my($row);
  foreach $row (@rows) {
    my($value)=$part_svc->getfield($svcdb.'__'.$row);
    my($flag)=$part_svc->getfield($svcdb.'__'.$row.'_flag');
    print "<TR>$ptmp<TD>$row - <FONT SIZE=-1>$defs{$svcdb}{$row}</FONT></TD>";
    print qq!<TD><INPUT TYPE="radio" NAME="${svcdb}__${row}_flag" VALUE=""!.
      ' CHECKED'x($flag eq ''). "><BR>Off</TD>";
    print qq!<TD><INPUT TYPE="radio" NAME="${svcdb}__${row}_flag" VALUE="D"!.
      ' CHECKED'x($flag eq 'D'). ">Default ";
    print qq!<INPUT TYPE="radio" NAME="${svcdb}__${row}_flag" VALUE="F"!.
      ' CHECKED'x($flag eq 'F'). ">Fixed ";
    print qq!<BR><INPUT TYPE="text" NAME="${svcdb}__${row}" VALUE="$value">!,
      "</TD></TR>";
    $ptmp='';
  }
}
print "</TABLE>";

print qq!\n<CENTER><BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{svcpart} ? "Apply changes" : "Add service",
      qq!"></CENTER>!;

print <<END;

    </FORM>
  </BODY>
</HTML>
END

