<% include('/elements/header-popup.html', "Enter additional $title") %>

<% include('/elements/error.html') %>

<FORM ACTION="<% $p1 %>process/cust_main_county-add.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="taxnum"  VALUE="<% $taxnum %>">
<INPUT TYPE="hidden" NAME="what"  VALUE="<% $what %>">

<TEXTAREA NAME="expansion" COLS="50" ROWS="16"><% $expansion |h %></TEXTAREA>

<BR>
<INPUT TYPE="submit" VALUE="Add <% $title %>">

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

$cgi->param('taxnum') =~ /^(\d+)$/ or die "Illegal taxnum";
my $taxnum = $1;

my $expansion = '';
if ( $cgi->param('error') ) {
  $expansion = $cgi->param('expansion');
}

my $cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum})
  or die "cust_main_county.taxnum $taxnum not found";

$cgi->param('what') =~ /^(\w+)$/ or die "Illegal what";
my $what = $1;

my $title;
if ( $what eq 'city' ) {
  $title = 'Cities';
} elsif ( $what eq 'county' ) {
  $title = 'Counties';
} else { #???
  die "unknown what $what";
  #$title = 'States/Provinces';
}

my $p1 = popurl(1);

</%init>
