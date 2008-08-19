<% include("/elements/header.html","$action Region", menubar(
      'View all regions' => "${p}browse/rate_region.html",
    ))
%>

<% include('/elements/error.html') %>

<FORM ACTION="<%$p1%>process/rate_region.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="regionnum" VALUE="<% $rate_region->regionnum %>">

%# region info

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
    <TD ALIGN="right">
      <B>Prefixes</B>
      <BR><FONT SIZE="-1">(comma-separated)</FONT>
    </TD>
    <TD>
      <TEXTAREA NAME="npa" WRAP=SOFT><% join(', ', map { $_->npa. (length($_->nxx) ? '-'.$_->nxx : '') } @rate_prefix ) %></TEXTAREA>
    </TD>
  </TR>

</TABLE>

%# rate plan info

<BR>

<% include('/elements/table-grid.html') %>
%   my $bgcolor1 = '#eeeeee';
%   my $bgcolor2 = '#ffffff';
%   my $bgcolor = '';

  <TR>
    <TH CLASS="grid" BGCOLOR="#cccccc">
      Rate plan
    </TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">
      <FONT SIZE=-1>Included<BR>minutes/calls</FONT>
    </TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">
      <FONT SIZE=-1>Charge per<BR>minute/call</FONT>
    </TH>
    <TH CLASS="grid" BGCOLOR="#cccccc">
      <FONT SIZE=-1>Granularity</FONT>
    </TH>
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
% if ( $bgcolor eq $bgcolor1 ) {
%   $bgcolor = $bgcolor2;
% } else {
%   $bgcolor = $bgcolor1;
% }

  <TR>

    <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
      <A HREF="<%$p%>edit/rate.cgi?<% $rate->ratenum %>"><% $rate->ratename %></A>
    </TD>

    <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
      <INPUT TYPE="text" SIZE=9 NAME="min_included<%$n%>" VALUE="<% $cgi->param("min_included$n") || $rate_detail->min_included |h %>">
    </TD>

    <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
      $<INPUT TYPE="text" SIZE=6 NAME="min_charge<%$n%>" VALUE="<% sprintf('%.2f', $cgi->param("min_charge$n") || $rate_detail->min_charge ) %>">
    </TD>

    <TD CLASS="grid" BGCOLOR="<% $bgcolor %>">
      <SELECT NAME="sec_granularity<%$n%>">
%       foreach my $granularity ( keys %granularity ) { 
          <OPTION VALUE="<%$granularity%>"<% $granularity == ( $cgi->param("sec_granularity$n") || $rate_detail->sec_granularity ) ? ' SELECTED' : '' %>><%$granularity{$granularity}%>
%       } 
      </SELECT>
    </TD>

  </TR>

% } 

</TABLE>


<BR><BR>
<INPUT TYPE="submit" VALUE="<% $rate_region->regionnum ? "Apply changes" : "Add region" %>">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $rate_region;
if ( $cgi->param('error') ) {
  $rate_region = new FS::rate_region ( {
    map { $_, scalar($cgi->param($_)) } fields('rate_region')
  } );
} elsif ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "unparsable regionnum";
  $rate_region = qsearchs( 'rate_region', { 'regionnum' => $1 } )
    or die "unknown regionnum $1\n";
} else { #adding
  $rate_region = new FS::rate_region {};
}
my $action = $rate_region->regionnum ? 'Edit' : 'Add';

my $p1 = popurl(1);

tie my %granularity, 'Tie::IxHash', FS::rate_detail::granularities();

my @rate_prefix = $rate_region->rate_prefix;
my $countrycode = '';
if ( @rate_prefix ) {
  $countrycode = $rate_prefix[0]->countrycode;
  foreach my $rate_prefix ( @rate_prefix ) {
    errorpage('multiple country codes per region not yet supported by web UI')
      unless $rate_prefix->countrycode eq $countrycode;
  }
}

</%init>
