<% include( 'elements/browse.html',
                 'title'       => 'Rate plans',
                 'menubar'     => [ 'Main menu' => $p, ],
                 'html_init'   => $html_init,
                 'name'        => 'rate plans',
                 'query'       => { 'table'     => 'rate',
                                    'hashref'   => {},
                                    'extra_sql' => 'ORDER BY ratenum',
                                  },
                 'count_query' => $count_query,
                 'header'      => [ '#', 'Rate plan', ],
                 'fields'      => [ 'ratenum', 'ratename' ],
                 'links'       => [ $link, $link ],
             )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $html_init = 
'Rate plans, regions and prefixes for VoIP and call billing.<BR><BR>'.
qq!<A HREF="${p}edit/rate.cgi"><I>Add a rate plan</I></A>!.
qq! | <A HREF="${p}edit/rate_region.cgi"><I>Add a region</I></A>!.
'<BR><BR>
 <SCRIPT>
 function rate_areyousure(href) {
  if (confirm("Are you sure you want to delete this rate plan?") == true)
    window.location.href = href;
 }
 </SCRIPT>';

my $count_query = 'SELECT COUNT(*) FROM rate';

my $link = [ $p.'edit/rate.cgi?', 'ratenum' ];

</%init>
