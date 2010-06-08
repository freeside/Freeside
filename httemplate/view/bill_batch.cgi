% if($magic eq 'print') {
<% include('/elements/header.html', "Download Batch") %>
<FORM NAME="OneTrueForm">
<INPUT TYPE="hidden" NAME="batchnum" VALUE="<% $batchnum %>">
% $cgi->delete('magic');
<% include('/elements/progress-init.html',
              'OneTrueForm',
              [ 'batchnum' ],
              $p.'misc/process/bill_batch-print.html',
              {'url' => $cgi->self_url . ';magic=download'},
              '',
) %></FORM>
<SCRIPT TYPE="text/javascript">process();</SCRIPT>
<% include('/elements/footer.html') %>
% }
% 
% elsif($magic eq 'download') {
%   $m->clear_buffer;
%   $r->content_type('application/pdf');
%   $r->headers_out->add('Content-Disposition' => 'attachment;filename="invoice_batch_'.$batchnum.'.pdf"');
<% $batch->pdf %>
%   $batch->pdf('');
%   my $error = $batch->replace;
%   warn "error deleting cached PDF: '$error'\n" if $error;
% }
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
                               'extra_sql' => '',
                                 " WHERE batchnum = $batchnum",
                             },
              'count_query' => "SELECT COUNT(*) FROM cust_bill_batch WHERE batchnum = $batchnum",
              'html_init' => $html_init,
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

use Data::Dumper;
warn Dumper($cgi->Vars);

my $conf = new FS::Conf;
my $batch;
my $batchnum = $cgi->param('batchnum');

$batch = FS::bill_batch->by_key($batchnum);
die "Batch '$batchnum' not found!\n" if !$batch;

my $magic = $cgi->param('magic');
my $html_init = '';

my $close = $cgi->param('close');
$batch->close if $close;

if(!$magic) {
  $cgi->param('magic' => 'print');
  $cgi->delete('close');
  $html_init  = '<A HREF="'.$cgi->self_url.'">Download this batch</A><BR>';
  if($batch->status eq 'O') {
    $cgi->param('close' => 1);
    $cgi->delete('magic');
    $html_init .= '<A HREF="'.$cgi->self_url.'">Close this batch</A><BR>';
  }
  $html_init .= '<BR>';
}

my $link = [ "$p/view/cust_bill.cgi?", 'invnum' ];
my $clink = [ "$p/view/cust_main.cgi?", 'custnum' ];
my $money_char = $conf->config('money_char') || '$';

</%init>
