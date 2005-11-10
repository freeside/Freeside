<%

my $title = $cgi->param('failed') ? 'Failed invoice events' : 'Invoice events';

my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);

##tie my %hash, 'Tie::DxHash', 
#my %hash = (
#      _date => { op=> '>=', value=>$beginning },
## i wish...
##      _date => { op=> '<=', value=>$ending },
#);
#$hash{'statustext'} = { op=> '!=', value=>'' }
#  if $cgi->param('failed');

my $where = " WHERE cust_bill_event._date >= $beginning".
            "   AND cust_bill_event._date <= $ending";

if ( $cgi->param('failed') ) {
  $where .= " AND statustext != '' ".
            " AND statustext IS NOT NULL ".
            " AND statustext != 'N/A' "
}

if ( $cgi->param('part_bill_event.payby') =~ /^(\w+)$/ ) {
  $where .= " AND part_bill_event.payby = '$1' ";
}

my $sql_query = {
  'table'     => 'cust_bill_event',
  #'hashref'   => \%hash,
  'hashref'   => {}, 
  'select'    => join(', ',
                   'cust_bill_event.*',
                   'part_bill_event.event',
                   'cust_bill.custnum',
                   'cust_bill._date AS cust_bill_date',
                   'cust_main.custnum AS cust_main_custnum',
                   FS::UI::Web::cust_sql_fields(),
                 ),
  'extra_sql' => "$where ORDER BY _date ASC",
  'addl_from' => 'LEFT JOIN part_bill_event USING ( eventpart ) '.
                 'LEFT JOIN cust_bill       USING ( invnum    ) '.
                 'LEFT JOIN cust_main       USING ( custnum   ) ',
};

my $count_sql = "SELECT COUNT(*) FROM cust_bill_event ".
                "LEFT JOIN part_bill_event USING ( eventpart ) ".
                $where;

my $conf = new FS::Conf;

my $failed = $cgi->param('failed');

my $html_init = join("\n", map {
  ( my $action = $_ ) =~ s/_$//;
  include('/elements/progress-init.html',
            $_.'form',
            [ 'action', 'beginning', 'ending', 'failed' ],
            "../misc/${_}invoice_events.cgi",
            { 'message' => "Invoices re-${action}ed" }, #would be nice to show the number of them, but...
            $_, #key
         ),
  qq!<FORM NAME="${_}form">!,
  qq!<INPUT TYPE="hidden" NAME="action" VALUE="$_">!, #not used though
  qq!<INPUT TYPE="hidden" NAME="beginning" VALUE="$beginning">!,
  qq!<INPUT TYPE="hidden" NAME="ending"    VALUE="$ending">!,
  qq!<INPUT TYPE="hidden" NAME="failed"    VALUE="$failed">!,
  qq!</FORM>!
} qw( print_ email_ fax_ ) );

my $menubar =  [
                 'Main menu' => $p,
                 'Re-print these events' =>
                   "javascript:print_process()",
                 'Re-email these events' =>
                   "javascript:email_process()",
               ];

push @$menubar, 'Re-fax these events' =>
                  "javascript:fax_process()"
  if $conf->exists('hylafax');

my $link_cust = sub {
  my $cust_bill_event = shift;
  $cust_bill_event->cust_main_custnum
    ? [ "${p}view/cust_main.cgi?", 'custnum' ]
    : '';
};

%><%= include( 'elements/search.html',
                 'title'       => $title,
                 'html_init'   => $html_init,
                 'menubar'     => $menubar,
                 'name'        => 'billing events',
                 'query'       => $sql_query,
                 'count_query' => $count_sql,
                 'header'      => [ 'Event',
                                    'Date',
                                    'Status',
                                    #'Inv #', 'Inv Date', 'Cust #',
                                    'Invoice',
                                    FS::UI::Web::cust_header(),
                                  ],
                 'fields' => [
                               'event',
                               sub { time2str("%b %d %Y %T", $_[0]->_date) },
                               sub { 
                                     #my $cust_bill_event = shift;
                                     my $status = $_[0]->status;
                                     $status .= ': '.$_[0]->statustext
                                       if $_[0]->statustext;
                                     $status;
                                   },
                               sub {
                                     #my $cust_bill_event = shift;
                                     'Invoice #'. $_[0]->invnum.
                                     ' ('.
                                       time2str("%D", $_[0]->cust_bill_date).
                                     ')';
                                   },
                               \&FS::UI::Web::cust_fields,
                             ],
                 'links' => [
                              '',
                              '',
                              '',
                              sub {
                                my $part_bill_event = shift;
                                my $template = $part_bill_event->templatename;
                                $template .= '-' if $template;
                                [ "${p}view/cust_bill.cgi?$template", 'invnum'];
                              },
                              ( map { $link_cust } FS::UI::Web::cust_header() ),
                            ],
             )
%>
