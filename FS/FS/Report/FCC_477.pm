package FS::Report::FCC_477;
use base qw( FS::Report );

use strict;
use vars qw( @upload @download @technology @part2aoption @part2boption
             %states
           );
use FS::Record qw( dbh );

use Tie::IxHash;
use Storable;

our $DEBUG = 0;

=head1 NAME

FS::Report::FCC_477 - Routines for FCC Form 477 reports

=head1 SYNOPSIS

=head1 BUGS

Documentation.

=head1 SEE ALSO

=cut

@upload = qw(
 <200kbps
 200-768kbps
 768kbps-1.5mbps
 1.5-3mpbs
 3-6mbps
 6-10mbps
 10-25mbps
 25-100mbps
 >100mbps
);

@download = qw(
 200-768kbps
 768kbps-1.5mbps
 1.5-3mbps
 3-6mbps
 6-10mbps
 10-25mbps
 25-100mbps
 >100mbps
);

@technology = (
  'Asymmetric xDSL',
  'Symmetric xDSL',
  'Other Wireline',
  'Cable Modem',
  'Optical Carrier',
  'Satellite',
  'Terrestrial Fixed Wireless',
  'Terrestrial Mobile Wireless',
  'Electric Power Line',
  'Other Technology',
);

@part2aoption = (
 'LD carrier',
 'owned loops',
 'unswitched UNE loops',
 'UNE-P',
 'UNE-P replacement',
 'FTTP',
 'coax',
 'wireless',
);

@part2boption = (
 'nomadic',
 'copper',
 'FTTP',
 'coax',
 'wireless',
 'other broadband',
);

#from the select at http://www.ffiec.gov/census/default.aspx
#though this is now in the database, also
%states = (
  '01' => 'ALABAMA (AL)',
  '02' => 'ALASKA (AK)',
  '04' => 'ARIZONA (AZ)',
  '05' => 'ARKANSAS (AR)',
  '06' => 'CALIFORNIA (CA)',
  '08' => 'COLORADO (CO)',

  '09' => 'CONNECTICUT (CT)',
  '10' => 'DELAWARE (DE)',
  '11' => 'DISTRICT OF COLUMBIA (DC)',
  '12' => 'FLORIDA (FL)',
  '13' => 'GEORGIA (GA)',
  '15' => 'HAWAII (HI)',

  '16' => 'IDAHO (ID)',
  '17' => 'ILLINOIS (IL)',
  '18' => 'INDIANA (IN)',
  '19' => 'IOWA (IA)',
  '20' => 'KANSAS (KS)',
  '21' => 'KENTUCKY (KY)',

  '22' => 'LOUISIANA (LA)',
  '23' => 'MAINE (ME)',
  '24' => 'MARYLAND (MD)',
  '25' => 'MASSACHUSETTS (MA)',
  '26' => 'MICHIGAN (MI)',
  '27' => 'MINNESOTA (MN)',

  '28' => 'MISSISSIPPI (MS)',
  '29' => 'MISSOURI (MO)',
  '30' => 'MONTANA (MT)',
  '31' => 'NEBRASKA (NE)',
  '32' => 'NEVADA (NV)',
  '33' => 'NEW HAMPSHIRE (NH)',

  '34' => 'NEW JERSEY (NJ)',
  '35' => 'NEW MEXICO (NM)',
  '36' => 'NEW YORK (NY)',
  '37' => 'NORTH CAROLINA (NC)',
  '38' => 'NORTH DAKOTA (ND)',
  '39' => 'OHIO (OH)',

  '40' => 'OKLAHOMA (OK)',
  '41' => 'OREGON (OR)',
  '42' => 'PENNSYLVANIA (PA)',
  '44' => 'RHODE ISLAND (RI)',
  '45' => 'SOUTH CAROLINA (SC)',
  '46' => 'SOUTH DAKOTA (SD)',

  '47' => 'TENNESSEE (TN)',
  '48' => 'TEXAS (TX)',
  '49' => 'UTAH (UT)',
  '50' => 'VERMONT (VT)',
  '51' => 'VIRGINIA (VA)',
  '53' => 'WASHINGTON (WA)',

  '54' => 'WEST VIRGINIA (WV)',
  '55' => 'WISCONSIN (WI)',
  '56' => 'WYOMING (WY)',
  '72' => 'PUERTO RICO (PR)',
);

