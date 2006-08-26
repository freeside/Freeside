<% header("Apply Payment", '') %>

% if ( $cgi->param('error') ) { 
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $cgi->param('error') %></FONT>
  <BR><BR>
% } 

<FORM ACTION="<% $p1 %>process/cust_bill_pay.cgi" METHOD=POST>

Payment #<B><% $paynum %></B>
<INPUT TYPE="hidden" NAME="paynum" VALUE="<% $paynum %>">

<BR>Date: <B><% time2str("%D", $cust_pay->_date) %></B>

<BR>Amount: $<B><% $cust_pay->paid %></B>

<BR>Unapplied amount: $<B><% $unapplied %></B>

<SCRIPT TYPE="text/javascript">
function changed(what) {
  cust_bill = what.options[what.selectedIndex].value;

% foreach my $cust_bill ( @cust_bill ) {

    if ( cust_bill == <% $cust_bill->invnum %> ) {
      what.form.amount.value = "<% min($cust_bill->owed, $unapplied) %>";
    }

% } 

  if ( cust_bill == "Refund" ) {
    what.form.amount.value = "<% $unapplied %>";
  }
}
</SCRIPT>

<BR>Invoice #<SELECT NAME="invnum" SIZE=1 onChange="changed(this)">
<OPTION VALUE="">

% foreach my $cust_bill ( @cust_bill ) { 
  <OPTION<% $cust_bill->invnum eq $invnum ? ' SELECTED' : '' %> VALUE="<% $cust_bill->invnum %>"><% $cust_bill->invnum %> - <% time2str("%D", $cust_bill->_date) %> - $<% $cust_bill->owed %>
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
my($paynum, $amount, $invnum);
if ( $cgi->param('error') ) {
  $paynum = $cgi->param('paynum');
  $amount = $cgi->param('amount');
  $invnum = $cgi->param('invnum');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $paynum = $1;
  $amount = '';
  $invnum = '';
}

my $otaker = getotaker;

my $p1 = popurl(1);

my $cust_pay = qsearchs('cust_pay', { 'paynum' => $paynum } );
die "payment $paynum not found!" unless $cust_pay;

my $unapplied = $cust_pay->unapplied;

my @cust_bill = sort {    $a->_date  <=> $b->_date
                       or $a->invnum <=> $b->invnum
                     }
                grep { $_->owed != 0 }
                qsearch('cust_bill', { 'custnum' => $cust_pay->custnum } );
</%init>

