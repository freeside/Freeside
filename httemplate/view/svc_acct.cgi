% if ( $custnum ) { 

  <% include("/elements/header.html","View $svc account") %>
  <% include( '/elements/small_custview.html', $custnum, '', 1,
     "${p}view/cust_main.cgi") %>
  <BR>

% } else { 

  <SCRIPT>
  function areyousure(href) {
      if (confirm("Permanently delete this account?") == true)
          window.location.href = href;
  }
  </SCRIPT>
  
  <% include("/elements/header.html",'Account View', menubar(
    "Cancel this (unaudited) account" =>
            "javascript:areyousure(\'${p}misc/cancel-unaudited.cgi?$svcnum\')",
  )) %>

% } 

% if ( $part_svc->part_export_usage ) {
%
%  my $last_bill;
%  my %plandata;
%  if ( $cust_pkg ) {
%    #false laziness w/httemplate/edit/part_pkg... this stuff doesn't really
%    #belong in plan data
%    %plandata = map { /^(\w+)=(.*)$/; ( $1 => $2 ); }
%                    split("\n", $cust_pkg->part_pkg->plandata );
%
%    $last_bill = $cust_pkg->last_bill;
%  } else {
%    $last_bill = 0;
%    %plandata = ();
%  }
%
%  my $seconds = $svc_acct->seconds_since_sqlradacct( $last_bill, time );
%  my $hour = int($seconds/3600);
%  my $min = int( ($seconds%3600) / 60 );
%  my $sec = $seconds%60;
%
%  my $input = $svc_acct->attribute_since_sqlradacct(
%    $last_bill, time, 'AcctInputOctets'
%  ) / 1048576;
%  my $output = $svc_acct->attribute_since_sqlradacct(
%    $last_bill, time, 'AcctOutputOctets'
%  ) / 1048576;
%
%


  RADIUS session information<BR>
  <% ntable('#cccccc',2) %>
  <TR><TD BGCOLOR="#ffffff">
% if ( $seconds ) { 

    Online <B><% $hour %></B>h <B><% $min %></B>m <B><% $sec %></B>s
% } else { 

    Has not logged on
% } 
% if ( $cust_pkg ) { 

    since last bill (<% time2str('%a %b %o %Y', $last_bill) %>)
% if ( length($plandata{recur_included_hours}) ) { 

    - <% $plandata{recur_included_hours} %> total hours in plan
% } 

    <BR>
% } else { 

    (no billing cycle available for unaudited account)<BR>
% } 


  Upload: <B><% sprintf("%.3f", $input) %></B> megabytes<BR>
  Download: <B><% sprintf("%.3f", $output) %></B> megabytes<BR>
  Last Login: <B><% $svc_acct->last_login_text %></B><BR>
% my $href = qq!<A HREF="${p}search/sqlradius.cgi?svcnum=$svcnum!; 

  View session detail:
      <% $href %>;begin=<% $last_bill %>">this billing cycle</A>
    | <% $href %>;begin=<% time-15552000 %>">past six months</A>
    | <% $href %>">all sessions</A>

  </TD></TR></TABLE><BR>
% } 

% my @part_svc = ();
% if ($FS::CurrentUser::CurrentUser->access_right('Change customer service')) {

    <SCRIPT TYPE="text/javascript">
      function enable_change () {
        if ( document.OneTrueForm.svcpart.selectedIndex > 1 ) {
          document.OneTrueForm.submit.disabled = false;
        } else {
          document.OneTrueForm.submit.disabled = true;
        }
      }
    </SCRIPT>

    <FORM NAME="OneTrueForm" ACTION="<%$p%>edit/process/cust_svc.cgi">
    <INPUT TYPE="hidden" NAME="svcnum" VALUE="<% $svcnum %>">
    <INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">

%   #print qq!<BR><A HREF="../misc/sendconfig.cgi?$svcnum">Send account information</A>!; 
% 
%   if ( $pkgnum ) { 
%     @part_svc = grep {    $_->svcdb   eq 'svc_acct'
%                        && $_->svcpart != $part_svc->svcpart }
%                 $cust_pkg->available_part_svc;
%   } else {
%     @part_svc = qsearch('part_svc', {
%       svcdb    => 'svc_acct',
%       disabled => '',
%       svcpart  => { op=>'!=', value=>$part_svc->svcpart },
%     } );
%   }
%
% }

