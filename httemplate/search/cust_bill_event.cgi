<% include( 'elements/search.html',
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
                'align' => 'lrlr'.FS::UI::Web::cust_aligns(),
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
                              ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                    FS::UI::Web::cust_header()
                              ),
                            ],
                 'color' => [ 
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_colors(),
                            ],
                 'style' => [ 
                              '',
                              '',
                              '',
                              '',
                              FS::UI::Web::cust_styles(),
                            ],
             )
%>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Billing event reports')
      or $curuser->access_right('View customer billing events')
         && $cgi->param('invnum') =~ /^(\d+)$/;

my $title = $cgi->param('failed')
              ? 'Failed invoice events'
              : 'Invoice events';

my %search = ();

if ( $cgi->param('agentnum') && $cgi->param('agentnum') =~ /^(\d+)$/ ) {
  $search{agentnum} = $1;
}

($search{beginning}, $search{ending})
  = FS::UI::Web::parse_beginning_ending($cgi);

if ( $cgi->param('failed') ) {
  $search{failed} = '1';
}

if ( $cgi->param('part_bill_event.payby') =~ /^(\w+)$/ ) {
  $search{payby} = $1;
}

if ( $cgi->param('invnum') =~ /^(\d+)$/ ) {
  $search{invnum} = $1;
}

my $where = 'WHERE '. FS::cust_bill_event->search_sql_where( \%search );

my $join = 'LEFT JOIN part_bill_event USING ( eventpart ) '.
           'LEFT JOIN cust_bill       USING ( invnum    ) '.
           'LEFT JOIN cust_main       USING ( custnum   ) ';

my $sql_query = {
  'table'     => 'cust_bill_event',
  'select'    => join(', ',
                    'cust_bill_event.*',
                    'part_bill_event.event',
                    'cust_bill.custnum',
                    'cust_bill._date AS cust_bill_date',
                    'cust_main.custnum AS cust_main_custnum',
                    FS::UI::Web::cust_sql_fields(),
                  ),
  'hashref'   => {}, 
  'extra_sql' => "$where ORDER BY _date ASC",
  'addl_from' => $join,
};

my $count_sql = "SELECT COUNT(*) FROM cust_bill_event $join $where";

my $conf = new FS::Conf;

my $html_init = '
    <FONT SIZE="+1">Invoice events are the deprecated, old-style actions taken o
n open invoices.  See Reports-&gt;Billing events-&gt;Billing events for current event reports.</FONT><BR><BR>';

$html_init .= join("\n", map {
  ( my $action = $_ ) =~ s/_$//;
  include('/elements/progress-init.html',
            $_.'form',
            [ keys(%search) ],
            "../misc/${_}invoice_events.cgi",
            { 'message' => "Invoices re-${action}ed" }, #would be nice to show the number of them, but...
            $_, #key
         ),
  qq!<FORM NAME="${_}form">!,
  qq!<INPUT TYPE="hidden" NAME="action" VALUE="$_">!, #not used though
  (map {qq!<INPUT TYPE="hidden" NAME="$_" VALUE="$search{$_}">!} keys(%search)),
  qq!</FORM>!
} qw( print_ email_ fax_ ) );

my $menubar = [];

if ( $curuser->access_right('Resend invoices') ) {

  push @$menubar, 'Re-print these events' =>
                    "javascript:print_process()",
                  'Re-email these events' =>
                    "javascript:email_process()",
                ;

  push @$menubar, 'Re-fax these events' =>
                    "javascript:fax_process()"
    if $conf->exists('hylafax');

}

my $link_cust = sub {
  my $cust_bill_event = shift;
  $cust_bill_event->cust_main_custnum
    ? [ "${p}view/cust_main.cgi?", 'custnum' ]
    : '';
};

</%init>
