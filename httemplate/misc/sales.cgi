<% encode_json( \@return ) %>\
<%init>

my( $agentnum ) = $cgi->param('arg');

my %hash = ( 'disabled' => '' );
if ( $agentnum > 0 ) {
  $hash{'agentnum'} = $agentnum;
}
my @sales = qsearch({
  'table'     => 'sales',
  'hashref'   => \%hash,
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
  'order_by'  => 'ORDER BY salesperson',
});

my @return = map  {
                    ( $_->salesnum,
                      $_->salesperson,
                    )
                  }
                  #sort { $a->salesperson cmp $b->salesperson }
                  @sales;

</%init>