Service #<B><% $svcnum %></B>
| <A HREF="<%$p%>edit/svc_acct.cgi?<%$svcnum%>">Edit this service</A>

% if ( @part_svc ) { 

| <SELECT NAME="svcpart" onChange="enable_change()">
    <OPTION VALUE="">Change service</OPTION>
    <OPTION VALUE="">--------------</OPTION>
% foreach my $opt_part_svc ( @part_svc ) { 

      <OPTION VALUE="<% $opt_part_svc->svcpart %>"><% $opt_part_svc->svc %></OPTION>
% } 

  </SELECT>
  <INPUT NAME="submit" TYPE="submit" VALUE="Change" disabled>

% } 


<% &ntable("#cccccc") %><TR><TD><% &ntable("#cccccc",2) %>

<TR>
  <TD ALIGN="right">Service</TD>
  <TD BGCOLOR="#ffffff"><% $part_svc->svc %></TD>
</TR>
<TR>
  <TD ALIGN="right">Username</TD>
  <TD BGCOLOR="#ffffff"><% $svc_acct->username %></TD>
</TR>
<TR>
  <TD ALIGN="right">Domain</TD>
  <TD BGCOLOR="#ffffff"><% $domain %></TD>
</TR>

<TR>
  <TD ALIGN="right">Password</TD>
  <TD BGCOLOR="#ffffff">
% my $password = $svc_acct->_password; 
% if ( $password =~ /^\*\w+\* (.*)$/ ) {
%         $password = $1;
%    

      <I>(login disabled)</I>
% } 
% if ( $conf->exists('showpasswords') ) { 

      <PRE><% encode_entities($password) %></PRE>
% } else { 

      <I>(hidden)</I>
% } 


  </TD>
</TR>
% $password = ''; 
% if ( $conf->exists('security_phrase') ) {
%     my $sec_phrase = $svc_acct->sec_phrase;
%

  <TR>
    <TD ALIGN="right">Security phrase</TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct->sec_phrase %></TD>
  </TR>
% } 
% if ( $svc_acct->popnum ) {
%    my $svc_acct_pop = qsearchs('svc_acct_pop',{'popnum'=>$svc_acct->popnum});
%

  <TR>
    <TD ALIGN="right">Access number</TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct_pop->text %></TD>
  </TR>
% } 
% if ($svc_acct->uid ne '') { 

  <TR>
    <TD ALIGN="right">UID</TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct->uid %></TD>
  </TR>
% } 
% if ($svc_acct->gid ne '') { 

  <TR>
    <TD ALIGN="right">GID</TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct->gid %></TD>
  </TR>
% } 
% if ($svc_acct->finger ne '') { 

  <TR>
    <TD ALIGN="right">GECOS</TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct->finger %></TD>
  </TR>
% } 
% if ($svc_acct->dir ne '') { 

  <TR>
    <TD ALIGN="right">Home directory</TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct->dir %></TD>
  </TR>
% } 
% if ($svc_acct->shell ne '') { 

  <TR>
    <TD ALIGN="right">Shell</TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct->shell %></TD>
  </TR>
% } 
% if ($svc_acct->quota ne '') { 

  <TR>
    <TD ALIGN="right">Quota</TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct->quota %></TD>
  </TR>
% } 
% if ($svc_acct->slipip) { 

  <TR>
    <TD ALIGN="right">IP address</TD>
    <TD BGCOLOR="#ffffff">
      <% ( $svc_acct->slipip eq "0.0.0.0" || $svc_acct->slipip eq '0e0' )
            ? "<I>(Dynamic)</I>"
            : $svc_acct->slipip
      %>
    </TD>
  </TR>
% } 
% my %ulabel = ( seconds    => 'Time',
%                upbytes    => 'Upload bytes',
%                downbytes  => 'Download bytes',
%                totalbytes => 'Total bytes',
%              );
% foreach my $uf ( keys %ulabel ) {
%   my $tf = $uf . "_threshold";
%   if ( $svc_acct->$uf ne '' ) {
%     my $v = $uf eq 'seconds'
%       #? (($svc_acct->$uf < 0 ? '-' : ''). duration_exact($svc_acct->$uf) )
%       ? ($svc_acct->$uf < 0 ? '-' : '').
%         int(abs($svc_acct->$uf)/3600). "hr ".
%         sprintf("%02d",(abs($svc_acct->$uf)%3600)/60). "min"
%       : FS::UI::bytecount::display_bytecount($svc_acct->$uf);
    <TR>
      <TD ALIGN="right"><% $ulabel{$uf} %> remaining</TD>
      <TD BGCOLOR="#ffffff"><% $v %></TD>
    </TR>

%   }
% }
% foreach my $attribute ( grep /^radius_/, $svc_acct->fields ) {
%  $attribute =~ /^radius_(.*)$/;
%  my $pattribute = $FS::raddb::attrib{$1};
%

  <TR>
    <TD ALIGN="right">Radius (reply) <% $pattribute %></TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct->getfield($attribute) %></TD>
  </TR>
% } 
% foreach my $attribute ( grep /^rc_/, $svc_acct->fields ) {
%  $attribute =~ /^rc_(.*)$/;
%  my $pattribute = $FS::raddb::attrib{$1};
%

  <TR>
    <TD ALIGN="right">Radius (check) <% $pattribute %></TD>
    <TD BGCOLOR="#ffffff"><% $svc_acct->getfield($attribute) %></TD>
  </TR>
% } 


