<!-- $Id: cust_main_county.cgi,v 1.4 2002-02-09 18:24:01 ivan Exp $ -->
<%

foreach ( $cgi->param ) {
  /^tax(\d+)$/ or die "Illegal form $_!";
  my($taxnum)=$1;
  my($old)=qsearchs('cust_main_county',{'taxnum'=>$taxnum})
    or die "Couldn't find taxnum $taxnum!";
  next unless $old->getfield('tax') ne $cgi->param("tax$taxnum");
  my(%hash)=$old->hash;
  $hash{tax}=$cgi->param("tax$taxnum");
  my($new)=new FS::cust_main_county \%hash;
  my($error)=$new->replace($old);
  if ( $error ) {
    $cgi->param('error', $error);
    print $cgi->redirect(popurl(2). "cust_main_county.cgi?". $cgi->query_string );
    myexit();
  }
}

print $cgi->redirect(popurl(3). "browse/cust_main_county.cgi");

%>
