<%
# <!-- $Id: svc_forward.cgi,v 1.4 2001-09-11 23:44:01 ivan Exp $ -->

use strict;
use vars qw( $conf $cgi $mydomain $action $svcnum $svc_forward $pkgnum $svcpart
             $part_svc $query %email $p1 $srcsvc $dstsvc $dst );
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FS::UID qw(cgisuidsetup);
use FS::CGI qw(header popurl);
use FS::Record qw(qsearch qsearchs fields);
use FS::svc_forward;
use FS::Conf;

$cgi = new CGI;
&cgisuidsetup($cgi);

$conf = new FS::Conf;
$mydomain = $conf->config('domain');

if ( $cgi->param('error') ) {
  $svc_forward = new FS::svc_forward ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_forward')
  } );
  $svcnum = $svc_forward->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;
} else {
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_forward=qsearchs('svc_forward',{'svcnum'=>$svcnum})
      or die "Unknown (svc_forward) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;
  
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { #adding

    $svc_forward = new FS::svc_forward({});

    foreach $_ (split(/-/,$query)) { #get & untaint pkgnum & svcpart
      $pkgnum=$1 if /^pkgnum(\d+)$/;
      $svcpart=$1 if /^svcpart(\d+)$/;
    }
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

    $svcnum='';

    #set fixed and default fields from part_svc
    foreach my $part_svc_column (
      grep { $_->columnflag } $part_svc->all_part_svc_column
    ) {
      $svc_forward->setfield( $part_svc_column->columnname,
                              $part_svc_column->columnvalue,
                            );
    }


  }
}
$action = $svc_forward->svcnum ? 'Edit' : 'Add';

if ($pkgnum) {

  #find all possible user svcnums (and emails)

  #starting with those currently attached
  if ( $svc_forward->srcsvc ) {
    my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $svc_forward->srcsvc } );
    $email{$svc_forward->srcsvc} = $svc_acct->email;
  }
  if ( $svc_forward->dstsvc ) {
    my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $svc_forward->dstsvc } );
    $email{$svc_forward->dstsvc} = $svc_acct->email;
  }

  #and including the rest for this customer
  my($u_part_svc,@u_acct_svcparts);
  foreach $u_part_svc ( qsearch('part_svc',{'svcdb'=>'svc_acct'}) ) {
    push @u_acct_svcparts,$u_part_svc->getfield('svcpart');
  }

  my($cust_pkg)=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  my($custnum)=$cust_pkg->getfield('custnum');
  my($i_cust_pkg);
  foreach $i_cust_pkg ( qsearch('cust_pkg',{'custnum'=>$custnum}) ) {
    my($cust_pkgnum)=$i_cust_pkg->getfield('pkgnum');
    my($acct_svcpart);
    foreach $acct_svcpart (@u_acct_svcparts) {   #now find the corresponding 
                                              #record(s) in cust_svc ( for this
                                              #pkgnum ! )
      my($i_cust_svc);
      foreach $i_cust_svc ( qsearch('cust_svc',{'pkgnum'=>$cust_pkgnum,'svcpart'=>$acct_svcpart}) ) {
        $svc_acct=qsearchs('svc_acct',{'svcnum'=>$i_cust_svc->getfield('svcnum')});
        $email{$svc_acct->getfield('svcnum')}=$svc_acct->email;
      }  
    }
  }

} elsif ( $action eq 'Edit' ) {

  my($svc_acct)=qsearchs('svc_acct',{'svcnum'=>$svc_forward->srcsvc});
  $email{$svc_forward->srcsvc} = $svc_acct->email;

  $svc_acct=qsearchs('svc_acct',{'svcnum'=>$svc_forward->dstsvc});
  $email{$svc_forward->dstsvc} = $svc_acct->email;

} else {
  die "\$action eq Add, but \$pkgnum is null!\n";
}

($srcsvc,$dstsvc,$dst)=(
  $svc_forward->srcsvc,
  $svc_forward->dstsvc,
  $svc_forward->dst,
);

#display

$p1 = popurl(1);
print $cgi->header( '-expires' => 'now' ), header("Mail Forward $action", '',
      " onLoad=\"visualize()\"");

%>

<SCRIPT>
function visualize(what){
    if (document.getElementById) {
      document.getElementById('dother').style.visibility = '<%= $dstsvc ? 'hidden' : 'visible' %>';
    }
}
function fixup(what){
    if (document.getElementById) {
      if (document.getElementById('dother').style.visibility == 'hidden') {
        what.dst.value='';
      }
    }
}
</SCRIPT>

<%

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="${p1}process/svc_forward.cgi" onSubmit="fixup(this)" METHOD=POST>!;

#svcnum
print qq!<INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">!;
print qq!Service #<FONT SIZE=+1><B>!, $svcnum ? $svcnum : " (NEW)", "</B></FONT>";
print qq!<BR>!;

#pkgnum
print qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">!;
 
#svcpart
print qq!<INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">!;

#srcsvc
print qq!\n\nMail to <SELECT NAME="srcsvc" SIZE=1>!;
foreach $_ (keys %email) {
  print "<OPTION", $_ eq $srcsvc ? " SELECTED" : "",
        qq! VALUE="$_">$email{$_}!;
}
print "</SELECT>";

#dstsvc
print qq! forwards to <SELECT NAME="dstsvc" SIZE=1 onChange="changed(this)">!;
foreach $_ (keys %email) {
  print "<OPTION", $_ eq $dstsvc ? " SELECTED" : "",
        qq! VALUE="$_">$email{$_}!;
}
print "<OPTION", 0 eq $dstsvc ? " SELECTED" : "",
      qq! VALUE="0">(other)!;
print "</SELECT> mailbox.";

%>

<SCRIPT>
var selectchoice = null;
function changed(what) {
  selectchoice = what.options[what.selectedIndex].value;
  if (selectchoice == "0") {
    if (document.getElementById) {
      document.getElementById('dother').style.visibility = "visible";
    }
  }else{
    if (document.getElementById) {
      document.getElementById('dother').style.visibility = "hidden";
    }
  }
}
if (document.getElementById) {
    document.write("<DIV ID=\"dother\" STYLE=\"visibility: hidden\">");
}
</SCRIPT>

<%
print qq! Other destination: <INPUT TYPE="text" NAME="dst" VALUE="$dst">!;
%>

<SCRIPT>
if (document.getElementById) {
    document.write("</DIV>");
}
</SCRIPT>

<CENTER><INPUT TYPE="submit" VALUE="Submit"></CENTER>
</FORM>

<TAG onLoad="
    if (document.getElementById) {
      document.getElementById('dother').style.visibility = '<%= $dstsvc ? 'hidden' : 'visible' %>';
      document.getElementById('dlabel').style.visibility = '<%= $dstsvc ? 'hidden' : 'visible' %>';
    }
">


  </BODY>
</HTML>
