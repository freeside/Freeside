<& elements/search.html,
              'title'       => 'Batch payment details',
              'name'        => 'batch details',
	      'query'       => $sql_query,
	      'count_query' => $count_query,
              'html_init'   => $pay_batch ? $html_init : '',
              'disable_download' => 1,
	      'header'      => [ '#',
	                         'Inv #',
                                 'Cust #',
	                         'Customer',
	                         'Card Name',
	                         'Card',
	                         'Exp',
	                         'Amount',
	                         'Status',
                                 '', # error_message
			       ],
              'fields'      => [  'paybatchnum',
                                  'invnum',
                                  'custnum',
                                  sub { $_[0]->cust_main->name_short },
                                  'payname',
                                  'mask_payinfo',
                                  sub {
                                    return('') if $_[0]->payby ne 'CARD';
                                    $_[0]->get('exp') =~ /^\d\d(\d\d)-(\d\d)/;
                                    sprintf('%02d/%02d',$1,$2);
                                  },
                                  sub {
                                    sprintf('%.02f', $_[0]->amount)
                                  },
                                  sub { $_[0]->display_status },
                                  'error_message',
                                ],
	      'align'       => 'rrrlllcrlll',
	      'links'       => [ '',
	                         ["${p}view/cust_bill.cgi?", 'invnum'],
	                         (["${p}view/cust_main.cgi?", 'custnum']) x 2,
			       ],
              'link_onclicks' => [ ('') x 8,
                                   $sub_receipt
                                 ],
&>
<%init>

my $conf = new FS::Conf;

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Financial reports')
      || $curuser->access_right('Process batches')
      || $curuser->access_right('Process global batches')
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
  push @search, "cust_pay_batch.custnum = $1";
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
  push @search, "cust_pay_batch.status IS DISTINCT FROM 'Approved'";
}

my ($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);
unless ($pay_batch){
  push @search, "pay_batch.upload >= $beginning" if ($beginning);
  push @search, "pay_batch.upload <= $ending" if ($ending < 4294967295);#2^32-1
  $orderby = "pay_batch.download,paybatchnum";
}

push @search, $curuser->agentnums_sql({ table => 'cust_main' });

push @search, $curuser->agentnums_sql({ table      => 'pay_batch',
                                        null_right => 'Process global batches',
                                     });

my $search = ' WHERE ' . join(' AND ', @search);

$count_query = 'SELECT COUNT(*) FROM cust_pay_batch ' .
                  'LEFT JOIN cust_main USING ( custnum ) ' .
                  'LEFT JOIN pay_batch USING ( batchnum )' .
		  $search;

$sql_query = {
  'table'     => 'cust_pay_batch',
  'select'    => 'cust_pay_batch.*, cust_main.*, cust_pay.paynum',
  'hashref'   => {},
  'addl_from' => 'LEFT JOIN pay_batch USING ( batchnum ) '.
                 'LEFT JOIN cust_main USING ( custnum ) '.
                 'LEFT JOIN cust_pay  USING ( batchnum, custnum ) ',
  'extra_sql' => $search,
  'order_by'  => "ORDER BY $orderby",
};

my $sub_receipt = sub {
  my $paynum = shift->paynum or return '';
  include('/elements/popup_link_onclick.html',
    'action'  => $p.'view/cust_pay.html?link=popup;paynum='.$paynum,
    'actionlabel' => emt('Payment Receipt'),
  );
};

my $html_init = '';
if ( $pay_batch ) {
  $html_init = include('elements/cust_pay_batch_top.html', 
                    'pay_batch' => $pay_batch);
}
</%init>
