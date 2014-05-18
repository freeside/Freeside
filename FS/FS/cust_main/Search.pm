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
use FS::payinfo_Mixin;

@EXPORT_OK = qw( smart_search );

# 1 is mostly method/subroutine entry and options
# 2 traces progress of some operations
# 3 is even more information including possibly sensitive data
$DEBUG = 0;
$me = '[FS::cust_main::Search]';

@fuzzyfields = (
  'cust_main.first', 'cust_main.last', 'cust_main.company', 
  'cust_main.ship_company', # if you're using it
  'cust_location.address1',
  'contact.first',   'contact.last',
);

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
address (if address1-search is on), invoicing email address, or credit card
number.

Searches match as an exact, or, in some cases, a substring or fuzzy match (see
the source code for the exact heuristics used); I<no_fuzzy_on_exact>, causes
smart_search to
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
  my $agentnums_href = $FS::CurrentUser::CurrentUser->agentnums_href;

  my @cust_main = ();

  my $skip_fuzzy = delete $options{'no_fuzzy_on_exact'};
  my $search = delete $options{'search'};
  ( my $alphanum_search = $search ) =~ s/\W//g;
  
  if ( $alphanum_search =~ /^1?(\d{3})(\d{3})(\d{4})(\d*)$/ ) { #phone# search

    #false laziness w/Record::ut_phone
    my $phonen = "$1-$2-$3";
    $phonen .= " x$4" if $4;

    my $phonenum = "$1$2$3";
    #my $extension = $4;

    #cust_main phone numbers
    push @cust_main, qsearch( {
      'table'   => 'cust_main',
      'hashref' => { %options },
      'extra_sql' => ( scalar(keys %options) ? ' AND ' : ' WHERE ' ).
                     ' ( '.
                         join(' OR ', map "$_ = '$phonen'",
                                          qw( daytime night mobile fax )
                             ).
                     ' ) '.
                     " AND $agentnums_sql", #agent virtualization
    } );

    #contact phone numbers
    push @cust_main,
      grep $agentnums_href->{$_->agentnum}, #agent virt
        grep $_, #skip contacts that don't have cust_main records
          map $_->contact->cust_main,
            qsearch({
                      'table'   => 'contact_phone',
                      'hashref' => { 'phonenum' => $phonenum },
                   });

    unless ( @cust_main || $phonen =~ /x\d+$/ ) { #no exact match
      #try looking for matches with extensions unless one was specified

      push @cust_main, qsearch( {
        'table'   => 'cust_main',
        'hashref' => { %options },
        'extra_sql' => ( scalar(keys %options) ? ' AND ' : ' WHERE ' ).
                       ' ( '.
                           join(' OR ', map "$_ LIKE '$phonen\%'",
                                            qw( daytime night )
                               ).
                       ' ) '.
                       " AND $agentnums_sql", #agent virtualization
      } );

    }

  } 
  
  
  if ( $search =~ /@/ ) { #email address

      # invoicing email address
      push @cust_main,
        grep $agentnums_href->{$_->agentnum}, #agent virt
	  map $_->cust_main,
	      qsearch( {
			 'table'     => 'cust_main_invoice',
			 'hashref'   => { 'dest' => $search },
		       }
		     );

      # contact email address
      push @cust_main,
        grep $agentnums_href->{$_->agentnum}, #agent virt
          grep $_, #skip contacts that don't have cust_main records
	    map $_->contact->cust_main,
	      qsearch( {
			 'table'     => 'contact_email',
			 'hashref'   => { 'emailaddress' => $search },
		       }
		     );

  # custnum search (also try agent_custid), with some tweaking options if your
  # legacy cust "numbers" have letters
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
    foreach my $agentnum ( keys %$agentnums_href ) {
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
      # probably the Right Thing: return customers that have any associated
      # locations matching the string, not just bill/ship location
      push @cust_main, qsearch( {
        'table'     => 'cust_main',
        'addl_from' => ' JOIN cust_location USING (custnum) ',
        'hashref'   => { %options, },
        'extra_sql' => 
          ( keys(%options) ? ' AND ' : ' WHERE ' ).
          " LOWER(SUBSTRING(cust_location.address1 FROM 1 FOR $len)) = '$num' ".
          " AND $agentnums_sql",
      } );
    }

  } elsif ( $search =~ /^\s*(\S.*\S)\s+\((.+), ([^,]+)\)\s*$/ ) {

    my($company, $last, $first) = ( $1, $2, $3 );

    # "Company (Last, First)"
    #this is probably something a browser remembered,
    #so just do an exact search (but case-insensitive, so USPS standardization
    #doesn't throw a wrench in the works)

    push @cust_main, qsearch( {
        'table'     => 'cust_main',
        'hashref'   => { %options },
        'extra_sql' => 
        ( keys(%options) ? ' AND ' : ' WHERE ' ).
        join(' AND ',
          " LOWER(first)   = ". dbh->quote(lc($first)),
          " LOWER(last)    = ". dbh->quote(lc($last)),
          " LOWER(company) = ". dbh->quote(lc($company)),
          $agentnums_sql,
        ),
      } ),

    #contacts?
    # probably not necessary for the "something a browser remembered" case

  } elsif ( $search =~ /^\s*(\S.*\S)\s*$/ ) { # value search
                                              # try {first,last,company}

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
      $sql .= "( LOWER(cust_main.last) = $q_last AND LOWER(cust_main.first) = $q_first )";

      #cust_main
      push @cust_main, qsearch( {
        'table'     => 'cust_main',
        'hashref'   => \%options,
        'extra_sql' => "$sql AND $agentnums_sql", #agent virtualization
      } );

      #contacts
      push @cust_main,
        grep $agentnums_href->{$_->agentnum}, #agent virt
          grep $_, #skip contacts that don't have cust_main records
	    map $_->cust_main,
	      qsearch( {
			 'table'     => 'contact',
			 'hashref'   => { 'first' => $first,
                                          'last'  => $last,
                                        }, 
		       }
		     );

      # or it just be something that was typed in... (try that in a sec)

    }

    my $q_value = dbh->quote($value);

    #exact
    my $sql = scalar(keys %options) ? ' AND ' : ' WHERE ';
    $sql .= " (    LOWER(cust_main.first)         = $q_value
                OR LOWER(cust_main.last)          = $q_value
                OR LOWER(cust_main.company)       = $q_value
                OR LOWER(cust_main.ship_company)  = $q_value
            ";

    #address1 (yes, it's a kludge)
    $sql .= "   OR EXISTS ( 
                            SELECT 1 FROM cust_location 
                              WHERE LOWER(cust_location.address1) = $q_value
                                AND cust_location.custnum = cust_main.custnum
                          )"
      if $conf->exists('address1-search');

    #contacts (look, another kludge)
    $sql .= "   OR EXISTS ( SELECT 1 FROM contact
                              WHERE (    LOWER(contact.first) = $q_value
                                      OR LOWER(contact.last)  = $q_value
                                    )
                                AND contact.custnum IS NOT NULL
                                AND contact.custnum = cust_main.custnum
                          )
              ) ";

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

      my @company_hashrefs = (
        { 'company'      => { op=>'ILIKE', value=>"%$value%" }, },
        { 'ship_company' => { op=>'ILIKE', value=>"%$value%" }, },
      );

      my @hashrefs = ();

      if ( $first && $last ) {

        @hashrefs = (
          { 'first'        => { op=>'ILIKE', value=>"%$first%" },
            'last'         => { op=>'ILIKE', value=>"%$last%" },
          },
        );

      } else {

        @hashrefs = (
          { 'first'        => { op=>'ILIKE', value=>"%$value%" }, },
          { 'last'         => { op=>'ILIKE', value=>"%$value%" }, },
        );
      }

      foreach my $hashref ( @company_hashrefs, @hashrefs ) {

        push @cust_main, qsearch( {
          'table'     => 'cust_main',
          'hashref'   => { %$hashref,
                           %options,
                         },
          'extra_sql' => " AND $agentnums_sql", #agent virtualizaiton
        } );

      }

      if ( $conf->exists('address1-search') ) {

        push @cust_main, qsearch( {
          table     => 'cust_main',
          addl_from => 'JOIN cust_location USING (custnum)',
          extra_sql => 'WHERE '.
                        ' cust_location.address1 ILIKE '.dbh->quote("%$value%").
                        " AND $agentnums_sql", #agent virtualizaiton
        } );

      }

      #contact substring

      foreach my $hashref ( @hashrefs ) {

        push @cust_main,
          grep $agentnums_href->{$_->agentnum}, #agent virt
            grep $_, #skip contacts that don't have cust_main records
	      map $_->cust_main,
                qsearch({
                          'table'     => 'contact',
                          'hashref'   => { %$hashref,
                                           #%options,
                                         },
                          #'extra_sql' => " AND $agentnums_sql", #agent virt
                       });

      }

      #fuzzy
      my %fuzopts = (
        'hashref'   => \%options,
        'select'    => '',
        'extra_sql' => "WHERE $agentnums_sql",    #agent virtualization
      );

      if ( $first && $last ) {
        push @cust_main, FS::cust_main::Search->fuzzy_search(
          { 'last'   => $last,    #fuzzy hashref
            'first'  => $first }, #
          %fuzopts
        );
        push @cust_main, FS::cust_main::Search->fuzzy_search(
          { 'contact.last'   => $last,    #fuzzy hashref
            'contact.first'  => $first }, #
          %fuzopts
        );
     }
      foreach my $field ( 'first', 'last', 'company', 'ship_company' ) {
        push @cust_main, FS::cust_main::Search->fuzzy_search(
          { $field => $value },
          %fuzopts
        );
      }
      foreach my $field ( 'first', 'last' ) {
        push @cust_main, FS::cust_main::Search->fuzzy_search(
          { "contact.$field" => $value },
          %fuzopts
        );
      }
      if ( $conf->exists('address1-search') ) {
        push @cust_main,
          FS::cust_main::Search->fuzzy_search(
            { 'cust_location.address1' => $value },
            %fuzopts
        );
      }

    }

  }

  ( my $nospace_search = $search ) =~ s/\s//g;
  ( my $card_search = $nospace_search ) =~ s/\-//g;
  $card_search =~ s/[x\*\.\_]/x/gi;
  
  if ( $card_search =~ /^[\dx]{15,16}$/i ) { #credit card search

    ( my $like_search = $card_search ) =~ s/x/_/g;
    my $mask_search = FS::payinfo_Mixin->mask_payinfo('CARD', $card_search);

    push @cust_main, qsearch({
      'table'     => 'cust_main',
      'hashref'   => {},
      'extra_sql' => " WHERE (    payinfo LIKE '$like_search'
                               OR paymask =    '$mask_search'
                             ) ".
                     " AND payby IN ('CARD','DCRD') ".
                     " AND $agentnums_sql", #agent virtulization
    });

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