sub restore_fcc477map {
  my $key = shift;
  FS::Record::scalar_sql('',"select formvalue from fcc477map where formkey = ?",$key);
}

sub save_fcc477map {
  my $key = shift;
  my $value = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $sql = "delete from fcc477map where formkey = ?";
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute($key) or do {
    warn "WARNING: Error removing FCC 477 form defaults: " . $sth->errstr;
    $dbh->rollback if $oldAutoCommit;
  };

  $sql = "insert into fcc477map (formkey,formvalue) values (?,?)";
  $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute($key,$value) or do {
    warn "WARNING: Error setting FCC 477 form defaults: " . $sth->errstr;
    $dbh->rollback if $oldAutoCommit;
  };

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

sub parse_technology_option {
  my $cgi = shift;
  my $save = shift;
  my @result = ();
  my $i = 0;
  for (my $i = 0; $i < scalar(@technology); $i++) {
    my $value = $cgi->param("part1_technology_option_$i"); #lame
    save_fcc477map("part1_technology_option_$i",$value) 
        if $save && $value =~ /^\d+$/;
    push @result, $value =~ /^\d+$/ ? $value : 0;
  }
  return (@result);
}

sub statenum2state {
  my $num = shift;
  $states{$num};
}
### everything above this point is unmaintained ###


=head1 THE "NEW" REPORT (October 2014 and later)

=head2 METHODS

=over 4

=cut

# functions for internal use

sub join_optionnames {
  join(' ', map { join_optionname($_) } @_);
}

sub join_optionnames_int {
  join(' ', map { join_optionname_int($_) } @_);
}

sub join_optionname {
  # Returns a FROM phrase to join a specific option into the query (via 
  # part_pkg).  The option value will appear as a field with the same name
  # as the option.
  my $name = shift;
  "LEFT JOIN (SELECT pkgpart, optionvalue AS $name FROM part_pkg_fcc_option".
    " WHERE fccoptionname = '$name') AS t_$name".
    " ON (part_pkg.pkgpart = t_$name.pkgpart)";
}

sub join_optionname_int {
  # Returns a FROM phrase to join a specific option into the query (via 
  # part_pkg) and cast it to integer..  Note this does not convert nulls
  # to zero.
  my $name = shift;
  "LEFT JOIN (SELECT pkgpart, CAST(optionvalue AS int) AS $name
   FROM part_pkg_fcc_option".
    " WHERE fccoptionname = '$name') AS t_$name".
    " ON (part_pkg.pkgpart = t_$name.pkgpart)";
}

sub dbaname {
  # Returns an sql expression for the DBA name
  "COALESCE( deploy_zone.dbaname,
     (SELECT value FROM conf WHERE conf.name = 'company_name'
                             AND (conf.agentnum = deploy_zone.agentnum
                                  OR conf.agentnum IS NULL)
                             ORDER BY conf.agentnum IS NOT NULL DESC
                             LIMIT 1)
     ) AS dbaname"
}

sub active_on {
  # Returns a condition to limit packages to those that were setup before a 
  # certain date, and not canceled before that date.
  #
  # (Strictly speaking this should also exclude suspended packages but 
  # "suspended as of some past date" is a complicated query.)
  my $date = shift;
  "cust_pkg.setup <= $date AND ".
  "(cust_pkg.cancel IS NULL OR cust_pkg.cancel > $date) AND ".
  "(cust_pkg.change_date IS NULL OR cust_pkg.change_date <= $date)"
}

sub is_fixed_broadband {
  "is_broadband::int = 1 AND technology::int IN( 10, 11, 12, 20, 30, 40, 41, 42, 50, 60, 70, 90, 0 )"
}

sub is_mobile_broadband {
  "is_broadband::int = 1 AND technology::int IN( 80, 81, 82, 83, 84, 85, 86, 87, 88)"
}


=item report SECTION, OPTIONS

Returns the report section SECTION (see the C<parts> method for section 
name strings).  OPTIONS may contain the following:

- date: a timestamp value. Packages that were active on that date will be 
counted.

- agentnum: limit to packages with this agent.

- ignore_quantity: if true, package quantities will be ignored (only distinct
packages will be counted).

