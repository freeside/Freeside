<& /elements/header.html, mt('Invoice View'), menubar(
  emt("View this customer (#[_1])",$display_custnum) => "${p}view/cust_main.cgi?$custnum",
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
%      && scalar( grep $payby{$_}, qw(BILL CASH WEST MCRD MCHK) )
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

%     if ( $payby{'MCHK'} && $curuser->access_right(['Post payment']) ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=MCHK;invnum=<% $invnum %>"><% mt('manual electronic check') |h %></A>
%     } 

      <% mt('payment against this invoice') |h %><BR><BR>

% } 

% if ( $conf->exists('cust_bill-enable_promised_date') ) {
%   my $onclick = include('/elements/popup_link_onclick.html',
%      'action'      => $p.'misc/cust_bill-promised_date.html?'.$invnum,
%      'actionlabel' => emt('Set promised payment date'),
%      'width'       => 320,
%      'height'      => 240,
%   );
%   $onclick = '<A HREF="#" onclick="'.$onclick.'">';
%   if ( $cust_bill->promised_date ) {
%     my $date_format = $conf->config('date_format') || '%b %o, %Y';
      <% mt('Payment promised by [_1]', 
            time2str($date_format, $cust_bill->promised_date) ) %>
      (&nbsp;<% $onclick %><% mt('change') |h %></A>&nbsp;)
      <BR><BR>
%   }
%   elsif ( $cust_bill->owed > 0 ) {
    <% $onclick %><% mt('Set promised payment date' ) |h %></A>
    <BR><BR>
%   }
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

% my @modes = grep {! $_->disabled} 
%   $cust_bill->cust_main->agent->invoice_modes;
% if ( @modes ) {
( <% mt('View as:') %>
<FORM STYLE="display:inline" ACTION="<% $cgi->url %>" METHOD="GET">
<INPUT NAME="invnum" VALUE="<% $invnum %>" TYPE="hidden">
<& /elements/select-table.html,
  table       => 'invoice_mode',
  field       => 'mode',
  curr_value  => scalar($cgi->param('mode')),
  records     => \@modes,
  name_col    => 'modename',
  onchange    => 'change_invoice_mode',
  empty_label => '(default)',
&> )
<SCRIPT TYPE="text/javascript">
function change_invoice_mode(obj) {
  obj.form.submit();
}
</SCRIPT>
% $br++;
% }

<% $br ? '<BR><BR>' : '' %>

% if ( $conf->exists('invoice_html') && ! $cgi->param('plaintext') ) { 
  <% join('', $cust_bill->print_html(\%opt) ) %>
% } else { 
  <PRE><% join('', $cust_bill->print_text(\%opt) ) |h %></PRE>
% } 

<& /elements/footer.html &>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('View invoices');

my $conf = FS::Conf->new;

my( $invnum, $mode, $template, $notice_name );
my($query) = $cgi->keywords;
if ( $query =~ /^((.+)-)?(\d+)$/ ) {
  $template = $2;
  $invnum = $3;
  $notice_name = 'Invoice';
} else {
  $invnum = $cgi->param('invnum');
  $template = $cgi->param('template');
  $notice_name = $cgi->param('notice_name');
  $mode = $cgi->param('mode');
}

my %opt = (
  'unsquelch_cdr' => $conf->exists('voip-cdr_email'),
  'template'      => $template,
  'notice_name'   => $notice_name,
);

$opt{'barcode_img'} = 1 if $conf->exists('invoice-barcode');

my @payby =  grep /\w/, $conf->config('payby');
@payby = (qw( CARD DCRD CHEK DCHK BILL CASH ))
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

$cust_bill->set('mode' => $mode);

my $custnum = $cust_bill->custnum;
my $display_custnum = $cust_bill->cust_main->display_custnum;

my $link = "invnum=$invnum";
$link .= ';mode=' . $mode if $mode;
$link .= ';template='. uri_escape($template) if $template;
$link .= ';notice_name='. $notice_name if $notice_name;

</%init>
