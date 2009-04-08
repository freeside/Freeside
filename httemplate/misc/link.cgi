<% include("/elements/header.html","Link to existing $svc") %>

<FORM ACTION="<% popurl(1) %>process/link.cgi" METHOD=POST>
% if ( $link_field ) { 

  <INPUT TYPE="hidden" NAME="svcnum" VALUE="">
  <INPUT TYPE="hidden" NAME="link_field" VALUE="<% $link_field %>">
  <% $link_field %> of existing service: <INPUT TYPE="text" NAME="link_value">
  <BR>
% if ( $link_field2 ) { 

    <INPUT TYPE="hidden" NAME="link_field2" VALUE="<% $link_field2->{field} %>">
    <% $link_field2->{'label'} %> of existing service: 
% if ( $link_field2->{'type'} eq 'select' ) { 
% if ( $link_field2->{'select_table'} ) { 

        <SELECT NAME="link_value2">
        <OPTION> </OPTION>
% foreach my $r ( qsearch( $link_field2->{'select_table'}, {})) { 
% my $key = $link_field2->{'select_key'}; 
% my $label = $link_field2->{'select_label'}; 

          <OPTION VALUE="<% $r->$key() %>"><% $r->$label() %></OPTION>
% } 

        </SELECT>
% } else { 

        Don't know how to process secondary link field for <% $svcdb %>
        (type=>select but no select_table)
% } 
% } else { 

      Don't know how to process secondary link field for <% $svcdb %>
        (unknown type <% $link_field2->{'type'} %>)
% } 

    <BR>
% } 
% } else { 

  Service # of existing service: <INPUT TYPE="text" NAME="svcnum" VALUE="">
% } 


<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">
<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $svcpart %>">
<BR><INPUT TYPE="submit" VALUE="Link">
</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View/link unlinked services');

my %link_field = (
  'svc_acct'    => 'username',
  'svc_domain'  => 'domain',
  'svc_phone'   => 'phonenum',
);

my %link_field2 = (
  'svc_acct'    => { label => 'Domain',
                     field => 'domsvc',
                     type  => 'select',
                     select_table => 'svc_domain',
                     select_key   => 'svcnum',
                     select_label => 'domain'
                   },
);

$cgi->param('pkgnum') =~ /^(\d+)$/ or die 'unparsable pkgnum';
my $pkgnum = $1;
$cgi->param('svcpart') =~ /^(\d+)$/ or die 'unparsable svcpart';
my $svcpart = $1;

my $part_svc = qsearchs('part_svc',{'svcpart'=>$svcpart});
my $svc = $part_svc->getfield('svc');
my $svcdb = $part_svc->getfield('svcdb');
my $link_field = $link_field{$svcdb};
my $link_field2 = $link_field2{$svcdb};

</%init>
