<% include("/elements/header.html",'Domain View', menubar(
  ( ( $pkgnum || $custnum )
    ? ( "View this customer (#$display_custnum)" => "${p}view/cust_main.cgi?$custnum",
      )
    : ( "Delete this (unaudited) domain" =>
          "javascript:areyousure('${p}misc/cancel-unaudited.cgi?$svcnum', 'Delete $domain and all records?' )" )
  )
)) %>

Service #<% $svcnum %>
<BR>Service: <B><% $part_svc->svc %></B>
<BR>Domain name: <B><% $domain %></B>
% if ( $FS::CurrentUser::CurrentUser->access_right('Edit domain catchall') ) {
    <BR>Catch all email <A HREF="<% ${p} %>misc/catchall.cgi?<% $svcnum %>">(change)</A>:
% } else {
    <BR>Catch all email:
% }

<% $email ? "<B>$email</B>" : "<I>(none)<I>" %>
<BR><BR><A HREF="<% ${p} %>misc/whois.cgi?custnum=<%$custnum%>;svcnum=<%$svcnum%>;domain=<%$domain%>">View whois information.</A>
<BR><BR>
<SCRIPT>
  function areyousure(href, message) {
    if ( confirm(message) == true )
      window.location.href = href;
  }
  function slave_areyousure() {
    return confirm("Remove all records and slave from " + document.SlaveForm.recdata.value + "?");
  }
</SCRIPT>

% my @records; if ( @records = $svc_domain->domain_record ) { 

  <% include('/elements/table-grid.html') %>

% my $bgcolor1 = '#eeeeee';
%     my $bgcolor2 = '#ffffff';
%     my $bgcolor = $bgcolor2;

  <tr>
    <th CLASS="grid" BGCOLOR="#cccccc">Zone</th>
    <th CLASS="grid" BGCOLOR="#cccccc">Type</th>
    <th CLASS="grid" BGCOLOR="#cccccc">Data</th>
  </tr>

% foreach my $domain_record ( @records ) {
%       my $type = $domain_record->rectype eq '_mstr'
%                    ? "(slave)"
%                    : $domain_record->recaf. ' '. $domain_record->rectype;


    <tr>
      <td CLASS="grid" BGCOLOR="<% $bgcolor %>"><% $domain_record->reczone %></td>
      <td CLASS="grid" BGCOLOR="<% $bgcolor %>"><% $type %></td>
      <td CLASS="grid" BGCOLOR="<% $bgcolor %>"><% $domain_record->recdata %>

% unless ( $domain_record->rectype eq 'SOA'
%          || ! $FS::CurrentUser::CurrentUser->access_right('Edit domain nameservice')
%        ) { 
%   ( my $recdata = $domain_record->recdata ) =~ s/"/\\'\\'/g;
      (<A HREF="javascript:areyousure('<%$p%>misc/delete-domain_record.cgi?<%$domain_record->recnum%>', 'Delete \'<% $domain_record->reczone %> <% $type %> <% $recdata %>\' ?' )">delete</A>)
% } 
      </td>
    </tr>


%   if ( $bgcolor eq $bgcolor1 ) {
%      $bgcolor = $bgcolor2;
%    } else {
%      $bgcolor = $bgcolor1;
%    }

% } 

  </table>
% } 

% if ( $FS::CurrentUser::CurrentUser->access_right('Edit domain nameservice') ) {
    <BR>
    <FORM METHOD="POST" ACTION="<%$p%>edit/process/domain_record.cgi">
      <INPUT TYPE="hidden" NAME="svcnum" VALUE="<%$svcnum%>">
      <INPUT TYPE="text" NAME="reczone"> 
      <INPUT TYPE="hidden" NAME="recaf" VALUE="IN"> IN 
      <SELECT NAME="rectype">
%       foreach (qw( A NS CNAME MX PTR TXT) ) { 
          <OPTION VALUE="<%$_%>"><%$_%></OPTION>
%       } 
      </SELECT>
      <INPUT TYPE="text" NAME="recdata">
      <INPUT TYPE="submit" VALUE="Add record">
    </FORM>

    <BR><BR>
    or
    <BR><BR>

    <FORM NAME="SlaveForm" METHOD="POST" ACTION="<%$p%>edit/process/domain_record.cgi">
      <INPUT TYPE="hidden" NAME="svcnum" VALUE="<%$svcnum%>">
%     if ( @records ) { 
         Delete all records and 
%     } 
      Slave from nameserver IP 
      <INPUT TYPE="hidden" NAME="svcnum" VALUE="<%$svcnum%>">
      <INPUT TYPE="hidden" NAME="reczone" VALUE="@"> 
      <INPUT TYPE="hidden" NAME="recaf" VALUE="IN">
      <INPUT TYPE="hidden" NAME="rectype" VALUE="_mstr">
      <INPUT TYPE="text" NAME="recdata">
      <INPUT TYPE="submit" VALUE="Slave domain" onClick="return slave_areyousure()">
    </FORM>

% }

<BR><BR>

<% joblisting({'svcnum'=>$svcnum}, 1) %>

<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

my($query) = $cgi->keywords;
$query =~ /^(\d+)$/;
my $svcnum = $1;
my $svc_domain = qsearchs({
  'select'    => 'svc_domain.*',
  'table'     => 'svc_domain',
  'addl_from' => ' LEFT JOIN cust_svc  USING ( svcnum  ) '.
                 ' LEFT JOIN cust_pkg  USING ( pkgnum  ) '.
                 ' LEFT JOIN cust_main USING ( custnum ) ',
  'hashref'   => {'svcnum'=>$svcnum},
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Unknown svcnum" unless $svc_domain;

my $cust_svc = qsearchs('cust_svc',{'svcnum'=>$svcnum});
my $pkgnum = $cust_svc->getfield('pkgnum');
my($cust_pkg, $custnum, $display_custnum);
if ($pkgnum) {
  $cust_pkg =qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  $custnum = $cust_pkg->custnum;
  $custnum = $cust_pkg->cust_main->display_custnum;
} else {
  $cust_pkg = '';
  $custnum = '';
}

my $part_svc = qsearchs('part_svc',{'svcpart'=> $cust_svc->svcpart } );
die "Unknown svcpart" unless $part_svc;

my $email = '';
if ($svc_domain->catchall) {
  my $svc_acct = qsearchs('svc_acct',{'svcnum'=> $svc_domain->catchall } );
  die "Unknown svcpart" unless $svc_acct;
  $email = $svc_acct->email;
}

my $domain = $svc_domain->domain;

</%init>
