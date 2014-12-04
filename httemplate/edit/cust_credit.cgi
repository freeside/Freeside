<& /elements/header-popup.html, mt('Enter Credit') &>

<& /elements/error.html &>

<FORM NAME="credit_popup" ACTION="<% $p1 %>process/cust_credit.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="crednum" VALUE="">
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum |h %>">
<INPUT TYPE="hidden" NAME="paybatch" VALUE="">
<INPUT TYPE="hidden" NAME="credited" VALUE="">

<% ntable("#cccccc", 2) %>

% my %date_args = (
%   'name'   =>  '_date',
%   'label'  => emt('Date'),
%   'value'  => $_date,
%   'format' => $date_format. ' %r',
% );
% if ( $FS::CurrentUser::CurrentUser->access_right('Backdate credit') ) {

  <& /elements/tr-input-date-field.html, \%date_args &>

% } else {

  <& /elements/tr-fixed-date.html, \%date_args &>

% }

  <TR>
    <TD ALIGN="right"><% mt('Amount') |h %></TD>
    <TD BGCOLOR="#ffffff"><% $money_char |h %><INPUT TYPE="text" NAME="amount" VALUE="<% $amount |h %>" SIZE=8 MAXLENGTH=9></TD>
  </TR>

<& /elements/tr-select-reason.html,
              'field'          => 'reasonnum',
              'reason_class'   => 'R',
              'control_button' => 'confirm_credit_button',
              'cgi'            => $cgi,
&>

  <TR>
    <TD ALIGN="right"><% mt('Additional info') |h %></TD>
    <TD>
      <INPUT TYPE="text" NAME="addlinfo" VALUE="<% $cgi->param('addlinfo') |h %>">
    </TD>
  </TR>

% if ( $conf->exists('credits-auto-apply-disable') ) {
        <INPUT TYPE="HIDDEN" NAME="apply" VALUE="no">
% } else {
  <TR>
    <TD ALIGN="right"><% mt('Auto-apply to invoices') |h %></TD>
    <TD><SELECT NAME="apply"><OPTION VALUE="yes" SELECTED><% mt('yes') |h %><OPTION><% mt('no') |h %></SELECT></TD>
  </TR>
% }

% if ( $conf->exists('pkg-balances') ) {
  <& /elements/tr-select-cust_pkg-balances.html,
               'custnum' => $custnum,
               'cgi'     => $cgi
  &>
% } else {
  <INPUT TYPE="hidden" NAME="pkgnum" VALUE="">
% }

</TABLE>

<BR>

<CENTER><INPUT TYPE="submit" ID="confirm_credit_button" VALUE="<% mt('Enter credit') |h %>" DISABLED></CENTER>

</FORM>
</BODY>
</HTML>
<%init>

my $conf = new FS::Conf;

my $money_char  = $conf->config('money_char')  || '$';
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Post credit');

my $custnum = $cgi->param('custnum');
my $amount  = $cgi->param('amount');
my $_date   = time;
my $p1      = popurl(1);

</%init>
