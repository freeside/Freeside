<% include( 'elements/search.html',
                 'title'         => 'Payment Batches',
		 'name_singular' => 'batch',
		 'query'         => { 'table'     => 'pay_batch',
		                      'hashref'   => $hashref,
				      'extra_sql' => $extra_sql,
                                      'order_by'  => 'ORDER BY batchnum DESC',
				    },
		 'count_query'   => "$count_query $extra_sql",
		 'header'        => [ 'Batch',
		                      'Type',
		                      'First Download',
				      'Last Upload',
				      'Item Count',
				      'Amount',
				      'Status',
                                    ],
		 'align'         => 'rcllrrc',
		 'fields'        => [ 'batchnum',
		                      sub { 
				        FS::payby->shortname(shift->payby);
				      },
                                      sub {
				        my $self = shift;
				        my $_date = $self->download;
				        if ( $_date ) {
					  time2str("%a %b %e %T %Y", $_date);
					} elsif ( $self->status eq 'O' ) {
					  'Download batch';
					} else {
					  '';
					}
				      },
                                      sub {
				        my $self = shift;
				        my $_date = $self->upload;
				        if ( $_date ) {
					  time2str("%a %b %e %T %Y", $_date);
					} elsif ( $self->status eq 'I' ) {
					  'Upload results';
					} else {
					  '';
					}
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
		 'links'         => [
		                      $link,
				      '',
				      sub { shift->status eq 'O' ? $link : '' },
				      sub { shift->status eq 'I' ? $link : '' },
				    ],
		 'size'         => [
		                      '',
				      '',
				      sub { shift->status eq 'O' ? "+1" : '' },
				      sub { shift->status eq 'I' ? "+1" : '' },
				    ],
		 'style'         => [
		                      '',
				      '',
				      sub { shift->status eq 'O' ? "b" : '' },
				      sub { shift->status eq 'I' ? "b" : '' },
				    ],
                 'html_init'     => $html_init,
      )

%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Financial reports')
      || $FS::CurrentUser::CurrentUser->access_right('Process batches');

my %statusmap = ('I'=>'In Transit', 'O'=>'Open', 'R'=>'Resolved');
my $hashref = {};
my $count_query = 'SELECT COUNT(*) FROM pay_batch';

my($begin, $end) = ( '', '' );

my @where;
if ( $cgi->param('beginning')
     && $cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/ ) {
  $begin = parse_datetime($1);
  push @where, "download >= $begin";
}
if ( $cgi->param('ending')
      && $cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/ ) {
  $end = parse_datetime($1) + 86399;
  push @where, "download < $end";
}

my @status;
if ( $cgi->param('open') ) {
  push @status, "O";
}

if ( $cgi->param('intransit') ) {
  push @status, "I";
}

if ( $cgi->param('resolved') ) {
  push @status, "R";
}

push @where,
     scalar(@status) ? q!(status='! . join(q!' OR status='!, @status) . q!')!
                     : q!status='X'!;  # kludgy, X is unused at present

my $extra_sql = scalar(@where) ? 'WHERE ' . join(' AND ', @where) : ''; 

my $link = [ "${p}search/cust_pay_batch.cgi?dcln=1;batchnum=", 'batchnum' ];

my $resolved = $cgi->param('resolved') || 0;
$cgi->param('resolved' => !$resolved);
my $html_init = '<A HREF="' . $cgi->self_url . '"><I>'.
    ($resolved ? 'Hide' : 'Show') . ' resolved batches</I></A><BR>';

</%init>
