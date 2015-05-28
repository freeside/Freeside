<& /elements/header.html, {
             'title' => $title,
             'title_noescape' => $title_noescape,
             'head'  => $head,
             'nobr'  => 1,
          }
&>

% my @part_tag = $cust_main->part_tag;
% if ( $conf->config('cust_tag-location') eq 'top' && @part_tag ) {
<TABLE STYLE="margin-bottom:8px" CELLSPACING=2>
%   foreach my $part_tag ( @part_tag ) {
<TR>
  <TD>
      <FONT SIZE="+1"
            <% length($part_tag->tagcolor)
                 ? 'STYLE="background-color:#'.$part_tag->tagcolor.'"'
                 : ''
      %>><% $part_tag->tagname.': '. $part_tag->tagdesc |h %></FONT>
  </TD>
</TR>
%   }
</TABLE>
% }

<& cust_main/menu.html, cust_main => $cust_main, show => $view &>
<BR>

<DIV CLASS="fstabcontainer">

<& /elements/init_overlib.html &>

<SCRIPT TYPE="text/javascript">
function areyousure(href, message) {
  if (confirm(message) == true)
    window.location.href = href;
}
</SCRIPT>

<br>

% ###
% # Basics
% ###

% if ( $view eq 'basics' ) {

% my $br = 0;
% if ( $curuser->access_right('Order customer package') && $conf->exists('cust_main-enable_order_package') ) {
  | <& /elements/order_pkg_link.html, 'cust_main'=>$cust_main &>
% }

% if ( $conf->config('cust_main-external_links') ) {
    <% $br++ ? ' | ' : '' %>
%   my @links = split(/\n/, $conf->config('cust_main-external_links'));
%   foreach my $link (@links) {
%     $link =~ /^\s*(\S+)\s+(.*?)(\s*\(([^\)]*)\))?$/ or next;
%     my($url, $label, $alt) = ($1, $2, $4);
      <A HREF="<% $url.$custnum %>" ALT="<% $alt |h %>"><% $label |h %></A>
%   }
% }

% if ( $br ) {
  <BR><BR>
% }

%my $signupurl = $conf->config('signupurl');
%if ( $signupurl ) {
  <% mt('This customer\'s signup URL:') |h %>
  <A HREF="<% $signupurl %>?ref=<% $custnum %>"><% $signupurl %>?ref=<% $custnum %></A>
  <BR><BR>
% } 

<TABLE BORDER=0>
<TR>
  <TD VALIGN="top">
    <& cust_main/contacts.html, $cust_main &>
    <BR>
    <& cust_main/misc.html, $cust_main &>
  </TD>
  <TD VALIGN="top" STYLE="padding-left: 54px">
    <& cust_main/billing.html, $cust_main &>
    <BR>
    <& cust_main/cust_payby.html, $cust_main &>
  </TD>
</TR>
<TR>
  <TD COLSPAN = 2>
    <& cust_main/contacts_new.html, $cust_main &>
  </TD>
</TR>
</TABLE>
<BR>

% }


% ###
% # Notes
% ###
% if ( $view eq 'notes' ) {
  <& cust_main/notes.html, 'cust_main' => $cust_main &>
  <BR>
% }


% ###
% # Tickets
% ###

% if ( $view eq 'tickets' ) {

% if ( $conf->config('ticket_system') ) { 
  <& cust_main/tickets.html, $cust_main &>
% } 
  <BR>

% }

% ###
% # Appointments
% ###

% if ( $view eq 'appointments' ) {

% if ( $conf->config('ticket_system')
%        && $curuser->access_right('View appointments') ) { 
  <& cust_main/appointments.html, $cust_main &>
% } 
  <BR>

% }


% ###
% # Quotations
% ###

% if ( $view eq 'quotations' ) {

%   if ( $curuser->access_right('Generate quotation') ) { 
      <& cust_main/quotations.html, $cust_main &>
%   }

% }


% ###
% # Packages
% ###

% if ( $view eq 'packages' ) {

% #XXX enable me# if ( $curuser->access_right('View customer packages') { 
<& cust_main/packages.html, $cust_main &>
% #}
<BR>

% }


% ###
% # Payment History
% ###

% if ( $view eq 'payment_history' ) {

<& cust_main/payment_history.html, $cust_main &>
<BR>

% }


% ###
% # Change History
% ###

% if ( $view eq 'change_history' ) {
<& cust_main/change_history.html, $cust_main &>
<BR>
% }

% if ( $view eq 'custom' ) { 
%   if ( $conf->config('cust_main-custom_link') ) {
<& cust_main/custom.html, $cust_main &>
%   } elsif ( $conf->config('cust_main-custom_content') ) {
      <& cust_main/custom_content.html, $cust_main &>
%   #} else {
%   #  warn "custom view without cust_main-custom_link or -custom_content?";
%   }
% }

</DIV>
<& /elements/footer.html &>
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
  $cgi->delete('keywords');
  $cgi->param('custnum', $1);
}

my $cust_main = qsearchs( {
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $curuser->agentnums_sql,
});
die "Customer not found!" unless $cust_main;

my $title = encode_entities($cust_main->name);
$title = '#'. $cust_main->display_custnum. " $title";
#  if $conf->exists('cust_main-title-display_custnum');
$title = mt("Customer")." ".$title;

my @agentnums = $curuser->agentnums;
if (scalar(@agentnums) > 1 ) {
  $title = encode_entities($cust_main->agent->agent). " $title";
}

my $status = $cust_main->status_label;
$status .= ' (Cancelled)' if $cust_main->is_status_delay_cancel;
my $title_noescape = $title. ' (<B><FONT COLOR="#'. $cust_main->statuscolor. '">'. $status.  '</FONT></B>)';
$title .= " ($status)";

#false laziness w/pref/pref.html and Conf.pm (cust_main-default_view)
tie my %views, 'Tie::IxHash',
       emt('Basics')           => 'basics',
       emt('Notes')            => 'notes', #notes and files?
;
if ( $conf->config('ticket_system') ) {
  $views{emt('Tickets')}       =  'tickets';
  $views{emt('Appointments')}  =  'appointments'
    if $curuser->access_right('View appointments');
}
$views{emt('Quotations')}      =  'quotations';
$views{emt('Packages')}        =  'packages';
$views{emt('Payment History')} =  'payment_history';
$views{emt('Change History')}  =  'change_history'
  if $curuser->access_right('View customer history');
$views{$conf->config('cust_main-custom_title') || emt('Custom')} =  'custom'
  if $conf->config('cust_main-custom_link')
  || $conf->config('cust_main-custom_content');

my %viewname = reverse %views;

my $view =  $cgi->param('show') || $curuser->default_customer_view;
$view = 'basics' if $view eq 'jumbo';

my $ie_compat = $conf->config('ie-compatibility_mode');
my $head = '';
if ( $ie_compat ) {
  $head = qq(<meta http-equiv="X-UA-Compatible" content="IE=$ie_compat" />);
}

</%init>
