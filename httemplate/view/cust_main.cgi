<& /elements/header-cust_main.html, view=>$view, cust_main=>$cust_main &>

% ###
% # Basics
% ###

% if ( $view eq 'basics' ) {

% my $br = 0;

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

if ($view eq 'last') {
  # something took us away from the page and is now bouncing back
  $view = get_page_pref('last_view', $custnum);
} else {
  # remember which view is open so we _can_ bounce back
  set_page_pref('last_view', $custnum, $view);
}

$view = 'basics' if $view eq 'jumbo';

</%init>
