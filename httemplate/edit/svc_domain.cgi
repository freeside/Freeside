<!-- mason kludge -->
<%

my($svcnum, $pkgnum, $svcpart, $kludge_action, $purpose, $part_svc,
   $svc_domain);
if ( $cgi->param('error') ) {
  $svc_domain = new FS::svc_domain ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_domain')
  } );
  $svcnum = $svc_domain->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $kludge_action = $cgi->param('action');
  $purpose = $cgi->param('purpose');
  $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
  die "No part_svc entry!" unless $part_svc;
} else {
  $kludge_action = '';
  $purpose = '';
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_domain=qsearchs('svc_domain',{'svcnum'=>$svcnum})
      or die "Unknown (svc_domain) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;

    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { #adding

    $svc_domain = new FS::svc_domain({});
  
    foreach $_ (split(/-/,$query)) {
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
      $svc_domain->setfield( $part_svc_column->columnname,
                             $part_svc_column->columnvalue,
                           );
    }

  }

}
my $action = $svcnum ? 'Edit' : 'Add';

my $svc = $part_svc->getfield('svc');

my $otaker = getotaker;

my $domain = $svc_domain->domain;

my $p1 = popurl(1);
print header("$action $svc", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print <<END;
    <FORM ACTION="${p1}process/svc_domain.cgi" METHOD=POST>
      <INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">
      <INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">
      <INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">
END

print qq!<INPUT TYPE="radio" NAME="action" VALUE="N"!;
print ' CHECKED' if $kludge_action eq 'N';
print qq!>New!;
print qq!<BR><INPUT TYPE="radio" NAME="action" VALUE="M"!;
print ' CHECKED' if $kludge_action eq 'M';
print qq!>Transfer!;

print <<END;
<P>Domain <INPUT TYPE="text" NAME="domain" VALUE="$domain" SIZE=28 MAXLENGTH=63>
<BR>Purpose/Description: <INPUT TYPE="text" NAME="purpose" VALUE="$purpose" SIZE=64>
<P><INPUT TYPE="submit" VALUE="Submit">
    </FORM>
  </BODY>
</HTML>
END

%>
