package FS::cust_main::Search;

use strict;
use base qw( Exporter );
use vars qw( @EXPORT_OK $DEBUG $me $conf @fuzzyfields );
use String::Approx qw(amatch);
use FS::UID qw( dbh );
use FS::Record qw( qsearch );
use FS::cust_main;
use FS::cust_main_invoice;
use FS::svc_acct;

@EXPORT_OK = qw( smart_search );

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;
$me = '[FS::cust_main::Search]';

@fuzzyfields = ( 'first', 'last', 'company', 'address1' );

install_callback FS::UID sub { 
  $conf = new FS::Conf;
  #yes, need it for stuff below (prolly should be cached)
};

=head1 NAME

FS::cust_main::Search - Customer searching

=head1 SYNOPSIS

  use FS::cust_main::Search;

  FS::cust_main::Search::smart_search(%options);

  FS::cust_main::Search::email_search(%options);

  FS::cust_main::Search->search( \%options );
  
  FS::cust_main::Search->fuzzy_search( \%fuzzy_hashref );

=head1 SUBROUTINES

=over 4

=item smart_search OPTION => VALUE ...

Accepts the following options: I<search>, the string to search for.  The string
will be searched for as a customer number, phone number, name or company name,
as an exact, or, in some cases, a substring or fuzzy match (see the source code
for the exact heuristics used); I<no_fuzzy_on_exact>, causes smart_search to
skip fuzzy matching when an exact match is found.

Any additional options are treated as an additional qualifier on the search
(i.e. I<agentnum>).

Returns a (possibly empty) array of FS::cust_main objects.

=cut

