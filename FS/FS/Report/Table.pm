package FS::Report::Table;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Report;
use Time::Local qw( timelocal );
use FS::UID qw( dbh driver_name );
use FS::Report::Table;
use FS::CurrentUser;

$DEBUG = 0; # turning this on will trace all SQL statements, VERY noisy
@ISA = qw( FS::Report );

=head1 NAME

FS::Report::Table - Tables of report data

=head1 SYNOPSIS

See the more specific report objects, currently only 
FS::Report::Table::Monthly and FS::Report::Table::Daily.

=head1 OBSERVABLES

The common interface for an observable named 'foo' is:

$report->foo($startdate, $enddate, $agentnum, %options)

This returns a scalar value for foo, over the period from 
$startdate to $enddate, limited to agent $agentnum, subject to 
options in %opt.

=over 4

=item invoiced: The total amount charged on all invoices.

=cut

sub invoiced { #invoiced
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  $self->scalar_sql("
    SELECT SUM(charged)
      FROM cust_bill
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum)
      . (%opt ? $self->for_custnum(%opt) : '')
  );
  
}

=item netsales: invoiced - netcredits

=cut

sub netsales { #net sales
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

    $self->invoiced($speriod,$eperiod,$agentnum,%opt)
  - $self->netcredits($speriod,$eperiod,$agentnum,%opt);
}

=item cashflow: payments - refunds

=cut

sub cashflow {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

    $self->payments($speriod, $eperiod, $agentnum, %opt)
  - $self->refunds( $speriod, $eperiod, $agentnum, %opt);
}

=item netcashflow: payments - netrefunds

=cut

sub netcashflow {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;

    $self->receipts($speriod, $eperiod, $agentnum)
  - $self->netrefunds( $speriod, $eperiod, $agentnum);
}

=item payments: The sum of payments received in the period.

=cut

sub payments {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;
  $self->scalar_sql("
    SELECT SUM(paid)
      FROM cust_pay
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum)
      . (%opt ? $self->for_custnum(%opt) : '')
  );
}

=item credits: The sum of credits issued in the period.

=cut

sub credits {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $self->scalar_sql("
    SELECT SUM(amount)
      FROM cust_credit
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum)
  );
}

=item refunds: The sum of refunds paid in the period.

=cut

sub refunds {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;
  $self->scalar_sql("
    SELECT SUM(refund)
      FROM cust_refund
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum)
      . (%opt ? $self->for_custnum(%opt) : '')
  );
}

=item netcredits: The sum of credit applications to invoices in the period.

=cut

sub netcredits {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;
  $self->scalar_sql("
    SELECT SUM(cust_credit_bill.amount)
      FROM cust_credit_bill
        LEFT JOIN cust_bill USING ( invnum  )
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent( $speriod,
                                                $eperiod,
                                                $agentnum,
                                                'cust_bill._date'
                                              )
      . (%opt ? $self->for_custnum(%opt) : '')
  );
}

=item receipts: The sum of payment applications to invoices in the period.

=cut

sub receipts { #net payments
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $self->scalar_sql("
    SELECT SUM(cust_bill_pay.amount)
      FROM cust_bill_pay
        LEFT JOIN cust_bill USING ( invnum  )
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent( $speriod,
                                                $eperiod,
                                                $agentnum,
                                                'cust_bill._date'
                                              )
  );
}

=item netrefunds: The sum of refund applications to credits in the period.

=cut

sub netrefunds {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $self->scalar_sql("
    SELECT SUM(cust_credit_refund.amount)
      FROM cust_credit_refund
        LEFT JOIN cust_credit USING ( crednum  )
        LEFT JOIN cust_main   USING ( custnum )
      WHERE ". $self->in_time_period_and_agent( $speriod,
                                                $eperiod,
                                                $agentnum,
                                                'cust_credit._date'
                                              )
  );
}

#XXX docs

#these should be auto-generated or $AUTOLOADed or something
sub invoiced_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->invoiced($speriod, $eperiod, $agentnum);
}

sub netsales_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->netsales($speriod, $eperiod, $agentnum);
}

sub receipts_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->receipts($speriod, $eperiod, $agentnum);
}

sub payments_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->payments($speriod, $eperiod, $agentnum);
}

sub credits_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->credits($speriod, $eperiod, $agentnum);
}

sub netcredits_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->netcredits($speriod, $eperiod, $agentnum);
}

