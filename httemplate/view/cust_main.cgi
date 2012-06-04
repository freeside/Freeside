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
                'width'       => 616, #make room for reasons
                'height'      => 366,
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
                'height'      => 366,
              }
  &> | 
% }

% if ( $curuser->access_right('Merge customer') ) {
  <& /elements/popup_link-cust_main.html,
              { 'action'      => $p. 'misc/merge_cust.html',
                'label'       => emt('Merge this customer'),
                'actionlabel' => emt('Merge customer'),
                'cust_main'   => $cust_main,
                'width'       => 480,
                'height'      => 192,
              }
  &> | 
% } 

% if ( $conf->exists('deletecustomers')
%        && $curuser->access_right('Delete customer')
%      ) {
  <A HREF="<% $p %>misc/delete-customer.cgi?<% $custnum%>"><% mt('Delete this customer') |h %></A> | 
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
%            'table' => 'cust_main', 
%            'search_hash' => { 'custnum' => $custnum },
%            'label' => 'Email a notice to this customer',
% );
% if ( $email_link and $br ) {
 | 
% }
<% $email_link || '' %>

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
</%doc>

%my $signupurl = $conf->config('signupurl');
%if ( $signupurl ) {
  <% mt('This customer\'s signup URL:') |h %>
  <A HREF="<% $signupurl %>?ref=<% $custnum %>"><% $signupurl %>?ref=<% $custnum %></A>
  <BR><BR>
% } 

%if ( $conf->exists('maestro-status_test') ) {
  <A HREF="<% $p %>misc/maestro-customer_status-test.html?<% $custnum %>"><% mt('Test maestro status') |h %></A>
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
</TABLE>

% }

% if ( $view eq 'notes' || $view eq 'jumbo' ) {

%if ( $cust_main->comments =~ /[^\s\n\r]/ ) {
<BR><% mt('Comments') |h %> 
<% ntable("#cccccc") %><TR><TD><% ntable("#cccccc",2) %>
<TR>
  <TD BGCOLOR="#ffffff">
    <PRE><% encode_entities($cust_main->comments) %></PRE>
  </TD>
</TR>
</TABLE></TABLE>
<BR><BR>
% }
<A NAME="notes">
% my $notecount = scalar($cust_main->notes(0));
% if ( ! $conf->exists('cust_main-disable_notes') || $notecount) {

%   unless ( $view eq 'notes' && $cust_main->comments !~ /[^\s\n\r]/ ) {
      <BR>
      <A NAME="cust_main_note"><FONT SIZE="+2"><% mt('Notes') |h %></FONT></A><BR>
%   }

%   if ( $curuser->access_right('Add customer note') &&
%        ! $conf->exists('cust_main-disable_notes')
%      ) {

  <& /elements/popup_link-cust_main.html,
                'label'       => emt('Add customer note'),
                'action'      => $p. 'edit/cust_main_note.cgi',
                'actionlabel' => emt('Enter customer note'),
                'cust_main'   => $cust_main,
                'width'       => 616,
                'height'      => 538, #575
  &>

%   }

<BR>

<& cust_main/notes.html, 'custnum' => $cust_main->custnum &>

% }
<BR>

% if(! $conf->config('disable_cust_attachment') 
%  and $curuser->access_right('Add attachment')) {
<& /elements/popup_link-cust_main.html,
              'label'       => emt('Attach file'),
              'action'      => $p.'edit/cust_main_attach.cgi',
              'actionlabel' => emt('Upload file'),
              'cust_main'   => $cust_main,
              'width'       => 480,
              'height'      => 296,
&>
% }
% if( $curuser->access_right('View attachments') ) {
<& cust_main/attachments.html, 'custnum' => $cust_main->custnum &>
%   if ($cgi->param('show_deleted')) {
<A HREF="<% $p.'view/cust_main.cgi?custnum=' . $cust_main->custnum .
           ($view ? ";show=$view" : '') . '#notes' 
           %>"><I>(<% mt('Show active attachments') |h %>)</I></A>
%   }
% elsif($curuser->access_right('View deleted attachments')) {
<A HREF="<% $p.'view/cust_main.cgi?custnum=' . $cust_main->custnum .
           ($view ? ";show=$view" : '') . ';show_deleted=1#notes'
           %>"><I>(<% mt('Show deleted attachments') |h %>)</I></A>
%   }
% }
<BR>

% }

% if ( $view eq 'jumbo' ) {
    <BR><BR>
    <A NAME="tickets"><FONT SIZE="+2"><% mt('Tickets') |h %></FONT></A><BR>
% }

% if ( $view eq 'tickets' || $view eq 'jumbo' ) {

% if ( $conf->config('ticket_system') ) { 
  <& cust_main/tickets.html, $cust_main &>
% } 
  <BR><BR>

% }

% if ( $view eq 'jumbo' ) { #XXX enable me && $curuser->access_right('View customer packages') { 

  <A NAME="cust_pkg"><FONT SIZE="+2"><% mt('Packages') |h %></FONT></A><BR>
% }

% if ( $view eq 'packages' || $view eq 'jumbo' ) {

% #XXX enable me# if ( $curuser->access_right('View customer packages') { 
<& cust_main/packages.html, $cust_main &>
% #}

% }

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
       emt('Basics')       => 'basics',
       emt('Notes')        => 'notes', #notes and files?
;
$views{emt('Tickets')}     =  'tickets'
                               if $conf->config('ticket_system');
$views{emt('Packages')}    =  'packages';
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