sub smart_search {
  my %options = @_;

  #here is the agent virtualization
  my $agentnums_sql = 
    $FS::CurrentUser::CurrentUser->agentnums_sql(table => 'cust_main');

  my @cust_main = ();

  my $skip_fuzzy = delete $options{'no_fuzzy_on_exact'};
  my $search = delete $options{'search'};
  ( my $alphanum_search = $search ) =~ s/\W//g;
  
  if ( $alphanum_search =~ /^1?(\d{3})(\d{3})(\d{4})(\d*)$/ ) { #phone# search

    #false laziness w/Record::ut_phone
    my $phonen = "$1-$2-$3";
    $phonen .= " x$4" if $4;

    push @cust_main, qsearch( {
      'table'   => 'cust_main',
      'hashref' => { %options },
      'extra_sql' => ( scalar(keys %options) ? ' AND ' : ' WHERE ' ).
                     ' ( '.
                         join(' OR ', map "$_ = '$phonen'",
                                          qw( daytime night fax
                                              ship_daytime ship_night ship_fax )
                             ).
                     ' ) '.
                     " AND $agentnums_sql", #agent virtualization
    } );

    unless ( @cust_main || $phonen =~ /x\d+$/ ) { #no exact match
      #try looking for matches with extensions unless one was specified

      push @cust_main, qsearch( {
        'table'   => 'cust_main',
        'hashref' => { %options },
        'extra_sql' => ( scalar(keys %options) ? ' AND ' : ' WHERE ' ).
                       ' ( '.
                           join(' OR ', map "$_ LIKE '$phonen\%'",
                                            qw( daytime night
                                                ship_daytime ship_night )
                               ).
                       ' ) '.
                       " AND $agentnums_sql", #agent virtualization
      } );

    }

  # custnum search (also try agent_custid), with some tweaking options if your
  # legacy cust "numbers" have letters
  } 
  
  
  if ( $search =~ /@/ ) {
      push @cust_main,
	  map $_->cust_main,
	      qsearch( {
			 'table'     => 'cust_main_invoice',
			 'hashref'   => { 'dest' => $search },
		       }
		     );
  } elsif ( $search =~ /^\s*(\d+)\s*$/
         || ( $conf->config('cust_main-agent_custid-format') eq 'ww?d+'
              && $search =~ /^\s*(\w\w?\d+)\s*$/
            )
         || ( $conf->config('cust_main-custnum-display_special')
           # it's not currently possible for special prefixes to contain
           # digits, so just strip off any alphabetic prefix and match 
           # the rest to custnum
              && $search =~ /^\s*[[:alpha:]]*(\d+)\s*$/
            )
         || ( $conf->exists('address1-search' )
              && $search =~ /^\s*(\d+\-?\w*)\s*$/ #i.e. 1234A or 9432-D
            )
     )
  {

    my $num = $1;

    if ( $num =~ /^(\d+)$/ && $num <= 2147483647 ) { #need a bigint custnum? wow
      my $agent_custid_null = $conf->exists('cust_main-default_agent_custid')
                                ? ' AND agent_custid IS NULL ' : '';
      push @cust_main, qsearch( {
        'table'     => 'cust_main',
        'hashref'   => { 'custnum' => $num, %options },
        'extra_sql' => " AND $agentnums_sql $agent_custid_null",
      } );
    }

    # for all agents this user can see, if any of them have custnum prefixes 
    # that match the search string, include customers that match the rest 
    # of the custnum and belong to that agent
    foreach my $agentnum ( $FS::CurrentUser::CurrentUser->agentnums ) {
      my $p = $conf->config('cust_main-custnum-display_prefix', $agentnum);
      next if !$p;
      if ( $p eq substr($num, 0, length($p)) ) {
        push @cust_main, qsearch( {
          'table'   => 'cust_main',
          'hashref' => { 'custnum' => 0 + substr($num, length($p)),
                         'agentnum' => $agentnum,
                          %options,
                       },
        } );
      }
    }

    push @cust_main, qsearch( {
        'table'     => 'cust_main',
        'hashref'   => { 'agent_custid' => $num, %options },
        'extra_sql' => " AND $agentnums_sql", #agent virtualization
    } );

    if ( $conf->exists('address1-search') ) {
      my $len = length($num);
      $num = lc($num);
      foreach my $prefix ( '', 'ship_' ) {
        push @cust_main, qsearch( {
          'table'     => 'cust_main',
          'hashref'   => { %options, },
          'extra_sql' => 
            ( keys(%options) ? ' AND ' : ' WHERE ' ).
            " LOWER(SUBSTRING(${prefix}address1 FROM 1 FOR $len)) = '$num' ".
            " AND $agentnums_sql",
        } );
      }
    }

  } elsif ( $search =~ /^\s*(\S.*\S)\s+\((.+), ([^,]+)\)\s*$/ ) {

    my($company, $last, $first) = ( $1, $2, $3 );

    # "Company (Last, First)"
    #this is probably something a browser remembered,
    #so just do an exact search (but case-insensitive, so USPS standardization
    #doesn't throw a wrench in the works)

    foreach my $prefix ( '', 'ship_' ) {
      push @cust_main, qsearch( {
        'table'     => 'cust_main',
        'hashref'   => { %options },
        'extra_sql' => 
          ( keys(%options) ? ' AND ' : ' WHERE ' ).
          join(' AND ',
            " LOWER(${prefix}first)   = ". dbh->quote(lc($first)),
            " LOWER(${prefix}last)    = ". dbh->quote(lc($last)),
            " LOWER(${prefix}company) = ". dbh->quote(lc($company)),
            $agentnums_sql,
          ),
      } );
    }

  } elsif ( $search =~ /^\s*(\S.*\S)\s*$/ ) { # value search
                                              # try (ship_){last,company}

    my $value = lc($1);

    # # remove "(Last, First)" in "Company (Last, First)", otherwise the
    # # full strings the browser remembers won't work
    # $value =~ s/\([\w \,\.\-\']*\)$//; #false laziness w/Record::ut_name

    use Lingua::EN::NameParse;
    my $NameParse = new Lingua::EN::NameParse(
             auto_clean     => 1,
             allow_reversed => 1,
    );

    my($last, $first) = ( '', '' );
    #maybe disable this too and just rely on NameParse?
    if ( $value =~ /^(.+),\s*([^,]+)$/ ) { # Last, First
    
      ($last, $first) = ( $1, $2 );
    
    #} elsif  ( $value =~ /^(.+)\s+(.+)$/ ) {
    } elsif ( ! $NameParse->parse($value) ) {

      my %name = $NameParse->components;
      $first = $name{'given_name_1'} || $name{'initials_1'}; #wtf NameParse, Ed?
      $last  = $name{'surname_1'};

    }

    if ( $first && $last ) {

      my($q_last, $q_first) = ( dbh->quote($last), dbh->quote($first) );

      #exact
      my $sql = scalar(keys %options) ? ' AND ' : ' WHERE ';
      $sql .= "
        (     ( LOWER(last) = $q_last AND LOWER(first) = $q_first )
           OR ( LOWER(ship_last) = $q_last AND LOWER(ship_first) = $q_first )
        )";

      push @cust_main, qsearch( {
        'table'     => 'cust_main',
        'hashref'   => \%options,
        'extra_sql' => "$sql AND $agentnums_sql", #agent virtualization
      } );

      # or it just be something that was typed in... (try that in a sec)

    }

    my $q_value = dbh->quote($value);

    #exact
    my $sql = scalar(keys %options) ? ' AND ' : ' WHERE ';
    $sql .= " (    LOWER(last)          = $q_value
                OR LOWER(company)       = $q_value
                OR LOWER(ship_last)     = $q_value
                OR LOWER(ship_company)  = $q_value
            ";
    $sql .= "   OR LOWER(address1)      = $q_value
                OR LOWER(ship_address1) = $q_value
            "
      if $conf->exists('address1-search');
    $sql .= " )";

    push @cust_main, qsearch( {
      'table'     => 'cust_main',
      'hashref'   => \%options,
      'extra_sql' => "$sql AND $agentnums_sql", #agent virtualization
    } );

    #no exact match, trying substring/fuzzy
    #always do substring & fuzzy (unless they're explicity config'ed off)
    #getting complaints searches are not returning enough
    unless ( @cust_main  && $skip_fuzzy || $conf->exists('disable-fuzzy') ) {

      #still some false laziness w/search (was search/cust_main.cgi)

      #substring

      my @hashrefs = (
        { 'company'      => { op=>'ILIKE', value=>"%$value%" }, },
        { 'ship_company' => { op=>'ILIKE', value=>"%$value%" }, },
      );

      if ( $first && $last ) {

        push @hashrefs,
          { 'first'        => { op=>'ILIKE', value=>"%$first%" },
            'last'         => { op=>'ILIKE', value=>"%$last%" },
          },
          { 'ship_first'   => { op=>'ILIKE', value=>"%$first%" },
            'ship_last'    => { op=>'ILIKE', value=>"%$last%" },
          },
        ;

      } else {

        push @hashrefs,
          { 'last'         => { op=>'ILIKE', value=>"%$value%" }, },
          { 'ship_last'    => { op=>'ILIKE', value=>"%$value%" }, },
        ;
      }

      if ( $conf->exists('address1-search') ) {
        push @hashrefs,
          { 'address1'      => { op=>'ILIKE', value=>"%$value%" }, },
          { 'ship_address1' => { op=>'ILIKE', value=>"%$value%" }, },
        ;
      }

      foreach my $hashref ( @hashrefs ) {

        push @cust_main, qsearch( {
          'table'     => 'cust_main',
          'hashref'   => { %$hashref,
                           %options,
                         },
          'extra_sql' => " AND $agentnums_sql", #agent virtualizaiton
        } );

      }

      #fuzzy
      my @fuzopts = (
        \%options,                #hashref
        '',                       #select
        " AND $agentnums_sql",    #extra_sql  #agent virtualization
      );

      if ( $first && $last ) {
        push @cust_main, FS::cust_main::Search->fuzzy_search(
          { 'last'   => $last,    #fuzzy hashref
            'first'  => $first }, #
          @fuzopts
        );
      }
      foreach my $field ( 'last', 'company' ) {
        push @cust_main,
          FS::cust_main::Search->fuzzy_search( { $field => $value }, @fuzopts );
      }
      if ( $conf->exists('address1-search') ) {
        push @cust_main,
          FS::cust_main::Search->fuzzy_search( { 'address1' => $value }, @fuzopts );
      }

    }

  }

  #eliminate duplicates
  my %saw = ();
  @cust_main = grep { !$saw{$_->custnum}++ } @cust_main;

  @cust_main;

}

