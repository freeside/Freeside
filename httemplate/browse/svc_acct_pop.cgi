<% include( 'elements/browse.html',
                'title'         => 'Access Numbers',
                'html_init'     => $html_init,
                'name_singular' => 'access number',
                'query'         => $query,
                'count_query'   => $count_query,
                'header'        => [
                                     '#',
                                     'City',
                                     'State',
                                     'Area code',
                                     'Exchange',
                                     'Local',
                                     'Accounts',
                                   ],
                  'fields'      => [
                                     'popnum',
                                     'city',
                                     'state',
                                     'ac',
                                     'exch',
                                     'loc',
                                     $num_accounts_sub,
                                   ],
                  'align'       => 'rllrrrr',
                  'links'       => [ map { $svc_acct_pop_link } (1..6) ],
          )
%>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;

die "access denied"
  unless $curuser->access_right('Dialup configuration')
      || $curuser->access_right('Dialup global configuration');

my $html_init = qq!
  <A HREF="${p}edit/svc_acct_pop.cgi"><I>Add new Access Number</I></A>
  <BR><BR>
!;

my $query = { 'select'    => '*,
                              ( SELECT COUNT(*) FROM svc_acct
                                  WHERE svc_acct.popnum = svc_acct_pop.popnum
                              ) AS num_accounts
                             ',
              'table'     => 'svc_acct_pop',
              #'hashref'   => { 'disabled' => '' },
              'order_by' => 'ORDER BY state, city, ac, exch, loc',
            };

my $count_query = "SELECT COUNT(*) FROM svc_acct_pop"; # WHERE DISABLED IS NULL OR DISABLED = ''";

my $svc_acct_pop_link = [ $p.'edit/svc_acct_pop.cgi?', 'popnum' ];

my $svc_acct_link = $p. 'search/svc_acct.cgi?popnum=';

my $num_accounts_sub = sub {
  my $svc_acct_pop = shift;
  [
    [
      { 'data'  => '<B><FONT COLOR="#00CC00">'.
                   $svc_acct_pop->get('num_accounts').
                   '</FONT></B>',
        'align' => 'right',
      },
      { 'data'  => 'active',
        'align' => 'left',
        'link'  => ( $svc_acct_pop->get('num_accounts')
                       ? $svc_acct_link. $svc_acct_pop->popnum
                       : ''
                   ),
      },
    ],
  ];
};

</%init>
