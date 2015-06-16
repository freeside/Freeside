<& /elements/header-popup.html, mt($title) &>

<SCRIPT TYPE="text/javascript" SRC="../elements/order_pkg.js"></SCRIPT>
<& /elements/error.html &>

<FORM NAME="OrderPkgForm" ACTION="<% $p %>edit/process/change-cust_pkg.html" METHOD=POST>
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">


<FONT CLASS="fsinnerbox-title"><% mt('Package') |h %></FONT>
<% ntable('#cccccc') %>

  <TR>
    <TH ALIGN="right"><% mt('Current package') |h %></TH>
    <TD COLSPAN=7>
      <FONT STYLE="background-color:#e8e8e8"><% $curuser->option('show_pkgnum') ? $cust_pkg->pkgnum.': ' : '' %><B><% $part_pkg->pkg |h %></B> - <% $part_pkg->comment |h %></FONT>
    </TD>
  </TR>

  <& /elements/tr-select-cust-part_pkg.html,
               'pre_label'  => emt('New'),
               'curr_value' => scalar($cgi->param('pkgpart')),
               'classnum'   => $part_pkg->classnum,
               'cust_main'  => $cust_main,
  &>

  <& /elements/tr-input-pkg-quantity.html,
               'curr_value' => $cust_pkg->quantity
  &>

% if ($use_contract_end) {
  <& /elements/tr-input-date-field.html, {
      'name'  => 'contract_end',
      'value' => ($cgi->param('contract_end') || $cust_pkg->get('contract_end')),
      'label' => '<B>Contract End</B>',
    } &>
% }

</TABLE>
<BR>


<FONT CLASS="fsinnerbox-title"><% mt('Change') |h %></FONT>
<% ntable('#cccccc') %>

  <SCRIPT TYPE="text/javascript">
    function delay_changed() {
      var enable = document.OrderPkgForm.delay[1].checked;
      document.getElementById('start_date_text').disabled = !enable;
      document.getElementById('start_date_button').style.display = 
        (enable ? '' : 'none');
      document.getElementById('start_date_button_disabled').style.display =
        (enable ? 'none' : '');
    }
    <&| /elements/onload.js &>
      delay_changed();
    </&>
  </SCRIPT>
  <TR>
    <TD> <INPUT TYPE="radio" NAME="delay" VALUE="0" \
          <% !$cgi->param('delay') ? 'CHECKED' : '' %> \
          onclick="delay_changed()"> Now </TD>
    <TD> <INPUT TYPE="radio" NAME="delay" VALUE="1" \
          <% $cgi->param('delay')  ? 'CHECKED' : '' %> \
          onclick="delay_changed()"> In the future
      <& /elements/input-date-field.html, {
          'name'  => 'start_date',
          'value' => ($cgi->param('start_date') || $cust_main->next_bill_date),
      } &>
    </TD>
  </TR>
</TABLE>
</BR>


<FONT CLASS="fsinnerbox-title"><% mt('Location') |h %></FONT>
<% ntable('#cccccc') %>

  <& /elements/tr-select-cust_location.html,
               'cgi'       => $cgi,
               'cust_main' => $cust_main,
  &>

</TABLE>
<BR>


<& /elements/standardize_locations.html,
            'form'        => "OrderPkgForm",
            'with_census' => 1,
            'with_census_functions' => 1,
            'callback'   => 'document.OrderPkgForm.submit()',
&>

<INPUT NAME    = "submitButton"
       TYPE    = "button"
       VALUE   = "<% mt("Change package") |h %>"
       onClick = "this.disabled=true; standardize_new_location();"
       <% scalar($cgi->param('pkgpart')) ? '' : 'DISABLED' %>
>

</FORM>
</BODY>
</HTML>

<%init>

my $conf = new FS::Conf;

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Change customer package');

my $pkgnum = scalar($cgi->param('pkgnum'));
$pkgnum =~ /^(\d+)$/ or die "illegal pkgnum $pkgnum";
$pkgnum = $1;

my $cust_pkg =
  qsearchs({
    'table'     => 'cust_pkg',
    'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
    'hashref'   => { 'pkgnum' => $pkgnum },
    'extra_sql' => ' AND '. $curuser->agentnums_sql,
  }) or die "unknown pkgnum $pkgnum";

my $cust_main = $cust_pkg->cust_main
  or die "can't get cust_main record for custnum ". $cust_pkg->custnum.
         " ( pkgnum ". cust_pkg->pkgnum. ")";

my $part_pkg = $cust_pkg->part_pkg;

my $title = "Change Package";

my $use_contract_end = $cust_pkg->get('contract_end') ? 1 : 0;

# if there's already a package change ordered, preload it
if ( $cust_pkg->change_to_pkgnum ) {
  my $change_to = FS::cust_pkg->by_key($cust_pkg->change_to_pkgnum);
  $cgi->param('delay', 1);
  foreach(qw( start_date pkgpart locationnum quantity )) {
    $cgi->param($_, $change_to->get($_));
  }
  if ($use_contract_end) {
    $cgi->param('contract_end', $change_to->get('contract_end'));
  }
  $title = "Edit Scheduled Package Change";
}
</%init>
