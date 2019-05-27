<% include('/elements/header-popup.html', 'Addition successful' ) %>

<SCRIPT TYPE="text/javascript">
  topreload();
</SCRIPT>

</BODY>
</HTML>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

$cgi->param('taxnum') =~ /^(\d+)$/ or die "Illegal taxnum!";
my $taxnum = $1;
my $cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum})
  or die ("Unknown taxnum!");

my @expansion = split /[\n\r]{1,2}/, $cgi->param('expansion');

@expansion=map {
  unless ( /^\s*([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=\[\]]+)\s*$/ ) {
    $cgi->param('error', "Illegal item in expansion: $_");
    print $cgi->redirect(popurl(2). "cust_main_county-expand.cgi?". $cgi->query_string );
    myexit();
  }
  $1;
} @expansion;

my $what = $cgi->param('what');
foreach my $new_tax_area ( @expansion ) {

  # Clone specific tax columns from original tax row
  #
  # UI Note:  Preserving original behavior, of cloning
  #   tax amounts into new tax record, against better
  #   judgement.  If the new city/county/state has a
  #   different tax value than the one being populated
  #   (rather likely?) now the user must remember to
  #   revisit each newly created tax row, and correct
  #   the possibly incorrect tax values that were populated.
  #   Values would be easier to identify and correct if
  #   they were initially populated with 0% tax rates
  # District Note: The 'district' column is NOT cloned
  #   to the new tax row.   Manually entered taxes
  #   are not be divided into road maintenance districts
  #   like Washington state sales taxes
  my $new = FS::cust_main_county->new({
    map { $_ => $cust_main_county->getfield($_) }
    qw/
      charge_prediscount
      exempt_amount
      exempt_amount_currency
      recurtax
      setuptax
      tax
      taxname
    /
  });

  # Clone additional location columns, based on the $what value
  my %clone_cols_for = (
    state  => [qw/country /],
    county => [qw/country state/],
    city   => [qw/country state county/],
  );

  die "unknown what: $what"
    unless grep { $_ eq $what } keys %clone_cols_for;

  $new->setfield( $_ => $cust_main_county->getfield($_) )
    for @{ $clone_cols_for{ $cgi->param('what') } };

  # In the US, store cities upper case for USPS validation
  $new_tax_area = uc($new_tax_area)
    if $what eq 'city'
    && $new->country eq 'US';

  $new->setfield( $what, $new_tax_area );
  if ( my $error = $new->insert ) {
    die $error;
  }
}

</%init>