<TR>
  <TD ALIGN="right">RADIUS groups</TD>
  <TD BGCOLOR="#ffffff"><% join('<BR>', $svc_acct->radius_groups) %></TD>
</TR>
%
%# Can this be abstracted further?  Maybe a library function like
%# widget('HTML', 'view', $svc_acct) ?  It would definitely make UI 
%# style management easier.
%
% foreach (sort { $a cmp $b } $svc_acct->virtual_fields) { 

  <% $svc_acct->pvf($_)->widget('HTML', 'view', $svc_acct->getfield($_)) %>
% } 


</TABLE></TD></TR></TABLE>
</FORM>
<BR><BR>

% if ( @svc_www ) {
  Hosting
  <% &ntable("#cccccc") %><TR><TD><% &ntable("#cccccc",2) %>
%   foreach my $svc_www (@svc_www) {
%     my($label, $value) = $svc_www->cust_svc->label;
%     my $link = $p. 'view/svc_www.cgi?'. $svc_www->svcnum;
      <TR>
        <TD BGCOLOR="#ffffff">
          <A HREF="<% $link %>"><% "$label: $value" %></A>
        </TD>
      </TR>
%   }
  </TABLE></TD></TR></TABLE>
  <BR><BR>
% }

<% join("<BR>", $conf->config('svc_acct-notes') ) %>
<BR><BR>

<% joblisting({'svcnum'=>$svcnum}, 1) %>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

my $conf = new FS::Conf;

my $addl_from = ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                ' LEFT JOIN cust_main USING ( custnum ) ';

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_acct = qsearchs({
  'select'    => 'svc_acct.*',
  'table'     => 'svc_acct',
  'addl_from' => $addl_from,
  'hashref'   => { 'svcnum' => $svcnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql(
                            'null_right' => 'View/link unlinked services'
                          ),
});
die "Unknown svcnum" unless $svc_acct;

#false laziness w/all svc_*.cgi
my $cust_svc = qsearchs( 'cust_svc' , { 'svcnum' => $svcnum } );
my $pkgnum = $cust_svc->getfield('pkgnum');
my($cust_pkg, $custnum);
if ($pkgnum) {
  $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $pkgnum } );
  $custnum = $cust_pkg->custnum;
} else {
  $cust_pkg = '';
  $custnum = '';
}
#eofalse

my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unknown svcpart" unless $part_svc;
my $svc = $part_svc->svc;

die 'Empty domsvc for svc_acct.svcnum '. $svc_acct->svcnum
  unless $svc_acct->domsvc;
my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $svc_acct->domsvc } );
die 'Unknown domain (domsvc '. $svc_acct->domsvc.
    ' for svc_acct.svcnum '. $svc_acct->svcnum. ')'
  unless $svc_domain;
my $domain = $svc_domain->domain;

my @svc_www = qsearch({
  'select'    => 'svc_www.*',
  'table'     => 'svc_www',
  'addl_from' => $addl_from,
  'hashref'   => { 'usersvc' => $svcnum },
  #XXX shit outta luck if you somehow got them linked across agents
  # maybe we should show but not link to them?  kinda makes sense...
  # (maybe a specific ACL for this situation???)
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql(
                            'null_right' => 'View/link unlinked services'
                          ),
});

</%init>