The result will be a hashref containing three parallel arrayrefs:
- "data", the columns required by the FCC.
- "detail", a list of the package numbers included in each row's aggregation
- "error", a hashref containing any error status strings in that row. Keys
are error identifiers, values are the messages to show the user.
as well as an informational item:
- "num_errors", the number of rows that contain errors

=item report_data SECTION, OPTIONS

Returns only the data, not the detail or error columns.  This is the part that
will be submitted to the FCC.

=cut

sub report {
  my $class = shift;
  my $section = shift;
  my %opt = @_;
  $opt{detail} = 1;

  # add the error column
  my $data = $class->report_data($section, %opt);
  my $error = [];
  my $detail = [];
  my $check_method = $section.'_check';
  my $num_errors = 0;
  foreach my $row (@$data) {
    if ( $class->can($check_method) ) { # they don't all have these
      my $eh = $class->$check_method( $row );
      $num_errors++ if keys(%$eh);
      push $error, $eh
    }
    push @$detail, pop @$row; # this comes from the query
  }
  
  return +{
    data => $data,
    error => $error,
    detail => $detail,
    num_errors => $num_errors,
  };
}

sub report_data {
  my $class = shift;
  my $section = shift;
  my %opt = @_;

  my $method = $section.'_sql';
  die "Report section '$section' is not implemented\n"
    unless $class->can($method);
  my $statement = $class->$method(%opt);

  warn $statement if $DEBUG;
  my $sth = dbh->prepare($statement);
  $sth->execute or die $sth->errstr;
  return $sth->fetchall_arrayref;
}

sub fbd_sql {
  my $class = shift;
  my %opt = @_;
  my $date = $opt{date} || time;
  my $agentnum = $opt{agentnum};

  my @select = (
    'censusblock',
    dbaname(),
    'technology',
    'CASE WHEN is_consumer IS NOT NULL THEN 1 ELSE 0 END',
    'adv_speed_down',
    'adv_speed_up',
    'CASE WHEN is_business IS NOT NULL THEN 1 ELSE 0 END',
    'cir_speed_down',
    'cir_speed_up',
  );
  push @select, 'blocknum' if $opt{detail};

  my $from = 'deploy_zone_block
    JOIN deploy_zone USING (zonenum)
    JOIN agent USING (agentnum)';
  my @where = (
    "zonetype = 'B'",
    "active_date  < $date",
    "(expire_date > $date OR expire_date IS NULL)",
  );
  push @where, "agentnum = $agentnum" if $agentnum;

  my $order_by = 'censusblock, agentnum, technology, is_consumer, is_business';

  "SELECT ".join(', ', @select) . "
  FROM $from
  WHERE ".join(' AND ', @where)."
  ORDER BY $order_by
  ";
}

sub fbs_sql {
  my $class = shift;
  my %opt = @_;
  my $date = $opt{date} || time;
  my $agentnum = $opt{agentnum};
  my $q = $opt{ignore_quantity} ? '1' : 'COALESCE(cust_pkg.quantity, 1)';

  my $censustract = "replace(cust_location.censustract, '.', '')";

  my @select = (
    "$censustract AS censustract",
    '(technology - technology % 10) AS media_type',
      # media types are multiples of 10
    'broadband_downstream',
    'broadband_upstream',
    "SUM($q)",
    "SUM(COALESCE(is_consumer,0) * $q)",
  );
  push @select, "array_to_string(array_agg(pkgnum), ',')" if $opt{detail};

  my $from =
    'cust_pkg
      JOIN cust_location ON (cust_pkg.locationnum = cust_location.locationnum)
      JOIN cust_main ON (cust_pkg.custnum = cust_main.custnum)
      JOIN part_pkg USING (pkgpart) '.
      join_optionnames_int(qw(
        is_broadband technology 
        is_consumer
        )).
      join_optionnames(qw(broadband_downstream broadband_upstream))
  ;
  my @where = (
    active_on($date),
    is_fixed_broadband()
  );
  push @where, "cust_main.agentnum = $agentnum" if $agentnum;
  my $group_by = "$censustract, technology, broadband_downstream, broadband_upstream ";
  my $order_by = $group_by;

  "SELECT ".join(', ', @select) . "
  FROM $from
  WHERE ".join(' AND ', @where)."
  GROUP BY $group_by
  ORDER BY $order_by
  ";

}

