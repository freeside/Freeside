<% include('/elements/header.html', 'Virtual field definitions') %>

<% include('/elements/error.html') %>

<A HREF="<%$p2%>edit/part_virtual_field.cgi"><I>Add a new field</I></A><BR><BR>
% foreach $dbtable (sort { $a cmp $b } keys (%pvfs)) { 

<H3><%$dbtable%></H3>

<%table()%>
<TH><TD>Field name</TD><TD>Description</TD></TH>
% foreach my $pvf (sort {$a->name cmp $b->name} @{ $pvfs{$dbtable} }) { 

  <TR>
    <TD></TD>
    <TD>
      <A HREF="<%$p2%>edit/part_virtual_field.cgi?<%$pvf->vfieldpart%>">
        <%$pvf->name%></A></TD>
    <TD><%$pvf->label%></TD>
  </TR>
%   } 

</TABLE>
% } 

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my %pvfs;
my $block;
my $p2 = popurl(2);
my $dbtable;

foreach (qsearch('part_virtual_field', {})) {
  push @{ $pvfs{$_->dbtable} }, $_;
}

</%init>