=item zip

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
    'zip'           => '',
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
  # parse sales person
  ##

  if ( $params->{'salesnum'} =~ /^(\d+)$/ ) {
    push @where, ($1 > 0 ) ? "cust_main.salesnum = $1"
                           : 'cust_main.salesnum IS NULL';
  }

  ##
  # parse usernum
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
  if ( $params->{'address'} ) {
    # allow this to be an arrayref
    my @values = ($params->{'address'});
    @values = @{$values[0]} if ref($values[0]);
    my @orwhere;
    foreach (grep /\S/, @values) {
      my $address = dbh->quote('%'. lc($_). '%');
      push @orwhere,
        "LOWER(cust_location.address1) LIKE $address",
        "LOWER(cust_location.address2) LIKE $address";
    }
    if (@orwhere) {
      push @where, "EXISTS(
        SELECT 1 FROM cust_location 
        WHERE cust_location.custnum = cust_main.custnum
          AND (".join(' OR ',@orwhere).")
        )";
    }
  }

  ##
  # zipcode
  ##
  if ( $params->{'zip'} =~ /\S/ ) {
    my $zip = dbh->quote($params->{'zip'} . '%');
    push @where, "EXISTS(
      SELECT 1 FROM cust_location
      WHERE cust_location.custnum = cust_main.custnum
        AND cust_location.zip LIKE $zip
    )";
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
  # "with email address(es)" checkbox
  ##

  push @where,
    'EXISTS ( SELECT 1 FROM cust_main_invoice
                WHERE cust_main_invoice.custnum = cust_main.custnum
                  AND length(dest) > 5
            )'  # AND dest LIKE '%@%'
    if $params->{'with_email'};

  ##
  # "with postal mail invoices" checkbox
  ##

  push @where,
    "EXISTS ( SELECT 1 FROM cust_main_invoice
                WHERE cust_main_invoice.custnum = cust_main.custnum
                  AND dest = 'POST' )"
    if $params->{'POST'};

  ##
  # "without postal mail invoices" checkbox
  ##

  push @where,
    "NOT EXISTS ( SELECT 1 FROM cust_main_invoice
                    WHERE cust_main_invoice.custnum = cust_main.custnum
                      AND dest = 'POST' )"
    if $params->{'no_POST'};

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
      if ( $params->{'all_tags'} ) {
        foreach ( @tagnums ) {
          push @where, 'exists(select 1 from cust_tag where '.
                       'cust_tag.custnum = cust_main.custnum and tagnum = '.
                       $_ . ')';
        }
      } else { # matching any tag, not all
	my $tags_where = "0 < (select count(1) from cust_tag where " 
		. " cust_tag.custnum = cust_main.custnum and tagnum in ("
		. join(',', @tagnums) . "))";

	push @where, $tags_where;
      }
    }
  }

  # pkg_classnum
  #   all_pkg_classnums
  #   any_pkg_status
  if ( $params->{'pkg_classnum'} ) {
    my @pkg_classnums = ref( $params->{'pkg_classnum'} ) ?
                          @{ $params->{'pkg_classnum'} } :
                             $params->{'pkg_classnum'};
    @pkg_classnums = grep /^(\d+)$/, @pkg_classnums;

    if ( @pkg_classnums ) {

      my @pkg_where;
      if ( $params->{'all_pkg_classnums'} ) {
        push @pkg_where, "part_pkg.classnum = $_" foreach @pkg_classnums;
      } else {
        push @pkg_where,
          'part_pkg.classnum IN('. join(',', @pkg_classnums).')';
      }
      foreach (@pkg_where) {
        my $select_pkg = 
          "SELECT 1 FROM cust_pkg JOIN part_pkg USING (pkgpart) WHERE ".
          "cust_pkg.custnum = cust_main.custnum AND $_ ";
        if ( not $params->{'any_pkg_status'} ) {
          $select_pkg .= 'AND '.FS::cust_pkg->active_sql;
        }
        push @where, "EXISTS($select_pkg)";
      }
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
  # always make address fields available in results
  for my $pre ('bill_', 'ship_') {
    $addl_from .= 
      'LEFT JOIN cust_location AS '.$pre.'location '.
      'ON (cust_main.'.$pre.'locationnum = '.$pre.'location.locationnum) ';
  }

  my $count_query = "SELECT COUNT(*) FROM cust_main $addl_from $extra_sql";

  my @select = (
                 'cust_main.custnum',
                 'cust_main.salesnum',
                 # there's a good chance that we'll need these
                 'cust_main.bill_locationnum',
                 'cust_main.ship_locationnum',
                 FS::UI::Web::cust_sql_fields($params->{'cust_fields'}),
               );

  my(@extra_headers) = ();
  my(@extra_fields)  = ();

  if ($params->{'flattened_pkgs'}) {

    #my $pkg_join = '';
    $addl_from .=
      ' LEFT JOIN cust_pkg ON ( cust_main.custnum = cust_pkg.custnum ) ';

    if ($dbh->{Driver}->{Name} eq 'Pg') {

      push @select, "
        ARRAY_TO_STRING(
          ARRAY(
            SELECT pkg FROM cust_pkg LEFT JOIN part_pkg USING ( pkgpart )
              WHERE cust_main.custnum = cust_pkg.custnum $pkgwhere
          ), '|'
        ) AS magic
      ";

    } elsif ($dbh->{Driver}->{Name} =~ /^mysql/i) {
      push @select, "GROUP_CONCAT(part_pkg.pkg SEPARATOR '|') as magic";
      $addl_from .= ' LEFT JOIN part_pkg USING ( pkgpart ) ';
      #$pkg_join  .= ' LEFT JOIN part_pkg USING ( pkgpart ) ';
    } else {
      warn "warning: unknown database type ". $dbh->{Driver}->{Name}. 
           "omitting package information from report.";
    }

    my $header_query = "
      SELECT COUNT(cust_pkg.custnum = cust_main.custnum) AS count
        FROM cust_main $addl_from $extra_sql $pkgwhere
          GROUP BY cust_main.custnum ORDER BY count DESC LIMIT 1
    ";

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
  #warn Data::Dumper::Dumper($sql_query);
  $sql_query;

}

=item fuzzy_search FUZZY_HASHREF [ OPTS ]

Performs a fuzzy (approximate) search and returns the matching FS::cust_main
records.  Currently, I<first>, I<last>, I<company> and/or I<address1> may be
specified.

Additional options are the same as FS::Record::qsearch

=cut

sub fuzzy_search {
  my $self = shift;
  my $fuzzy = shift;
  # sensible defaults, then merge in any passed options
  my %fuzopts = (
    'table'     => 'cust_main',
    'addl_from' => '',
    'extra_sql' => '',
    'hashref'   => {},
    @_
  );

  my @cust_main = ();

  my @fuzzy_mod = 'i';
  my $conf = new FS::Conf;
  my $fuzziness = $conf->config('fuzzy-fuzziness');
  push @fuzzy_mod, $fuzziness if $fuzziness;

  check_and_rebuild_fuzzyfiles();
  foreach my $field ( keys %$fuzzy ) {

    my $all = $self->all_X($field);
    next unless scalar(@$all);

    my %match = ();
    $match{$_}=1 foreach ( amatch( $fuzzy->{$field}, \@fuzzy_mod, @$all ) );
    next if !keys(%match);

    my $in_matches = 'IN (' .
                     join(',', map { dbh->quote($_) } keys %match) .
                     ')';

    my $extra_sql = $fuzopts{extra_sql};
    if ($extra_sql =~ /^\s*where /i or keys %{ $fuzopts{hashref} }) {
      $extra_sql .= ' AND ';
    } else {
      $extra_sql .= 'WHERE ';
    }
    $extra_sql .= "$field $in_matches";

    my $addl_from = $fuzopts{addl_from};
    if ( $field =~ /^cust_location\./ ) {
      $addl_from .= ' JOIN cust_location USING (custnum)';
    } elsif ( $field =~ /^contact\./ ) {
      $addl_from .= ' JOIN contact USING (custnum)';
    }

    push @cust_main, qsearch({
      %fuzopts,
      'addl_from' => $addl_from,
      'extra_sql' => $extra_sql,
    });
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
  rebuild_fuzzyfiles()
    if grep { ! -e "$dir/$_" }
         map {
               my ($field, $table) = reverse split('\.', $_);
               $table ||= 'cust_main';
               "$table.$field"
             }
           @fuzzyfields;
}

=item rebuild_fuzzyfiles

=cut

sub rebuild_fuzzyfiles {

  use Fcntl qw(:flock);

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  mkdir $dir, 0700 unless -d $dir;

  foreach my $fuzzy ( @fuzzyfields ) {

    my ($field, $table) = reverse split('\.', $fuzzy);
    $table ||= 'cust_main';

    open(LOCK,">>$dir/$table.$field")
      or die "can't open $dir/$table.$field: $!";
    flock(LOCK,LOCK_EX)
      or die "can't lock $dir/$table.$field: $!";

    open (CACHE, '>:encoding(UTF-8)', "$dir/$table.$field.tmp")
      or die "can't open $dir/$table.$field.tmp: $!";

    my $sth = dbh->prepare(
      "SELECT $field FROM $table WHERE $field IS NOT NULL AND $field != ''"
    );
    $sth->execute or die $sth->errstr;

    while ( my $row = $sth->fetchrow_arrayref ) {
      print CACHE $row->[0]. "\n";
    }

    close CACHE or die "can't close $dir/$table.$field.tmp: $!";
  
    rename "$dir/$table.$field.tmp", "$dir/$table.$field";
    close LOCK;
  }

}

=item append_fuzzyfiles FIRSTNAME LASTNAME COMPANY ADDRESS1

=cut

sub append_fuzzyfiles {
  #my( $first, $last, $company ) = @_;

  check_and_rebuild_fuzzyfiles();

  #foreach my $fuzzy (@fuzzyfields) {
  foreach my $fuzzy ( 'cust_main.first', 'cust_main.last', 'cust_main.company', 
                      'cust_location.address1',
                      'cust_main.ship_company',
                    ) {

    append_fuzzyfiles_fuzzyfield($fuzzy, shift);

  }

  1;
}

=item append_fuzzyfiles_fuzzyfield COLUMN VALUE

=item append_fuzzyfiles_fuzzyfield TABLE.COLUMN VALUE

=cut

use Fcntl qw(:flock);
sub append_fuzzyfiles_fuzzyfield {
  my( $fuzzyfield, $value ) = @_;

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;


  my ($field, $table) = reverse split('\.', $fuzzyfield);
  $table ||= 'cust_main';

  return unless defined($value) && length($value);

  open(CACHE, '>>:encoding(UTF-8)', "$dir/$table.$field" )
    or die "can't open $dir/$table.$field: $!";
  flock(CACHE,LOCK_EX)
    or die "can't lock $dir/$table.$field: $!";

  print CACHE "$value\n";

  flock(CACHE,LOCK_UN)
    or die "can't unlock $dir/$table.$field: $!";
  close CACHE;

}

=item all_X

=cut

sub all_X {
  my( $self, $fuzzy ) = @_;
  my ($field, $table) = reverse split('\.', $fuzzy);
  $table ||= 'cust_main';

  my $dir = $FS::UID::conf_dir. "/cache.". $FS::UID::datasrc;
  open(CACHE, '<:encoding(UTF-8)', "$dir/$table.$field")
    or die "can't open $dir/$table.$field: $!";
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