=item email_search

Accepts the following options: I<email>, the email address to search for.  The
email address will be searched for as an email invoice destination and as an
svc_acct account.

#Any additional options are treated as an additional qualifier on the search
#(i.e. I<agentnum>).

Returns a (possibly empty) array of FS::cust_main objects (but usually just
none or one).

=cut

sub email_search {
  my %options = @_;

  local($DEBUG) = 1;

  my $email = delete $options{'email'};

  #we're only being used by RT at the moment... no agent virtualization yet
  #my $agentnums_sql = $FS::CurrentUser::CurrentUser->agentnums_sql;

  my @cust_main = ();

  if ( $email =~ /([^@]+)\@([^@]+)/ ) {

    my ( $user, $domain ) = ( $1, $2 );

    warn "$me smart_search: searching for $user in domain $domain"
      if $DEBUG;

    push @cust_main,
      map $_->cust_main,
          qsearch( {
                     'table'     => 'cust_main_invoice',
                     'hashref'   => { 'dest' => $email },
                   }
                 );

    push @cust_main,
      map  $_->cust_main,
      grep $_,
      map  $_->cust_svc->cust_pkg,
          qsearch( {
                     'table'     => 'svc_acct',
                     'hashref'   => { 'username' => $user, },
                     'extra_sql' =>
                       'AND ( SELECT domain FROM svc_domain
                                WHERE svc_acct.domsvc = svc_domain.svcnum
                            ) = '. dbh->quote($domain),
                   }
                 );
  }

  my %saw = ();
  @cust_main = grep { !$saw{$_->custnum}++ } @cust_main;

  warn "$me smart_search: found ". scalar(@cust_main). " unique customers"
    if $DEBUG;

  @cust_main;

}

