% my $batchnum = $cgi->param('download');
% if ( $batchnum =~ /^\d+$/ ) {
%   $cgi->delete('download');
<HTML>
<HEAD><TITLE>Starting download...</TITLE>
<SCRIPT TYPE="text/javascript">
function refreshParent() {
  window.top.setTimeout("window.top.location.href = '<% $cgi->self_url %>'", 2000);
  window.top.location.replace('<%$p%>misc/download-bill_batch.html?<%$batchnum%>');
}
</SCRIPT>
</HEAD><BODY onload="refreshParent();">
<& /elements/footer.html &>
% }
% else {
<% include( 'elements/search.html',
                 'title'         => 'Invoice Batches',
		 'name_singular' => 'batch',
		 'query'         => { 'table'     => 'bill_batch',
		                      'hashref'   => $hashref,
				      #'extra_sql' => $extra_sql.
                                      'order_by'  => 'ORDER BY batchnum DESC',
				    },
		 'count_query'   => $count_query,
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
                                      \&download_link,
				    ],
		 'links'         => [
                                      $link,
                                      $link,
                                      $link,
                                      '',
                                    ],
                 'really_disable_download' => 1,
                 'agent_virt' => 1,
                 'agent_null_right' => [ 'Process global invoice batches', 'Configuration' ],
                 'agent_pos' => 1,

      )

%>
%}
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Process invoice batches')
      || $curuser->access_right('Process global invoice batches')
      || $curuser->access_right('Configuration'); #remove in 2.5

my %statusmap = ('O'=>'Open', 'R'=>'Closed');
my $hashref = {};
my $count_query = "SELECT COUNT(*) FROM bill_batch WHERE". # $extra_sql AND "
                    $curuser->agentnums_sql(
                      'null_right' => ['Process global invoice batches', 'Configuration' ],
                    );

#my $extra_sql = ''; # may add something here later
my $link = [ "${p}view/bill_batch.cgi?batchnum=", 'batchnum' ];

my $download_id = int(rand(1000000));

sub download_link {
  my $batch = shift;
  my $batchnum = $batch->batchnum;
  my $close = ($batch->status eq 'O' ? ';close=1' : '');
  my $html = qq!<FORM NAME="Download$batchnum" STYLE="display:inline">
  <INPUT TYPE="hidden" NAME="batchnum" VALUE="$batchnum">
  <INPUT TYPE="hidden" NAME="close" VALUE="1">
  !;
  $html .= include('/elements/progress-init.html',
    "Download$batchnum",
    [ 'batchnum', 'close' ],
    $p.'misc/process/bill_batch-print.html',
    { url => $p."search/bill_batch.cgi?download=$batchnum" },
    "batch$batchnum" #key
  );
  $html .= '<A href="#" onclick="batch'.$batchnum.'process();">' .
  ($batch->status eq 'O' ? '<B>Download and close</B>' : 'Download');
  $html .= '</A></FORM>';
  return $html;
}

</%init>
