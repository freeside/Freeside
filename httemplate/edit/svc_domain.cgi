<% include('/elements/header.html', "$action $svc", '') %>

<% include('/elements/error.html') %>

<FORM ACTION="<% $p1 %>process/svc_domain.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="svcnum" VALUE="<% $svcnum %>">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">
<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $svcpart %>">

<% ntable("#cccccc",2) %>
<TR>
<P>Domain <INPUT TYPE="text" NAME="domain" VALUE="<% $domain %>" SIZE=28 MAXLENGTH=63>
<BR>
% if ($export) {
Available top-level domains: <% $export->option('tlds') %>
</TR>

<TR>
<INPUT TYPE="radio" NAME="action" VALUE="N"<% $kludge_action eq 'N' ? ' CHECKED' : '' %>>Register at <% $registrar->{'name'} %>
<BR>

<INPUT TYPE="radio" NAME="action" VALUE="M"<% $kludge_action eq 'M' ? ' CHECKED' : '' %>>Transfer to <% $registrar->{'name'} %>
<BR>

<INPUT TYPE="radio" NAME="action" VALUE="I"<% $kludge_action eq 'I' ? ' CHECKED' : '' %>>Registered elsewhere

</TR>

% }

<TR>
<P><INPUT TYPE="submit" VALUE="Submit">
</TR>
</TABLE>
</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my($svcnum, $pkgnum, $svcpart, $kludge_action, $part_svc,
   $svc_domain);
if ( $cgi->param('error') ) {

  $svc_domain = new FS::svc_domain ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_domain')
  } );
  $svcnum = $svc_domain->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $kludge_action = $cgi->param('action');
  $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
  die "No part_svc entry!" unless $part_svc;

} elsif ( $cgi->param('pkgnum') && $cgi->param('svcpart') ) { #adding

  $cgi->param('pkgnum') =~ /^(\d+)$/ or die 'unparsable pkgnum';
  $pkgnum = $1;
  $cgi->param('svcpart') =~ /^(\d+)$/ or die 'unparsable svcpart';
  $svcpart = $1;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $svc_domain = new FS::svc_domain({});

  $svcnum='';

  $svc_domain->set_default_and_fixed;

} else { #editing

  $kludge_action = '';
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "unparsable svcnum";
  $svcnum=$1;
  $svc_domain=qsearchs('svc_domain',{'svcnum'=>$svcnum})
    or die "Unknown (svc_domain) svcnum!";

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
    or die "Unknown (cust_svc) svcnum!";

  $pkgnum=$cust_svc->pkgnum;
  $svcpart=$cust_svc->svcpart;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

}
my $action = $svcnum ? 'Edit' : 'Add';

my $svc = $part_svc->getfield('svc');

my @exports = $part_svc->part_export();

my $registrar;
my $export;

# Find the first export that does domain registration
foreach (@exports) {
	$export = $_ if $_->can('registrar');
}
# If we have a domain registration export, get the registrar object
if ($export) {
	$registrar = $export->registrar;
}

my $otaker = getotaker;

my $domain = $svc_domain->domain;

my $p1 = popurl(1);

</%init>