sub cashflow_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->cashflow($speriod, $eperiod, $agentnum);
}

sub netcashflow_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->cashflow($speriod, $eperiod, $agentnum);
}

sub refunds_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->refunds($speriod, $eperiod, $agentnum);
}

sub netrefunds_12mo {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $speriod = $self->_subtract_11mo($speriod);
  $self->netrefunds($speriod, $eperiod, $agentnum);
}


#not being too bad with the false laziness
sub _subtract_11mo {
  my($self, $time) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($time) )[0,1,2,3,4,5];
  $mon -= 11;
  if ( $mon < 0 ) { $mon+=12; $year--; }
  timelocal($sec,$min,$hour,$mday,$mon,$year);
}

=item cust_pkg_setup_cost: The total setup costs of packages setup in the period

'classnum': limit to this package class.

=cut

sub cust_pkg_setup_cost {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;
  my $where = '';
  my $comparison = '';
  if ( $opt{'classnum'} =~ /^(\d+)$/ ) {
    if ( $1 == 0 ) {
      $comparison = 'IS NULL';
    }
    else {
      $comparison = "= $1";
    }
    $where = "AND part_pkg.classnum $comparison";
  }
  $agentnum ||= $opt{'agentnum'};

  my $total_sql = " SELECT SUM(part_pkg.setup_cost) ";
  $total_sql .= " FROM cust_pkg 
             LEFT JOIN cust_main USING ( custnum )
             LEFT JOIN part_pkg  USING ( pkgpart )
                  WHERE pkgnum != 0
                  $where
                  AND ".$self->in_time_period_and_agent(
                    $speriod, $eperiod, $agentnum, 'cust_pkg.setup');
  return $self->scalar_sql($total_sql);
}

=item cust_pkg_recur_cust: the total recur costs of packages in the period

'classnum': limit to this package class.

=cut

sub cust_pkg_recur_cost {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;
  my $where = '';
  my $comparison = '';
  if ( $opt{'classnum'} =~ /^(\d+)$/ ) {
    if ( $1 == 0 ) {
      $comparison = 'IS NULL';
    }
    else {
      $comparison = "= $1";
    }
    $where = " AND part_pkg.classnum $comparison";
  }
  $agentnum ||= $opt{'agentnum'};
  # duplication of in_time_period_and_agent
  # because we do it a little differently here
  $where .= " AND cust_main.agentnum = $agentnum" if $agentnum;
  $where .= " AND ".
          $FS::CurrentUser::CurrentUser->agentnums_sql('table' => 'cust_main');

  my $total_sql = " SELECT SUM(part_pkg.recur_cost) ";
  $total_sql .= " FROM cust_pkg
             LEFT JOIN cust_main USING ( custnum )
             LEFT JOIN part_pkg  USING ( pkgpart )
                  WHERE pkgnum != 0
                  $where
                  AND cust_pkg.setup < $eperiod
                  AND (cust_pkg.cancel > $speriod OR cust_pkg.cancel IS NULL)
                  ";
  return $self->scalar_sql($total_sql);
}

=item cust_bill_pkg: the total package charges on invoice line items.

'charges': limit the type of charges included (setup, recur, usage).
Should be a string containing one or more of 'S', 'R', or 'U'; if 
unspecified, defaults to all three.

'classnum': limit to this package class.

'use_override': for line items generated by an add-on package, use the class
of the add-on rather than the base package.

'freq': limit to packages with this frequency.  Currently uses the part_pkg 
frequency, so term discounted packages may give odd results.

'distribute': for non-monthly recurring charges, ignore the invoice 
date.  Instead, consider the line item's starting/ending dates.  Determine 
the fraction of the line item duration that falls within the specified 
interval and return that fraction of the recurring charges.  This is 
somewhat experimental.

'project': enable if this is a projected period.  This is very experimental.

=cut

sub cust_bill_pkg {
  my $self = shift;
  my( $speriod, $eperiod, $agentnum, %opt ) = @_;

  my %charges = map {$_=>1} split('', $opt{'charges'} || 'SRU');

  my $sum = 0;
  $sum += $self->cust_bill_pkg_setup(@_) if $charges{S};
  $sum += $self->cust_bill_pkg_recur(@_) if $charges{R};
  $sum += $self->cust_bill_pkg_detail(@_) if $charges{U};
  $sum;
}

