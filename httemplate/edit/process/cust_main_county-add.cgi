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

my @expansion = split /[\n\r]{1,2}/, $cgi->param('expansion');

@expansion=map {
  unless ( /^\s*([\w \!\@\#\$\%\&\(\)\-\+\;\:\'\"\,\.\?\/\=\[\]]+)\s*$/ ) {
    $cgi->param('error', "Illegal item in expansion: $_");
    print $cgi->redirect(popurl(2). "cust_main_county-expand.cgi?". $cgi->query_string );
    myexit();
  }
  $1;
} @expansion;

foreach ( @expansion ) {
  my(%hash)=$cust_main_county->hash;
  my($new)=new FS::cust_main_county \%hash;
  $new->setfield('taxnum','');
  $new->setfield('taxclass', '');
  if ( $cgi->param('what') eq 'state' ) { #??
    $new->setfield('state',$_);
    $new->setfield('county', '');
    $new->setfield('city', '');
  } elsif ( $cgi->param('what') eq 'county' ) {
    $new->setfield('county',$_);
    $new->setfield('city', '');
  } elsif ( $cgi->param('what') eq 'city' ) {
    #uppercase cities in the US to try and agree with USPS validation
    $new->setfield('city', $new->country eq 'US' ? uc($_) : $_ );
  } else { #???
    die 'unknown what '. $cgi->param('what');
  }
  my $error = $new->insert;
  die $error if $error;
}

</%init>
