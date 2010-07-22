%if ( $error ) {
%  $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "rate_region.cgi?". $cgi->query_string ) %>
%} elsif ( $action eq 'Add' ) {
<% $cgi->redirect(popurl(2). "rate_region.cgi?$regionnum") %>
%} else { 
<% $cgi->redirect(popurl(3). "browse/rate_region.html") %>
%}
<%init>

my $conf = new FS::Conf;
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $regionnum = $cgi->param('regionnum');
my $action = $regionnum ? 'Edit' : 'Add';

my $old = qsearchs('rate_region', { 'regionnum' => $regionnum } ) if $regionnum;

my $new = new FS::rate_region ( {
  map {
    $_, scalar($cgi->param($_));
  } ( fields('rate_region') )
} );

my $countrycode = $cgi->param('countrycode');
my @npa = split(/\s*,\s*/, $cgi->param('npa'));
$npa[0] = '' unless @npa;
my @rate_prefix = map {
                        #my($npa,$nxx) = split('-', $_);
                        s/\D//g;
                        new FS::rate_prefix {
                          'countrycode' => $countrycode,
                          #'npa'         => $npa,
                          #'nxx'         => $nxx,
                          'npa'         => $_,
                        }
                      } @npa;
# we no longer process dest_detail records here
my $error;
if ( $regionnum ) {
  $error = $new->replace($old, 'rate_prefix' => \@rate_prefix );
} else {
  $error = $new->insert( 'rate_prefix' => \@rate_prefix );
  $regionnum = $new->getfield('regionnum');
}

</%init>
