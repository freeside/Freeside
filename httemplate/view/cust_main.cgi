<% include('/elements/header.html', {
             'title' => "Customer View: ". $cust_main->name,
             'nobr'  => 1,
          })
%>
<BR>

<% include('/elements/menubar.html',
             { 'newstyle' => 1,
               'selected' => $viewname{$view},
               'url_base' => $cgi->url. "?custnum=$custnum;show=",
             },
             %views,
          )
%>
<BR>

<% include('/elements/init_overlib.html') %>

<SCRIPT TYPE="text/javascript">
function areyousure(href, message) {
  if (confirm(message) == true)
    window.location.href = href;
}
</SCRIPT>

% if ( $view eq 'basics' || $view eq 'jumbo' ) {

% if ( $curuser->access_right('Edit customer') ) { 
  <A HREF="<% $p %>edit/cust_main.cgi?<% $custnum %>">Edit this customer</A> | 
% } 

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

% }

% if ( $view eq 'notes' || $view eq 'jumbo' ) {

%if ( $cust_main->comments =~ /[^\s\n\r]/ ) {
<BR>
Comments
<% ntable("#cccccc") %><TR><TD><% ntable("#cccccc",2) %>
<TR>
  <TD BGCOLOR="#ffffff">
    <PRE><% encode_entities($cust_main->comments) %></PRE>
  </TD>
</TR>
</TABLE></TABLE>
<BR><BR>
% }

% my $notecount = scalar($cust_main->notes());
% if ( ! $conf->exists('cust_main-disable_notes') || $notecount) {

%   unless ( $view eq 'notes' && $cust_main->comments !~ /[^\s\n\r]/ ) {
      <A NAME="cust_main_note"><FONT SIZE="+2">Notes</FONT></A><BR>
%   }

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
<BR>

% if(! $conf->config('disable_cust_attachment') 
%  and $curuser->access_right('Add attachment')) {
<% include( '/elements/popup_link-cust_main.html',
              'label'       => 'Attach file',
              'action'      => $p.'edit/cust_main_attach.cgi',
              'actionlabel' => 'Upload file',
              'cust_main'   => $cust_main,
              'width'       => 616,
              'height'      => 408,
          )
%>
% }
<% include('cust_main/attachments.html', 'custnum' => $cust_main->custnum ) %>
<BR>

% }

% if ( $view eq 'jumbo' ) {
    <BR><BR>
    <A NAME="tickets"><FONT SIZE="+2">Tickets</FONT></A><BR>
% }

% if ( $view eq 'tickets' || $view eq 'jumbo' ) {

% if ( $conf->config('ticket_system') ) { 
  <% include('cust_main/tickets.html', $cust_main ) %>
% } 
  <BR><BR>

% }

% if ( $view eq 'jumbo' ) { #XXX enable me && $curuser->access_right('View customer packages') { 

  <A NAME="cust_pkg"><FONT SIZE="+2">Packages</FONT></A><BR>
% }

% if ( $view eq 'packages' || $view eq 'jumbo' ) {

% #XXX enable me# if ( $curuser->access_right('View customer packages') { 
<% include('cust_main/packages.html', $cust_main ) %>
% #}

% }

% if ( $view eq 'jumbo' ) {
    <BR><BR>
    <A NAME="history"><FONT SIZE="+2">Payment History</FONT></A><BR>
% }

% if ( $view eq 'payment_history' || $view eq 'jumbo' ) {

% if ( $conf->config('payby-default') ne 'HIDE' ) { 
  <% include('cust_main/payment_history.html', $cust_main ) %>
% } 

% }

<% include('/elements/footer.html') %>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('View customer');

my $conf = new FS::Conf;

my $custnum;
if ( $cgi->param('custnum') =~ /^(\d+)$/ ) {
  $custnum = $1;
} else {
  die "No customer specified (bad URL)!" unless $cgi->keywords;
  my($query) = $cgi->keywords; # needs parens with my, ->keywords returns array
  $query =~ /^(\d+)$/;
  $custnum = $1;
}

my $cust_main = qsearchs( {
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $curuser->agentnums_sql,
});
die "Customer not found!" unless $cust_main;

#false laziness w/pref/pref.html and Conf.pm (cust_main-default_view)
tie my %views, 'Tie::IxHash',
       'Basics'           => 'basics',
       'Notes'            => 'notes', #notes and files?
;
$views{'Tickets'}         =  'tickets'
                               if $conf->config('ticket_system');
$views{'Packages'}        =  'packages';
$views{'Payment History'} =  'payment_history'
                               unless $conf->config('payby-default' eq 'HIDE');
#$views{'Change History'}  =  '';
$views{'Jumbo'}           =  'jumbo';

my %viewname = reverse %views;

my $view =  $cgi->param('show') || $curuser->default_customer_view;

</%init>
