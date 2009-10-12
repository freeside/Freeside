<% include('/elements/header-popup.html', "Enter $title") %>

<% include('/elements/error.html') %>

<FORM ACTION="<% $p1 %>process/cust_main_county-expand.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="taxnum" VALUE="<% $taxnum %>">

<TEXTAREA NAME="expansion" COLS="50" ROWS="16"><% $expansion |h %></TEXTAREA>

<BR>
<INPUT TYPE="submit" VALUE="Add <% $title %>">

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my($taxnum, $expansion);
my($query) = $cgi->keywords;
if ( $cgi->param('error') ) {
  $taxnum = $cgi->param('taxnum');
  $expansion = $cgi->param('expansion');
} else {
  $query =~ /^(\d+)$/
    or die "Illegal taxnum (query $query)";
  $taxnum = $1;
  $expansion = '';
}

my $cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum})
  or die "cust_main_county.taxnum $taxnum not found";

my $title;

die "Can't expand entry!" if $cust_main_county->city;

if ( $cust_main_county->county ) {
  $title = 'Cities';
} elsif ( $cust_main_county->state ) {
  $title = 'Counties';
} else {
  $title = 'States/Provinces';
}

my $p1 = popurl(1);

</%init>
