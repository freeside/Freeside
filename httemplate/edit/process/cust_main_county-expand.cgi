%
%
%$cgi->param('taxnum') =~ /^(\d+)$/ or die "Illegal taxnum!";
%my $taxnum = $1;
%my $cust_main_county = qsearchs('cust_main_county',{'taxnum'=>$taxnum})
%  or die ("Unknown taxnum!");
%
%my @expansion;
%if ( $cgi->param('delim') eq 'n' ) {
%  @expansion=split(/\n/,$cgi->param('expansion'));
%} elsif ( $cgi->param('delim') eq 's' ) {
%  @expansion=split(' ',$cgi->param('expansion'));
%} else {
%  die "Illegal delim!";
%}
%
%@expansion=map {
%  unless ( /^\s*([\w\- ]+)\s*$/ ) {
%    $cgi->param('error', "Illegal item in expansion");
%    print $cgi->redirect(popurl(2). "cust_main_county-expand.cgi?". $cgi->query_string );
%    myexit();
%  }
%  $1;
%} @expansion;
%
%foreach ( @expansion) {
%  my(%hash)=$cust_main_county->hash;
%  my($new)=new FS::cust_main_county \%hash;
%  $new->setfield('taxnum','');
%  if ( $cgi->param('taxclass') ) {
%    $new->setfield('taxclass', $_);
%  } elsif ( ! $cust_main_county->state ) {
%    $new->setfield('state',$_);
%  } else {
%    $new->setfield('county',$_);
%  }
%  #if (datasrc =~ m/Pg/)
%  #{
%  #    $new->setfield('tax',0.0);
%  #}
%  my($error)=$new->insert;
%  die $error if $error;
%}
%
%unless ( qsearch( 'cust_main', {
%                                 'state'  => $cust_main_county->state,
%                                 'county' => $cust_main_county->county,
%                                 'country' =>  $cust_main_county->country,
%                               } )
%         || ! @expansion
%) {
%  my($error)=($cust_main_county->delete);
%  die $error if $error;
%}
%
%print $cgi->redirect(popurl(3). "browse/cust_main_county.cgi");
%
%

