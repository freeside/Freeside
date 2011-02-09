<% include('/elements/header-popup.html', 'Addition successful' ) %>

<SCRIPT TYPE="text/javascript">
  window.top.location.reload();
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

my @expansion;
if ( $cgi->param('taxclass') ) {
  my $sth = dbh->prepare('SELECT taxclass FROM part_pkg_taxclass')
    or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  @expansion = map $_->[0], @{$sth->fetchall_arrayref};
  errorpage "No taxclasses - add one first" unless @expansion;
} else {
  @expansion = split /[\n\r]{1,2}/, $cgi->param('expansion');

  #warn scalar(@expansion);
  #warn "$_: $expansion[$_]\n" foreach (0..$#expansion);

  @expansion=map {
    unless ( /^\s*([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=\[\]]+)\s*$/ ) {
      $cgi->param('error', "Illegal item in expansion: $_");
      print $cgi->redirect(popurl(2). "cust_main_county-expand.cgi?". $cgi->query_string );
      myexit();
    }
    $1;
  } @expansion;

}

foreach ( @expansion) {
  my(%hash)=$cust_main_county->hash;
  my($new)=new FS::cust_main_county \%hash;
  $new->setfield('taxnum','');
  if ( $cgi->param('taxclass') ) {
    $new->setfield('taxclass', $_);
  } elsif ( ! $cust_main_county->state ) {
    $new->setfield('state',$_);
  } elsif ( ! $cust_main_county->county ) {
    $new->setfield('county',$_);
  } else {
    #uppercase cities in the US to try and agree with USPS validation
    $new->setfield('city', $new->country eq 'US' ? uc($_) : $_ );
  }
  my $error = $new->insert;
  die $error if $error;
}

unless ( qsearch( 'cust_main', {
                                 'city'    => $cust_main_county->city,
                                 'county'  => $cust_main_county->county,
                                 'state'   => $cust_main_county->state,
                                 'country' => $cust_main_county->country,
                               } )
         || ! @expansion
) {
  my $error = $cust_main_county->delete;
  die $error if $error;
}

if ( $cgi->param('taxclass') ) {
  print $cgi->redirect(popurl(3). "browse/cust_main_county.cgi?".
                         'city='.    uri_escape($cust_main_county->city   ).';'.
                         'county='.  uri_escape($cust_main_county->county ).';'.
                         'state='.   uri_escape($cust_main_county->state  ).';'.
                         'country='. uri_escape($cust_main_county->country)
                      );
  myexit;
}

</%init>
