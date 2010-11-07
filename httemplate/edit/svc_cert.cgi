<% include('/elements/header.html', "$action $svc", '') %>

<% include('/elements/error.html') %>

<FORM ACTION="<% $p %>edit/process/svc_cert.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="svcnum" VALUE="<% $svcnum %>">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">
<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $svcpart %>">

<% ntable("#cccccc",2) %>

<TR>
  <TD ALIGN="right">Private key</TD>
  <TD BGCOLOR="#ffffff">

% if ( $svc_cert->privatekey && $svc_cert->check_privatekey ) {

    <FONT COLOR="#33ff33">Verification OK</FONT>
%   # remove key & cert link?  just unprovision?

    </TD></TR>

%   if (0) { #( $svc_cert->csr_submitted ) { #XXX add field?  date? }

%     # just show the fields once the csr has been submitted

%   } else {

%     my $cust_main = $svc_cert->cust_svc->cust_pkg->cust_main;

      <TR>
        <TD ALIGN="right">Common name</TD>
        <TD><INPUT TYPE="text" NAME="common_name" SIZE=40 MAXLENGTH=80 VALUE="<% $svc_cert->common_name |h %>"></TD>
      </TR>

      <TR>
        <TD ALIGN="right">Organization</TD>
        <TD><INPUT TYPE="text" NAME="organization" SIZE=40 MAXLENGTH=80 VALUE="<% $svc_cert->organization || $cust_main->company |h %>"></TD>
      </TR>

      <TR>
        <TD ALIGN="right">Organization Unit</TD>
        <TD><INPUT TYPE="text" NAME="organization_unit" SIZE=40 MAXLENGTH=80 VALUE="<% $svc_cert->organization_unit |h %>"></TD>
      </TR>

      <TR>
        <TD ALIGN="right">City</TD>
        <TD><% include('/elements/city.html',
                         'city'    => $svc_cert->city    || $cust_main->city,
                         'state'   => $svc_cert->state   || $cust_main->state,
                         'country' => $svc_cert->country || $cust_main->country,
                      )
            %>
        </TD>
      </TR>

      <TR>
        <TD ALIGN="right">State</TD>
        <TD><% include('/elements/select-state.html',
                         'city'    => $svc_cert->city    || $cust_main->city,
                         'state'   => $svc_cert->state   || $cust_main->state,
                         'country' => $svc_cert->country || $cust_main->country,
                      )
            %>
        </TD>
      </TR>

      <TR>
        <TD ALIGN="right">Country</TD>
        <TD><% include('/elements/select-country.html',
                         'city'    => $svc_cert->city    || $cust_main->city,
                         'state'   => $svc_cert->state   || $cust_main->state,
                         'country' => $svc_cert->country || $cust_main->country,
                      )
            %>
        </TD>
      </TR>

      <TR>
        <TD ALIGN="right">Contact email</TD>
        <TD><INPUT TYPE="text" NAME="cert_contact" SIZE=40 MAXLENGTH=80 VALUE="<% $svc_cert->cert_contact || ($cust_main->invoicing_list_emailonly)[0] |h %>"></TD>
      </TR>

%   }

% } else {
%   my $re = '';
%   if ( $svc_cert->privatekey ) {
      <FONT COLOR="#ff0000">Verification error</FONT>
%     $re = 'Clear and Re-';
%   }
    <% include('/elements/popup_link.html', {
        'action'         => "svc_cert/generate_privatekey.html$link_query",
        'label'          => $re.'Generate',
        'actionlabel'    => 'Generate private key',
        #opt
        'width'          => '350',
        'height'         => '150'
        #'color'          => '#ff0000',
        #'closetext'      => 'Go Away',      # the value '' removes the link
    })%>

    or

    <% include('/elements/popup_link.html', {
        'action'         => "svc_cert/import_privatekey.html$link_query",
        'label'          => $re.'Import',
        'actionlabel'    => 'Import private key',
        #opt
        'width'          => '544',
        'height'         => '368',
        #'color'          => '#ff0000',
        #'closetext'      => 'Go Away',      # the value '' removes the link
    })%>
%   if ( $svc_cert->privatekey ) {
      <PRE><% $svc_cert->privatekey |h %></PRE>
%   }
  </TD>
</TR>
% }

</TABLE>
<BR>

<INPUT TYPE="submit" VALUE="Submit">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;

my($svcnum, $pkgnum, $svcpart, $part_svc, $svc_cert );
if ( $cgi->param('error') ) {

  $svc_cert = new FS::svc_cert ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_cert')
  } );
  $svcnum = $svc_cert->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
  die "No part_svc entry!" unless $part_svc;

} elsif ( $cgi->param('pkgnum') && $cgi->param('svcpart') ) { #adding

  $cgi->param('pkgnum') =~ /^(\d+)$/ or die 'unparsable pkgnum';
  $pkgnum = $1;
  $cgi->param('svcpart') =~ /^(\d+)$/ or die 'unparsable svcpart';
  $svcpart = $1;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $svc_cert = new FS::svc_cert({});

  $svcnum='';

  $svc_cert->set_default_and_fixed;

} else { #editing

  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "unparsable svcnum";
  $svcnum=$1;
  $svc_cert=qsearchs('svc_cert',{'svcnum'=>$svcnum})
    or die "Unknown (svc_cert) svcnum!";

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
    or die "Unknown (cust_svc) svcnum!";

  $pkgnum=$cust_svc->pkgnum;
  $svcpart=$cust_svc->svcpart;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

}
my $action = $svcnum ? 'Edit' : 'Add';

my $svc = $part_svc->getfield('svc');

#my $otaker = getotaker;

my $p1 = popurl(1);

my $link_query = "?svcnum=$svcnum;pkgnum=$pkgnum;svcpart=$svcpart";

</%init>