my $cust_bill_pkg_join = '
    LEFT JOIN cust_bill USING ( invnum )
    LEFT JOIN cust_main USING ( custnum )
    LEFT JOIN cust_pkg USING ( pkgnum )
    LEFT JOIN part_pkg USING ( pkgpart )
    LEFT JOIN part_pkg AS override ON pkgpart_override = override.pkgpart';

sub cust_bill_pkg_setup {
  my $self = shift;
  my ($speriod, $eperiod, $agentnum, %opt) = @_;
  # no projecting setup fees--use real invoices only
  # but evaluate this anyway, because the design of projection is that
  # if there are somehow real setup fees in the future, we want to count
  # them

  $agentnum ||= $opt{'agentnum'};

  my @where = (
    'pkgnum != 0',
    $self->with_classnum($opt{'classnum'}, $opt{'use_override'}),
    $self->in_time_period_and_agent($speriod, $eperiod, $agentnum),
  );

  my $total_sql = "SELECT COALESCE(SUM(cust_bill_pkg.setup),0)
  FROM cust_bill_pkg
  $cust_bill_pkg_join
  WHERE " . join(' AND ', grep $_, @where);

  $self->scalar_sql($total_sql);
}

sub cust_bill_pkg_recur {
  my $self = shift;
  my ($speriod, $eperiod, $agentnum, %opt) = @_;

  $agentnum ||= $opt{'agentnum'};
  my $cust_bill_pkg = $opt{'project'} ? 'v_cust_bill_pkg' : 'cust_bill_pkg';

  my @where = (
    'pkgnum != 0',
    $self->with_classnum($opt{'classnum'}, $opt{'use_override'}),
  );

  # subtract all usage from the line item regardless of date
  my $item_usage;
  if ( $opt{'project'} ) {
    $item_usage = 'usage'; #already calculated
  }
  else {
    $item_usage = '( SELECT COALESCE(SUM(amount),0)
      FROM cust_bill_pkg_detail
      WHERE cust_bill_pkg_detail.billpkgnum = cust_bill_pkg.billpkgnum )';
  }
  my $recur_fraction = '';

  if ( $opt{'distribute'} ) {
    push @where, "cust_main.agentnum = $agentnum" if $agentnum;
    push @where,
      "$cust_bill_pkg.sdate < $eperiod",
      "$cust_bill_pkg.edate > $speriod",
    ;
    # the fraction of edate - sdate that's within [speriod, eperiod]
    $recur_fraction = " * 
      CAST(LEAST($eperiod, $cust_bill_pkg.edate) - 
       GREATEST($speriod, $cust_bill_pkg.sdate) AS DECIMAL) / 
      ($cust_bill_pkg.edate - $cust_bill_pkg.sdate)";
  }
  else {
    # we don't want to have to create v_cust_bill
    my $_date = $opt{'project'} ? 'v_cust_bill_pkg._date' : 'cust_bill._date';
    push @where, 
      $self->in_time_period_and_agent($speriod, $eperiod, $agentnum, $_date);
  }

  my $total_sql = 'SELECT '.
  "COALESCE(SUM(($cust_bill_pkg.recur - $item_usage) $recur_fraction),0)
  FROM $cust_bill_pkg 
  $cust_bill_pkg_join
  WHERE ".join(' AND ', grep $_, @where);

  $self->scalar_sql($total_sql);
}

=item cust_bill_pkg_detail: the total usage charges in detail lines.

Arguments as for C<cust_bill_pkg>, plus:

'usageclass': limit to this usage class number.

=cut

sub cust_bill_pkg_detail {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  my @where = ( "cust_bill_pkg.pkgnum != 0" );

  $agentnum ||= $opt{'agentnum'};

  push @where,
    $self->with_classnum($opt{'classnum'}, $opt{'use_override'}),
    $self->with_usageclass($opt{'usageclass'}),
    ;

  if ( $opt{'distribute'} ) {
    # then limit according to the usage time, not the billing date
    push @where, $self->in_time_period_and_agent($speriod, $eperiod, $agentnum,
      'cust_bill_pkg_detail.startdate'
    );
  }
  else {
    push @where, $self->in_time_period_and_agent($speriod, $eperiod, $agentnum,
      'cust_bill._date'
    );
  }

  my $total_sql = " SELECT SUM(amount) ";

  $total_sql .=
    " / CASE COUNT(cust_pkg.*) WHEN 0 THEN 1 ELSE COUNT(cust_pkg.*) END "
      if $opt{average_per_cust_pkg};

  $total_sql .=
    " FROM cust_bill_pkg_detail
        LEFT JOIN cust_bill_pkg USING ( billpkgnum )
        LEFT JOIN cust_bill ON cust_bill_pkg.invnum = cust_bill.invnum
        LEFT JOIN cust_main USING ( custnum )
        LEFT JOIN cust_pkg ON cust_bill_pkg.pkgnum = cust_pkg.pkgnum
        LEFT JOIN part_pkg USING ( pkgpart )
        LEFT JOIN part_pkg AS override ON pkgpart_override = override.pkgpart
      WHERE ".join( ' AND ', grep $_, @where );

  $self->scalar_sql($total_sql);
  
}