=back

=head1 CLASS METHODS

=over 4

=item search HASHREF

(Class method)

Returns a qsearch hash expression to search for parameters specified in
HASHREF.  Valid parameters are

=over 4

=item agentnum

=item status

=item address

=item refnum

=item cancelled_pkgs

bool

=item signupdate

listref of start date, end date

=item birthdate

listref of start date, end date

=item spouse_birthdate

listref of start date, end date

=item anniversary_date

listref of start date, end date

=item payby

listref

=item paydate_year

=item paydate_month

=item current_balance

listref (list returned by FS::UI::Web::parse_lt_gt($cgi, 'current_balance'))

=item cust_fields

=item flattened_pkgs

bool

=back

=cut

sub search {
  my ($class, $params) = @_;

  my $dbh = dbh;

  my @where = ();
  my $orderby;

  # initialize these to prevent warnings
  $params = {
    'custnum'       => '',
    'agentnum'      => '',
    'usernum'       => '',
    'status'        => '',
    'address'       => '',
    'paydate_year'  => '',
    'invoice_terms' => '',
    'custbatch'     => '',
    %$params
  };

  ##
  # explicit custnum(s)
  ##

  if ( $params->{'custnum'} ) {
    my @custnums = ref($params->{'custnum'}) ? 
                      @{ $params->{'custnum'} } : 
                      $params->{'custnum'};
    push @where, 
      'cust_main.custnum IN (' . 
      join(',', map { $_ =~ /^(\d+)$/ ? $1 : () } @custnums ) .
      ')' if scalar(@custnums) > 0;
  }

  ##
  # parse agent
  ##

  if ( $params->{'agentnum'} =~ /^(\d+)$/ and $1 ) {
    push @where,
      "cust_main.agentnum = $1";
  }

  ##
  # do the same for user
  ##

  if ( $params->{'usernum'} =~ /^(\d+)$/ and $1 ) {
    push @where,
      "cust_main.usernum = $1";
  }

  ##
  # parse status
  ##

  #prospect ordered active inactive suspended cancelled
  if ( grep { $params->{'status'} eq $_ } FS::cust_main->statuses() ) {
    my $method = $params->{'status'}. '_sql';
    #push @where, $class->$method();
    push @where, FS::cust_main->$method();
  }

  ##
  # address
  ##
  if ( $params->{'address'} =~ /\S/ ) {
    my $address = dbh->quote('%'. lc($params->{'address'}). '%');
    push @where, '('. join(' OR ',
                             map "LOWER($_) LIKE $address",
                               qw(address1 address2 ship_address1 ship_address2)
                          ).
                 ')';
  }

  ###
  # refnum
  ###
  if ( $params->{'refnum'}  ) {

    my @refnum = ref( $params->{'refnum'} )
                   ? @{ $params->{'refnum'} }
                   :  ( $params->{'refnum'} );

    @refnum = grep /^(\d*)$/, @refnum;

    push @where, '( '. join(' OR ', map "cust_main.refnum = $_", @refnum ). ' )'
      if @refnum;

  }

  ##
  # parse cancelled package checkbox
  ##

  my $pkgwhere = "";

  $pkgwhere .= "AND (cancel = 0 or cancel is null)"
    unless $params->{'cancelled_pkgs'};

  ##
  # parse without census tract checkbox
  ##

  push @where, "(censustract = '' or censustract is null)"
    if $params->{'no_censustract'};

  ##
  # parse with hardcoded tax location checkbox
  ##

  push @where, "geocode is not null"
    if $params->{'with_geocode'};

  ##
  # dates
  ##

  foreach my $field (qw( signupdate birthdate spouse_birthdate anniversary_date )) {

    next unless exists($params->{$field});

    my($beginning, $ending, $hour) = @{$params->{$field}};

    push @where,
      "cust_main.$field IS NOT NULL",
      "cust_main.$field >= $beginning",
      "cust_main.$field <= $ending";

    if($field eq 'signupdate' && defined $hour) {
      if ($dbh->{Driver}->{Name} =~ /Pg/i) {
        push @where, "extract(hour from to_timestamp(cust_main.$field)) = $hour";
      }
      elsif( $dbh->{Driver}->{Name} =~ /mysql/i) {
        push @where, "hour(from_unixtime(cust_main.$field)) = $hour"
      }
      else {
        warn "search by time of day not supported on ".$dbh->{Driver}->{Name}." databases";
      }
    }

    $orderby ||= "ORDER BY cust_main.$field";

  }

  ###
  # classnum
  ###

  if ( $params->{'classnum'} ) {

    my @classnum = ref( $params->{'classnum'} )
                     ? @{ $params->{'classnum'} }
                     :  ( $params->{'classnum'} );

    @classnum = grep /^(\d*)$/, @classnum;

    if ( @classnum ) {
      push @where, '( '. join(' OR ', map {
                                            $_ ? "cust_main.classnum = $_"
                                               : "cust_main.classnum IS NULL"
                                          }
                                          @classnum
                             ).
                   ' )';
    }

  }

  ###
  # payby
  ###

  if ( $params->{'payby'} ) {

    my @payby = ref( $params->{'payby'} )
                  ? @{ $params->{'payby'} }
                  :  ( $params->{'payby'} );

    @payby = grep /^([A-Z]{4})$/, @payby;

    push @where, '( '. join(' OR ', map "cust_main.payby = '$_'", @payby). ' )'
      if @payby;

  }

  ###
  # paydate_year / paydate_month
  ###

  if ( $params->{'paydate_year'} =~ /^(\d{4})$/ ) {
    my $year = $1;
    $params->{'paydate_month'} =~ /^(\d\d?)$/
      or die "paydate_year without paydate_month?";
    my $month = $1;

    push @where,
      'paydate IS NOT NULL',
      "paydate != ''",
      "CAST(paydate AS timestamp) < CAST('$year-$month-01' AS timestamp )"
;
  }

  ###
  # invoice terms
  ###

  if ( $params->{'invoice_terms'} =~ /^([\w ]+)$/ ) {
    my $terms = $1;
    if ( $1 eq 'NULL' ) {
      push @where,
        "( cust_main.invoice_terms IS NULL OR cust_main.invoice_terms = '' )";
    } else {
      push @where,
        "cust_main.invoice_terms IS NOT NULL",
        "cust_main.invoice_terms = '$1'";
    }
  }

  ##
  # amounts
  ##

  if ( $params->{'current_balance'} ) {

    #my $balance_sql = $class->balance_sql();
    my $balance_sql = FS::cust_main->balance_sql();

    my @current_balance =
      ref( $params->{'current_balance'} )
      ? @{ $params->{'current_balance'} }
      :  ( $params->{'current_balance'} );

    push @where, map { s/current_balance/$balance_sql/; $_ }
                     @current_balance;

  }

  ##
  # custbatch
  ##

  if ( $params->{'custbatch'} =~ /^([\w\/\-\:\.]+)$/ and $1 ) {
    push @where,
      "cust_main.custbatch = '$1'";
  }
  
  if ( $params->{'tagnum'} ) {
    my @tagnums = ref( $params->{'tagnum'} ) ? @{ $params->{'tagnum'} } : ( $params->{'tagnum'} );

    @tagnums = grep /^(\d+)$/, @tagnums;

    if ( @tagnums ) {
	my $tags_where = "0 < (select count(1) from cust_tag where " 
		. " cust_tag.custnum = cust_main.custnum and tagnum in ("
		. join(',', @tagnums) . "))";

	push @where, $tags_where;
    }
  }


  ##
  # setup queries, subs, etc. for the search
  ##

  $orderby ||= 'ORDER BY custnum';

  # here is the agent virtualization
  push @where,
    $FS::CurrentUser::CurrentUser->agentnums_sql(table => 'cust_main');

  my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

  my $addl_from = '';

  my $count_query = "SELECT COUNT(*) FROM cust_main $extra_sql";

  my @select = (
                 'cust_main.custnum',
                 FS::UI::Web::cust_sql_fields($params->{'cust_fields'}),
               );

  my(@extra_headers) = ();
  my(@extra_fields)  = ();

  if ($params->{'flattened_pkgs'}) {

    #my $pkg_join = '';
    $addl_from .= ' LEFT JOIN cust_pkg USING ( custnum ) ';

    if ($dbh->{Driver}->{Name} eq 'Pg') {

      push @select, "array_to_string(array(select pkg from cust_pkg left join part_pkg using ( pkgpart ) where cust_main.custnum = cust_pkg.custnum $pkgwhere),'|') as magic";

    } elsif ($dbh->{Driver}->{Name} =~ /^mysql/i) {
      push @select, "GROUP_CONCAT(part_pkg.pkg SEPARATOR '|') as magic";
      $addl_from .= ' LEFT JOIN part_pkg USING ( pkgpart ) ';
      #$pkg_join  .= ' LEFT JOIN part_pkg USING ( pkgpart ) ';
    } else {
      warn "warning: unknown database type ". $dbh->{Driver}->{Name}. 
           "omitting package information from report.";
    }

    my $header_query = "SELECT COUNT(cust_pkg.custnum = cust_main.custnum) AS count FROM cust_main $addl_from $extra_sql $pkgwhere group by cust_main.custnum order by count desc limit 1";

    my $sth = dbh->prepare($header_query) or die dbh->errstr;
    $sth->execute() or die $sth->errstr;
    my $headerrow = $sth->fetchrow_arrayref;
    my $headercount = $headerrow ? $headerrow->[0] : 0;
    while($headercount) {
      unshift @extra_headers, "Package ". $headercount;
      unshift @extra_fields, eval q!sub {my $c = shift;
                                         my @a = split '\|', $c->magic;
                                         my $p = $a[!.--$headercount. q!];
                                         $p;
                                        };!;
    }

  }

  if ( $params->{'with_geocode'} ) {

    unshift @extra_headers, 'Tax location override', 'Calculated tax location';
    unshift @extra_fields, sub { my $c = shift; $c->get('geocode'); },
                           sub { my $c = shift;
                                 $c->set('geocode', '');
                                 $c->geocode('cch'); #XXX only cch right now
                               };
    push @select, 'geocode';
    push @select, 'zip' unless grep { $_ eq 'zip' } @select;
    push @select, 'ship_zip' unless grep { $_ eq 'ship_zip' } @select;
  }

  my $select = join(', ', @select);

  my $sql_query = {
    'table'         => 'cust_main',
    'select'        => $select,
    'addl_from'     => $addl_from,
    'hashref'       => {},
    'extra_sql'     => $extra_sql,
    'order_by'      => $orderby,
    'count_query'   => $count_query,
    'extra_headers' => \@extra_headers,
    'extra_fields'  => \@extra_fields,
  };

}

