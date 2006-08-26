%
%
%my ($count_query, $sql_query, $batchnum);
%my $hashref = {};
%my @search = ();
%my $orderby = 'paybatchnum';
%
%if ( $cgi->param('batchnum') && $cgi->param('batchnum') =~ /^(\d+)$/ ) {
%  push @search, "batchnum = $1";
%  my $pay_batch = qsearchs('pay_batch', { 'batchnum' => $1 } );
%  die "Batch $1 not found!" unless $pay_batch;
%  $batchnum = $pay_batch->batchnum;
%}
%
%if ( $cgi->param('payby')  ) {
%  $cgi->param('payby') =~ /^(CARD|CHEK)$/
%    or die "illegal payby " . $cgi->param('payby');
%
%  push @search, "cust_pay_batch.payby = '$1'";
%}
%
%if ( not $cgi->param('dcln') ) {
%  push @search, "cpb.status IS DISTINCT FROM 'Approved'";
%}
%
%my ($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);
%unless ($batchnum){
%  push @search, "pay_batch.upload >= $beginning" if ($beginning);
%  push @search, "pay_batch.upload <= $ending" if ($ending < 4294967295);#2^32-1
%  $orderby = "pay_batch.download,paybatchnum";
%}
%
%push @search, $FS::CurrentUser::CurrentUser->agentnums_sql;
%my $search = ' WHERE ' . join(' AND ', @search);
%
%$count_query = 'SELECT COUNT(*) FROM cust_pay_batch AS cpb ' .
%                  'LEFT JOIN cust_main USING ( custnum ) ' .
%                  'LEFT JOIN pay_batch USING ( batchnum )' .
%		  $search;
%
%#grr
%$sql_query = "SELECT paybatchnum,invnum,custnum,cpb.last,cpb.first," .
%             "cpb.payname,cpb.payinfo,cpb.exp,amount,cpb.status " .
%	     "FROM cust_pay_batch AS cpb " .
%             'LEFT JOIN cust_main USING ( custnum ) ' .
%             'LEFT JOIN pay_batch USING ( batchnum ) ' .
%             "$search ORDER BY $orderby";
%
%my $html_init = <<EOF;
%<FORM ACTION="$p/misc/download-batch.cgi" METHOD="POST">
%Download batch in format <SELECT NAME="format">
%<OPTION VALUE="">Default batch mode</OPTION>
%<OPTION VALUE="csv-td_canada_trust-merchant_pc_batch">CSV file for TD Canada Trust Merchant PC Batch</OPTION>
%<OPTION VALUE="PAP">80 byte file for TD Canada Trust PAP Batch</OPTION>
%<OPTION VALUE="BoM">Bank of Montreal ECA batch</OPTION>
%</SELECT><INPUT TYPE="hidden" NAME="batchnum" VALUE="$batchnum"><INPUT TYPE="submit" VALUE="Download"></FORM>
%<BR><BR>
%
%<FORM ACTION="$p/misc/upload-batch.cgi" METHOD="POST" ENCTYPE="multipart/form-data">
%Upload results<BR>
%Filename <INPUT TYPE="file" NAME="batch_results"><BR>
%Format <SELECT NAME="format">
%<OPTION VALUE="">Default batch mode</OPTION>
%<OPTION VALUE="csv-td_canada_trust-merchant_pc_batch">CSV results from TD Canada Trust Merchant PC Batch</OPTION>
%<OPTION VALUE="PAP">264 byte results for TD Canada Trust PAP Batch</OPTION>
%<OPTION VALUE="BoM">Bank of Montreal ECA results</OPTION>
%</SELECT><BR>
%<INPUT TYPE="submit" VALUE="Upload"></FORM>
%<BR>
%EOF
%
%if ($batchnum) {
%  my $sth = dbh->prepare($count_query) or die dbh->errstr. "doing $count_query";
%  $sth->execute or die "Error executing \"$count_query\": ". $sth->errstr;
%  my $cards = $sth->fetchrow_arrayref->[0];
%
%  my $st = "SELECT SUM(amount) from cust_pay_batch WHERE batchnum=". $batchnum;
%  $sth = dbh->prepare($st) or die dbh->errstr. "doing $st";
%  $sth->execute or die "Error executing \"$st\": ". $sth->errstr;
%  my $total = $sth->fetchrow_arrayref->[0];
%
%  $html_init .= "$cards credit card payments batched<BR>\$" .
%                sprintf("%.2f", $total) ." total in batch<BR>";
%}
%
%
<% include('elements/search.html',
              'title'       => 'Batch payment details',
              'name'        => 'batch details',
	      'menubar'     => ['Main Menu'  => $p,],
	      'query'       => $sql_query,
	      'count_query' => $count_query,
              'html_init'   => $batchnum ? $html_init : '',
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
                                   $mon = "0$mon" if $mon < 10;
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

