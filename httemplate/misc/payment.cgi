<& /elements/header-cust_main.html, view=>'payment_history', cust_main=>$cust_main &>

<h2><% emt("Process [_1] payment",$type{$payby}) %></h2>

<FORM NAME="OneTrueForm" ACTION="process/payment.cgi" METHOD="POST" onSubmit="document.OneTrueForm.process.disabled=true">
<INPUT TYPE="hidden" NAME="custnum"   VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="payby"     VALUE="<% $payby %>">
<INPUT TYPE="hidden" NAME="payunique" VALUE="<% $payunique %>">
<INPUT TYPE="hidden" NAME="balance"   VALUE="<% $balance %>">

<& /elements/init_overlib.html &>

<TABLE class="fsinnerbox">

  <& /elements/tr-select-payment_options.html,
       'custnum'            => $cust_main->custnum,
       'amount'             => $balance,
       'process-pkgpart'    => 
          scalar($conf->config('manual_process-pkgpart', $cust_main->agentnum)),
       'process-display'    => scalar($conf->config('manual_process-display')),
       'process-skip_first' => $conf->exists('manual_process-skip_first'),
       'num_payments'       => scalar($cust_main->cust_pay), 
       'surcharge_percentage' =>
         ( $payby eq 'CARD'
             ? scalar($conf->config('credit-card-surcharge-percentage', $cust_main->agentnum))
             : 0
         ),
       'surcharge_flatfee' =>
         ( $payby eq 'CARD'
             ? scalar($conf->config('credit-card-surcharge-flatfee', $cust_main->agentnum))
             : 0
         ),
  &>

% if ( $conf->exists('part_pkg-term_discounts') ) {
    <& /elements/tr-select-discount_term.html,
         'custnum'   => $custnum,
         'amount_id' => 'amount',
    &>
% }

% my $disallow_no_auto_apply = 0;
% if ( $conf->exists("batch-enable")
%      || grep $payby eq $_, $conf->config('batch-enable_payby')
%    ) {
%
%     if ( grep $payby eq $_, $conf->config('realtime-disable_payby') ) {
%       $disallow_no_auto_apply = 1;

          <INPUT TYPE="hidden" NAME="batch" VALUE="1">

%     } else {

          <TR>
            <TH ALIGN="right">&nbsp;&nbsp;&nbsp;<% mt('Add to current batch') |h %></TH>
            <TD>
              <INPUT TYPE="checkbox" NAME="batch" VALUE="1" ID="batch_checkbox" ONCHANGE="change_batch_checkbox()">
            </TD>
          </TR>

%     }
% }

% unless ($disallow_no_auto_apply) {
%   # false laziness with edit/cust_pay.cgi

<TR ID="apply_box_row">
  <TH ALIGN="right"><% mt('Auto-apply to invoices') |h %></TH>
  <TD>
    <SELECT NAME="apply" ID="apply_box">
      <OPTION VALUE="yes" SELECTED><% mt('yes') |h %></OPTION> 
      <OPTION VALUE=""><% mt('not now') |h %></OPTION>
      <OPTION VALUE="never"><% mt('never') |h %></OPTION>
    </SELECT>
  </TD>
</TR>

% # this can go away if no_auto_apply handling gets added to batch payment processing
<SCRIPT>
function change_batch_checkbox () {
  if (document.getElementById('batch_checkbox').checked) {
    document.getElementById('apply_box').disabled = true;
    document.getElementById('apply_box_row').style.display = 'none';
  } else {
    document.getElementById('apply_box').disabled = false;
    document.getElementById('apply_box_row').style.display = '';
  }
}
</SCRIPT>

% }

<SCRIPT TYPE="text/javascript">
  function cust_payby_changed (what) {
    var custpaybynum = what.options[what.selectedIndex].value
    if ( custpaybynum == '' || custpaybynum == '0' ) {
       //what.form.payinfo.disabled = false;
       $('#cust_payby').slideDown();
    } else {
       //what.form.payinfo.value = '';
       //what.form.payinfo.disabled = true;
       $('#cust_payby').slideUp();
    }
  }
</SCRIPT>

% #can't quite handle CARD/CHEK on the same page yet, but very close
% #does it make sense from a UI/usability perspective?
%
% my @cust_payby = ();
% if ( $payby eq 'CARD' ) {
%   @cust_payby = $cust_main->cust_payby('CARD','DCRD');
% } elsif ( $payby eq 'CHEK' ) {
%   @cust_payby = $cust_main->cust_payby('CHEK','DCHK');
% } else {
%   die "unknown payby $payby";
% }
%
% my $custpaybynum = length(scalar($cgi->param('custpaybynum')))
%                      ? scalar($cgi->param('custpaybynum'))
%                      : scalar(@cust_payby) && $cust_payby[0]->custpaybynum;

<& /elements/tr-select-cust_payby.html,
     'cust_payby' => \@cust_payby,
     'curr_value' => $custpaybynum,
     'onchange'   => 'cust_payby_changed(this)',
&>

</TABLE>
<BR>
<DIV ID="cust_payby"
  <% $custpaybynum ? 'STYLE="display:none"'
                   : ''
  %>
>
<TABLE class="fsinnerbox">

<& /elements/cust_payby_new.html,
     'cust_payby' => \@cust_payby,
     'curr_value' => $custpaybynum,
&>

</TABLE>
</DIV>

<BR>
<INPUT TYPE="submit" NAME="process" VALUE="<% mt('Process payment') |h %>">
</FORM>

<& /elements/footer-cust_main.html &>
<%once>

my %weight = (
  1 => 'Primary',
  2 => 'Secondary',
  3 => 'Tertiary',
  4 => 'Fourth',
  5 => 'Fifth',
  6 => 'Sixth',
  7 => 'Seventh',
);

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Process payment');

my %type = ( 'CARD' => 'credit card',
             'CHEK' => 'electronic check (ACH)',
           );

$cgi->param('payby') =~ /^(CARD|CHEK)$/
  or die "unknown payby ". $cgi->param('payby');
my $payby = $1;

$cgi->param('custnum') =~ /^(\d+)$/
  or die "illegal custnum ". $cgi->param('custnum');
my $custnum = $1;

my $cust_main = qsearchs( 'cust_main', { 'custnum'=>$custnum } );
die "unknown custnum $custnum" unless $cust_main;

my $balance = $cust_main->balance;

my $payinfo = '';

my $conf = new FS::Conf;

my $payunique = "webui-payment-". time. "-$$-". rand() * 2**32;

</%init>
