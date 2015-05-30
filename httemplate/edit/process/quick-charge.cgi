% if ( $error ) {
%   $cgi->param('error', $error );
<% $cgi->redirect($p.'quick-charge.html?'. $cgi->query_string) %>
% } else {
<% header(emt($message)) %>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY></HTML>
% }
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied"
  unless $curuser->access_right('One-time charge');

my $error = '';
my $conf = new FS::conf;
my $param = $cgi->Vars;

my @description = ();
for ( my $row = 0; exists($param->{"description$row"}); $row++ ) {
  push @description, $param->{"description$row"}
    if ($param->{"description$row"} =~ /\S/);
}

my( $cust_main, $prospect_main, $quotation ) = ( '', '', '' );
if ( $cgi->param('quotationnum') =~ /^(\d+)$/ ) {
  $quotation = FS::quotation->by_key($1) or die "quotationnum $1 not found";
}
if ( $param->{"custnum"} =~ /^(\d+)$/ ) {
  $cust_main = FS::cust_main->by_key($1) or die "custnum $1 not found";
  exists($curuser->agentnums_href->{$cust_main->agentnum})
    or die "access denied";
}
if ( $param->{"prospectnum"} =~ /^(\d+)$/ ) {
  $prospect_main = FS::prospect_main->by_key($1) or die "prospectnum $1 not found";
  exists($curuser->agentnums_href->{$prospect_main->agentnum})
    or die "access denied";
}

my $message;

if ( $param->{'pkgnum'} =~ /^(\d+)$/ ) { #modifying an existing one-time charge
  $message = "One-time charge changed";
  my $pkgnum = $1;
  die "access denied"
    unless $curuser->access_right('Modify one-time charge');

  my $cust_pkg = FS::cust_pkg->by_key($1)
    or die "pkgnum $pkgnum not found";

  my $part_pkg = $cust_pkg->part_pkg;
  die "pkgnum $pkgnum is not a one-time charge" unless $part_pkg->freq eq '0';

  my ($amount, $setup_cost, $quantity);
  if ( $cgi->param('amount') =~ /^\s*(\d*(\.\d{1,2})*)\s*$/ ) {
    $amount = sprintf('%.2f', $1);
  }
  if ( $cgi->param('setup_cost') =~ /^\s*(\d*(\.\d{1,2})*)\s*$/ ) {
    $setup_cost = sprintf('%.2f', $1);
  }
  if ( $cgi->param('quantity') =~ /^\s*(\d*)\s*$/ ) {
    $quantity = $1 || 1;
  }

  my $start_date = $cgi->param('start_date')
                     ? parse_datetime($cgi->param('start_date'))
                     : time;
   
  $param->{'tax_override'} =~ /^\s*([,\d]*)\s*$/
    or $error .= "Illegal tax override " . $param->{"tax_override"} . "  ";
  my $override = $1;
 
  if ( $param->{'taxclass'} eq '(select)' ) {
    $error .= "Must select a tax class.  "
      unless ($conf->config('tax_data_vendor') &&
               ( $override || $param->{taxproductnum} )
             );
    $cgi->param('taxclass', '');
  }

  $error = $cust_pkg->modify_charge(
      'pkg'               => scalar($cgi->param('pkg')),
      'classnum'          => scalar($cgi->param('classnum')),
      'additional'        => \@description,
      'adjust_commission' => ($cgi->param('adjust_commission') ? 1 : 0),
      'amount'            => $amount,
      'setup_cost'        => $setup_cost,
      'setuptax'          => scalar($cgi->param('setuptax')),
      'taxclass'          => scalar($cgi->param('taxclass')),
      'taxproductnum'     => scalar($cgi->param('taxproductnum')),
      'tax_override'      => $override,
      'quantity'          => $quantity,
      'start_date'        => $start_date,
      'separate_bill'     => scalar($cgi->param('separate_bill')),
  );

} else { # the usual case: new one-time charge

  $message = "One-time charge added";

  $param->{"amount"} =~ /^\s*(\d*(?:\.?\d{1,2}))\s*$/
    or $error .= "Illegal amount " . $param->{"amount"} . "  ";
  my $amount = $1;

  my $setup_cost = '';
  if ( $param->{setup_cost} =~ /\S/ ) {
    $param->{setup_cost} =~ /^\s*(\d*(?:\.?\d{1,2}))\s*$/
      or $error .= "Illegal setup_cost " . $param->{setup_cost} . "  ";
    $setup_cost = $1;
  }

  my $quantity = 1;
  if ( $cgi->param('quantity') =~ /^\s*(\d+)\s*$/ ) {
    $quantity = $1;
  }

  $param->{'tax_override'} =~ /^\s*([,\d]*)\s*$/
    or $error .= "Illegal tax override " . $param->{"tax_override"} . "  ";
  my $override = $1;

  if ( $param->{'taxclass'} eq '(select)' ) {
    $error .= "Must select a tax class.  "
      unless ($conf->config('tax_data_vendor'))
               ( $override || $param->{taxproductnum} )
             );
    $cgi->param('taxclass', '');
  }

  my %charge = (
    'amount'        => $amount,
    'setup_cost'    => $setup_cost,
    'quantity'      => $quantity,
    'bill_now'      => scalar($cgi->param('bill_now')),
    'invoice_terms' => scalar($cgi->param('invoice_terms')),
    'start_date'    => ( scalar($cgi->param('start_date'))
                           ? parse_datetime($cgi->param('start_date'))
                           : ''
                       ),
    'no_auto'       => scalar($cgi->param('no_auto')),
    'separate_bill' => scalar($cgi->param('separate_bill')),
    'pkg'           => scalar($cgi->param('pkg')),
    'setuptax'      => scalar($cgi->param('setuptax')),
    'taxclass'      => scalar($cgi->param('taxclass')),
    'taxproductnum' => scalar($cgi->param('taxproductnum')),
    'tax_override'  => $override,
    'classnum'      => scalar($cgi->param('classnum')),
    'additional'    => \@description,
  );

  if ( $quotation ) {
    $error ||= $quotation->charge( \%charge );
  } else {
    $error ||= $cust_main->charge( \%charge );
  }

}

</%init>
