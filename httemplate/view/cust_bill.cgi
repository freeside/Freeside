<% include("/elements/header.html",'Invoice View', menubar(
  "Main Menu" => $p,
  "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
)) %>


% if ( $cust_bill->owed > 0
%        && ( $payby{'BILL'} || $payby{'CASH'} || $payby{'WEST'} || $payby{'MCRD'} )
%      )
%   {
%     my $s = 0;

  Post 
% if ( $payby{'BILL'} ) { 

  
    <% $s++ ? ' | ' : '' %>
    <A HREF="<% $p %>edit/cust_pay.cgi?payby=BILL;invnum=<% $invnum %>">check</A>
% } 
% if ( $payby{'CASH'} ) { 

  
    <% $s++ ? ' | ' : '' %>
    <A HREF="<% $p %>edit/cust_pay.cgi?payby=CASH;invnum=<% $invnum %>">cash</A>
% } 
% if ( $payby{'WEST'} ) { 

  
    <% $s++ ? ' | ' : '' %>
    <A HREF="<% $p %>edit/cust_pay.cgi?payby=WEST;invnum=<% $invnum %>">Western Union</A>
% } 
% if ( $payby{'MCRD'} ) { 

  
    <% $s++ ? ' | ' : '' %>
    <A HREF="<% $p %>edit/cust_pay.cgi?payby=MCRD;invnum=<% $invnum %>">manual credit card</A>
% } 


  payment against this invoice<BR>
% } 


<A HREF="<% $p %>misc/print-invoice.cgi?<% $link %>">Re-print this invoice</A>
% if ( grep { $_ ne 'POST' } $cust_bill->cust_main->invoicing_list ) { 

  | <A HREF="<% $p %>misc/email-invoice.cgi?<% $link %>">Re-email
      this invoice</A>
% } 
% if ( $conf->exists('hylafax') && length($cust_bill->cust_main->fax) ) { 

  | <A HREF="<% $p %>misc/fax-invoice.cgi?<% $link %>">Re-fax
      this invoice</A>
% } 


<BR><BR>
% if ( $conf->exists('invoice_latex') ) { 

  <A HREF="<% $p %>view/cust_bill-pdf.cgi?<% $link %>.pdf">View typeset invoice</A>
  <BR><BR>
% } 
% #false laziness with search/cust_bill_event.cgi
%   unless ( $templatename ) { 


  <% table() %>
  <TR>
    <TH>Event</TH>
    <TH>Date</TH>
    <TH>Status</TH>
  </TR>
% foreach my $cust_bill_event (
%       sort { $a->_date <=> $b->_date } $cust_bill->cust_bill_event
%     ) {
%
%    my $status = $cust_bill_event->status;
%    $status .= ': '. encode_entities($cust_bill_event->statustext)
%      if $cust_bill_event->statustext;
%    my $part_bill_event = $cust_bill_event->part_bill_event;
%  

    <TR>
      <TD><% $part_bill_event->event %>
% if ( $part_bill_event->templatename ) {
%          my $alt_templatename = $part_bill_event->templatename;
%          my $alt_link = "$alt_templatename-$invnum";
%        

          ( <A HREF="<% $p %>view/cust_bill.cgi?<% $alt_link %>">view</A>
          | <A HREF="<% $p %>view/cust_bill-pdf.cgi?<% $alt_link %>.pdf">view
              typeset</A>
          | <A HREF="<% $p %>misc/print-invoice.cgi?<% $alt_link %>">re-print</A>
% if ( grep { $_ ne 'POST' }
%                       $cust_bill->cust_main->invoicing_list ) { 

            | <A HREF="<% $p %>misc/email-invoice.cgi?<% $alt_link %>">re-email</A>
% } 
% if ( $conf->exists('hylafax')
%                  && length($cust_bill->cust_main->fax) ) { 

            | <A HREF="<% $p %>misc/fax-invoice.cgi?<% $alt_link %>">re-fax</A>
% } 


          )
% } 

  
      </TD>
      <TD><% time2str("%a %b %e %T %Y", $cust_bill_event->_date) %></TD>
      <TD><% $status %></TD>
    </TR>
% } 


  </TABLE>
  <BR>
% } 
% if ( $conf->exists('invoice_html') ) { 

  <% join('', $cust_bill->print_html('', $templatename) ) %>
% } else { 

  <PRE><% join('', $cust_bill->print_text('', $templatename) ) %></PRE>
% } 

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

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
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Invoice #$invnum not found!" unless $cust_bill;

my $custnum = $cust_bill->custnum;

#my $printed = $cust_bill->printed;

my $link = $templatename ? "$templatename-$invnum" : $invnum;

</%init>


