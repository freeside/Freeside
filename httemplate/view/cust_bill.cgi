<& /elements/header-cust_main.html, view=>'payment_history', custnum=>$custnum &>

<h2>Invoice #<% $invnum %></h2>

% if ( !$cust_bill->closed ) { # otherwise allow no changes
%   my $can_delete = $conf->exists('deleteinvoices')
%                    && $curuser->access_right('Delete invoices');
%   my $can_void = $curuser->access_right('Void invoices');
%   if ( $can_void ) {
    <& /elements/popup_link.html,
      'label'       => emt('Void this invoice'),
      'actionlabel' => emt('Void this invoice'),
      'action'      => $p.'misc/void-cust_bill.html?invnum='.$invnum,
    &>
%   }
%   if ( $can_void and $can_delete ) {
  &nbsp;|&nbsp;
%   }
%   if ( $can_delete ) {
    <A href="" onclick="areyousure(\
      '<%$p%>misc/delete-cust_bill.html?<% $invnum %>',\
      <% mt('Are you sure you want to delete this invoice?') |js_string %>)"\
    TITLE = "<% mt('Delete this invoice from the database completely') |h %>">\
    <% emt('Delete this invoice') |h %></A>
%   }
%   if ( $can_void or $can_delete ) {
  <BR><BR>
%   }
% }