sub fbs_check {
  my $class = shift;
  my $row = shift;
  my %e;
  #censustract
  if ( length($row->[0]) == 0 ) {
    $e{'censustract_null'} = 'The package location has no census tract.';
  } elsif ($row->[0] !~ /^\d{11}$/) {
    $e{'censustract_bad'} = 'The census tract must be exactly 11 digits.';
  }

  #technology
  if ( length($row->[1]) == 0 ) {
    $e{'technology_null'} = 'The package has no technology type.';
  }

  #speeds
  if ( length($row->[2]) == 0 or length($row->[3]) == 0 ) {
    $e{'speed_null'} = 'The package is missing downstream or upstream speeds.';
  } elsif ( $row->[2] !~ /^\d*(\.\d+)?$/ or $row->[3] !~ /^\d*(\.\d+)?$/ ) {
    $e{'speed_bad'} = 'The downstream and upstream speeds must be decimal numbers in Mbps.';
  } elsif ( $row->[2] == 0 or $row->[3] == 0 ) {
    $e{'speed_zero'} = 'The downstream and upstream speeds cannot be zero.';
  }

  return \%e;
}

sub fvs_sql {
  my $class = shift;
  my %opt = @_;
  my $date = $opt{date} || time;
  my $agentnum = $opt{agentnum};
  my $q = $opt{ignore_quantity} ? '1' : 'COALESCE(cust_pkg.quantity, 1)';
  my $censustract = "replace(cust_location.censustract, '.', '')";

  my @select = (
    "$censustract AS censustract",
    # VoIP indicator (0 for non-VoIP, 1 for VoIP)
    'COALESCE(is_voip, 0)',
    # number of lines/subscriptions
    "SUM($q * (CASE WHEN is_voip = 1 THEN 1 ELSE phone_lines END))",
    # consumer grade lines/subscriptions
    "SUM($q * COALESCE(is_consumer,0) * (CASE WHEN is_voip = 1 THEN voip_sessions ELSE phone_lines END))",
  );
  push @select, "array_to_string(array_agg(pkgnum), ',')" if $opt{detail};

  my $from = 'cust_pkg
    JOIN cust_location ON (cust_pkg.locationnum = cust_location.locationnum)
    JOIN cust_main ON (cust_pkg.custnum = cust_main.custnum)
    JOIN part_pkg USING (pkgpart) '.
    join_optionnames_int(qw(
      is_phone is_voip is_consumer phone_lines voip_sessions
      ))
  ;

  my @where = (
    active_on($date),
    "(is_voip = 1 OR is_phone = 1)",
  );
  push @where, "cust_main.agentnum = $agentnum" if $agentnum;
  my $group_by = "$censustract, COALESCE(is_voip, 0)";
  my $order_by = $group_by;

  "SELECT ".join(', ', @select) . "
  FROM $from
  WHERE ".join(' AND ', @where)."
  GROUP BY $group_by
  ORDER BY $order_by
  ";

}

sub fvs_check {
  my $class = shift;
  my $row = shift;
  my %e;
  #censustract
  if ( length($row->[0]) == 0 ) {
    $e{'censustract_null'} = 'The package location has no census tract.';
  } elsif ($row->[0] !~ /^\d{11}$/) {
    $e{'censustract_bad'} = 'The census tract must be exactly 11 digits.';
  }
  return \%e;
}

sub lts_sql {
  my $class = shift;
  my %opt = @_;
  my $date = $opt{date} || time;
  my $agentnum = $opt{agentnum};
  my $q = $opt{ignore_quantity} ? '1' : 'COALESCE(cust_pkg.quantity, 1)';

  my @select = (
    "state.fips",
    "SUM($q * phone_vges)",
    "SUM($q * phone_circuits)",
    "SUM($q * phone_lines)",
    "SUM($q * (CASE WHEN is_broadband = 1 THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN is_consumer = 1 AND phone_longdistance IS NULL THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN is_consumer = 1 AND phone_longdistance = 1 THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN is_consumer IS NULL AND phone_longdistance IS NULL THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN is_consumer IS NULL AND phone_longdistance = 1 THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN phone_localloop = 'owned' THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN phone_localloop = 'leased' THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN phone_localloop = 'resale' THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN media = 'Fiber' THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN media = 'Cable Modem' THEN phone_lines ELSE 0 END))",
    "SUM($q * (CASE WHEN media = 'Fixed Wireless' THEN phone_lines ELSE 0 END))",
  );
  push @select, "array_to_string(array_agg(pkgnum),',')" if $opt{detail};

  my $from =
    'cust_pkg
      JOIN cust_location ON (cust_pkg.locationnum = cust_location.locationnum)
      JOIN state USING (country, state)
      JOIN cust_main ON (cust_pkg.custnum = cust_main.custnum)
      JOIN part_pkg USING (pkgpart) '.
      join_optionnames_int(qw(
        is_phone is_broadband
        phone_vges phone_circuits phone_lines
        is_consumer phone_longdistance
        )).
      join_optionnames('media', 'phone_localloop')
  ;
  my @where = (
    active_on($date),
    "is_phone = 1",
  );
  push @where, "cust_main.agentnum = $agentnum" if $agentnum;
  my $group_by = 'state.fips';
  my $order_by = $group_by;

  "SELECT ".join(', ', @select) . "
  FROM $from
  WHERE ".join(' AND ', @where)."
  GROUP BY $group_by
  ORDER BY $order_by
  ";
}

