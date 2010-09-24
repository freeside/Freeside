<% include("/elements/header.html", { title => "$action Time Period" }) %>
<% include("/elements/menubar.html",
      'Rate plans' => "${p}browse/rate.cgi",
    ) %>
<BR>
<% include('/elements/error.html') %>
<BR>

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
                      'header' => [ '', 'Start','','', '','End','','' ],
                      'fields' => [ qw(sd sh sm sa ed eh em ea) ],
                      'select' => [ ($day, $hour, $min, $ampm) x 2 ],
                      'data'   => \@data,
   ) %>
<INPUT TYPE="submit" VALUE="<% $rate_time ? 'Apply changes' : 'Add period'%>">
</FORM>
<BR>
<A HREF="<% "${p}edit/process/rate_time.cgi?ratetimenum=$ratetimenum;delete=1" %>">Delete this period</A>
<% include('/elements/footer.html') %>

<%init>
my $ratetimenum = ($cgi->keywords)[0] || $cgi->param('ratetimenum') || '';
my $action = 'Add';
my $rate_time;
my @data = ();
my $day = [ 0 => 'Sun',
            1 => 'Mon',
            2 => 'Tue',
            3 => 'Wed',
            4 => 'Thu',
            5 => 'Fri',
            6 => 'Sat', ];
my $hour = [ map( {$_, sprintf('%02d',$_) } 12, 1..11 )];
my $min  = [ map( {$_, sprintf('%02d',$_) } 0,30  )];
my $ampm = [ 0 => 'AM', 1 => 'PM' ];

if($ratetimenum) {
  $action = 'Edit';
  $rate_time = qsearchs('rate_time', {ratetimenum => $ratetimenum})
    or die "ratetimenum $ratetimenum not found";
  if($cgi->param('error')) {
    my %vars = $cgi->Vars;
    foreach my $i (sort {$a <=> $b } map { /^sd(\d+)$/ } keys(%vars)) {
      push @data, [ @vars{"sd$i", "sh$i", "sm$i", "sa$i",
                          "ed$i", "eh$i", "em$i", "ea$i"} ];
    }
  }
  else {
    foreach my $interval ($rate_time->intervals) {
      push @data, [ map { int($_/86400) % 7,
                          (int($_/3600) % 12 || 12),
                          int($_/60) % 60,
                          int($_/43200) % 2, } 
                    ( $interval->stime, $interval->etime ) 
      ];
    }
  }
}

</%init>
