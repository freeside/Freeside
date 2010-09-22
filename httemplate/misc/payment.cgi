<% include( '/elements/header.html', "Process $type{$payby} payment" ) %>
<% include( '/elements/small_custview.html', $cust_main, '', '', popurl(2) . "view/cust_main.cgi" ) %>
<FORM NAME="OneTrueForm" ACTION="process/payment.cgi" METHOD="POST" onSubmit="document.OneTrueForm.process.disabled=true">
<INPUT TYPE="hidden" NAME="custnum"   VALUE="<% $custnum %>">
<INPUT TYPE="hidden" NAME="payby"     VALUE="<% $payby %>">
<INPUT TYPE="hidden" NAME="payunique" VALUE="<% $payunique %>">
<INPUT TYPE="hidden" NAME="balance"   VALUE="<% $balance %>">

<% include('/elements/init_overlib.html') %>

% #include( '/elements/table.html', '#cccccc' ) 

<% ntable('#cccccc') %>
  <TR>
    <TH ALIGN="right">Payment amount</TH>
    <TD COLSPAN=7>
      <TABLE><TR><TD BGCOLOR="#ffffff">
        <% $money_char %><INPUT NAME     = "amount"
                                TYPE     = "text"
                                VALUE    = "<% $amount %>"
                                SIZE     = 8
                                STYLE    = "text-align:right;"
%                               if ( $fee ) {
                                  onChange   = "amount_changed(this)"
                                  onKeyDown  = "amount_changed(this)"
                                  onKeyUp    = "amount_changed(this)"
                                  onKeyPress = "amount_changed(this)"
%                               }
                         >
      </TD><TD BGCOLOR="#cccccc">
%        if ( $fee ) {
           <INPUT TYPE="hidden" NAME="fee_pkgpart" VALUE="<% $fee_pkg->pkgpart %>">
           <INPUT TYPE="hidden" NAME="fee" VALUE="<% $fee_display eq 'add' ? $fee : '' %>">
           <B><FONT SIZE='+1'><% $fee_op %></FONT>
              <% $money_char . $fee %>
           </B>
           <% $fee_pkg->pkg |h %>
           <B><FONT SIZE='+1'>=</FONT></B>
      </TD><TD ID="ajax_total_cell" BGCOLOR="#dddddd" STYLE="border:1px solid blue">
           <FONT SIZE="+1"><% length($amount) ? $money_char. sprintf('%.2f', ($fee_display eq 'add') ? $amount + $fee : $amount - $fee ) : '' %> <% $fee_display eq 'add' ? 'TOTAL' : 'AVAILABLE' %></FONT>
  
%        }
      </TD></TR></TABLE>
    </TD>
  </TR>

% if ( $fee ) {

    <SCRIPT TYPE="text/javascript">

      function amount_changed(what) {


        var total = '';
        if ( what.value.length ) {
          total = parseFloat(what.value) <% $fee_op %> <% $fee %>;
          /* total = Math.round(total*100)/100; */
          total = '<% $money_char %>' + total.toFixed(2);
        }

        var total_cell = document.getElementById('ajax_total_cell');
        total_cell.innerHTML = '<FONT SIZE="+1">' + total + ' <% $fee_display eq 'add' ? 'TOTAL' : 'AVAILABLE' %></FONT>';

      }

    </SCRIPT>

% }

<% include('/elements/tr-select-discount_term.html',
             'custnum' => $custnum,
             'cgi'     => $cgi
          )
%>

