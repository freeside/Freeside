%
%
%my %statusmap = ('I'=>'In Transit', 'O'=>'Open', 'R'=>'Resolved');
%my $hashref = {};
%my $count_query = 'SELECT COUNT(*) FROM pay_batch';
%
%my($begin, $end) = ( '', '' );
%
%my @where;
%if ( $cgi->param('beginning')
%     && $cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/ ) {
%  $begin = str2time($1);
%  push @where, "download >= $begin";
%}
%if ( $cgi->param('ending')
%      && $cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/ ) {
%  $end = str2time($1) + 86399;
%  push @where, "download < $end";
%}
%
%my @status;
%if ( $cgi->param('open') ) {
%  push @status, "O";
%}
%
%if ( $cgi->param('intransit') ) {
%  push @status, "I";
%}
%
%if ( $cgi->param('resolved') ) {
%  push @status, "R";
%}
%
%push @where,
%     scalar(@status) ? q!(status='! . join(q!' OR status='!, @status) . q!')!
%                     : q!status='X'!;  # kludgy, X is unused at present
%
%my $extra_sql = scalar(@where) ? 'WHERE ' . join(' AND ', @where) : ''; 
%
%
<% include( 'elements/search.html',
                 'title'        => 'Credit Card Batches',
		 'menubar'      => [ 'Main Menu' => $p, ],
		 'name'         => 'batches',
		 'query'        => { 'table'     => 'pay_batch',
		                     'hashref'   => $hashref,
				     'extra_sql' => "$extra_sql ORDER BY batchnum DESC",
				   },
		 'count_query'  => "$count_query $extra_sql",
		 'header'       => [ 'Batch',
		                     'First Download',
				     'Last Upload',
				     'Item Count',
				     'Amount',
				     'Status',
				   ],
		 'align'        => 'lllrrl',
		 'fields'       => [ 'batchnum',
                                     sub {
				       my $_date = shift->download;
				       $_date ? time2str("%a %b %e %T %Y", $_date) : '' 
				     },
                                     sub {
				       my $_date = shift->upload;
				       $_date ? time2str("%a %b %e %T %Y", $_date) : '' 
				     },
				     sub {
                                       my $st = "SELECT COUNT(*) from cust_pay_batch WHERE batchnum=" . shift->batchnum;
                                       my $sth = dbh->prepare($st)
                                         or die dbh->errstr. "doing $st";
                                       $sth->execute
				         or die "Error executing \"$st\": ". $sth->errstr;
                                       $sth->fetchrow_arrayref->[0];
				     },
				     sub {
                                       my $st = "SELECT SUM(amount) from cust_pay_batch WHERE batchnum=" . shift->batchnum;
                                       my $sth = dbh->prepare($st)
				         or die dbh->errstr. "doing $st";
                                       $sth->execute
				         or die "Error executing \"$st\": ". $sth->errstr;
                                       $sth->fetchrow_arrayref->[0];
				     },
                                     sub {
				       $statusmap{shift->status};
				     },
				   ],
		 'links'        => [ [ "${p}search/cust_pay_batch.cgi?batchnum=", 'batchnum',],
				   ],
      )

%>