sub cust_bill_pkg_discount {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  #my $where = '';
  #my $comparison = '';
  #if ( $opt{'classnum'} =~ /^(\d+)$/ ) {
  #  if ( $1 == 0 ) {
  #    $comparison = "IS NULL";
  #  } else {
  #    $comparison = "= $1";
  #  }
  #
  #  if ( $opt{'use_override'} ) {
  #    $where = "(
  #      part_pkg.classnum $comparison AND pkgpart_override IS NULL OR
  #      override.classnum $comparison AND pkgpart_override IS NOT NULL
  #    )";
  #  } else {
  #    $where = "part_pkg.classnum $comparison";
  #  }
  #}

  $agentnum ||= $opt{'agentnum'};

  my $total_sql =
    " SELECT COALESCE( SUM( cust_bill_pkg_discount.amount ), 0 ) ";

  #$total_sql .=
  #  " / CASE COUNT(cust_pkg.*) WHEN 0 THEN 1 ELSE COUNT(cust_pkg.*) END "
  #    if $opt{average_per_cust_pkg};

  $total_sql .=
    " FROM cust_bill_pkg_discount
        LEFT JOIN cust_bill_pkg USING ( billpkgnum )
        LEFT JOIN cust_bill USING ( invnum )
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum);
  #      LEFT JOIN cust_pkg_discount USING ( pkgdiscountnum )
  #      LEFT JOIN discount USING ( discountnum )
  #      LEFT JOIN cust_pkg USING ( pkgnum )
  #      LEFT JOIN part_pkg USING ( pkgpart )
  #      LEFT JOIN part_pkg AS override ON pkgpart_override = override.pkgpart
  
  return $self->scalar_sql($total_sql);

}

sub setup_pkg  { shift->pkg_field( @_, 'setup' ); }
sub susp_pkg   { shift->pkg_field( @_, 'susp'  ); }
sub cancel_pkg { shift->pkg_field( @_, 'cancel'); }
 
sub pkg_field {
  my( $self, $speriod, $eperiod, $agentnum, $field ) = @_;
  $self->scalar_sql("
    SELECT COUNT(*) FROM cust_pkg
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent( $speriod,
                                                $eperiod,
                                                $agentnum,
                                                "cust_pkg.$field",
                                              )
  );

}

#this is going to be harder..
#sub unsusp_pkg {
#  my( $self, $speriod, $eperiod, $agentnum ) = @_;
#  $self->scalar_sql("
#    SELECT COUNT(*) FROM h_cust_pkg
#      WHERE 
#
#}

sub in_time_period_and_agent {
  my( $self, $speriod, $eperiod, $agentnum ) = splice(@_, 0, 4);
  my $col = @_ ? shift() : '_date';

  my $sql = "$col >= $speriod AND $col < $eperiod";

  #agent selection
  $sql .= " AND cust_main.agentnum = $agentnum"
    if $agentnum;

  #agent virtualization
  $sql .= ' AND '.
          $FS::CurrentUser::CurrentUser->agentnums_sql( 'table'=>'cust_main' );

  $sql;
}

sub for_custnum {
    my ( $self, %opt ) = @_;
    return '' unless $opt{'custnum'};
    $opt{'custnum'} =~ /^\d+$/ ? " and custnum = $opt{custnum} " : '';
}

sub with_classnum {
  my $self = shift;
  my ($classnum, $use_override) = @_;
  return '' unless $classnum =~ /^\d+$/;
  my $comparison;
  if ( $classnum == 0 ) {
    $comparison = 'IS NULL';
  }
  else {
    $comparison = "= $classnum";
  }
  if ( $use_override ) {
    return "(
      part_pkg.classnum $comparison AND pkgpart_override IS NULL OR
      override.classnum $comparison AND pkgpart_override IS NOT NULL
    )";
  }
  else {
    return "part_pkg.classnum $comparison";
  }
}

