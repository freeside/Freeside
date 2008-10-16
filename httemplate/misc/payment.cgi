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
    <TD ALIGN="right">Payment amount</TD>
    <TD>
      <TABLE><TR><TD BGCOLOR="#ffffff">
        $<INPUT TYPE="text" NAME="amount" SIZE=8 VALUE="<% $balance > 0 ? sprintf("%.2f", $balance) : '' %>">
      </TD></TR></TABLE>
    </TD>
  </TR>
% if ( $payby eq 'CARD' ) {
%     my( $payinfo, $paycvv, $month, $year ) = ( '', '', '', '' );
%     my $payname = $cust_main->first. ' '. $cust_main->getfield('last');
%     my $address1 = $cust_main->address1;
%     my $address2 = $cust_main->address2;
%     my $city     = $cust_main->city;
%     my $state    = $cust_main->state;
%     my $zip     = $cust_main->zip;
%     if ( $cust_main->payby =~ /^(CARD|DCRD)$/ ) {
%       $payinfo = $cust_main->paymask;
%       $paycvv = $cust_main->paycvv;
%       ( $month, $year ) = $cust_main->paydate_monthyear;
%       $payname = $cust_main->payname if $cust_main->payname;
%     }
%

  <TR>
    <TD ALIGN="right">Card&nbsp;number</TD>
    <TD>
      <TABLE>
        <TR>
          <TD>
            <INPUT TYPE="text" NAME="payinfo" SIZE=20 MAXLENGTH=19 VALUE="<%$payinfo%>"> </TD>
          <TD>Exp.</TD>
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
    <TD ALIGN="right">CVV2</TD>
    <TD><INPUT TYPE="text" NAME="paycvv" VALUE="<% $paycvv %>" SIZE=4 MAXLENGTH=4>
        (<A HREF="javascript:void(0);" onClick="overlib( OLiframeContent('../docs/cvv2.html', 480, 352, 'cvv2_popup' ), CAPTION, 'CVV2 Help', STICKY, AUTOSTATUSCAP, CLOSECLICK, DRAGGABLE ); return false;">help</A>)
    </TD>
  </TR>
  <TR>
    <TD ALIGN="right">Exact&nbsp;name&nbsp;on&nbsp;card</TD>
    <TD><INPUT TYPE="text" SIZE=32 MAXLENGTH=80 NAME="payname" VALUE="<%$payname%>"></TD>
  </TR><TR>
    <TD ALIGN="right">Card&nbsp;billing&nbsp;address</TD>
    <TD>
      <INPUT TYPE="text" SIZE=40 MAXLENGTH=80 NAME="address1" VALUE="<%$address1%>">
    </TD>
  </TR><TR>
    <TD ALIGN="right">Address&nbsp;line&nbsp;2</TD>
    <TD>
      <INPUT TYPE="text" SIZE=40 MAXLENGTH=80 NAME="address2" VALUE="<%$address2%>">
    </TD>
  </TR><TR>
    <TD ALIGN="right">City</TD>
    <TD>
      <TABLE>
        <TR>
          <TD>
            <INPUT TYPE="text" NAME="city" SIZE="12" MAXLENGTH=80 VALUE="<%$city%>">
          </TD>
          <TD>State</TD>
          <TD>
            <SELECT NAME="state">
% for ( @states ) { 

                <OPTION<% $_ eq $state ? ' SELECTED' : '' %>><% $_ %> 
% } 

            </SELECT>
          </TD>
          <TD>Zip</TD>
          <TD>
            <INPUT TYPE="text" NAME="zip" SIZE=11 MAXLENGTH=10 VALUE="<%$zip%>">
          </TD>
        </TR>
      </TABLE>
    </TD>
  </TR>
% } elsif ( $payby eq 'CHEK' ) {
%     my( $payinfo1, $payinfo2, $payname, $ss, $paytype, $paystate,
%         $stateid, $stateid_state )
%       = ( '', '', '', '', '', '', '', '' );
%     if ( $cust_main->payby =~ /^(CHEK|DCHK)$/ ) {
%       $cust_main->paymask =~ /^([\dx]+)\@([\dx]+)$/i
%         or die "unparsable payinfo ". $cust_main->payinfo;
%       ($payinfo1, $payinfo2) = ($1, $2);
%       $payname = $cust_main->payname;
%       $ss = $cust_main->ss;
%       $paytype = $cust_main->getfield('paytype');
%       $paystate = $cust_main->getfield('paystate');
%       $stateid = $cust_main->getfield('stateid');
%       $stateid_state = $cust_main->getfield('stateid_state');
%     }
%

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
  <TR>
    <TD ALIGN="right">Bank&nbsp;state</TD>
    <TD><% include('../edit/cust_main/select-state.html', #meh 
                   'empty'   => '(choose)',
                   'state'   => $paystate,
                   'country' => $cust_main->country,
                   'prefix'  => 'pay',
                  ) %></TD>
  </TR>
  <TR>
    <TD ALIGN="right">
      Account&nbsp;holder<BR>
      Social&nbsp;security&nbsp;or&nbsp;tax&nbsp;ID&nbsp;#
    </TD>
    <TD><INPUT TYPE="text" NAME="ss" VALUE="<%$ss%>"></TD>
  </TR>
  <TR>
    <TD ALIGN="right">
      Account&nbsp;holder<BR>
      Driver&rsquo;s&nbsp;license&nbsp;or&nbsp;state&nbsp;ID&nbsp;#
    </TD>
    <TD><INPUT TYPE="text" NAME="stateid" VALUE="<%$stateid%>"></TD>
    <TD ALIGN="right">State</TD>
    <TD><% include('../edit/cust_main/select-state.html', #meh 
                   'empty'   => '(choose)',
                   'state'   => $stateid_state,
                   'country' => $cust_main->country,
                   'prefix'  => 'stateid_',
                  ) %></TD>
  </TR>
% } 


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

#false laziness w/selfservice make_payment.html shortcut for one-country
my $conf = new FS::Conf;
my %states = map { $_->state => 1 }
               qsearch('cust_main_county', {
                 'country' => $conf->config('countrydefault') || 'US'
               } );
my @states = sort { $a cmp $b } keys %states;

my $payunique = "webui-payment-". time. "-$$-". rand() * 2**32;

</%init>


