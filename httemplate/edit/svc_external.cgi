<!-- mason kludge -->
<%

my( $svcnum,  $pkgnum, $svcpart, $part_svc, $svc_external );
if ( $cgi->param('error') ) {
  $svc_external = new FS::svc_external ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_external')
  } );
  $svcnum = $svc_external->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;
} else {
  my($query) = $cgi->keywords;
  if ( $query =~ /^(\d+)$/ ) { #editing
    $svcnum=$1;
    $svc_external=qsearchs('svc_external',{'svcnum'=>$svcnum})
      or die "Unknown (svc_external) svcnum!";

    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
      or die "Unknown (cust_svc) svcnum!";

    $pkgnum=$cust_svc->pkgnum;
    $svcpart=$cust_svc->svcpart;
  
    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

  } else { #adding

    foreach $_ (split(/-/,$query)) { #get & untaint pkgnum & svcpart
      $pkgnum=$1 if /^pkgnum(\d+)$/;
      $svcpart=$1 if /^svcpart(\d+)$/;
    }
    $svc_external = new FS::svc_external { svcpart => $svcpart };

    $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
    die "No part_svc entry!" unless $part_svc;

    $svcnum='';

    #set fixed and default fields from part_svc
    foreach my $part_svc_column (
      grep { $_->columnflag } $part_svc->all_part_svc_column
    ) {
      $svc_external->setfield( $part_svc_column->columnname,
                               $part_svc_column->columnvalue,
                             );
    }

  }
}
my $action = $svc_external->svcnum ? 'Edit' : 'Add';

my $p1 = popurl(1);
print header("External service $action", '');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print qq!<FORM ACTION="${p1}process/svc_external.cgi" METHOD=POST>!;

#display
 

#svcnum
print qq!<INPUT TYPE="hidden" NAME="svcnum" VALUE="$svcnum">!;
print qq!Service #<B>!, $svcnum ? $svcnum : "(NEW)", "</B><BR><BR>";

#pkgnum
print qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">!;
 
#svcpart
print qq!<INPUT TYPE="hidden" NAME="svcpart" VALUE="$svcpart">!;

my($id,$title)=(
  $svc_external->id,
  $svc_external->title,
);

print &ntable("#cccccc",2),
      '<TR><TD ALIGN="right">External ID</TD><TD>'.
      qq!<INPUT TYPE="text" NAME="id" VALUE="$id">!.
      '</TD></TR>'.
      '<TR><TD ALIGN="right">Title</TD><TD>'.
      qq!<INPUT TYPE="text" NAME="title" VALUE="$title">!.
      '</TD></TR>';

foreach my $field ($svc_external->virtual_fields) {
  if ( $part_svc->part_svc_column($field)->columnflag ne 'F' ) {
    # If the flag is X, it won't even show up in $svc_acct->virtual_fields.
    print $svc_external->pvf($field)->widget('HTML', 'edit', 
        $svc_external->getfield($field));
  }
}

%>

</TABLE><BR><INPUT TYPE="submit" VALUE="Submit">
    </FORM>
  </BODY>
</HTML>