sub with_usageclass {
  my $self = shift;
  my ($classnum, $use_override) = @_;
  return '' unless $classnum =~ /^\d+$/;
  my $comparison;
  if ( $classnum == 0 ) {
    $comparison = 'IS NULL';
  }
  else {
    $comparison = "= $classnum";
  }
  return "cust_bill_pkg_detail.classnum $comparison";
}

sub scalar_sql {
  my( $self, $sql ) = ( shift, shift );
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  warn "FS::Report::Table\n$sql\n" if $DEBUG;
  $sth->execute
    or die "Unexpected error executing statement $sql: ". $sth->errstr;
  $sth->fetchrow_arrayref->[0] || 0;
}

=back

=head1 METHODS

=over 4

=item init_projection

Sets up for future projection of all observables on the report.  Currently 
this is limited to 'cust_bill_pkg'.

=cut

sub init_projection {
  # this is weird special case stuff--some redesign may be needed 
  # to use it for anything else
  my $self = shift;

  if ( driver_name ne 'Pg' ) {
    # also database-specific for now
    die "projection reports not supported on this platform";
  }

  my %items = map {$_ => 1} @{ $self->{items} };
  if ($items{'cust_bill_pkg'}) {
    my $dbh = dbh;
    # v_ for 'virtual'
    my @sql = (
      # could use TEMPORARY TABLE but we're already transaction-protected
      'DROP TABLE IF EXISTS v_cust_bill_pkg',
      'CREATE TABLE v_cust_bill_pkg ' . 
       '(LIKE cust_bill_pkg,
          usage numeric(10,2), _date integer, expire integer)',
      # XXX this should be smart enough to take only the ones with 
      # sdate/edate overlapping the ROI, for performance
      "INSERT INTO v_cust_bill_pkg ( 
        SELECT cust_bill_pkg.*,
          (SELECT COALESCE(SUM(amount),0) FROM cust_bill_pkg_detail 
          WHERE cust_bill_pkg_detail.billpkgnum = cust_bill_pkg.billpkgnum),
          cust_bill._date,
          cust_pkg.expire
        FROM cust_bill_pkg $cust_bill_pkg_join
      )",
    );
    foreach my $sql (@sql) {
      warn "[init_projection] $sql\n" if $DEBUG;
      $dbh->do($sql) or die $dbh->errstr;
    }
  }
}

=item extend_projection START END

Generates data for the next period of projection.  This will be called 
for sequential periods where the END of one equals the START of the next
(with no gaps).

=cut

sub extend_projection {
  my $self = shift;
  my ($speriod, $eperiod) = @_;
  my %items = map {$_ => 1} @{ $self->{items} };
  if ($items{'cust_bill_pkg'}) {
    # append, head-to-tail, new line items identical to any that end within the 
    # period (and aren't expiring)
    my @fields = ( FS::cust_bill_pkg->fields, qw( usage _date expire ) );
    my $insert_fields = join(',', @fields);
    #advance (sdate, edate) by one billing period
    foreach (@fields) {
      if ($_ eq 'edate') {
        $_ = '(edate + (edate - sdate)) AS edate' #careful of integer overflow
      }
      elsif ($_ eq 'sdate') {
        $_ = 'edate AS sdate'
      }
      elsif ($_ eq 'setup') {
        $_ = '0 AS setup' #because recurring only
      }
      elsif ($_ eq '_date') {
        $_ = '(_date + (edate - sdate)) AS _date'
      }
    }
    my $select_fields = join(',', @fields);
    my $dbh = dbh;
    my $sql =
      "INSERT INTO v_cust_bill_pkg ($insert_fields)
        SELECT $select_fields FROM v_cust_bill_pkg
        WHERE edate >= $speriod AND edate < $eperiod 
              AND recur > 0
              AND (expire IS NULL OR expire > edate)";
    warn "[extend_projection] $sql\n" if $DEBUG;
    my $rows = $dbh->do($sql) or die $dbh->errstr;
    warn "[extend_projection] $rows rows\n" if $DEBUG;
  }
}

=head1 BUGS

Documentation.

=head1 SEE ALSO

L<FS::Report::Table::Monthly>, reports in the web interface.

=cut

1;
