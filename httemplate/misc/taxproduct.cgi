<%once>
my $conf = FS::Conf->new;
my $vendor = $conf->config('tax_data_vendor');
</%once>
<%init>
my $term = $cgi->param('term');
warn "taxproduct.cgi?$term"; # XXX debug
my $search = { table => 'part_pkg_taxproduct' };
if ( $term =~ /^\d+$/ ) {
  $search->{extra_sql} = " WHERE taxproduct LIKE '$term%'";
  $search->{order_by} = " ORDER BY taxproduct ASC";
} elsif ( length($term) ) {
  $term = dbh->quote( lc($term) ); # protect against bad strings
  $search->{extra_sql} = " WHERE POSITION($term IN LOWER(description)) > 0";
  # and sort by how close to the beginning of the string it is
  $search->{order_by} = " ORDER BY POSITION($term IN LOWER(description)) ASC, LOWER(description) ASC, taxproduct ASC";
}
my @taxproducts = qsearch($search);
my @results = map {
  { label => $_->taxproduct . ' ' . $_->description,
    value => $_->taxproductnum } 
} @taxproducts;
</%init>
<% encode_json(\@results) %>\
