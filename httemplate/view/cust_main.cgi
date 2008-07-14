<% include("/elements/header.html","Customer View: ". $cust_main->name ) %>

% if ( $curuser->access_right('Edit customer') ) { 
  <A HREF="<% $p %>edit/cust_main.cgi?<% $custnum %>">Edit this customer</A> | 
% } 

<% include('/elements/init_overlib.html') %>

<SCRIPT TYPE="text/javascript">
function areyousure(href, message) {
  if (confirm(message) == true)
    window.location.href = href;
}
</SCRIPT>

% if ( $curuser->access_right('Cancel customer')
%        && $cust_main->ncancelled_pkgs
%      ) {

  <% include( '/elements/popup_link-cust_main.html',
              { 'action'      => $p. 'misc/cancel_cust.html',
                'label'       => 'Cancel&nbsp;this&nbsp;customer',
                'actionlabel' => 'Confirm Cancellation',
                'color'       => '#ff0000',
                'cust_main'   => $cust_main,
              }
            )
  %> | 

% }

% if ( $conf->exists('deletecustomers')
%        && $curuser->access_right('Delete customer')
%      ) {
  <A HREF="<% $p %>misc/delete-customer.cgi?<% $custnum%>">Delete this customer</A> | 
% } 

% unless ( $conf->exists('disable_customer_referrals') ) { 
  <A HREF="<% $p %>edit/cust_main.cgi?referral_custnum=<% $custnum %>">Refer a new customer</A> | 
  <A HREF="<% $p %>search/cust_main.cgi?referral_custnum=<% $custnum %>">View this customer's referrals</A>
% } 

<BR><BR>

% if (    $curuser->access_right('Billing event reports') 
%      || $curuser->access_right('View customer billing events')
%    ) {

  <A HREF="<% $p %>search/cust_event.html?custnum=<% $custnum %>">View billing events for this customer</A>
  <BR><BR>

% }

%my $signupurl = $conf->config('signupurl');
%if ( $signupurl ) {
  This customer's signup URL: <A HREF="<% $signupurl %>?ref=<% $custnum %>"><% $signupurl %>?ref=<% $custnum %></A><BR><BR>
% } 


<A NAME="cust_main"></A>
<TABLE BORDER=0>
<TR>
  <TD VALIGN="top">
    <% include('cust_main/contacts.html', $cust_main ) %>
  </TD>
  <TD VALIGN="top" STYLE="padding-left: 54px">
    <% include('cust_main/misc.html', $cust_main ) %>
% if ( $conf->config('payby-default') ne 'HIDE' ) { 

      <BR>
      <% include('cust_main/billing.html', $cust_main ) %>
% } 

  </TD>
</TR>
</TABLE>
%
%if ( $cust_main->comments =~ /[^\s\n\r]/ ) {
%

<BR>
Comments
<% ntable("#cccccc") %><TR><TD><% ntable("#cccccc",2) %>
<TR>
  <TD BGCOLOR="#ffffff">
    <PRE><% encode_entities($cust_main->comments) %></PRE>
  </TD>
</TR>
</TABLE></TABLE>
% } 
<BR><BR>
% my $notecount = scalar($cust_main->notes());
% if ( ! $conf->exists('cust_main-disable_notes') || $notecount) {

<A NAME="cust_main_note"><FONT SIZE="+2">Notes</FONT></A><BR>
%   if ( $curuser->access_right('Add customer note') &&
%        ! $conf->exists('cust_main-disable_notes')
%      ) {

  <% include( '/elements/popup_link-cust_main.html',
                'label'       => 'Add customer note',
                'action'      => $p. 'edit/cust_main_note.cgi',
                'actionlabel' => 'Enter customer note',
                'cust_main'   => $cust_main,
                'width'       => 616,
                'height'      => 408,
            )
  %>

%   }

<BR>

<% include('cust_main/notes.html', 'custnum' => $cust_main->custnum ) %>

% }


% if ( $conf->config('ticket_system') ) { 

  <BR><BR>
  <% include('cust_main/tickets.html', $cust_main ) %>
% } 


<BR><BR>

% #XXX enable me# if ( $curuser->access_right('View customer packages') { 
<% include('cust_main/packages.html', $cust_main ) %>
% #}

% if ( $conf->config('payby-default') ne 'HIDE' ) { 
  <% include('cust_main/payment_history.html', $cust_main ) %>
% } 


<% include('/elements/footer.html') %>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('View customer');

my $conf = new FS::Conf;

die "No customer specified (bad URL)!" unless $cgi->keywords;
my($query) = $cgi->keywords; # needs parens with my, ->keywords returns array
$query =~ /^(\d+)$/;
my $custnum = $1;
my $cust_main = qsearchs( {
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $curuser->agentnums_sql,
});
die "Customer not found!" unless $cust_main;

</%init>