=item fuzzy_search FUZZY_HASHREF [ HASHREF, SELECT, EXTRA_SQL, CACHE_OBJ ]

Performs a fuzzy (approximate) search and returns the matching FS::cust_main
records.  Currently, I<first>, I<last>, I<company> and/or I<address1> may be
specified (the appropriate ship_ field is also searched).

Additional options are the same as FS::Record::qsearch

=cut

sub fuzzy_search {
  my( $self, $fuzzy, $hash, @opt) = @_;
  #$self
  $hash ||= {};
  my @cust_main = ();

  check_and_rebuild_fuzzyfiles();
  foreach my $field ( keys %$fuzzy ) {

    my $all = $self->all_X($field);
    next unless scalar(@$all);

    my %match = ();
    $match{$_}=1 foreach ( amatch( $fuzzy->{$field}, ['i'], @$all ) );

    my @fcust = ();
    foreach ( keys %match ) {
      push @fcust, qsearch('cust_main', { %$hash, $field=>$_}, @opt);
      push @fcust, qsearch('cust_main', { %$hash, "ship_$field"=>$_}, @opt);
    }
    my %fsaw = ();
    push @cust_main, grep { ! $fsaw{$_->custnum}++ } @fcust;
  }

  # we want the components of $fuzzy ANDed, not ORed, but still don't want dupes
  my %saw = ();
  @cust_main = grep { ++$saw{$_->custnum} == scalar(keys %$fuzzy) } @cust_main;

  @cust_main;

}

