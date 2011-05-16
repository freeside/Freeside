<& /elements/header.html, mt('Invoice View'), menubar(
  mt('View this customer')." (#$display_custnum)" => "${p}view/cust_main.cgi?$custnum",
) &>

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
                  '<% mt('Are you sure you want to delete this invoice?') |h %>'
               )"
       TITLE = "<% mt('Delete this invoice from the database completely') |h %>"
    ><% mt('Delete this invoice') |h %></A>
    <BR><BR>

% }

% if ( $cust_bill->owed > 0
%      && scalar( grep $payby{$_}, qw(BILL CASH WEST MCRD) )
%      && $curuser->access_right(['Post payment', 'Post check payment', 'Post cash payment'])
%      && ! $conf->exists('pkg-balances')
%    )
% {
%     my $s = 0;

      <% mt('Post') |h %> 

%     if ( $payby{'BILL'} && $curuser->access_right(['Post payment', 'Post check payment']) ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=BILL;invnum=<% $invnum %>"><% mt('check') |h %></A>
%     } 

%     if ( $payby{'CASH'} && $curuser->access_right(['Post payment', 'Post cash payment']) ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=CASH;invnum=<% $invnum %>"><% mt('cash') |h %></A>
%     } 

%     if ( $payby{'WEST'} && $curuser->access_right(['Post payment']) ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=WEST;invnum=<% $invnum %>"><% mt('Western Union') |h %></A>
%     } 

%     if ( $payby{'MCRD'} && $curuser->access_right(['Post payment']) ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=MCRD;invnum=<% $invnum %>"><% mt('manual credit card') |h %></A>
%     } 

      <% mt('payment against this invoice') |h %><BR><BR>

% } 

% if ( $curuser->access_right('Resend invoices') ) {

    <A HREF="<% $p %>misc/send-invoice.cgi?method=print;<% $link %>"><% mt('Re-print this invoice') |h %></A>

%   if ( grep { $_ ne 'POST' } $cust_bill->cust_main->invoicing_list ) { 
        | <A HREF="<% $p %>misc/send-invoice.cgi?method=email;<% $link %>"><% mt('Re-email this invoice') |h %></A>
%   } 

%   if ( $conf->exists('hylafax') && length($cust_bill->cust_main->fax) ) { 
        | <A HREF="<% $p %>misc/send-invoice.cgi?method=fax;<% $link %>"><% mt('Re-fax this invoice') |h %></A>
%   } 

    <BR><BR>

% } 

% if ( $conf->exists('invoice_latex') ) { 

  <A HREF="<% $p %>view/cust_bill-pdf.cgi?<% $link %>"><% mt('View typeset invoice PDF') |h %></A>
  <BR><BR>
% } 

% my $br = 0;
% if ( $cust_bill->num_cust_event ) { $br++;
<A HREF="<%$p%>search/cust_event.html?invnum=<% $cust_bill->invnum %>">( <% mt('View invoice events') |h %> )</A> 
% } 

% if ( $cust_bill->num_cust_bill_event ) { $br++;
<A HREF="<%$p%>search/cust_bill_event.cgi?invnum=<% $cust_bill->invnum %>">( <% mt('View deprecated, old-style invoice events') |h %> )</A> 
% }

<% $br ? '<BR><BR>' : '' %>

% if ( $conf->exists('invoice_html') ) { 
  <% join('', $cust_bill->print_html(\%opt) ) %>
% } else { 
  <PRE><% join('', $cust_bill->print_text(\%opt) ) %></PRE>
% } 

<& /elements/footer.html &>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('View invoices');

my( $invnum, $template, $notice_name );
my($query) = $cgi->keywords;
if ( $query =~ /^((.+)-)?(\d+)$/ ) {
  $template = $2;
  $invnum = $3;
  $notice_name = 'Invoice';
} else {
  $invnum = $cgi->param('invnum');
  $template = $cgi->param('template');
  $notice_name = $cgi->param('notice_name');
}

my $conf = new FS::Conf;

my %opt = (
  'unsquelch_cdr' => $conf->exists('voip-cdr_email'),
  'template'      => $template,
  'notice_name'   => $notice_name,
);

$opt{'barcode_img'} = 1 if $conf->exists('invoice-barcode');

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

my $link = "invnum=$invnum";
$link .= ';template='. uri_escape($template) if $template;
$link .= ';notice_name='. $notice_name if $notice_name;

</%init>
