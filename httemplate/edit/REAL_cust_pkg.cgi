<!-- mason kludge -->
<%
# <!-- $Id: REAL_cust_pkg.cgi,v 1.4 2002-07-08 13:07:40 ivan Exp $ -->

my $error ='';
my $pkgnum = '';
if ( $cgi->param('error') ) {
  $error = $cgi->param('error');
  $pkgnum = $cgi->param('pkgnum');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "no pkgnum";
  $pkgnum = $1;
}

#get package record
my $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
die "No package!" unless $cust_pkg;
my $part_pkg = qsearchs('part_pkg',{'pkgpart'=>$cust_pkg->getfield('pkgpart')});

if ( $error ) {
  #$cust_pkg->$_(str2time($cgi->param($_)) foreach qw(setup bill);
  $cust_pkg->setup(str2time($cgi->param('setup')));
  $cust_pkg->bill(str2time($cgi->param('bill')));
}

#my $custnum = $cust_pkg->getfield('custnum');
print header('Package Edit'); #, menubar(
#  "View this customer (#$custnum)" => popurl(2). "view/cust_main.cgi?$custnum",
#  'Main Menu' => popurl(2)
#));

#print info
my($susp,$cancel,$expire)=(
  $cust_pkg->getfield('susp'),
  $cust_pkg->getfield('cancel'),
  $cust_pkg->getfield('expire'),
);
my($pkg,$comment)=($part_pkg->getfield('pkg'),$part_pkg->getfield('comment'));
my($setup,$bill)=($cust_pkg->getfield('setup'),$cust_pkg->getfield('bill'));
my $otaker = $cust_pkg->getfield('otaker');

print '<FORM NAME="formname" ACTION="process/REAL_cust_pkg.cgi" METHOD="POST">',      qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="$pkgnum">!;

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: $error</FONT>!
  if $error;

print ntable("#cccccc",2),
      '<TR><TD ALIGN="right">Package number</TD><TD BGCOLOR="#ffffff">',
      $pkgnum, '</TD></TR>',
      '<TR><TD ALIGN="right">Package</TD><TD BGCOLOR="#ffffff">',
      $pkg,  '</TD></TR>',
      '<TR><TD ALIGN="right">Comment</TD><TD BGCOLOR="#ffffff">',
      $comment,  '</TD></TR>',
      '<TR><TD ALIGN="right">Order taker</TD><TD BGCOLOR="#ffffff">',
      $otaker,  '</TD></TR>',
      '<TR><TD ALIGN="right">Setup date</TD><TD>'.
      '<INPUT TYPE="text" NAME="setup" SIZE=32 VALUE="',
      ( $setup ? time2str("%c %z (%Z)",$setup) : "" ), '"></TD></TR>',
      '<TR><TD ALIGN="right">Next bill date</TD><TD>',
      '<INPUT TYPE="text" NAME="bill" SIZE=32 VALUE="',
      ( $bill ? time2str("%c %z (%Z)",$bill) : "" ), '"></TD></TR>',
;

print '<TR><TD ALIGN="right">Suspension date</TD><TD BGCOLOR="#ffffff">',
       time2str("%D",$susp), '</TD></TR>'
  if $susp;

#print '<TR><TD ALIGN="right">Expiration date</TD><TD BGCOLOR="#ffffff">',
#       time2str("%D",$expire), '</TD></TR>'
#  if $expire;
print '<TR><TD ALIGN="right">Expiration date'.
      '</TD><TD>',
      '<INPUT TYPE="text" NAME="expire" SIZE=32 VALUE="',
      ( $expire ? time2str("%c %z (%Z)",$expire) : "" ), '">'.
      '<BR><FONT SIZE=-1>(will <b>cancel</b> this package'.
      ' when the date is reached)</FONT>'.
      '</TD></TR>';

print '<TR><TD ALIGN="right">Cancellation date</TD><TD BGCOLOR="#ffffff">',
       time2str("%D",$cancel), '</TD></TR>'
  if $cancel;

%>
</TABLE>
<BR><INPUT TYPE="submit" VALUE="Apply Changes">
</FORM>
</BODY>
</HTML>
