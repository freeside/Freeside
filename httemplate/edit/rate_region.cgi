<!-- mason kludge -->
%
%
%my $rate_region;
%if ( $cgi->param('error') ) {
%  $rate_region = new FS::rate_region ( {
%    map { $_, scalar($cgi->param($_)) } fields('rate_region')
%  } );
%} elsif ( $cgi->keywords ) {
%  my($query) = $cgi->keywords;
%  $query =~ /^(\d+)$/;
%  $rate_region = qsearchs( 'rate_region', { 'regionnum' => $1 } );
%} else { #adding
%  $rate_region = new FS::rate_region {};
%}
%my $action = $rate_region->regionnum ? 'Edit' : 'Add';
%
%my $p1 = popurl(1);
%
%my %granularity = (
%  '6'  => '6 second',
%  '60' => 'minute',
%);
%
%my @rate_prefix = $rate_region->rate_prefix;
%my $countrycode = '';
%if ( @rate_prefix ) {
%  $countrycode = $rate_prefix[0]->countrycode;
%  foreach my $rate_prefix ( @rate_prefix ) {
%    errorpage('multiple country codes per region not yet supported by web UI')
%      unless $rate_prefix->countrycode eq $countrycode;
%  }
%}
%
%


<% include("/elements/header.html","$action Region", menubar(
      'Main Menu' => $p,
      #'View all regions' => "${p}browse/rate_region.cgi",
    ))
%>

<% include('/elements/error.html') %>

<FORM ACTION="<%$p1%>process/rate_region.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="regionnum" VALUE="<% $rate_region->regionnum %>">

<% ntable('#cccccc') %>
<TR>
  <TH ALIGN="right">Region name</TH>
  <TD><INPUT TYPE="text" NAME="regionname" SIZE=32 VALUE="<% $rate_region->regionname %>"></TR>
</TR>

<TR>
  <TH ALIGN="right">Country code</TH>
  <TD><INPUT TYPE="text" NAME="countrycode" SIZE=4 MAXLENGTH=3 VALUE="<% $countrycode %>"></TR>
</TR>


<TR>
  <TH ALIGN="right">Prefixes</TH>
  <TD>
    <TEXTAREA NAME="npa" WRAP=SOFT><% join(', ', map $_->npa, @rate_prefix ) %></TEXTAREA>
  </TD>
</TR>

</TABLE>

<BR>
<% table() %>
<TR>
  <TH>Rate plan</TH>
  <TH><FONT SIZE=-1>Included<BR>minutes</FONT></TH>
  <TH><FONT SIZE=-1>Charge per<BR>minute</FONT></TH>
  <TH><FONT SIZE=-1>Granularity</FONT></TH>
</TR>
% foreach my $rate ( qsearch('rate', {}) ) {
%
%  my $n = $rate->ratenum;
%  my $rate_detail = $rate->dest_detail($rate_region)
%                    || new FS::rate_region { 'min_included'    => 0,
%                                             'min_charge'      => 0,
%                                             'sec_granularity' => '60'
%                                           };
%
%

  <TR>
    <TD><A HREF="<%$p%>edit/rate.cgi?<% $rate->ratenum %>"><% $rate->ratename %></TD>
    <TD><INPUT TYPE="text" SIZE=5 NAME="min_included<%$n%>" VALUE="<% $cgi->param("min_included$n") || $rate_detail->min_included %>"></TD>
    <TD>$<INPUT TYPE="text" SIZE=4 NAME="min_charge<%$n%>" VALUE="<% sprintf('%.2f', $cgi->param("min_charge$n") || $rate_detail->min_charge ) %>"></TD>
    <TD>
      <SELECT NAME="sec_granularity<%$n%>">
% foreach my $granularity ( keys %granularity ) { 

          <OPTION VALUE="<%$granularity%>"<% $granularity == ( $cgi->param("sec_granularity$n") || $rate_detail->sec_granularity ) ? ' SELECTED' : '' %>><%$granularity{$granularity}%>
% } 

      </SELECT>
  </TR>
% } 


</TABLE>

<BR><BR><INPUT TYPE="submit" VALUE="<% 
  $rate_region->regionnum ? "Apply changes" : "Add region"
%>">

    </FORM>
  </BODY>
</HTML>