=back

=head1 UTILITY SUBROUTINES

=over 4

=item check_and_rebuild_fuzzyfiles

=cut

sub check_and_rebuild_fuzzyfiles {
  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  rebuild_fuzzyfiles() if grep { ! -e "$dir/cust_main.$_" } @fuzzyfields;
}

=item rebuild_fuzzyfiles

=cut

sub rebuild_fuzzyfiles {

  use Fcntl qw(:flock);

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  mkdir $dir, 0700 unless -d $dir;

  foreach my $fuzzy ( @fuzzyfields ) {

    open(LOCK,">>$dir/cust_main.$fuzzy")
      or die "can't open $dir/cust_main.$fuzzy: $!";
    flock(LOCK,LOCK_EX)
      or die "can't lock $dir/cust_main.$fuzzy: $!";

    open (CACHE, '>:encoding(UTF-8)', "$dir/cust_main.$fuzzy.tmp")
      or die "can't open $dir/cust_main.$fuzzy.tmp: $!";

    foreach my $field ( $fuzzy, "ship_$fuzzy" ) {
      my $sth = dbh->prepare("SELECT $field FROM cust_main".
                             " WHERE $field != '' AND $field IS NOT NULL");
      $sth->execute or die $sth->errstr;

      while ( my $row = $sth->fetchrow_arrayref ) {
        print CACHE $row->[0]. "\n";
      }

    } 

    close CACHE or die "can't close $dir/cust_main.$fuzzy.tmp: $!";
  
    rename "$dir/cust_main.$fuzzy.tmp", "$dir/cust_main.$fuzzy";
    close LOCK;
  }

}

=item append_fuzzyfiles FIRSTNAME LASTNAME COMPANY ADDRESS1

=cut

sub append_fuzzyfiles {
  #my( $first, $last, $company ) = @_;

  check_and_rebuild_fuzzyfiles();

  use Fcntl qw(:flock);

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;

  foreach my $field (@fuzzyfields) {
    my $value = shift;

    if ( $value ) {

      open(CACHE, '>>:encoding(UTF-8)', "$dir/cust_main.$field" )
        or die "can't open $dir/cust_main.$field: $!";
      flock(CACHE,LOCK_EX)
        or die "can't lock $dir/cust_main.$field: $!";

      print CACHE "$value\n";

      flock(CACHE,LOCK_UN)
        or die "can't unlock $dir/cust_main.$field: $!";
      close CACHE;
    }

  }

  1;
}

=item all_X

=cut

sub all_X {
  my( $self, $field ) = @_;
  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  open(CACHE, '<:encoding(UTF-8)', "$dir/cust_main.$field")
    or die "can't open $dir/cust_main.$field: $!";
  my @array = map { chomp; $_; } <CACHE>;
  close CACHE;
  \@array;
}

=head1 BUGS

Bed bugs

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=cut

1;

