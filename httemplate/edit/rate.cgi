<% include("/elements/header.html","$action Rate plan", menubar(
      'View all rate plans' => "${p}browse/rate.cgi",
    ))
%>

<% include('/elements/progress-init.html',
              'OneTrueForm',
              [ 'rate', 'preserve_rate_detail' ], # 'rate', 'min_', 'sec_' ],
              'process/rate.cgi',
              $p.'browse/rate.cgi',
           )
%>
<FORM NAME="OneTrueForm">
<INPUT TYPE="hidden" NAME="ratenum" VALUE="<% $rate->ratenum %>">

Rate plan
<INPUT TYPE="text" NAME="ratename" SIZE=32 VALUE="<% $rate->ratename %>">
<BR><BR>

<INPUT TYPE="hidden" NAME="preserve_rate_detail" VALUE="1">

<INPUT NAME="submit" TYPE="button" VALUE="<% 
  $rate->ratenum ? "Apply changes" : "Add rate plan"
%>" onClick="document.OneTrueForm.submit.disabled=true; process();">
</FORM>

% if($rate->ratenum) {
<BR><BR><FONT SIZE="+2">Rates in this plan</FONT>
% if ( my $select_cdr_type = include('/elements/select-cdr_type.html',
%  'curr_value'   => $cdrtypenum,
%  'onchange'     => 'form.submit();',
%  'name_col'     => 'cdrtypename',
%  'value_col'    => 'cdrtypenum',
%  'empty_label'  => '(default)',
% ) ) {
<FORM ACTION="<%$cgi->url%>" METHOD="GET">
<INPUT TYPE="hidden" NAME="ratenum" VALUE="<% $rate->ratenum %>">
<INPUT TYPE="hidden" NAME="countrycode" VALUE="<% $countrycode %>">
<FONT SIZE="+1">Usage type: <% $select_cdr_type %></FONT>
</FORM>
% }

<% include('/edit/elements/rate_detail.html',
            'ratenum'     => $rate->ratenum,
            'countrycode' => $countrycode,
            'cdrtypenum'  => $cdrtypenum,
) %>
% }

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $rate;
if ( $cgi->param('ratenum') ) {
  $cgi->param('ratenum') =~ /^(\d+)$/;
  $rate = qsearchs( 'rate', { 'ratenum' => $1 } );
} else { #adding
  $rate = new FS::rate {};
}
my $action = $rate->ratenum ? 'Edit' : 'Add';

my $countrycode = '';
if ( $cgi->param('countrycode') =~ /^(\d+)$/ ) {
  $countrycode = $1;
}

my $cdrtypenum = '';
if ( $cgi->param('cdrtypenum') =~ /^(\d+)$/ ) {
  $cdrtypenum = $1;
}
</%init>
