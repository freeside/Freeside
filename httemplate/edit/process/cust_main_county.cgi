<%

foreach ( grep { /^tax\d+$/ } $cgi->param ) {
  /^tax(\d+)$/ or die "Illegal form $_!";
  my($taxnum)=$1;
  my($old)=qsearchs('cust_main_county',{'taxnum'=>$taxnum})
    or die "Couldn't find taxnum $taxnum!";
  my $exempt_amount = $cgi->param("exempt_amount$taxnum");
  next unless $old->tax ne $cgi->param("tax$taxnum")
              || $old->exempt_amount ne $exempt_amount;
  my %hash = $old->hash;
  $hash{tax} = $cgi->param("tax$taxnum");
  $hash{exempt_amount} = $exempt_amount;
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
