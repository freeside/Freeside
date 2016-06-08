<& elements/svc_Common.html,
                 'title'             => "Phone number search results",
                 'name'              => 'phone numbers',
                 'query'             => $sql_query,
                 'count_query'       => $count_query,
                 'redirect'          => $redirect,
                 'header'            => [ '#',
                                          'Service',
                                          'Country code',
                                          'Phone number',
                                          @header,
                                          emt('Pkg. Status'),
                                          FS::UI::Web::cust_header($cgi->param('cust_fields')),
                                        ],
                 'fields'            => [ 'svcnum',
                                          'svc',
                                          'countrycode',
                                          'phonenum',
                                          @fields,
                                          sub {
                                            $cust_pkg_cache{$_[0]->svcnum} ||= $_[0]->cust_svc->cust_pkg;
                                            return '' unless $cust_pkg_cache{$_[0]->svcnum};
                                            $cust_pkg_cache{$_[0]->svcnum}->ucfirst_status
                                          },
                                          \&FS::UI::Web::cust_fields,
                                        ],
                 'links'             => [ $link,
                                          $link,
                                          $link,
                                          $link,
                                          ( map '', @header ),
                                          '', # pkg status
                                          ( map { $_ ne 'Cust. Status' ? $link_cust : '' }
                                                FS::UI::Web::cust_header($cgi->param('cust_fields'))
                                          ),
                                        ],
                 'align' => 'rlrr'.
                            join('', map 'r', @header).
                            'r'.
                            FS::UI::Web::cust_aligns(),
                 'color' => [ 
                              '',
                              '',
                              '',
                              '',
                              ( map '', @header ),
                              sub {
                                $cust_pkg_cache{$_[0]->svcnum} ||= $_[0]->cust_svc->cust_pkg;
                                return '' unless $cust_pkg_cache{$_[0]->svcnum};
                                my $c = FS::cust_pkg::statuscolors;
                                $c->{$cust_pkg_cache{$_[0]->svcnum}->status };
                              }, # pkg status
                              FS::UI::Web::cust_colors(),
                            ],
                 'style' => [ 
                              '',
                              '',
                              '',
                              '',
                              ( map '', @header ),
                              'b',
                              FS::UI::Web::cust_styles(),
                            ],
              
&>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('List services');

my %cust_pkg_cache;

my $conf = new FS::Conf;

my @select = ();
my $orderby = 'ORDER BY svcnum';

my @header = ();
my @fields = ();
my $link = [ "${p}view/svc_phone.cgi?", 'svcnum' ];
my $redirect = $link;

my %search_hash = ();
my @extra_sql = ();

if ( $cgi->param('magic') =~ /^(all|unlinked)$/ ) {

  $search_hash{'unlinked'} = 1
    if $cgi->param('magic') eq 'unlinked';

  if ( $cgi->param('sortby') =~ /^(\w+)$/ ) {
    my $sortby = $1;
    $orderby = "ORDER BY $sortby";
  }

  if ( $cgi->param('usage_total') ) {

    my($beginning,$ending) = FS::UI::Web::parse_beginning_ending($cgi, 'usage');

    $redirect = '';

    #my $and_date = " AND startdate >= $beginning AND startdate <= $ending ";
    my $and_date = " AND enddate >= $beginning AND enddate <= $ending ";

    my $fromwhere = " FROM cdr WHERE cdr.svcnum = svc_phone.svcnum $and_date";

    #more efficient to join against cdr just once... this will do for now
    push @select, map { " ( SELECT SUM($_) $fromwhere ) AS $_ " }
                      qw( billsec rated_price );

    my $money_char = $conf->config('money_char') || '$';

    push @header, 'Minutes', 'Billed';
    push @fields, 
      sub { sprintf('%.3f', shift->get('billsec') / 60 ); },
      sub { $money_char. sprintf('%.2f', shift->get('rated_price') ); };

    #XXX and termination... (this needs a config to turn on, not by default)
    if ( 1 ) { # $conf->exists('cdr-termination_hack') { #}

      my $f_w =
        " FROM cdr_termination LEFT JOIN cdr USING ( acctid ) ".
        " WHERE cdr.carrierid = CAST(svc_phone.phonenum AS BIGINT) ". # XXX connectone-specific, has to match svc_external.id :/
        $and_date;

      push @select,
        " ( SELECT SUM(billsec) $f_w ) AS term_billsec ",
        " ( SELECT SUM(cdr_termination.rated_price) $f_w ) AS term_rated_price";

      push @header, 'Term Min', 'Term Billed';
      push @fields,
        sub { sprintf('%.3f', shift->get('term_billsec') / 60 ); },
        sub { $money_char. sprintf('%.2f', shift->get('rated_price') ); };

    }
                 

  }

} elsif ( $cgi->param('magic') =~ /^advanced$/ ) {

  for (qw( agentnum custnum cust_status balance balance_days cust_fields )) {
    $search_hash{$_} = $cgi->param($_) if length($cgi->param($_));
  }

  for (qw( payby pkgpart svcpart )) {
    $search_hash{$_} = [ $cgi->param($_) ] if $cgi->param($_);
  }

} elsif ( $cgi->param('svcpart') =~ /^(\d+)$/ ) {
  $search_hash{'svcpart'} = [ $1 ];
  if ( defined($cgi->param('cancelled')) ) {
    $search_hash{'cancelled'} = $cgi->param('cancelled') ? 1 : 0;
  }
} else {
  $cgi->param('phonenum') =~ /^([\d\- ]+)$/; 
  my $phonenum = $1;
  $phonenum =~ s/\D//g;
  push @extra_sql, "phonenum = '$phonenum'";
}

$search_hash{'addl_select'} = \@select;
$search_hash{'order_by'} = $orderby;
$search_hash{'where'} = \@extra_sql;

my $sql_query = FS::svc_phone->search(\%search_hash);
my $count_query = delete($sql_query->{'count_query'});

#smaller false laziness w/svc_*.cgi here
my $link_cust = sub {
  my $svc_x = shift;
  $svc_x->custnum ? [ "${p}view/cust_main.cgi?", 'custnum' ] : '';
};

</%init>