# voip_sql has a special case: the fifth column, "Voice with Internet",
# must test whether there are _any_ broadband packages at the same location,
# not just whether this package is both VoIP and broadband.

sub voip_sql {
  my $class = shift;
  my %opt = @_;
  my $date = $opt{date} || time;
  my $agentnum = $opt{agentnum};
  my $q = $opt{ignore_quantity} ? '1' : 'COALESCE(cust_pkg.quantity, 1)';

  # subquery to test whether there's an is_broadband package at this location
  my $broadband_pkg =
    "SELECT 1 FROM cust_pkg AS broadband_pkg
    WHERE broadband_pkg.locationnum = cust_pkg.locationnum 
    AND EXISTS(SELECT 1 FROM part_pkg_fcc_option
      WHERE fccoptionname = 'is_broadband'
      AND part_pkg_fcc_option.pkgpart = broadband_pkg.pkgpart
      AND optionvalue = '1')
    AND ".  active_on( $date );

  my $has_broadband = "EXISTS($broadband_pkg)";

  my @select = (
    "state.fips",
    # OTT, OTT + consumer
    "SUM($q * (CASE WHEN (voip_lastmile IS NULL) THEN 1 ELSE 0 END))",
    "SUM($q * (CASE WHEN (voip_lastmile IS NULL AND is_consumer = 1) THEN 1 ELSE 0 END))",
    # non-OTT: total, consumer, broadband bundle, media types
    "SUM($q * (CASE WHEN (voip_lastmile = 1) THEN 1 ELSE 0 END))",
    "SUM($q * (CASE WHEN (voip_lastmile = 1 AND is_consumer = 1) THEN 1 ELSE 0 END))",
    "SUM($q * (CASE WHEN (voip_lastmile = 1 AND $has_broadband) THEN 1 ELSE 0 END))",
    "SUM($q * (CASE WHEN (voip_lastmile = 1 AND media = 'Copper') THEN 1 ELSE 0 END))",
    "SUM($q * (CASE WHEN (voip_lastmile = 1 AND media = 'Fiber') THEN 1 ELSE 0 END))",
    "SUM($q * (CASE WHEN (voip_lastmile = 1 AND media = 'Cable Modem') THEN 1 ELSE 0 END))",
    "SUM($q * (CASE WHEN (voip_lastmile = 1 AND media = 'Fixed Wireless') THEN 1 ELSE 0 END))",
    "SUM($q * (CASE WHEN (voip_lastmile = 1 AND media NOT IN('Copper', 'Fiber', 'Cable Modem', 'Fixed Wireless') ) THEN 1 ELSE 0 END))",
  );
  push @select, "array_to_string(array_agg(pkgnum),',')" if $opt{detail};

  my $from =
    'cust_pkg
      JOIN cust_location ON (cust_pkg.locationnum = cust_location.locationnum)
      JOIN state USING (country, state)
      JOIN cust_main ON (cust_pkg.custnum = cust_main.custnum)
      JOIN part_pkg USING (pkgpart) '.
      join_optionnames_int(
        qw( is_voip is_consumer voip_lastmile)
      ).
      join_optionnames('media')
  ;
  my @where = (
    active_on($date),
    "is_voip = 1",
  );
  push @where, "cust_main.agentnum = $agentnum" if $agentnum;
  my $group_by = 'state.fips';
  my $order_by = $group_by;

  "SELECT ".join(', ', @select) . "
  FROM $from
  WHERE ".join(' AND ', @where)."
  GROUP BY $group_by
  ORDER BY $order_by
  ";
}

