<% include("/elements/header.html","$action Time Period", menubar(
      'Rate plans' => "${p}browse/rate.cgi",
    ) )
%>

<% include('/elements/error.html') %>

<FORM METHOD="POST" ACTION="<% "${p}edit/process/rate_time.cgi" %>">
<INPUT TYPE="hidden" NAME="ratetimenum" VALUE="<% $ratetimenum %>">
<% ntable('#cccccc',2) %>
<TABLE>
  <TR>
    <TH ALIGN="right">Period name</TH>
    <TD><INPUT TYPE="text" NAME="ratetimename" VALUE="<% $rate_time ? $rate_time->ratetimename : '' %>"></TD>
  </TR>
</TABLE>
<% include('/elements/auto-table.html', 
                      header => [ 'Start', 'End' ],
                      fields => [ 'stime', 'etime' ],
                      size   => [ 18, 18 ],
                      maxl   => [ 15, 15 ],
                      align  => [ 'right', 'right' ],
                      data   => \@data,
   ) %>
<INPUT TYPE="submit" VALUE="<% $rate_time ? 'Apply changes' : 'Add period'%>">
</FORM>
<BR>
<A HREF="<% "${p}edit/process/rate_time.cgi?ratetimenum=$ratetimenum;delete=1" %>">Delete this period</A>
<% include('/elements/footer.html') %>

<%init>
my $ratetimenum = ($cgi->keywords)[0] || '';
my $action = 'Add';
my $rate_time;
my @data = ();

if($ratetimenum) {
  $action = 'Edit';
  $rate_time = qsearchs('rate_time', {ratetimenum => $ratetimenum})
    or die "ratetimenum $ratetimenum not found";
  @data = $rate_time->description;
}

</%init>