% if ( $cust_bill->owed > 0
%      && $curuser->access_right(['Post payment', 'Post check payment', 'Post cash payment'])
%      && ! $conf->exists('pkg-balances')
%    )
% {
%     my $s = 0;

      <% mt('Post') |h %> 

%     if ( $curuser->access_right(['Post payment', 'Post check payment']) ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=BILL;invnum=<% $invnum %>"><% mt('check') |h %></A>
%     } 

%     if ( $curuser->access_right(['Post payment', 'Post cash payment']) ) { 
          <% $s++ ? ' | ' : '' %>
          <A HREF="<% $p %>edit/cust_pay.cgi?payby=CASH;invnum=<% $invnum %>"><% mt('cash') |h %></A>
%     } 

%#  %     if ( $payby{'WEST'} && $curuser->access_right(['Post payment']) ) { 
%#            <% $s++ ? ' | ' : '' %>
%#            <A HREF="<% $p %>edit/cust_pay.cgi?payby=WEST;invnum=<% $invnum %>"><% mt('Western Union') |h %></A>
%#  %     } 
%#  
%#  %     if ( $payby{'MCRD'} && $curuser->access_right(['Post payment']) ) { 
%#            <% $s++ ? ' | ' : '' %>
%#            <A HREF="<% $p %>edit/cust_pay.cgi?payby=MCRD;invnum=<% $invnum %>"><% mt('manual credit card') |h %></A>
%#  %     } 
%#  
%#  %     if ( $payby{'MCHK'} && $curuser->access_right(['Post payment']) ) { 
%#            <% $s++ ? ' | ' : '' %>
%#            <A HREF="<% $p %>edit/cust_pay.cgi?payby=MCHK;invnum=<% $invnum %>"><% mt('manual electronic check') |h %></A>
%#  %     } 

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
      <% emt('Payment promised by [_1]', 
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
        <A HREF="<% $p %>misc/send-invoice.cgi?method=print;<% $link %>"><% mt('Print this invoice') |h %></A>
% }

% if ( $conf->exists('support-key')
%        && $curuser->access_right('Print and mail invoices')
%    )
% {
        | <& /elements/popup_link.html,
               'action'      => $p."misc/post_fsinc-invoice.cgi?$link",
               'label'       => 'Print and mail this invoice online',
               'actionlabel' => 'Invoice printing and mailing',
          &>
% }

% if ( $curuser->access_right('Resend invoices') ) {

%   if ( grep { $_ ne 'POST' } $cust_bill->cust_main->invoicing_list ) { 
        | <A HREF="<% $p %>misc/send-invoice.cgi?method=email;<% $link %>"><% mt('Re-email this invoice') |h %></A>
%   } 

%   if ( $conf->exists('hylafax') && length($cust_bill->cust_main->fax) ) { 
        | <A HREF="<% $p %>misc/send-invoice.cgi?method=fax;<% $link %>"><% mt('Re-fax this invoice') |h %></A>
%   } 

% }

% if (    $curuser->access_right('Resend invoices')
%      || $curuser->access_right('Print and mail invoices') ) {
        <BR><BR>
% } 

% my $br = 0;
% if ( $conf->exists('invoice_latex') ) {

  <A HREF="<% $p %>view/cust_bill-pdf.cgi?<% $link %>"><% mt('View typeset invoice PDF') |h %></A>

%   $br++;
% }

% my @modes = grep {! $_->disabled} 
%   $cust_bill->cust_main->agent->invoice_modes;
% if ( @modes || $include_statement_template ) {
<% $br ? '|' : '' %>
<% emt('View as:') %>
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
  $include_statement_template ? (
    'post_options' => [ 'statement', '(statement)' ]
  ) : ()
&>
<SCRIPT TYPE="text/javascript">
function change_invoice_mode(obj) {
  obj.form.submit();
}
</SCRIPT>
</FORM>
% }

% if ( $cust_bill->num_cust_event ) {
<% $br ? '|' : '' %>
<A HREF="<%$p%>search/cust_event.html?invnum=<% $cust_bill->invnum %>"><% mt('View invoice events') |h %></A> 
%   $br++;
% }
% if ( $cust_bill->tax > 0 ) { # inefficient
<% $br ? '|' : '' %>
<& /elements/popup_link.html,
  'action'      => 'cust_bill_tax_matrix.html?' . $cust_bill->invnum,
  'label'       => mt('View tax details'),
  'actionlabel' => mt('Tax details'),
  'width'       => 1050,
  'height'      => 500,
  'title'       => emt('Tax details'),
&>
%   $br++;
% }

<BR><BR>

% if ( $conf->exists('invoice_html') && ! $cgi->param('plaintext') ) { 
  <% join('', $cust_bill->print_html(\%opt) ) %>
% } else { 
  <PRE><% join('', $cust_bill->print_text(\%opt) ) |h %></PRE>
% } 

<& /elements/footer-cust_main.html &>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('View invoices');

my $conf = FS::Conf->new;

my( $invnum, $mode, $template, $notice_name, $no_coupon );
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

if ($mode eq 'statement') {
  $mode = undef;
  $template = 'statement';
  $notice_name = 'Statement';
  $no_coupon = 1;
}

my $include_statement_template = $conf->config('payment_receipt_statement_mode') ? 0 : 1;

my %opt = (
  'unsquelch_cdr' => $conf->exists('voip-cdr_email'),
  'template'      => $template,
  'notice_name'   => $notice_name,
);

$opt{'barcode_img'} = 1 if $conf->exists('invoice-barcode');

my $cust_bill = qsearchs({
  'select'    => 'cust_bill.*',
  'table'     => 'cust_bill',
  'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'hashref'   => { 'invnum' => $invnum },
  'extra_sql' => ' AND '. $curuser->agentnums_sql,
});
# if we're asked for a voided invnum, redirect appropriately
if (!$cust_bill and FS::cust_bill_void->row_exists("invnum = $invnum") ) {
  $m->clear_buffer;
  my $url = $p.'view/cust_bill_void.html?'.$cgi->query_string;
  $m->print( $cgi->redirect($url) );
  $m->abort;
}
die "Invoice #$invnum not found!" unless $cust_bill;

$cust_bill->set('mode' => $mode);

my $custnum = $cust_bill->custnum;
my $display_custnum = $cust_bill->cust_main->display_custnum;

my $link = "invnum=$invnum";
$link .= ';mode=' . $mode if $mode;
$link .= ';template='. uri_escape($template) if $template;
$link .= ';notice_name='. $notice_name if $notice_name;
$link .= ';no_coupon=1' if $no_coupon;

</%init>
