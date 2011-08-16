% my $batchnum = $cgi->param('download');
% if ( $batchnum =~ /^\d+$/ ) {
%   my $download = $p."misc/download-bill_batch.html?$batchnum";
<HTML>
<HEAD><TITLE>Starting download...</TITLE>
<SCRIPT TYPE="text/javascript">
function start() {
  window.location.replace('<% $download %>');
}
</SCRIPT>
<!--[if lte IE 7]>
<SCRIPT TYPE="text/javascript">function start() {}</SCRIPT>
<![endif]-->
</HEAD>
<BODY onload="start()" STYLE="background-color:#ccccff">
<TABLE STYLE="height:125px; width:100%; text-align:center"><TR><TD STYLE="vertical-align:middle;text-align:center">
<A HREF="<% $download %>">Click here if your download does not start</A>
</TD></TR></TABLE>
<& /elements/footer.html &>
% }
% else {
%# delete existing download cookie
%   my $cookie = CGI::Cookie->new(
%     -name => 'bill_batch_download',
%     -value => 0,
%     -expires => '-1d',
%   );
%   $r->headers_out->add( 'Set-Cookie' => $cookie->as_string );
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
                 'html_foot' => include('.foot'),

      )

%>
%}
<%def .foot>
<SCRIPT type="text/javascript">
var timer;
function checkDownloadStatus(batchnum) {
  var re = new RegExp('bill_batch_download=' + batchnum);
  if ( re.test(document.cookie) ) {
    window.clearInterval(timer);
    window.location.reload();
  }
}
function startBatch(batchnum) {
  timer = window.setInterval(function() { 
      checkDownloadStatus(batchnum);
  }, 2000);
  eval('batch'+batchnum+'process()');
}
</SCRIPT>
</%def>
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
    { popup_url => $p."search/bill_batch.cgi?download=$batchnum" },
    "batch$batchnum" #key
  );
  $html .= '<A href="#" onclick="startBatch('.$batchnum.');">' .
  ($batch->status eq 'O' ? '<B>Download and close</B>' : 'Download');
  $html .= '</A></FORM>';
  return $html;
}

</%init>