sub mbs_sql {
  my $class = shift;
  my %opt = @_;
  my $date = $opt{date} || time;
  my $agentnum = $opt{agentnum};
  my $q = $opt{ignore_quantity} ? '1' : 'COALESCE(cust_pkg.quantity, 1)';

  my @select = (
    'state.fips',
    'broadband_downstream',
    'broadband_upstream',
    "SUM($q)",
    "SUM(COALESCE(is_consumer, 0) * $q)",
  );
  push @select, "array_to_string(array_agg(pkgnum),',')" if $opt{detail};

  my $from =
    'cust_pkg
      JOIN cust_location ON (cust_pkg.locationnum = cust_location.locationnum)
      JOIN state USING (country, state)
      JOIN cust_main ON (cust_pkg.custnum = cust_main.custnum)
      JOIN part_pkg USING (pkgpart) '.
      join_optionnames_int(qw(
        is_broadband technology
        is_consumer
        )).
      join_optionnames(qw(broadband_downstream broadband_upstream))
  ;
  my @where = (
    active_on($date),
    is_mobile_broadband()
  );
  push @where, "cust_main.agentnum = $agentnum" if $agentnum;
  my $group_by = 'state.fips, broadband_downstream, broadband_upstream ';
  my $order_by = $group_by;

  "SELECT ".join(', ', @select) . "
  FROM $from
  WHERE ".join(' AND ', @where)."
  GROUP BY $group_by
  ORDER BY $order_by
  ";
}

sub mvs_sql {
  my $class = shift;
  my %opt = @_;
  my $date = $opt{date} || time;
  my $agentnum = $opt{agentnum};
  my $q = $opt{ignore_quantity} ? '1' : 'COALESCE(cust_pkg.quantity, 1)';

  my @select = (
    'state.fips',
    "SUM($q)",
    "SUM($q * COALESCE(mobile_direct,0))",
  );
  push @select, "array_to_string(array_agg(pkgnum),',')" if $opt{detail};

  my $from =
    'cust_pkg
      JOIN cust_location ON (cust_pkg.locationnum = cust_location.locationnum)
      JOIN state USING (country, state)
      JOIN cust_main ON (cust_pkg.custnum = cust_main.custnum)
      JOIN part_pkg USING (pkgpart) '.
      join_optionnames_int(qw( is_mobile mobile_direct) )
  ;
  my @where = (
    active_on($date),
    'is_mobile = 1'
  );
  push @where, "cust_main.agentnum = $agentnum" if $agentnum;
  my $group_by = 'state.fips';
  my $order_by = $group_by;

  "SELECT ".join(', ', @select) . "
  FROM $from
  WHERE ".join(' AND ', @where)."
  GROUP BY $group_by
  ORDER BY $order_by
  ";
}

=item parts

Returns a Tie::IxHash reference of the internal short names used for the 
report sections ('fbd', 'mbs', etc.) to the full names.

=cut

tie our %parts, 'Tie::IxHash', (
  fbd   => 'Fixed Broadband Deployment',
  fbs   => 'Fixed Broadband Subscription',
  fvs   => 'Fixed Voice Subscription',
  lts   => 'Local Exchange Telephone Subscription',
  voip  => 'Interconnected VoIP Subscription',
  mbd   => 'Mobile Broadband Deployment',
  mbsa  => 'Mobile Broadband Service Availability',
  mbs   => 'Mobile Broadband Subscription',
  mvd   => 'Mobile Voice Deployment',
  mvs   => 'Mobile Voice Subscription',
);

sub parts {
  Storable::dclone(\%parts);
}

=item part_table SECTION

Returns the name of the primary table that's aggregated in the report section 
SECTION. The last column of the report returned by the L</report> method is 
a comma-separated list of record numbers, in this table, that are included in
the report line item.

=cut

sub part_table {
  my ($class, $part) = @_;
  if ($part eq 'fbd') {
    return 'deploy_zone_block';
  } else {
    return 'cust_pkg';
  } # add other cases as we add more of the deployment/availability reports
}

1;
