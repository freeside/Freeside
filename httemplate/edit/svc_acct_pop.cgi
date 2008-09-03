<% include('/elements/header.html', "$action Access Number", menubar(
     'View all Access Numbers' => popurl(2). "browse/svc_acct_pop.cgi",
   ))
%>

<% include('/elements/error.html') %>

<FORM ACTION="<%$p1%>process/svc_acct_pop.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="popnum" VALUE="<% $hashref->{popnum} %>">
Access Number #<% $hashref->{popnum} ? $hashref->{popnum} : "(NEW)" %>

<PRE>
City      <INPUT TYPE="text" NAME="city" SIZE=32 VALUE="<% $hashref->{city} %>">
State     <INPUT TYPE="text" NAME="state" SIZE=16 MAXLENGTH=16 VALUE="<% $hashref->{state} %>">
Area Code <INPUT TYPE="text" NAME="ac" SIZE=4 MAXLENGTH=3 VALUE="<% $hashref->{ac} %>">
Exchange  <INPUT TYPE="text" NAME="exch" SIZE=4 MAXLENGTH=3 VALUE="<% $hashref->{exch} %>">
Local     <INPUT TYPE="text" NAME="loc" SIZE=5 MAXLENGTH=4 VALUE="<% $hashref->{loc} %>">
</PRE>

<BR>
<INPUT TYPE="submit" VALUE="<% $hashref->{popnum} ? "Apply changes" : "Add Access Number" %>">

</FORM>

<% include('/elements/footer.html') %>

<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Dialup configuration')
      || $curuser->access_right('Dialup global configuration');

my $svc_acct_pop;
if ( $cgi->param('error') ) {
  $svc_acct_pop = new FS::svc_acct_pop ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_acct_pop')
  } );
} elsif ( $cgi->keywords ) { #editing
  my($query)=$cgi->keywords;
  $query =~ /^(\d+)$/;
  $svc_acct_pop=qsearchs('svc_acct_pop',{'popnum'=>$1});
} else { #adding
  $svc_acct_pop = new FS::svc_acct_pop {};
}
my $action = $svc_acct_pop->popnum ? 'Edit' : 'Add';
my $hashref = $svc_acct_pop->hashref;

my $p1 = popurl(1);

</%init>
