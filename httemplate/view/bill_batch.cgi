% if($magic eq 'download') {
%   my $content = $batch->pdf;
%   $batch->pdf('');
%   my $error = $batch->replace;
%   warn "error deleting cached PDF: '$error'\n" if $error;
%
%   $m->clear_buffer;
%   $r->content_type('application/pdf');
%   $r->headers_out->add('Content-Disposition' => 'attachment;filename="invoice_batch_'.$batchnum.'.pdf"');
<% $content %>
% }
%
% elsif ($magic eq 'download_popup') {
%
<& /elements/header-popup.html,
  { 'etc' => 'BGCOLOR="#ccccff"' } &>
<SCRIPT type="text/javascript">
function start() {
window.open('<% $cgi->self_url . ';magic=download' %>');
parent.nd(1);
}
</SCRIPT>
<TABLE WIDTH="100%"><TR><TD STYLE="text-align:center;vertical-align:middle">
<FONT SIZE="+1">
<A HREF="javascript:start()">Download batch #<% $batchnum %></A>
</FONT>
</TD></TR></TABLE>
<& /elements/footer.html &>
%
% }
%
% else {
<% include('/search/elements/search.html', 
              'title'     => $close ?
                              "Batch $batchnum closed." :
                              "Invoice Batch $batchnum",
              'name'      => 'invoices',
              'query'     => { 'table'   => 'cust_bill_batch',
                               'select'  => join(', ',
                                          'cust_bill.*',
                                          FS::UI::Web::cust_sql_fields(),
                                          'cust_main.custnum AS cust_main_custnum',
                                ),
                               'hashref' => { },
                               'addl_from' => 
                                 'LEFT JOIN cust_bill USING ( invnum ) '.
                                 'LEFT JOIN cust_main USING ( custnum )',
                               'extra_sql' => " WHERE batchnum = $batchnum",
                             },
              'count_query' => "SELECT COUNT(*) FROM cust_bill_batch WHERE batchnum = $batchnum",
              'html_init' => $html_init,
              'html_foot' => $html_foot,
              'header'    => [ 'Invoice #',
                               'Amount',
                               'Date',
                               'Customer',
                             ],
              'fields'    => [ sub { shift->cust_bill->display_invnum },
                               sub { sprintf($money_char.'%.2f', 
                                      shift->cust_bill->charged ) },
                               sub { time2str('%b %d %Y', 
                                      shift->cust_bill->_date ) },
                               sub { shift->cust_bill->cust_main->name },
                             ],
              'align'     => 'rrll',
              'links'     => [ ($link) x 3, $clink,
                             ],
              'really_disable_download' => 1,
) %>
% }
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('View invoices');

my $conf = new FS::Conf;
my $batch;
my $batchnum = $cgi->param('batchnum');

$batch = FS::bill_batch->by_key($batchnum);
die "Batch '$batchnum' not found!\n" if !$batch;

my $magic = $cgi->param('magic');
$cgi->delete('magic');

my $close = $cgi->param('close');
$batch->close if $close;

my $html_init = '';
my $html_foot = '';
if ( !$magic ) {
  $html_init .= qq!<FORM NAME="OneTrueForm">
    <INPUT TYPE="hidden" NAME="batchnum" VALUE="$batchnum">!;
  $html_init .= include('/elements/progress-init.html',
                  'OneTrueForm',
                  [ 'batchnum' ],
                  $p.'misc/process/bill_batch-print.html',
                  {
                    'popup_url' => $cgi->self_url . ';magic=download_popup',
                  },
                  '',
  );
  $html_init .= '</FORM>
<A HREF="javascript:process()">Download this batch</A></BR>';
  if ( $batch->status eq 'O' ) {
    $cgi->param('close' => 1);
    $html_init .= '<A HREF="'.$cgi->self_url.'">Close this batch</A><BR>';
  }
  $html_init .= '<BR>';
  if ( $cgi->param('start_download') ) {
    $cgi->delete('start_download');
    $html_foot = '<SCRIPT TYPE="text/javascript">process();</SCRIPT>';
  }
}

my $link = [ "$p/view/cust_bill.cgi?", 'invnum' ];
my $clink = [ "$p/view/cust_main.cgi?", 'custnum' ];
my $money_char = $conf->config('money_char') || '$';

</%init>