% if ( $payby eq 'CARD' ) {
%
%   my( $payinfo, $paycvv, $month, $year ) = ( '', '', '', '' );
%   my $payname = $cust_main->first. ' '. $cust_main->getfield('last');
%   if ( $cust_main->payby =~ /^(CARD|DCRD)$/ ) {
%     $payinfo = $cust_main->paymask;
%     $paycvv = $cust_main->paycvv;
%     ( $month, $year ) = $cust_main->paydate_monthyear;
%     $payname = $cust_main->payname if $cust_main->payname;
%   }

    <TR>
      <TH ALIGN="right">Card&nbsp;number</TH>
      <TD COLSPAN=7>
        <TABLE>
          <TR>
            <TD>
              <INPUT TYPE="text" NAME="payinfo" SIZE=20 MAXLENGTH=19 VALUE="<%$payinfo%>"> </TD>
            <TH>Exp.</TH>
            <TD>
              <SELECT NAME="month">
% for ( ( map "0$_", 1 .. 9 ), 10 .. 12 ) { 

                  <OPTION<% $_ == $month ? ' SELECTED' : '' %>><% $_ %>
% } 

              </SELECT>
            </TD>
            <TD> / </TD>
            <TD>
              <SELECT NAME="year">
% my @a = localtime; for ( $a[5]+1900 .. $a[5]+1915 ) { 

                  <OPTION<% $_ == $year ? ' SELECTED' : '' %>><% $_ %>
% } 

              </SELECT>
            </TD>
          </TR>
        </TABLE>
      </TD>
    </TR>
    <TR>
      <TH ALIGN="right">CVV2</TH>
      <TD><INPUT TYPE="text" NAME="paycvv" VALUE="<% $paycvv %>" SIZE=4 MAXLENGTH=4>
          (<A HREF="javascript:void(0);" onClick="overlib( OLiframeContent('../docs/cvv2.html', 480, 352, 'cvv2_popup' ), CAPTION, 'CVV2 Help', STICKY, AUTOSTATUSCAP, CLOSECLICK, DRAGGABLE ); return false;">help</A>)
      </TD>
    </TR>
    <TR>
      <TH ALIGN="right">Exact&nbsp;name&nbsp;on&nbsp;card</TH>
      <TD><INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="payname" VALUE="<%$payname%>"></TD>
    </TR>

    <% include( '/elements/location.html',
                  'object'         => $cust_main, #XXX errors???
                  'no_asterisks'   => 1,
                  'address1_label' => 'Card billing address',
              )
    %>

% } elsif ( $payby eq 'CHEK' ) {
%
%   my( $payinfo1, $payinfo2, $payname, $ss, $paytype, $paystate,
%       $stateid, $stateid_state )
%     = ( '', '', '', '', '', '', '', '' );
%   if ( $cust_main->payby =~ /^(CHEK|DCHK)$/ ) {
%     $cust_main->paymask =~ /^([\dx]+)\@([\dx]+)$/i
%       or die "unparsable payinfo ". $cust_main->payinfo;
%     ($payinfo1, $payinfo2) = ($1, $2);
%     $payname = $cust_main->payname;
%     $ss = $cust_main->ss;
%     $paytype = $cust_main->getfield('paytype');
%     $paystate = $cust_main->getfield('paystate');
%     $stateid = $cust_main->getfield('stateid');
%     $stateid_state = $cust_main->getfield('stateid_state');
%   }

    <INPUT TYPE="hidden" NAME="month" VALUE="12">
    <INPUT TYPE="hidden" NAME="year" VALUE="2037">
    <TR>
      <TD ALIGN="right">Account&nbsp;number</TD>
      <TD><INPUT TYPE="text" SIZE=10 NAME="payinfo1" VALUE="<%$payinfo1%>"></TD>
      <TD ALIGN="right">Type</TD>
      <TD><SELECT NAME="paytype"><% join('', map { qq!<OPTION VALUE="$_" !.($paytype eq $_ ? 'SELECTED' : '').">$_</OPTION>" } @FS::cust_main::paytypes) %></SELECT></TD>
    </TR>
    <TR>
      <TD ALIGN="right">ABA/Routing&nbsp;number</TD>
      <TD>
        <INPUT TYPE="text" SIZE=10 MAXLENGTH=9 NAME="payinfo2" VALUE="<%$payinfo2%>">
        (<A HREF="javascript:void(0);" onClick="overlib( OLiframeContent('../docs/ach.html', 380, 240, 'ach_popup' ), CAPTION, 'ACH Help', STICKY, AUTOSTATUSCAP, CLOSECLICK, DRAGGABLE ); return false;">help</A>)
      </TD>
    </TR>
    <TR>
      <TD ALIGN="right">Bank&nbsp;name</TD>
      <TD><INPUT TYPE="text" NAME="payname" VALUE="<%$payname%>"></TD>
    </TR>

%   if ( $conf->exists('show_bankstate') ) {
      <TR>
        <TD ALIGN="right">Bank&nbsp;state</TD>
        <TD><% include('/elements/select-state.html',
                         'disable_empty' => 0,
                         'empty_label'   => '(choose)',
                         'state'         => $paystate,
                         'country'       => $cust_main->country,
                         'prefix'        => 'pay',
                      )
            %>
        </TD>
      </TR>
%   } else {
      <INPUT TYPE="hidden" NAME="paystate" VALUE="<% $paystate %>">
%   }

%   if ( $conf->exists('show_ss') ) {
      <TR>
        <TD ALIGN="right">
          Account&nbsp;holder<BR>
          Social&nbsp;security&nbsp;or&nbsp;tax&nbsp;ID&nbsp;#
        </TD>
        <TD><INPUT TYPE="text" NAME="ss" VALUE="<% $ss %>"></TD>
      </TR>
%   } else {
      <INPUT TYPE="hidden" NAME="ss" VALUE="<% $ss %>"></TD>
%   }

%   if ( $conf->exists('show_stateid') ) {
      <TR>
        <TD ALIGN="right">
          Account&nbsp;holder<BR>
          Driver&rsquo;s&nbsp;license&nbsp;or&nbsp;state&nbsp;ID&nbsp;#
        </TD>
        <TD><INPUT TYPE="text" NAME="stateid" VALUE="<% $stateid %>"></TD>
        <TD ALIGN="right">State</TD>
        <TD><% include('/elements/select-state.html',
                         'disable_empty' => 0,
                         'empty_label'   => '(choose)',
                         'state'         => $stateid_state,
                         'country'       => $cust_main->country,
                         'prefix'        => 'stateid_',
                      )
            %>
        </TD>
      </TR>
%   } else {
      <INPUT TYPE="hidden" NAME="stateid" VALUE="<% $stateid %>">
      <INPUT TYPE="hidden" NAME="stateid_state" VALUE="<% $stateid_state %>">
%   }

% } #end CARD/CHEK-specific section


