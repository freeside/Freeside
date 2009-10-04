<% include("/elements/header.html",'Invoice View', menubar(
  "View this customer (#$display_custnum)" => "${p}view/cust_main.cgi?$custnum",
)) %>

% if ( $conf->exists('deleteinvoices')
%      && $curuser->access_right('Delete invoices' )
%    )
% {

    <SCRIPT TYPE="text/javascript">
    function areyousure(href, message) {
      if (confirm(message) == true)
        window.location.href = href;
    }
    </SCRIPT>

    <A HREF  = "javascript:areyousure(
                  '<%$p%>misc/delete-cust_bill.html?<% $invnum %>',
                  'Are you sure you want to delete this invoice?'
               )"
       TITLE = "Delete this invoice from the database completely"
    >Delete this invoice</A>
    <BR><BR>

% }

% if ( $cust_bill->owed > 0
%      && scalar( grep $payby{$_}, qw(BILL CASH WEST MCRD) )
%      && $curuser->access_right('Post payment')
%      && ! $conf->exists('pkg-balances')
%    )
% {
%     my $s = 0;

      Post 

%     if ( $payby{'BILL'} ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=BILL;invnum=<% $invnum %>">check</A>
%     } 

%     if ( $payby{'CASH'} ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=CASH;invnum=<% $invnum %>">cash</A>
%     } 

%     if ( $payby{'WEST'} ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=WEST;invnum=<% $invnum %>">Western Union</A>
%     } 

%     if ( $payby{'MCRD'} ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=MCRD;invnum=<% $invnum %>">manual credit card</A>
%     } 

      payment against this invoice<BR><BR>

% } 

% if ( $curuser->access_right('Resend invoices') ) {

    <A HREF="<% $p %>misc/print-invoice.cgi?<% $link %>">Re-print this invoice</A>

%   if ( grep { $_ ne 'POST' } $cust_bill->cust_main->invoicing_list ) { 
        | <A HREF="<% $p %>misc/email-invoice.cgi?<% $link %>">Re-email this invoice</A>
%   } 

%   if ( $conf->exists('hylafax') && length($cust_bill->cust_main->fax) ) { 
        | <A HREF="<% $p %>misc/fax-invoice.cgi?<% $link %>">Re-fax this invoice</A>
%   } 

    <BR><BR>

% } 

% if ( $conf->exists('invoice_latex') ) { 

  <A HREF="<% $p %>view/cust_bill-pdf.cgi?<% $link %>.pdf">View typeset invoice PDF</A>
  <BR><BR>
% } 

% my $br = 0;
% if ( $cust_bill->num_cust_event ) { $br++;
<A HREF="<%$p%>search/cust_event.html?invnum=<% $cust_bill->invnum %>">(&nbsp;View invoice events&nbsp;)</A> 
% } 

% if ( $cust_bill->num_cust_bill_event ) { $br++;
<A HREF="<%$p%>search/cust_bill_event.cgi?invnum=<% $cust_bill->invnum %>">(&nbsp;View deprecated, old-style invoice events&nbsp;)</A> 
% }

<% $br ? '<BR><BR>' : '' %>

% if ( $conf->exists('invoice_html') ) { 

  <% join('', $cust_bill->print_html('', $templatename) ) %>
% } else { 

  <PRE><% join('', $cust_bill->print_text('', $templatename) ) %></PRE>
% } 

<% include('/elements/footer.html') %>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('View invoices');

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)$/;
my $templatename = $2;
my $invnum = $3;

my $conf = new FS::Conf;

my @payby =  grep /\w/, $conf->config('payby');
#@payby = (qw( CARD DCRD CHEK DCHK LECB BILL CASH WEST COMP ))
@payby = (qw( CARD DCRD CHEK DCHK LECB BILL CASH COMP ))
  unless @payby;
my %payby = map { $_=>1 } @payby;

my $cust_bill = qsearchs({
  'select'    => 'cust_bill.*',
  'table'     => 'cust_bill',
  'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'hashref'   => { 'invnum' => $invnum },
  'extra_sql' => ' AND '. $curuser->agentnums_sql,
});
die "Invoice #$invnum not found!" unless $cust_bill;

my $custnum = $cust_bill->custnum;
my $display_custnum = $cust_bill->cust_main->display_custnum;

#my $printed = $cust_bill->printed;

my $link = $templatename ? "$templatename-$invnum" : $invnum;

</%init>
