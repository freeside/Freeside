<& /elements/header.html, {
             'title' => $title,
             'head'  => $head,
             'nobr'  => 1,
          }
&>
<BR>
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

<& /elements/menubar.html,
             { 'newstyle' => 1,
               'selected' => $viewname{$view},
               'url_base' => $cgi->url. "?custnum=$custnum;show=",
             },
             %views,
&>
<DIV CLASS="fstabcontainer">

<& /elements/init_overlib.html &>

<SCRIPT TYPE="text/javascript">
function areyousure(href, message) {
  if (confirm(message) == true)
    window.location.href = href;
}
</SCRIPT>


% ###
% # Basics
% ###

% if ( $view eq 'basics' || $view eq 'jumbo' ) {

% if ( $curuser->access_right('Edit customer') ) { 
  <A HREF="<% $p %>edit/cust_main.cgi?<% $custnum %>"><% mt('Edit this customer') |h %></A> | 
% } 

% if ( $curuser->access_right('Suspend customer')
%        && scalar($cust_main->unsuspended_pkgs)
%      ) {
  <& /elements/popup_link-cust_main.html,
              { 'action'      => $p. 'misc/suspend_cust.html',
                'label'       => emt('Suspend this customer'),
                'actionlabel' => emt('Confirm Suspension'),
                'color'       => '#ff9900',
                'cust_main'   => $cust_main,
                'width'       => 768, #make room for reasons
                'height'      => 450, 
              }
  &> | 
% }

% if ( $curuser->access_right('Unsuspend customer')
%        && scalar($cust_main->suspended_pkgs)
%      ) {
  <& /elements/popup_link-cust_main.html,
              { 'action'      => $p. 'misc/unsuspend_cust.html',
                'label'       => emt('Unsuspend this customer'),
                'actionlabel' => emt('Confirm Unsuspension'),
                #'color'       => '#ff9900',
                'cust_main'   => $cust_main,
                #'width'       => 616, #make room for reasons
                #'height'      => 366,
              }
  &> | 
% }

% if ( $curuser->access_right('Cancel customer')
%        && scalar($cust_main->ncancelled_pkgs)
%      ) {
  <& /elements/popup_link-cust_main.html,
              { 'action'      => $p. 'misc/cancel_cust.html',
                'label'       => emt('Cancel this customer'),
                'actionlabel' => emt('Confirm Cancellation'),
                'color'       => '#ff0000',
                'cust_main'   => $cust_main,
                'width'       => 616, #make room for reasons
                'height'      => 410,
              }
  &> | 
% }

% if (     $curuser->access_right('Merge customer')
%      and (    scalar($cust_main->ncancelled_pkgs)
%            # || we start supporting payment info merge again in some way
%          )
%    )
% {
  <& /elements/popup_link-cust_main.html,
              { 'action'      => $p. 'misc/merge_cust.html',
                'label'       => emt('Merge this customer'),
                'actionlabel' => emt('Merge customer'),
                'cust_main'   => $cust_main,
                'width'       => 569,
                'height'      => 210,
              }
  &> | 
% } 

% unless ( $conf->exists('disable_customer_referrals') ) { 
  <A HREF="<% $p %>edit/cust_main.cgi?referral_custnum=<% $custnum %>"><% mt('Refer a new customer') |h %></A> | 
  <A HREF="<% $p %>search/cust_main.cgi?referral_custnum=<% $custnum %>"><% mt('View this customer\'s referrals') |h %></A>
% } 

<BR><BR>

% my $br = 0;
% if (    $curuser->access_right('Billing event reports') 
%      || $curuser->access_right('View customer billing events')
%    ) {
% $br=1;
  <A HREF="<% $p %>search/cust_event.html?custnum=<% $custnum %>"><% mt('View billing events for this customer') |h %></A>
% }
% 
% my $email_link = ($cust_main->invoicing_list_emailonly) && 
%   include('/elements/email-link.html',
%            'table'               => 'cust_main', 
%            'search_hash'         => { 'custnum' => $custnum },
%            'agent_virt_agentnum' => $cust_main->agentnum,
%            'label'               => 'Email a notice to this customer',
% );
% if ( $email_link and $br ) {
 | 
% }
<% $email_link || '' %>

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

<A NAME="cust_main"></A>
<TABLE BORDER=0>
<TR>
  <TD VALIGN="top">
    <& cust_main/contacts.html, $cust_main &>
  </TD>
  <TD VALIGN="top" STYLE="padding-left: 54px">
    <& cust_main/misc.html, $cust_main &>
% if ( $conf->config('payby-default') ne 'HIDE' ) { 
      <BR><& cust_main/billing.html, $cust_main &>
% } 

  </TD>
</TR>
<TR>
  <TD COLSPAN = 2>
    <& cust_main/contacts_new.html, $cust_main &>
  </TD>
</TR>
</TABLE>

% }


