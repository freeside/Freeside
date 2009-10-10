% if ( $error ) {
%   $cgi->param('error', $error );
<% $cgi->redirect($p.'quick-charge.html?'. $cgi->query_string) %>
% } else {
<% header("One-time charge added") %>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY></HTML>
% }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('One-time charge');

my $error = '';
my $conf = new FS::conf;
my $param = $cgi->Vars;

my @description = ();
for ( my $row = 0; exists($param->{"description$row"}); $row++ ) {
  push @description, $param->{"description$row"}
    if ($param->{"description$row"} =~ /\S/);
}

$param->{"custnum"} =~ /^(\d+)$/
  or $error .= "Illegal customer number " . $param->{"custnum"} . "  ";
my $custnum = $1;

$param->{"amount"} =~ /^\s*(\d*(?:\.?\d{1,2}))\s*$/
  or $error .= "Illegal amount " . $param->{"amount"} . "  ";
my $amount = $1;

my $quantity = 1;
if ( $cgi->param('quantity') =~ /^\s*(\d+)\s*$/ ) {
  $quantity = $1;
}

$param->{'tax_override'} =~ /^\s*([,\d]*)\s*$/
  or $error .= "Illegal tax override " . $param->{"tax_override"} . "  ";
my $override = $1;

if ( $param->{'taxclass'} eq '(select)' ) {
  $error .= "Must select a tax class.  "
    unless ($conf->exists('enable_taxproducts') &&
             ( $override || $param->{taxproductnum} )
           );
  $cgi->param('taxclass', '');
}

unless ( $error ) {
  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or $error .= "Unknown customer number $custnum.  ";

  $error ||= $cust_main->charge( {
    'amount'        => $amount,
    'quantity'      => $quantity,
    'bill_now'      => scalar($cgi->param('bill_now')),
    'invoice_terms' => scalar($cgi->param('invoice_terms')),
    'start_date'    => ( scalar($cgi->param('start_date'))
                           ? str2time($cgi->param('start_date'))
                           : ''
                       ),
    'pkg'           => scalar($cgi->param('pkg')),
    'setuptax'      => scalar($cgi->param('setuptax')),
    'taxclass'      => scalar($cgi->param('taxclass')),
    'taxproductnum' => scalar($cgi->param('taxproductnum')),
    'tax_override'  => $override,
    'classnum'      => scalar($cgi->param('classnum')),
    'additional'    => \@description,
  } );
}

</%init>
