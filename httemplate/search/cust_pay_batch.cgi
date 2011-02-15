<% include('elements/search.html',
              'title'       => 'Batch payment details',
              'name'        => 'batch details',
	      'query'       => $sql_query,
	      'count_query' => $count_query,
              'html_init'   => $pay_batch ? 
                                  include('elements/cust_pay_batch_top.html',
                                          'pay_batch' => $pay_batch
                                  ) : '',
	      'header'      => [ '#',
	                         'Inv #',
	                         'Customer',
	                         'Customer',
	                         'Card Name',
	                         'Card',
	                         'Exp',
	                         'Amount',
	                         'Status',
			       ],
	      'fields'      => [ sub {
	                           shift->[0];
				 },
	                         sub {
	                           shift->[1];
				 },
	                         sub {
	                           shift->[2];
				 },
			  	 sub {
	                           my $cpb = shift;
				   $cpb->[3] . ', ' . $cpb->[4];
				 },
	                         sub {
	                           shift->[5];
				 },
				 sub {
	                           my $cardnum = shift->[6];
                                   'x'x(length($cardnum)-4). substr($cardnum,(length($cardnum)-4));
				 },
				 sub {
				   shift->[7] =~ /^\d{2}(\d{2})[\/\-](\d+)[\/\-]\d+$/;
                                   my( $mon, $year ) = ( $2, $1 );
                                   $mon = "0$mon" if length($mon) == 1;
                                   "$mon/$year";
				 },
	                         sub {
	                           shift->[8];
				 },
	                         sub {
	                           shift->[9];
				 },
			       ],
	      'align'       => 'lllllllrl',
	      'links'       => [ ['', sub{'#';}],
	                         ["${p}view/cust_bill.cgi?", sub{shift->[1];},],
	                         ["${p}view/cust_main.cgi?", sub{shift->[2];},],
	                         ["${p}view/cust_main.cgi?", sub{shift->[2];},],
			       ],
      )
%>
<%init>

my $conf = new FS::Conf;

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports')
      || $FS::CurrentUser::CurrentUser->access_right('Process batches')
      || ( $cgi->param('custnum') 
           && (    $conf->exists('batch-enable')
                || $conf->config('batch-enable_payby')
              )
         );

my( $count_query, $sql_query );
my $hashref = {};
my @search = ();
my $orderby = 'paybatchnum';

my( $pay_batch, $batchnum ) = ( '', '');
if ( $cgi->param('batchnum') && $cgi->param('batchnum') =~ /^(\d+)$/ ) {
  push @search, "batchnum = $1";
  $pay_batch = qsearchs('pay_batch', { 'batchnum' => $1 } );
  die "Batch $1 not found!" unless $pay_batch;
  $batchnum = $pay_batch->batchnum;
}

if ( $cgi->param('custnum') && $cgi->param('custnum') =~ /^(\d+)$/ ) {
  push @search, "custnum = $1";
}

if ( $cgi->param('status') && $cgi->param('status') =~ /^(\w)$/ ) {
  push @search, "pay_batch.status = '$1'";
}

if ( $cgi->param('payby') ) {
  $cgi->param('payby') =~ /^(CARD|CHEK)$/
    or die "illegal payby " . $cgi->param('payby');

  push @search, "cust_pay_batch.payby = '$1'";
}

if ( not $cgi->param('dcln') ) {
  push @search, "cpb.status IS DISTINCT FROM 'Approved'";
}

my ($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);
unless ($pay_batch){
  push @search, "pay_batch.upload >= $beginning" if ($beginning);
  push @search, "pay_batch.upload <= $ending" if ($ending < 4294967295);#2^32-1
  $orderby = "pay_batch.download,paybatchnum";
}

push @search, $FS::CurrentUser::CurrentUser->agentnums_sql;
my $search = ' WHERE ' . join(' AND ', @search);

$count_query = 'SELECT COUNT(*) FROM cust_pay_batch AS cpb ' .
                  'LEFT JOIN cust_main USING ( custnum ) ' .
                  'LEFT JOIN pay_batch USING ( batchnum )' .
		  $search;

#grr
$sql_query = "SELECT paybatchnum,invnum,custnum,cpb.last,cpb.first," .
             "cpb.payname,cpb.payinfo,cpb.exp,amount,cpb.status " .
	     "FROM cust_pay_batch AS cpb " .
             'LEFT JOIN cust_main USING ( custnum ) ' .
             'LEFT JOIN pay_batch USING ( batchnum ) ' .
             "$search ORDER BY $orderby";

my $html_init = '';
if ( $pay_batch ) {
  $html_init = include('elements/cust_pay_batch_top.html', 
                    'pay_batch' => $pay_batch);
}
</%init>
