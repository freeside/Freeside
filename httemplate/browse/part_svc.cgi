<% include('/elements/header.html', 'Service Definition Listing') %>

<SCRIPT>
function part_export_areyousure(href) {
  if (confirm("Are you sure you want to delete this export?") == true)
    window.location.href = href;
}
</SCRIPT>

    Service definitions are the templates for items you offer to your customers.<BR><BR>

<FORM METHOD="POST" ACTION="<% $p %>edit/part_svc.cgi">
<A HREF="<% $p %>edit/part_svc.cgi"><I>Add a new service definition</I></A>
% if ( @part_svc ) { 
&nbsp;or&nbsp;<SELECT NAME="clone"><OPTION></OPTION>
% foreach my $part_svc ( @part_svc ) { 

  <OPTION VALUE="<% $part_svc->svcpart %>"><% $part_svc->svc %></OPTION>
% } 

</SELECT><INPUT TYPE="submit" VALUE="Clone existing service">
% } 

</FORM><BR>

<% $total %> service definitions
<% $cgi->param('showdisabled')
      ? do { $cgi->param('showdisabled', 0);
             '( <a href="'. $cgi->self_url. '">hide disabled services</a> )'; }
      : do { $cgi->param('showdisabled', 1);
             '( <a href="'. $cgi->self_url. '">show disabled services</a> )'; }
%>
% $cgi->param('showdisabled', ( 1 ^ $cgi->param('showdisabled') ) ); 

<% include('/elements/table-grid.html') %>
%   my $bgcolor1 = '#eeeeee';
%   my $bgcolor2 = '#ffffff';
%   my $bgcolor = '';

  <TR>

    <TH CLASS="grid" BGCOLOR="#cccccc"><A HREF="<% do { $cgi->param('orderby', 'svcpart'); $cgi->self_url } %>">#</A></TH>

% if ( $cgi->param('showdisabled') ) { 
      <TH CLASS="grid" BGCOLOR="#cccccc">Status</TH>
% } 

    <TH CLASS="grid" BGCOLOR="#cccccc"><A HREF="<% do { $cgi->param('orderby', 'svc'); $cgi->self_url; } %>">Service</A></TH>

    <TH CLASS="grid" BGCOLOR="#cccccc">Table</TH>

    <TH CLASS="grid" BGCOLOR="#cccccc"><A HREF="<% do { $cgi->param('orderby', 'active'); $cgi->self_url; } %>"><FONT SIZE=-1>Customer<BR>Services</FONT></A></TH>

    <TH CLASS="grid" BGCOLOR="#cccccc">Export</TH>

    <TH CLASS="grid" BGCOLOR="#cccccc">Field</TH>

    <TH CLASS="grid" BGCOLOR="#cccccc">Label</TH>

    <TH COLSPAN=2 CLASS="grid" BGCOLOR="#cccccc">Modifier</TH>

  </TR>