<TR>
  <TD COLSPAN=2>
    <INPUT TYPE="checkbox" CHECKED NAME="save" VALUE="1">
    Remember this information
  </TD>
</TR>

% if ( $conf->exists("batch-enable")
%      || grep $payby eq $_, $conf->config('batch-enable_payby')
%    ) {
%
%     if ( grep $payby eq $_, $conf->config('realtime-disable_payby') ) {

          <INPUT TYPE="hidden" NAME="batch" VALUE="1">

%     } else {

          <TR>
            <TD COLSPAN=2>
              <INPUT TYPE="checkbox" NAME="batch" VALUE="1">
              Add to current batch
            </TD>
          </TR>

%     }
% }

<TR>
  <TD COLSPAN=2>
    <INPUT TYPE="checkbox"<% ( ( $payby eq 'CARD' && $cust_main->payby ne 'DCRD' ) || ( $payby eq 'CHEK' && $cust_main->payby eq 'CHEK' ) ) ? ' CHECKED' : '' %> NAME="auto" VALUE="1" onClick="if (this.checked) { document.OneTrueForm.save.checked=true; }">
    Charge future payments to this <% $type{$payby} %> automatically
  </TD>
</TR>

</TABLE>

<BR>
<INPUT TYPE="submit" NAME="process" VALUE="Process payment">
</FORM>

<% include('/elements/footer.html') %>
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

my $money_char = $conf->config('money_char') || '$';

#false laziness w/selfservice make_payment.html shortcut for one-country
my %states = map { $_->state => 1 }
               qsearch('cust_main_county', {
                 'country' => $conf->config('countrydefault') || 'US'
               } );
my @states = sort { $a cmp $b } keys %states;

my $fee = '';
my $fee_pkg = '';
my $fee_display = '';
my $fee_op = '';
my $num_payments = scalar($cust_main->cust_pay);
#handle old cust_main.pm (remove...)
$num_payments = scalar( @{ [ $cust_main->cust_pay ] } )
  unless defined $num_payments;
if ( $conf->config('manual_process-pkgpart')
     and ! $conf->exists('manual_process-skip_first') || $num_payments
   )
{

  $fee_display = $conf->config('manual_process-display') || 'add';
  $fee_op = $fee_display eq 'add' ? '+' : '-';

  $fee_pkg =
    qsearchs('part_pkg', { pkgpart=>$conf->config('manual_process-pkgpart') } );

  #well ->unit_setup or ->calc_setup both call for a $cust_pkg
  # (though ->unit_setup doesn't use it...)
  $fee = $fee_pkg->option('setup_fee')
    if $fee_pkg; #in case.. better than dying with a perl traceback

}

my $amount = '';
if ( $balance > 0 ) {
  $amount = $balance;
  $amount += $fee
    if $fee && $fee_display eq 'subtract';
  $amount = sprintf("%.2f", $amount);
}

my $payunique = "webui-payment-". time. "-$$-". rand() * 2**32;

</%init>
