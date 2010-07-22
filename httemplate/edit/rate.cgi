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
<% include('/edit/elements/rate_detail.html',
            'ratenum' => $rate->ratenum
) %>
% }

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $rate;
if ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $rate = qsearchs( 'rate', { 'ratenum' => $1 } );
} else { #adding
  $rate = new FS::rate {};
}
my $action = $rate->ratenum ? 'Edit' : 'Add';

</%init>
