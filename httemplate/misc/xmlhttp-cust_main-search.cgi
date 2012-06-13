% if ( $sub eq 'custnum_search' ) { 
%   my $custnum = $cgi->param('arg');
%   my $return = [];
%   if ( $custnum =~ /^(\d+)$/ ) { #should also handle
%                                  # cust_main-agent_custid-format') eq 'ww?d+'
%	$return = findbycustnum_or_agent_custid($1);
%   }
<% objToJson($return) %>
% } elsif ( $sub eq 'smart_search' ) {
%
%   my $string = $cgi->param('arg');
%   my @cust_main = smart_search( 'search' => $string,
%                                 'no_fuzzy_on_exact' => 1, #pref?
%                               );
%   my $return = [ map [ $_->custnum,
%                        $_->name,
%                        $_->balance,
%                        $_->ucfirst_status,
%                        $_->statuscolor,
%                        scalar($_->open_cust_bill)
%                      ],
%                    @cust_main
%                ];
%     
<% objToJson($return) %>
% } elsif ( $sub eq 'invnum_search' ) {
%
%   my $string = $cgi->param('arg');
%   if ( $string =~ /^(\d+)$/ ) {
%     my $inv = qsearchs('cust_bill', { 'invnum' => $1 });
%     my $return = $inv ? findbycustnum($inv->custnum) : [];
<% objToJson($return) %>
%   } else { #return nothing
[]
%   }
% } 
% elsif ( $sub eq 'exact_search' ) {
%   # XXX possibly should query each element separately
%   my $hashref = decode_json($cgi->param('arg'));
%   my @cust_main = qsearch('cust_main', $hashref);
%   my $return = [];
%   foreach (@cust_main) {
%     push @$return, {
%       custnum => $_->custnum,
%       name => $_->name_short,
%       address1 => $_->address1,
%       city => $_->city,
%     };
%   }
<% objToJson($return) %>
% }
<%init>

my $sub = $cgi->param('sub');

sub findbycustnum {

  my $c = qsearchs({
    'table'     => 'cust_main',
    'hashref'   => { 'custnum' => shift },
    'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
  }) or return [];

  [ $c->custnum,
    $c->name,
    $c->balance,
    $c->ucfirst_status,
    $c->statuscolor,
    scalar($c->open_cust_bill)
  ];
}

sub findbycustnum_or_agent_custid {
  my $num = shift;

  my @or = ( 'agent_custid = ?' );
  my @param = ( $num );

  if ( $num =~ /^\d+$/ && $num <= 2147483647 ) { #need a bigint custnum? wow
    my $conf = new FS::Conf;
    if ( $conf->exists('cust_main-default_agent_custid') ) {
      push @or, "( agent_custid IS NULL AND custnum = $num )";
    } else {
      push @or, "custnum = $num";
    }
  }

  my $extra_sql = ' WHERE '. $FS::CurrentUser::CurrentUser->agentnums_sql.
                  ' AND ( '. join(' OR ', @or). ' )';
                      
  [ map [ $_->custnum,
          $_->name,
          $_->balance,
          $_->ucfirst_status,
          $_->statuscolor,
          scalar($_->open_cust_bill),
        ],

      qsearch({
        'table'       => 'cust_main',
        'hashref'     => {},
        'extra_sql'   => $extra_sql,
        'extra_param' => \@param,
      })
  ];
}

</%init>