% ###
% # Notes
% ###

% if ( $view eq 'notes' || $view eq 'jumbo' ) {

<& cust_main/notes.html, 'cust_main' => $cust_main &>

% }

% if ( $view eq 'jumbo' ) {
    <BR>
% }

<BR>


% ###
% # Tickets
% ###

% if ( $view eq 'tickets' || $view eq 'jumbo' ) {

% if ( $conf->config('ticket_system') ) { 
  <& cust_main/tickets.html, $cust_main &>
% } 
  <BR><BR>

% }

% ###
% # Appointments
% ###

% if ( $view eq 'appointments' || $view eq 'jumbo' ) {

% if ( $conf->config('ticket_system')
%        && $curuser->access_right('View appointments') ) { 
  <& cust_main/appointments.html, $cust_main &>
% } 
  <BR><BR>

% }


% ###
% # Quotations
% ###

% if ( $view eq 'jumbo' && $curuser->access_right('Generate quotation') ) { 
  <A NAME="quotation"><FONT SIZE="+2"><% mt('Quotations') |h %></FONT></A><BR>
% }

% if ( $view eq 'quotations' || $view eq 'jumbo' ) {

%   if ( $curuser->access_right('Generate quotation') ) { 
      <& cust_main/quotations.html, $cust_main &>
%   }

% }


% ###
% # Packages
% ###

% if ( $view eq 'jumbo' ) { #XXX enable me && $curuser->access_right('View customer packages') { 

  <A NAME="cust_pkg"><FONT SIZE="+2"><% mt('Packages') |h %></FONT></A><BR>
% }

% if ( $view eq 'packages' || $view eq 'jumbo' ) {

% #XXX enable me# if ( $curuser->access_right('View customer packages') { 
<& cust_main/packages.html, $cust_main &>
% #}

% }


% ###
% # Payment History
% ###

% if ( $view eq 'jumbo' ) {
    <BR><BR>
    <A NAME="history"><FONT SIZE="+2"><% mt('Payment History') |h %></FONT></A>
    <BR>
% }

% if ( $view eq 'payment_history' || $view eq 'jumbo' ) {

% if ( $conf->config('payby-default') ne 'HIDE' ) { 
  <& cust_main/payment_history.html, $cust_main &>
% } 

% }


% ###
% # Change History
% ###

% if ( $view eq 'change_history' ) { #  || $view eq 'jumbo' 	 
<& cust_main/change_history.html, $cust_main &> 	 
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
  $cgi->param('custnum', $1);
}

my $cust_main = qsearchs( {
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $curuser->agentnums_sql,
});
die "Customer not found!" unless $cust_main;

my $title = $cust_main->name;
$title = '('. $cust_main->display_custnum. ") $title"
  if $conf->exists('cust_main-title-display_custnum');
$title = mt("Customer:")." ".$title;

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
$views{emt('Payment History')} =  'payment_history'
                               unless $conf->config('payby-default' eq 'HIDE');
$views{emt('Change History')}  =  'change_history'
  if $curuser->access_right('View customer history');
$views{$conf->config('cust_main-custom_title') || emt('Custom')} =  'custom'
  if $conf->config('cust_main-custom_link')
  || $conf->config('cust_main-custom_content');
$views{emt('Jumbo')}           =  'jumbo';

my %viewname = reverse %views;

my $view =  $cgi->param('show') || $curuser->default_customer_view;

my $ie_compat = $conf->config('ie-compatibility_mode');
my $head = '';
if ( $ie_compat ) {
  $head = qq(<meta http-equiv="X-UA-Compatible" content="IE=$ie_compat" />);
}

</%init>
