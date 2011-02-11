<% include( 'elements/browse.html',
              'title'       => 'Rate plans',
              'menubar'     => [ 'Regions and Prefixes' =>
                                   $p.'browse/rate_region.html',
                                 'Time Periods' =>
                                   $p.'browse/rate_time.html',
                                 'CDR Types' =>
                                   $p.'edit/cdr_type.cgi',
                               ],
              'html_init'   => $html_init,
              'name'        => 'rate plans',
              'query'       => { 'table'     => 'rate',
                                 'hashref'   => {},
                                 'order_by' => 'ORDER BY ratenum',
                               },
              'count_query' => $count_query,
              'header'      => [ '#',       'Rate plan', 'Rates'    ],
              'fields'      => [ 'ratenum', 'ratename',  $rates_sub ],
              'links'       => [ $link,     $link,       ''         ],
              'really_disable_download' => 1
          )
%>
<%once>

my $all_countrycodes = join("\n", map qq(<OPTION VALUE="$_">$_),
                                      FS::rate_prefix->all_countrycodes
                           );

my $rates_sub = sub {
  my $rate = shift;
  my $ratenum = $rate->ratenum;

  qq( <FORM METHOD="GET" ACTION="${p}edit/rate.cgi">
        <INPUT TYPE="hidden" NAME="ratenum" VALUE="$ratenum">
        <SELECT NAME="countrycode" onChange="this.form.submit();">
          <OPTION SELECTED>Select Country Code
          <OPTION VALUE="">(all)
          $all_countrycodes
        </SELECT>
      </FORM>
    );


};

my $html_init = 
  'Rate plans for VoIP and call billing.<BR><BR>'.
  qq!<A HREF="${p}edit/rate.cgi"><I>Add a rate plan</I></A>!.
  qq! | <A HREF="${p}misc/copy-rate_detail.html"><I>Copy rates between plans</I></A>!.
  '<BR><BR>
   <SCRIPT>
   function rate_areyousure(href) {
    if (confirm("Are you sure you want to delete this rate plan?") == true)
      window.location.href = href;
   }
   </SCRIPT>
  ';

my $count_query = 'SELECT COUNT(*) FROM rate';

my $link = [ $p.'edit/rate.cgi?ratenum=', 'ratenum' ];

</%once>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

</%init>
