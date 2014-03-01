package FS::cust_pkg::Search;

use strict;
use FS::CurrentUser;
use FS::UI::Web;
use FS::cust_main;
use FS::cust_pkg;

=item search HASHREF

(Class method)

Returns a qsearch hash expression to search for parameters specified in HASHREF.
Valid parameters are

=over 4

=item agentnum

=item magic

active, inactive, suspended, cancel (or cancelled)

=item status

active, inactive, suspended, one-time charge, inactive, cancel (or cancelled)

=item custom

 boolean selects custom packages

=item classnum

=item pkgpart

pkgpart or arrayref or hashref of pkgparts

=item setup

arrayref of beginning and ending epoch date

=item last_bill

arrayref of beginning and ending epoch date

=item bill

arrayref of beginning and ending epoch date

=item adjourn

arrayref of beginning and ending epoch date

=item susp

arrayref of beginning and ending epoch date

=item expire

arrayref of beginning and ending epoch date

=item cancel

arrayref of beginning and ending epoch date

=item query

pkgnum or APKG_pkgnum

=item cust_fields

a value suited to passing to FS::UI::Web::cust_header

=item CurrentUser

specifies the user for agent virtualization

=item fcc_line

boolean; if true, returns only packages with more than 0 FCC phone lines.

=item state, country

Limit to packages with a service location in the specified state and country.
For FCC 477 reporting, mostly.

=item location_cust

Limit to packages whose service locations are the same as the customer's 
default service location.

=item location_nocust

Limit to packages whose service locations are not the customer's default 
service location.

=item location_census

Limit to packages whose service locations have census tracts.

=item location_nocensus

Limit to packages whose service locations do not have a census tract.

=item location_geocode

Limit to packages whose locations have geocodes.

=item location_geocode

Limit to packages whose locations do not have geocodes.

=back

=cut

