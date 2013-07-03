<% $content %>\
<%init>

#false laziness w/elements/cust_bill-typeset

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Generate quotation'); #View quotations ?

my $quotationnum = $cgi->param('quotationnum');

my $conf = new FS::Conf;

my $quotation = qsearchs({
  'select'    => 'quotation.*',
  'table'     => 'quotation',
  #'addl_from' => 'LEFT JOIN cust_main USING ( custnum )',
  'hashref'   => { 'quotationnum' => $quotationnum },
  #'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
});
die "Quotation #$quotationnum not found!" unless $quotation;

my $content = $quotation->print_pdf(); #\%opt);

http_header('Content-Type' => 'application/pdf');
http_header('Content-Disposition' => "filename=$quotationnum.pdf" );
http_header('Content-Length' => length($content) );
http_header('Cache-control' => 'max-age=60' );

</%init>
