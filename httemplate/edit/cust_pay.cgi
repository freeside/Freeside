% if ( $link eq 'popup' ) { 
  <& /elements/header-popup.html, $title  &>
% } else { 
  <& /elements/header-cust_main.html, view=>'payment_history', custnum=>$custnum &>
  <h2><% $title |h %></h2>
% } 

<& /elements/init_calendar.html &>

<& /elements/error.html &>

<FORM NAME="PaymentForm" ACTION="<% popurl(1) %>process/cust_pay.cgi" METHOD=POST onSubmit="document.PaymentForm.submitButton.disabled=true">
<INPUT TYPE="hidden" NAME="link" VALUE="<% $link %>">
<INPUT TYPE="hidden" NAME="linknum" VALUE="<% $linknum %>">
<INPUT TYPE="hidden" NAME="payby" VALUE="<% $payby %>">
<INPUT TYPE="hidden" NAME="paybatch" VALUE="<% $paybatch %>">

<TABLE CLASS="fsinnerbox">

% my %date_args = (
%   'name'    =>  '_date',
%   'label'   => emt('Date'),
%   'value'   => $_date,
%   'format'  => $date_format. ' %r',
%   'colspan' => 2,
% );
% if ( $FS::CurrentUser::CurrentUser->access_right('Backdate payment') ) {

  <& /elements/tr-input-date-field.html, \%date_args &>

% } else {

  <& /elements/tr-fixed-date.html, \%date_args &>

% }

<TR>
  <TH ALIGN="right"><% mt('Amount') |h %></TH>
  <TD><% $money_char |h %><INPUT TYPE="text" NAME="paid" ID="paid" VALUE="<% $paid %>" SIZE=8 MAXLENGTH=9> <% mt('by') |h %> <B><% mt(FS::payby->payname($payby)) |h %></B></TD>
</TR>

% if ( $conf->exists('part_pkg-term_discounts') ) {
    <& /elements/tr-select-discount_term.html,
         'custnum'   => $custnum,
         'amount_id' => 'paid',
    &>
% }

% if ( $payby eq 'BILL' ) { 
  <TR>
    <TH ALIGN="right"><% mt('Check #') |h %></TH>
    <TD COLSPAN=2><INPUT TYPE="text" NAME="payinfo" VALUE="<% $payinfo %>" SIZE=10></TD>
  </TR>
% }
% elsif ( $payby eq 'CASH' and $conf->exists('require_cash_deposit_info') ) {
  <TR>
    <TH ALIGN="right"><% mt('Bank') |h %></TH>
    <TD COLSPAN=3><INPUT TYPE="text" NAME="bank" VALUE="<% $cgi->param('bank') %>"></TD>
  </TR>
  <TR>
    <TH ALIGN="right"><% mt('Check #') |h %></TH>
    <TD COLSPAN=2><INPUT TYPE="text" NAME="payinfo" VALUE="<% $payinfo %>" SIZE=10></TD>
  </TR>
  <TR>
    <TH ALIGN="right"><% mt('Teller #') |h %></TH>
    <TD COLSPAN=2><INPUT TYPE="text" NAME="teller" VALUE="<% $cgi->param('teller') %>" SIZE=10></TD>
  </TR>
  <TR>
    <TH ALIGN="right"><% mt('Depositor') |h %></TH>
    <TD COLSPAN=3><INPUT TYPE="text" NAME="depositor" VALUE="<% $cgi->param('depositor') %>"></TD>
  </TR>
  <TR>
    <TH ALIGN="right"><% mt('Account #') |h %></TH>
    <TD COLSPAN=2><INPUT TYPE="text" NAME="account" VALUE="<% $cgi->param('account') %>" SIZE=18></TD>
  </TR>
% }

<TR>
% if ( $link eq 'custnum' || $link eq 'popup' ) { 

  <TD ALIGN="right"><% mt('Auto-apply to invoices') |h %></TD>
  <TD COLSPAN=2>
    <SELECT NAME="apply">
      <OPTION VALUE="yes" SELECTED><% mt('yes') |h %></OPTION> 
      <OPTION VALUE=""><% mt('not now') |h %></OPTION>
      <OPTION VALUE="never"><% mt('never') |h %></OPTION>
    </SELECT>
  </TD>

% } elsif ( $link eq 'invnum' ) { 

  <TH ALIGN="right"><% mt('Apply to') |h %></TH>
  <TD COLSPAN=2>Invoice #<B><% $linknum %></B> only</TD>
  <INPUT TYPE="hidden" NAME="apply" VALUE="">

% } 
</TR>

% if ( $conf->exists('pkg-balances') ) {
  <& /elements/tr-select-cust_pkg-balances.html,
               'custnum' => $custnum,
               'cgi'     => $cgi
  &>
% } else {
  <INPUT TYPE="hidden" NAME="pkgnum" VALUE="">
% }

</TABLE>

<BR>
<INPUT NAME="submitButton" TYPE="submit" VALUE="<% mt('Post payment') |h %>">

</FORM>

% if ( $link eq 'popup' ) { 
    </BODY>
    </HTML>
% } else { 
    <& /elements/footer-cust_main.html &>
% } 

<%init>

my $conf = new FS::Conf;

my $money_char  = $conf->config('money_char')  || '$';
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

my($link, $linknum, $paid, $payby, $payinfo, $_date);
if ( $cgi->param('error') ) {
  $link     = $cgi->param('link');
  $linknum  = $cgi->param('linknum');
  $paid     = $cgi->param('paid');
  $payby    = $cgi->param('payby');
  $payinfo  = $cgi->param('payinfo');
  $_date    = $cgi->param('_date') ? parse_datetime($cgi->param('_date')) : time;
} elsif ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  $link     = $cgi->param('popup') ? 'popup' : 'custnum';
  $linknum  = $1;
  $paid     = '';
  $payby    = $cgi->param('payby') || 'BILL';
  $payinfo  = '';
  $_date    = time;
} elsif ( $cgi->param('invnum') =~ /^(\d+)$/ ) {
  $link     = 'invnum';
  $linknum  = $1;
  $paid     = '';
  $payby    = $cgi->param('payby') || 'BILL';
  $payinfo  = "";
  $_date    = time;
} else {
  die "illegal query ". $cgi->keywords;
}

my @rights = ('Post payment');
push @rights, 'Post check payment' if $payby eq 'BILL';
push @rights, 'Post cash payment'  if $payby eq 'CASH';

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right(\@rights);

my $paybatch = "webui-$_date-$$-". rand() * 2**32;

my $title = mt('Post '. FS::payby->payname($payby). ' payment');
$title .= mt(" against Invoice #[_1]",$linknum) if $link eq 'invnum';

my $custnum;
if ( $link eq 'invnum' ) {
  my $cust_bill = qsearchs('cust_bill', { 'invnum' => $linknum } )
    or die "unknown invnum $linknum";
  $custnum = $cust_bill->custnum;
} elsif ( $link eq 'custnum' || $link eq 'popup' ) {
  $custnum = $linknum;
}

</%init>
