<% include('/elements/header-popup.html', "Enter $title") %>

<% include('/elements/error.html') %>

<FORM ACTION="<% $p1 %>process/cust_main_county-expand.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="taxnum" VALUE="<% $taxnum %>">
<INPUT TYPE="hidden" NAME="taxclass" VALUE="<% $taxclass |h %>">

<TEXTAREA NAME="expansion" COLS="50" ROWS="16"><% $expansion |h %></TEXTAREA>

<BR>
<INPUT TYPE="submit" VALUE="Add <% $title %>">

</FORM>
</BODY>
</HTML>

<%init>

my($taxnum, $expansion, $taxclass);
my($query) = $cgi->keywords;
if ( $cgi->param('error') ) {
  $taxnum = $cgi->param('taxnum');
  $expansion = $cgi->param('expansion');
  $taxclass = $cgi->param('taxclass');
} else {
  $query =~ /^(taxclass)?(\d+)$/
    or die "Illegal taxnum (query $query)";
  $taxclass = $1 ? 'taxclass' : '';
  $taxnum = $2;
  $expansion = '';
}

my $cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum})
  or die "cust_main_county.taxnum $taxnum not found";

my $title;
if ( $taxclass ) {
  die "Can't expand entry!" if $cust_main_county->taxclass;

  $title = 'Tax Classes';

  # prepopuplate with other tax classes... which should really have a primary
  #  key of their own... also this could be more efficient in the error case...
  my $sth = dbh->prepare("SELECT DISTINCT taxclass FROM cust_main_county")
    or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  my %taxclasses = map { $_->[0] => 1 } @{$sth->fetchall_arrayref};
  $expansion ||= join("\n", grep $_, keys %taxclasses );
  
} else {
  die "Can't expand entry!" if $cust_main_county->county;

  if ( $cust_main_county->state ) {
    $title = 'Counties';
  } else {
    $title = 'States/Provinces';
  }

}

my $p1 = popurl(1);

</%init>
