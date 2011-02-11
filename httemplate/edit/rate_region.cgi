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

<BR>
<INPUT TYPE="submit" VALUE="<% $rate_region->regionnum ? "Apply changes" : "Add region" %>">
</FORM>
%# rate plan info, if the region has been created yet

% if($rate_region->regionnum) {
<BR><BR><FONT SIZE="+2">Rates in this region</FONT>
% if ( my $select_cdr_type = include('/elements/select-cdr_type.html',
%  'curr_value'   => $cdrtypenum,
%  'onchange'     => 'form.submit();',
%  'name_col'     => 'cdrtypename',
%  'value_col'    => 'cdrtypenum',
%  'empty_label'  => '(default)',
% ) ) {
<FORM ACTION="<%$cgi->url%>" METHOD="GET">
<INPUT TYPE="hidden" NAME="regionnum"   VALUE="<% $rate_region->regionnum %>">
<FONT SIZE="+1">Usage type: <% $select_cdr_type %></FONT>
</FORM>
% }
<% include('/edit/elements/rate_detail.html',
            'regionnum'   => $rate_region->regionnum,
            'cdrtypenum'  => $cdrtypenum,
) %>
% }

<% include('/elements/footer.html') %>
<%once>

tie my %conn_secs,   'Tie::IxHash', FS::rate_detail::conn_secs();

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

my $rate_region;
if ( $cgi->param('error') ) {
  $rate_region = new FS::rate_region ( {
    map { $_, scalar($cgi->param($_)) } fields('rate_region')
  } );
} elsif ( $cgi->param('regionnum') ) {
  $cgi->param('regionnum') =~ /^(\d+)$/ or die "unparseable regionnum";
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
my $cdrtypenum = '';
if ( $cgi->param('cdrtypenum') =~ /^(\d+)$/ ) {
  $cdrtypenum = $1;
}
</%init>