% foreach my $part_svc ( @part_svc ) {
%     my $svcdb = $part_svc->svcdb;
%     my $svc_x = "FS::$svcdb"->new( { svcpart => $part_svc->svcpart } );
%     my @dfields = $svc_x->fields;
%     push @dfields, 'usergroup' if $svcdb eq 'svc_acct'; #kludge
%     my @fields =
%       grep { my $col = $part_svc->part_svc_column($_);
%              my $def = FS::part_svc->svc_table_fields($svcdb)->{$_};
%              $svc_x->pvf($_)
%              or $_ ne 'svcnum' && (
%                $col->columnflag || ( $col->columnlabel !~ /^\S*$/
%                                      && $col->columnlabel ne $def->{'label'}
%                                    )
%              )
%            }
%            @dfields ;
%     my $rowspan = scalar(@fields) || 1;
%     my $url = "${p}edit/part_svc.cgi?". $part_svc->svcpart;
%
%     if ( $bgcolor eq $bgcolor1 ) {
%       $bgcolor = $bgcolor2;
%     } else {
%       $bgcolor = $bgcolor1;
%     }


  <TR>

    <TD ROWSPAN=<% $rowspan %> CLASS="grid" BGCOLOR="<% $bgcolor %>">
      <A HREF="<% $url %>"><% $part_svc->svcpart %></A>
    </TD>

% if ( $cgi->param('showdisabled') ) { 
    <TD ROWSPAN=<% $rowspan %> CLASS="grid" BGCOLOR="<% $bgcolor %>">
      <% $part_svc->disabled
            ? '<FONT COLOR="#FF0000"><B>Disabled</B></FONT>'
            : '<FONT COLOR="#00CC00"><B>Enabled</B></FONT>'
      %>
    </TD>
% } 

    <TD ROWSPAN=<% $rowspan %> CLASS="grid" BGCOLOR="<% $bgcolor %>"><A HREF="<% $url %>">
      <% $part_svc->svc %></A></TD>

    <TD ROWSPAN=<% $rowspan %> CLASS="grid" BGCOLOR="<% $bgcolor %>">
      <% $svcdb %></TD>

    <TD ROWSPAN=<% $rowspan %> CLASS="grid" BGCOLOR="<% $bgcolor %>">
      <FONT COLOR="#00CC00"><B><% $num_active_cust_svc{$part_svc->svcpart} %></B></FONT>&nbsp;<% $num_active_cust_svc{$part_svc->svcpart} ? svc_url( 'ahref' => 1, 'm' => $m, 'action' => 'search', 'part_svc' => $part_svc, 'query' => "svcpart=". $part_svc->svcpart ) : '<A NAME="zero">' %>active</A>

% if ( $num_active_cust_svc{$part_svc->svcpart} ) { 
        <BR><FONT SIZE="-1">[ <A HREF="<%$p%>edit/bulk-cust_svc.html?svcpart=<% $part_svc->svcpart %>">change</A> ]</FONT>
% } 

    </TD>

    <TD ROWSPAN=<% $rowspan %> CLASS="inv" BGCOLOR="<% $bgcolor %>">
      <TABLE CLASS="inv">
%
%#  my @part_export =
%map { qsearchs('part_export', { exportnum => $_->exportnum } ) } qsearch('export_svc', { svcpart => $part_svc->svcpart } ) ;
%  foreach my $part_export (
%    map { qsearchs('part_export', { exportnum => $_->exportnum } ) } 
%      qsearch('export_svc', { svcpart => $part_svc->svcpart } )
%  ) {
%

        <TR>
          <TD><A HREF="<% $p %>edit/part_export.cgi?<% $part_export->exportnum %>">
<% $part_export->exportnum %>:&nbsp;
% if ($part_export->exportname) {
<B><% $part_export->exportname %></B> (
% }
<% $part_export->exporttype %>&nbsp;to&nbsp;<% $part_export->machine %>
% if ($part_export->exportname) {
)
% }
</A></TD>
	</TR>
%  } 

      </TABLE>
    </TD>

%     unless ( @fields ) {
%       for ( 1..4 ) {  
	  <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"</TD>
%       }
%     }
%   
%     my($n1)='';
%     foreach my $field ( @fields ) {
%
%       #a few lines of false laziness w/edit/part_svc.cgi
%       my $def = FS::part_svc->svc_table_fields($svcdb)->{$field};
%       my $formatter = $def->{format} || sub { shift };
%
%       my $part_svc_column = $part_svc->part_svc_column($field);
%       my $label = $part_svc_column->columnlabel || $def->{'label'};
%       my $flag = $part_svc_column->columnflag;

     <% $n1 %>
     <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><% $field %></TD>
     <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><% $label %></TD>
     <TD CLASS="grid" BGCOLOR="<% $bgcolor %>"><% $flag{$flag} %></TD>

     <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
% my $value = &$formatter($part_svc->part_svc_column($field)->columnvalue);
% if ( $flag =~ /^[MAH]$/ ) { 
%   my $select_table = ($flag eq 'H') ? 'hardware_class' : 'inventory_class';
%   $select_class{$value} ||= 
%       qsearchs($select_table, { 'classnum' => $value } );
% 
            <% $select_class{$value}
                  ? $select_class{$value}->classname
                  : "WARNING: $select_table.classnum $value not found" %>
% } else { 

            <% $value %>
% } 

     </TD>
%     $n1="</TR><TR>";
%     }
%

  </TR>
% } 

</TABLE>
</BODY>
</HTML>
<%init>
 
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

#code duplication w/ edit/part_svc.cgi, should move this hash to part_svc.pm
my %flag = (
  ''  => '',
  'D' => 'Default',
  'F' => 'Fixed (unchangeable)',
  'S' => 'Selectable choice',
  #'M' => 'Manual selection from inventory',
  'M' => 'Manual selected from inventory',
  #'A' => 'Automatically fill in from inventory',
  'A' => 'Automatically filled in from inventory',
  'H' => 'Selected from hardware class',
  'X' => 'Excluded',
);

my %search;
if ( $cgi->param('showdisabled') ) {
  %search = ();
} else {
  %search = ( 'disabled' => '' );
}

my @part_svc =
  sort { $a->getfield('svcpart') <=> $b->getfield('svcpart') }
    qsearch('part_svc', \%search );
my $total = scalar(@part_svc);

my %num_active_cust_svc = map { $_->svcpart => $_->num_cust_svc } @part_svc;

if ( $cgi->param('orderby') eq 'active' ) {
  @part_svc = sort { $num_active_cust_svc{$b->svcpart} <=>
                     $num_active_cust_svc{$a->svcpart}     } @part_svc;
} elsif ( $cgi->param('orderby') eq 'svc' ) { 
  @part_svc = sort { lc($a->svc) cmp lc($b->svc) } @part_svc;
}

my %select_class = ();

</%init>