sub search {
  my ($class, $params) = @_;
  my @where = ();

  ##
  # parse agent
  ##

  if ( $params->{'agentnum'} =~ /^(\d+)$/ and $1 ) {
    push @where,
      "cust_main.agentnum = $1";
  }

  ##
  # parse cust_status
  ##

  if ( $params->{'cust_status'} =~ /^([a-z]+)$/ ) {
    push @where, FS::cust_main->cust_status_sql . " = '$1' ";
  }

  ##
  # parse customer sales person
  ##

  if ( $params->{'cust_main_salesnum'} =~ /^(\d+)$/ ) {
    push @where, ($1 > 0) ? "cust_main.salesnum = $1"
                          : 'cust_main.salesnum IS NULL';
  }


  ##
  # parse sales person
  ##

  if ( $params->{'salesnum'} =~ /^(\d+)$/ ) {
    push @where, ($1 > 0) ? "cust_pkg.salesnum = $1"
                          : 'cust_pkg.salesnum IS NULL';
  }

  ##
  # parse custnum
  ##

  if ( $params->{'custnum'} =~ /^(\d+)$/ and $1 ) {
    push @where,
      "cust_pkg.custnum = $1";
  }

  ##
  # custbatch
  ##

  if ( $params->{'pkgbatch'} =~ /^([\w\/\-\:\.]+)$/ and $1 ) {
    push @where,
      "cust_pkg.pkgbatch = '$1'";
  }

  ##
  # parse status
  ##

  if (    $params->{'magic'}  eq 'active'
       || $params->{'status'} eq 'active' ) {

    push @where, FS::cust_pkg->active_sql();

  } elsif (    $params->{'magic'}  =~ /^not[ _]yet[ _]billed$/
            || $params->{'status'} =~ /^not[ _]yet[ _]billed$/ ) {

    push @where, FS::cust_pkg->not_yet_billed_sql();

  } elsif (    $params->{'magic'}  =~ /^(one-time charge|inactive)/
            || $params->{'status'} =~ /^(one-time charge|inactive)/ ) {

    push @where, FS::cust_pkg->inactive_sql();

  } elsif (    $params->{'magic'}  eq 'suspended'
            || $params->{'status'} eq 'suspended'  ) {

    push @where, FS::cust_pkg->suspended_sql();

  } elsif (    $params->{'magic'}  =~ /^cancell?ed$/
            || $params->{'status'} =~ /^cancell?ed$/ ) {

    push @where, FS::cust_pkg->cancelled_sql();

  }

  ###
  # parse package class
  ###

  if ( exists($params->{'classnum'}) ) {

    my @classnum = ();
    if ( ref($params->{'classnum'}) ) {

      if ( ref($params->{'classnum'}) eq 'HASH' ) {
        @classnum = grep $params->{'classnum'}{$_}, keys %{ $params->{'classnum'} };
      } elsif ( ref($params->{'classnum'}) eq 'ARRAY' ) {
        @classnum = @{ $params->{'classnum'} };
      } else {
        die 'unhandled classnum ref '. $params->{'classnum'};
      }


    } elsif ( $params->{'classnum'} =~ /^(\d*)$/ && $1 ne '0' ) {
      @classnum = ( $1 );
    }

    if ( @classnum ) {

      my @c_where = ();
      my @nums = grep $_, @classnum;
      push @c_where, 'part_pkg.classnum IN ('. join(',',@nums). ')' if @nums;
      my $null = scalar( grep { $_ eq '' } @classnum );
      push @c_where, 'part_pkg.classnum IS NULL' if $null;

      if ( scalar(@c_where) == 1 ) {
        push @where, @c_where;
      } elsif ( @c_where ) {
        push @where, ' ( '. join(' OR ', @c_where). ' ) ';
      }

    }
    

  }

  ###
  # parse package report options
  ###

  my @report_option = ();
  if ( exists($params->{'report_option'}) ) {
    if ( ref($params->{'report_option'}) eq 'ARRAY' ) {
      @report_option = @{ $params->{'report_option'} };
    } elsif ( $params->{'report_option'} =~ /^([,\d]*)$/ ) {
      @report_option = split(',', $1);
    }

  }

  if (@report_option) {
    # this will result in the empty set for the dangling comma case as it should
    push @where, 
      map{ "0 < ( SELECT count(*) FROM part_pkg_option
                    WHERE part_pkg_option.pkgpart = part_pkg.pkgpart
                    AND optionname = 'report_option_$_'
                    AND optionvalue = '1' )"
         } @report_option;
  }

  foreach my $any ( grep /^report_option_any/, keys %$params ) {

    my @report_option_any = ();
    if ( ref($params->{$any}) eq 'ARRAY' ) {
      @report_option_any = @{ $params->{$any} };
    } elsif ( $params->{$any} =~ /^([,\d]*)$/ ) {
      @report_option_any = split(',', $1);
    }

    if (@report_option_any) {
      # this will result in the empty set for the dangling comma case as it should
      push @where, ' ( '. join(' OR ',
        map{ "0 < ( SELECT count(*) FROM part_pkg_option
                      WHERE part_pkg_option.pkgpart = part_pkg.pkgpart
                      AND optionname = 'report_option_$_'
                      AND optionvalue = '1' )"
           } @report_option_any
      ). ' ) ';
    }

  }

  ###
  # parse custom
  ###

  push @where,  "part_pkg.custom = 'Y'" if $params->{custom};

  ###
  # parse fcc_line
  ###

  push @where,  "(part_pkg.fcc_ds0s > 0 OR pkg_class.fcc_ds0s > 0)" 
                                                        if $params->{fcc_line};

  ###
  # parse censustract
  ###

  if ( exists($params->{'censustract'}) ) {
    $params->{'censustract'} =~ /^([.\d]*)$/;
    my $censustract = "cust_location.censustract = '$1'";
    $censustract .= ' OR cust_location.censustract is NULL' unless $1;
    push @where,  "( $censustract )";
  }

  ###
  # parse censustract2
  ###
  if ( exists($params->{'censustract2'})
       && $params->{'censustract2'} =~ /^(\d*)$/
     )
  {
    if ($1) {
      push @where, "cust_location.censustract LIKE '$1%'";
    } else {
      push @where,
        "( cust_location.censustract = '' OR cust_location.censustract IS NULL )";
    }
  }

  ###
  # parse country/state
  ###
  for (qw(state country)) { # parsing rules are the same for these
  if ( exists($params->{$_}) 
    && uc($params->{$_}) =~ /^([A-Z]{2})$/ )
    {
      # XXX post-2.3 only--before that, state/country may be in cust_main
      push @where, "cust_location.$_ = '$1'";
    }
  }

  ###
  # location_* flags
  ###
  if ( $params->{location_cust} xor $params->{location_nocust} ) {
    my $op = $params->{location_cust} ? '=' : '!=';
    push @where, "cust_location.locationnum $op cust_main.ship_locationnum";
  }
  if ( $params->{location_census} xor $params->{location_nocensus} ) {
    my $op = $params->{location_census} ? "IS NOT NULL" : "IS NULL";
    push @where, "cust_location.censustract $op";
  }
  if ( $params->{location_geocode} xor $params->{location_nogeocode} ) {
    my $op = $params->{location_geocode} ? "IS NOT NULL" : "IS NULL";
    push @where, "cust_location.geocode $op";
  }

  ###
  # parse part_pkg
  ###

  if ( ref($params->{'pkgpart'}) ) {

    my @pkgpart = ();
    if ( ref($params->{'pkgpart'}) eq 'HASH' ) {
      @pkgpart = grep $params->{'pkgpart'}{$_}, keys %{ $params->{'pkgpart'} };
    } elsif ( ref($params->{'pkgpart'}) eq 'ARRAY' ) {
      @pkgpart = @{ $params->{'pkgpart'} };
    } else {
      die 'unhandled pkgpart ref '. $params->{'pkgpart'};
    }

    @pkgpart = grep /^(\d+)$/, @pkgpart;

    push @where, 'pkgpart IN ('. join(',', @pkgpart). ')' if scalar(@pkgpart);

  } elsif ( $params->{'pkgpart'} =~ /^(\d+)$/ ) {
    push @where, "pkgpart = $1";
  } 

  ###
  # parse dates
  ###

  my $orderby = '';

  #false laziness w/report_cust_pkg.html
  my %disable = (
    'all'             => {},
    'one-time charge' => { 'last_bill'=>1, 'bill'=>1, 'adjourn'=>1, 'susp'=>1, 'expire'=>1, 'cancel'=>1, },
    'active'          => { 'susp'=>1, 'cancel'=>1 },
    'suspended'       => { 'cancel' => 1 },
    'cancelled'       => {},
    ''                => {},
  );

  if( exists($params->{'active'} ) ) {
    # This overrides all the other date-related fields, and includes packages
    # that were active at some time during the interval.  It excludes:
    # - packages that were set up after the end of the interval
    # - packages that were canceled before the start of the interval
    # - packages that were suspended before the start of the interval
    #   and are still suspended now
    my($beginning, $ending) = @{$params->{'active'}};
    push @where,
      "cust_pkg.setup IS NOT NULL",
      "cust_pkg.setup <= $ending",
      "(cust_pkg.cancel IS NULL OR cust_pkg.cancel >= $beginning )",
      "(cust_pkg.susp   IS NULL OR cust_pkg.susp   >= $beginning )",
      "NOT (".FS::cust_pkg->onetime_sql . ")";
  }
  else {
    foreach my $field (qw( setup last_bill bill adjourn susp expire contract_end change_date cancel )) {

      next unless exists($params->{$field});

      my($beginning, $ending) = @{$params->{$field}};

      next if $beginning == 0 && $ending == 4294967295;

      push @where,
        "cust_pkg.$field IS NOT NULL",
        "cust_pkg.$field >= $beginning",
        "cust_pkg.$field <= $ending";

      $orderby ||= "ORDER BY cust_pkg.$field";

    }
  }

  $orderby ||= 'ORDER BY bill';

  ###
  # parse magic, legacy, etc.
  ###

  if ( $params->{'magic'} &&
       $params->{'magic'} =~ /^(active|inactive|suspended|cancell?ed)$/
  ) {

    $orderby = 'ORDER BY pkgnum';

    if ( $params->{'pkgpart'} =~ /^(\d+)$/ ) {
      push @where, "pkgpart = $1";
    }

  } elsif ( $params->{'query'} eq 'pkgnum' ) {

    $orderby = 'ORDER BY pkgnum';

  } elsif ( $params->{'query'} eq 'APKG_pkgnum' ) {

    $orderby = 'ORDER BY pkgnum';

    push @where, '0 < (
      SELECT count(*) FROM pkg_svc
       WHERE pkg_svc.pkgpart =  cust_pkg.pkgpart
         AND pkg_svc.quantity > ( SELECT count(*) FROM cust_svc
                                   WHERE cust_svc.pkgnum  = cust_pkg.pkgnum
                                     AND cust_svc.svcpart = pkg_svc.svcpart
                                )
    )';
  
  }

  ##
  # setup queries, links, subs, etc. for the search
  ##

  # here is the agent virtualization
  if ($params->{CurrentUser}) {
    my $access_user =
      qsearchs('access_user', { username => $params->{CurrentUser} });

    if ($access_user) {
      push @where, $access_user->agentnums_sql('table'=>'cust_main');
    } else {
      push @where, "1=0";
    }
  } else {
    push @where, $FS::CurrentUser::CurrentUser->agentnums_sql('table'=>'cust_main');
  }

  my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

  my $addl_from = 'LEFT JOIN part_pkg  USING ( pkgpart  ) '.
                  'LEFT JOIN pkg_class ON ( part_pkg.classnum = pkg_class.classnum ) '.
                  'LEFT JOIN cust_location USING ( locationnum ) '.
                  FS::UI::Web::join_cust_main('cust_pkg', 'cust_pkg');

  my $select;
  my $count_query;
  if ( $params->{'select_zip5'} ) {
    my $zip = 'cust_location.zip';

    $select = "DISTINCT substr($zip,1,5) as zip";
    $orderby = "ORDER BY substr($zip,1,5)";
    $count_query = "SELECT COUNT( DISTINCT substr($zip,1,5) )";
  } else {
    $select = join(', ',
                         'cust_pkg.*',
                         ( map "part_pkg.$_", qw( pkg freq ) ),
                         'pkg_class.classname',
                         'cust_main.custnum AS cust_main_custnum',
                         FS::UI::Web::cust_sql_fields(
                           $params->{'cust_fields'}
                         ),
                  );
    $count_query = 'SELECT COUNT(*)';
  }

  $count_query .= " FROM cust_pkg $addl_from $extra_sql";

  my $sql_query = {
    'table'       => 'cust_pkg',
    'hashref'     => {},
    'select'      => $select,
    'extra_sql'   => $extra_sql,
    'order_by'    => $orderby,
    'addl_from'   => $addl_from,
    'count_query' => $count_query,
  };

}

1;

