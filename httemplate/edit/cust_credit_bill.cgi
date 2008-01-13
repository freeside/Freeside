<% include('/elements/header-popup.html', 'Apply Credit') %>

<% include('/elements/error.html') %>

<FORM ACTION="<% $p1 %>process/cust_credit_bill.cgi" METHOD=POST>

Credit #<B><% $crednum %></B>
<INPUT TYPE="hidden" NAME="crednum" VALUE="<% $crednum %>">

<BR>Date: <B><% time2str("%D", $cust_credit->_date) %></B>

<BR>Amount: $<B><% $cust_credit->amount %></B>

<BR>Unapplied amount: $<B><% $credited %></B>

<BR>Reason: <B><% $cust_credit->reason %></B>

<SCRIPT>
function changed(what) {
  cust_bill = what.options[what.selectedIndex].value;

% foreach my $cust_bill ( @cust_bill ) {

  if ( cust_bill == <% $cust_bill->invnum %> ) {
    what.form.amount.value = "<% min($cust_bill->owed, $credited) %>";
  }

% } 

  if ( cust_bill == "Refund" ) {
    what.form.amount.value = "<% $credited %>";
  }
}
</SCRIPT>

<BR>Invoice #<SELECT NAME="invnum" SIZE=1 onChange="changed(this)">
<OPTION VALUE="">

% foreach my $cust_bill ( @cust_bill ) { 
  <OPTION<% $cust_bill->invnum eq $invnum ? ' SELECTED' : '' %> VALUE="<% $cust_bill->invnum %>"><% $cust_bill->invnum %> - <% time2str("%D",$cust_bill->_date) %> - $<% $cust_bill->owed %>
% } 

<OPTION VALUE="Refund">Refund
</SELECT>

<BR>Amount $<INPUT TYPE="text" NAME="amount" VALUE="<% $amount %>" SIZE=8 MAXLENGTH=8>

<BR>
<CENTER><INPUT TYPE="submit" VALUE="Apply"></CENTER>

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Apply credit') #;
      || $FS::CurrentUser::CurrentUser->access_right('Post credit'): #remove after 1.7.3

my($crednum, $amount, $invnum);
if ( $cgi->param('error') ) {
  #$cust_credit_bill = new FS::cust_credit_bill ( {
  #  map { $_, scalar($cgi->param($_)) } fields('cust_credit_bill')
  #} );
  $crednum = $cgi->param('crednum');
  $amount = $cgi->param('amount');
  #$refund = $cgi->param('refund');
  $invnum = $cgi->param('invnum');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $crednum = $1;
  $amount = '';
  #$refund = 'yes';
  $invnum = '';
}

my $otaker = getotaker;

my $p1 = popurl(1);

my $cust_credit = qsearchs('cust_credit', { 'crednum' => $crednum } );
die "credit $crednum not found!" unless $cust_credit;

my $credited = $cust_credit->credited;

my @cust_bill = sort {    $a->_date  <=> $b->_date
                       or $a->invnum <=> $b->invnum
                     }
                grep { $_->owed != 0 }
                qsearch('cust_bill', { 'custnum' => $cust_credit->custnum } );

</%init>
