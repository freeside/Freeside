<% include( 'elements/search.html',
                 'title'         => 'Invoice Batches',
		 'name_singular' => 'batch',
		 'query'         => { 'table'     => 'bill_batch',
		                      'hashref'   => $hashref,
				      'extra_sql' => $extra_sql.
                                        'ORDER BY batchnum DESC',
				    },
		 'count_query'   => "$count_query $extra_sql",
		 'header'        => [ 'Batch',
				      'Item Count',
				      'Status',
                                      '',
                                    ],
		 'align'         => 'rrcc',
		 'fields'        => [ 'batchnum',
                                      sub {
                                        my $st = "SELECT COUNT(*) from cust_bill_batch WHERE batchnum=" . shift->batchnum;
                                        my $sth = dbh->prepare($st)
                                          or die dbh->errstr. "doing $st";
                                        $sth->execute
				          or die "Error executing \"$st\": ". $sth->errstr;
                                        $sth->fetchrow_arrayref->[0];
				      },
				      sub {
				        $statusmap{shift->status};
				      },
                                      sub { shift->status eq 'O' ? 
                                            'Download and close' : 'Download' 
                                      },
				    ],
		 'links'         => [
                                      $link,
                                      $link,
                                      $link,
                                      $dlink,
                                    ],
		 'style'         => [
		                      '',
                                      '',
                                      '',
				      sub { shift->status eq 'O' ? "b" : '' },
				    ],
                 'really_disable_download' => 1,
      )

%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

my %statusmap = ('O'=>'Open', 'R'=>'Closed');
my $hashref = {};
my $count_query = 'SELECT COUNT(*) FROM bill_batch';

my $extra_sql = ''; # may add something here later
my $link = [ "${p}view/bill_batch.cgi?batchnum=", 'batchnum' ];
my $dlink = sub {
  [ "${p}view/bill_batch.cgi?magic=print;".
      (shift->status eq 'O' ? 'close=1;' : '').
      'batchnum=',
    'batchnum'] 
};
</%init>
