<% include('/elements/header.html', "Add/Edit Packages", '') %>

<% include('/elements/error.html') %>

<FORM ACTION="<% $p1 %>process/cust_pkg.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="action" VALUE="bulk">
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum %>">

%#current packages
%my @cust_pkg = qsearch('cust_pkg', { 'custnum' => $custnum, 'cancel' => '' } );
%if (@cust_pkg) {

  Current packages - select to remove (services are moved to a new package below)
  <TABLE>
    <TR STYLE="background-color: #cccccc;">
      <TH COLSPAN="2">Pkg #</TH>
      <TH>Package description</TH>
    </TR>
  <BR><BR>
%
%
%  foreach ( sort {     $all_pkg{ $a->getfield('pkgpart') }
%                   cmp $all_pkg{ $b->getfield('pkgpart') }
%                 }
%                 @cust_pkg
%          )
%  {
%    my($pkgnum,$pkgpart)=( $_->getfield('pkgnum'), $_->getfield('pkgpart') );
%    my $checked = $remove_pkg{$pkgnum} ? ' CHECKED' : '';
%
%  


    <TR>
      <TD><INPUT TYPE="checkbox" NAME="remove_pkg" VALUE="<% $pkgnum %>"<% $checked %>></TD>
      <TD ALIGN="right"><% $pkgnum %>:</TD>
      <TD><% $all_pkg{$pkgpart} %> - <% $all_comment{$pkgpart} %></TD>
    </TR>
% } 


  </TABLE>
  <BR><BR>
% } 


Order new packages
<BR><BR>
%
%my $cust_main = qsearchs('cust_main',{'custnum'=>$custnum});
%my $agent = qsearchs('agent',{'agentnum'=> $cust_main->agentnum });
%
%my %agent_pkgs = map { ( $_->pkgpart , $all_pkg{$_->pkgpart} ) }
%                     qsearch('type_pkgs',{'typenum'=> $agent->typenum });
%
%my $count = 0;
%my $pkgparts = 0;
%


<TABLE>
  <TR STYLE="background-color: #cccccc;">
    <TH>Qty.</TH>
    <TH COLSPAN="2">Package Description</TH>
  </TR>
%
%#foreach my $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
%foreach my $pkgpart ( sort { $agent_pkgs{$a} cmp $agent_pkgs{$b} }
%                             keys(%agent_pkgs) ) {
%  $pkgparts++;
%  next unless exists $pkg{$pkgpart}; #skip disabled ones
%  #print qq!<TR>! if ( $count == 0 );
%  my $value = $cgi->param("pkg$pkgpart") || 0;
%


  <TR>
    <TD>
      <INPUT TYPE="text" NAME="<% "pkg$pkgpart" %>" VALUE="<% $value %>" SIZE="2" MAXLENGTH="2">
    </TD>
    <TD ALIGN="right"><% $pkgpart %>:</TD>
    <TD><% $pkg{$pkgpart} %> - <% $comment{$pkgpart}%></TD>
  </TR>
%
%  $count ++ ;
%  #if ( $count == 2 ) {
%  #  print qq!</TR>\n! ;
%  #  $count = 0;
%  #}
%}
%


</TABLE>
% unless ( $pkgparts ) {
%     my $p2 = popurl(2);
%     my $typenum = $agent->typenum;
%     my $agent_type = qsearchs( 'agent_type', { 'typenum' => $typenum } );
%     my $atype = $agent_type->atype;
%


     (No <A HREF="<% $p2 %>browse/part_pkg.cgi">package definitions</A>,
     or agent type
     <A HREF="<% $p2 %>edit/agent_type.cgi?<% $typenum %>"><% $atype %></a>
     is not allowed to purchase any packages.)
% } 


<P><INPUT TYPE="submit" VALUE="Order">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Bulk change customer packages');

my %pkg = ();
my %comment = ();
my %all_pkg = ();
my %all_comment = ();
#foreach (qsearch('part_pkg', { 'disabled' => '' })) {
#  $pkg{ $_ -> getfield('pkgpart') } = $_->getfield('pkg');
#  $comment{ $_ -> getfield('pkgpart') } = $_->getfield('comment');
#}
foreach (qsearch('part_pkg', {} )) {
  $all_pkg{ $_ -> getfield('pkgpart') } = $_->getfield('pkg');
  $all_comment{ $_ -> getfield('pkgpart') } = $_->custom_comment;
  next if $_->disabled;
  $pkg{ $_ -> getfield('pkgpart') } = $_->getfield('pkg');
  $comment{ $_ -> getfield('pkgpart') } = $_->custom_comment;
}

my($custnum, %remove_pkg);
if ( $cgi->param('error') ) {
  $custnum = $cgi->param('custnum');
  %remove_pkg = map { $_ => 1 } $cgi->param('remove_pkg');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $custnum = $1;
  %remove_pkg = ();
}

my $p1 = popurl(1);

</%init>
