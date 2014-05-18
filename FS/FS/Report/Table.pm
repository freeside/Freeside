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

=item signups: The number of customers signed up.  Options are:

- cust_classnum: limit to this customer class
- pkg_classnum: limit to customers with a package of this class.  If this is
  an arrayref, it's an ANY match.
- refnum: limit to this advertising source
- indirect: boolean; limit to customers that have a referral_custnum that
  matches the advertising source

=cut

sub signups {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;
  my @where = ( $self->in_time_period_and_agent($speriod, $eperiod, $agentnum, 
      'cust_main.signupdate')
  );
  my $join = '';
  if ( $opt{'indirect'} ) {
    $join = " JOIN cust_main AS referring_cust_main".
            " ON (cust_main.referral_custnum = referring_cust_main.custnum)";

    if ( $opt{'refnum'} ) {
      push @where, "referring_cust_main.refnum = ".$opt{'refnum'};
    }
  }
  elsif ( $opt{'refnum'} ) {
    push @where, "refnum = ".$opt{'refnum'};
  }

  push @where, $self->with_cust_classnum(%opt);
  if ( $opt{'pkg_classnum'} ) {
    my $classnum = $opt{'pkg_classnum'};
    $classnum = [ $classnum ] unless ref $classnum;
    @$classnum = grep /^\d+$/, @$classnum;
    if (@$classnum) {
      my $in = 'IN ('. join(',', @$classnum). ')';
      push @where,
        "EXISTS(SELECT 1 FROM cust_pkg JOIN part_pkg USING (pkgpart) ".
               "WHERE cust_pkg.custnum = cust_main.custnum ".
               "AND part_pkg.classnum $in".
               ")";
    }
  }

  $self->scalar_sql(
    "SELECT COUNT(*) FROM cust_main $join WHERE ".join(' AND ', @where)
  );
}

=item invoiced: The total amount charged on all invoices.

=cut

sub invoiced { #invoiced
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  my $sql = 'SELECT SUM(cust_bill.charged) FROM cust_bill';
  if ( $opt{'setuprecur'} ) {
    $sql = 'SELECT SUM('.
            FS::cust_bill_pkg->charged_sql($speriod, $eperiod, %opt).
           ') FROM cust_bill_pkg JOIN cust_bill USING (invnum)';
  }

  $self->scalar_sql("
      $sql
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum).
               $self->for_opts(%opt)
  );
  
}

=item netsales: invoiced - netcredits

=cut

sub netsales { #net sales
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

    $self->invoiced(  $speriod, $eperiod, $agentnum, %opt)
  - $self->netcredits($speriod, $eperiod, $agentnum, %opt);
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
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

    $self->receipts(   $speriod, $eperiod, $agentnum, %opt)
  - $self->netrefunds( $speriod, $eperiod, $agentnum, %opt);
}

=item payments: The sum of payments received in the period.

=cut

sub payments {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;
  $self->scalar_sql("
    SELECT SUM(paid)
      FROM cust_pay
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum).
               $self->for_opts(%opt)
  );
}

=item credits: The sum of credits issued in the period.

=cut

sub credits {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;
  $self->scalar_sql("
    SELECT SUM(cust_credit.amount)
      FROM cust_credit
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum).
               $self->for_opts(%opt)
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
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum).
               $self->for_opts(%opt)
  );
}

=item netcredits: The sum of credit applications to invoices in the period.

=cut

sub netcredits {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  my $sql = 'SELECT SUM(cust_credit_bill.amount) FROM cust_credit_bill';
  if ( $opt{'setuprecur'} ) {
    $sql = 'SELECT SUM('.
            FS::cust_bill_pkg->credited_sql($speriod, $eperiod, %opt).
           ') FROM cust_bill_pkg';
  }

  $self->scalar_sql("
    $sql
        LEFT JOIN cust_bill USING ( invnum  )
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent( $speriod,
                                                $eperiod,
                                                $agentnum,
                                                'cust_bill._date'
                                              ).
               $self->for_opts(%opt)
  );
}

=item receipts: The sum of payment applications to invoices in the period.

=cut

sub receipts { #net payments
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  my $sql = 'SELECT SUM(cust_bill_pay.amount) FROM cust_bill_pay';
  if ( $opt{'setuprecur'} ) {
    $sql = 'SELECT SUM('.
            FS::cust_bill_pkg->paid_sql($speriod, $eperiod, %opt).
           ') FROM cust_bill_pkg';
  }

  $self->scalar_sql("
    $sql
        LEFT JOIN cust_bill USING ( invnum  )
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent( $speriod,
                                                $eperiod,
                                                $agentnum,
                                                'cust_bill._date'
                                              ).
               $self->for_opts(%opt)
  );
}

=item netrefunds: The sum of refund applications to credits in the period.

=cut

sub netrefunds {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;
  $self->scalar_sql("
    SELECT SUM(cust_credit_refund.amount)
      FROM cust_credit_refund
        LEFT JOIN cust_credit USING ( crednum  )
        LEFT JOIN cust_main   USING ( custnum )
      WHERE ". $self->in_time_period_and_agent( $speriod,
                                                $eperiod,
                                                $agentnum,
                                                'cust_credit._date'
                                              ).
               $self->for_opts(%opt)
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

  if ( $opt{'classnum'} ne '' ) {
    my $classnums = $opt{'classnum'};
    $classnums = [ $classnums ] if !ref($classnums);
    @$classnums = grep /^\d+$/, @$classnums;
    $where .= ' AND COALESCE(part_pkg.classnum,0) IN ('. join(',', @$classnums).
                                                    ')';
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

  if ( $opt{'classnum'} ne '' ) {
    my $classnums = $opt{'classnum'};
    $classnums = [ $classnums ] if !ref($classnums);
    @$classnums = grep /^\d+$/, @$classnums;
    $where .= ' AND COALESCE(part_pkg.classnum,0) IN ('. join(',', @$classnums).
                                                    ')';
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
    LEFT JOIN part_pkg AS override ON pkgpart_override = override.pkgpart
    LEFT JOIN part_fee USING ( feepart )';

sub cust_bill_pkg_setup {
  my $self = shift;
  my ($speriod, $eperiod, $agentnum, %opt) = @_;
  # no projecting setup fees--use real invoices only
  # but evaluate this anyway, because the design of projection is that
  # if there are somehow real setup fees in the future, we want to count
  # them

  $agentnum ||= $opt{'agentnum'};

  my @where = (
    '(pkgnum != 0 OR feepart IS NOT NULL)',
    $self->with_classnum($opt{'classnum'}, $opt{'use_override'}),
    $self->with_report_option(%opt),
    $self->in_time_period_and_agent($speriod, $eperiod, $agentnum),
  );

  # yuck, false laziness
  push @where, "cust_main.refnum = ". $opt{'refnum'} if $opt{'refnum'};

  push @where, $self->with_cust_classnum(%opt);

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
    '(pkgnum != 0 OR feepart IS NOT NULL)',
    $self->with_classnum($opt{'classnum'}, $opt{'use_override'}),
    $self->with_report_option(%opt),
  );

  push @where, 'cust_main.refnum = '. $opt{'refnum'} if $opt{'refnum'};

  push @where, $self->with_cust_classnum(%opt);

  # subtract all usage from the line item regardless of date
  my $item_usage;
  if ( $opt{'project'} ) {
    $item_usage = 'usage'; #already calculated
  }
  else {
    $item_usage = '( SELECT COALESCE(SUM(cust_bill_pkg_detail.amount),0)
      FROM cust_bill_pkg_detail
      WHERE cust_bill_pkg_detail.billpkgnum = cust_bill_pkg.billpkgnum )';
  }
  my $recur_fraction = '';

  if ( $opt{'distribute'} ) {
    $where[0] = 'pkgnum != 0'; # specifically exclude fees
    push @where, "cust_main.agentnum = $agentnum" if $agentnum;
    push @where,
      "$cust_bill_pkg.sdate <  $eperiod",
      "$cust_bill_pkg.edate >= $speriod",
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

  my @where = 
    ( "(cust_bill_pkg.pkgnum != 0 OR cust_bill_pkg.feepart IS NOT NULL)" );

  push @where, 'cust_main.refnum = '. $opt{'refnum'} if $opt{'refnum'};

  push @where, $self->with_cust_classnum(%opt);

  $agentnum ||= $opt{'agentnum'};

  push @where,
    $self->with_classnum($opt{'classnum'}, $opt{'use_override'}),
    $self->with_usageclass($opt{'usageclass'}),
    $self->with_report_option(%opt),
    ;

  if ( $opt{'distribute'} ) {
    # exclude fees
    $where[0] = 'cust_bill_pkg.pkgnum != 0';
    # and limit according to the usage time, not the billing date
    push @where, $self->in_time_period_and_agent($speriod, $eperiod, $agentnum,
      'cust_bill_pkg_detail.startdate'
    );
  }
  else {
    push @where, $self->in_time_period_and_agent($speriod, $eperiod, $agentnum,
      'cust_bill._date'
    );
  }

  my $total_sql = " SELECT SUM(cust_bill_pkg_detail.amount) ";

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
        LEFT JOIN part_fee USING ( feepart )
      WHERE ".join( ' AND ', grep $_, @where );

  $self->scalar_sql($total_sql);
  
}

sub cust_bill_pkg_discount {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  #need to do this the new multi-classnum way if it gets re-enabled
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

sub setup_pkg  { shift->pkg_field( 'setup',  @_ ); }
sub susp_pkg   { shift->pkg_field( 'susp',   @_ ); }
sub cancel_pkg { shift->pkg_field( 'cancel', @_ ); }
 
sub pkg_field {
  my( $self, $field, $speriod, $eperiod, $agentnum ) = @_;
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

sub for_opts {
    my ( $self, %opt ) = @_;
    my $sql = '';
    if ( $opt{'custnum'} =~ /^(\d+)$/ ) {
      $sql .= " and custnum = $1 ";
    }
    if ( $opt{'refnum'} =~ /^(\d+)$/ ) {
      $sql .= " and refnum = $1 ";
    }
    if ( my $where = $self->with_cust_classnum(%opt) ) {
      $sql .= " and $where";
    }

    $sql;
}

sub with_classnum {
  my ($self, $classnum, $use_override) = @_;
  return '' if $classnum eq '';

  $classnum = [ $classnum ] if !ref($classnum);
  @$classnum = grep /^\d+$/, @$classnum;
  my $in = 'IN ('. join(',', @$classnum). ')';

  my $expr = "
         ( COALESCE(part_pkg.classnum, 0) $in AND pkgpart_override IS NULL)
      OR ( COALESCE(part_fee.classnum, 0) $in AND feepart IS NOT NULL )";
  if ( $use_override ) {
    $expr .= "
      OR ( COALESCE(override.classnum, 0) $in AND pkgpart_override IS NOT NULL )";
  }
  "( $expr )";
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

sub with_report_option {
  my ($self, %opt) = @_;
  # %opt can contain:
  # - report_optionnum: a comma-separated list of numbers.  Zero means to 
  #   include packages with _no_ report classes.
  # - not_report_optionnum: a comma-separated list.  Packages that have 
  #   any of these report options will be excluded from the result.
  #   Zero does nothing.
  # - use_override: also matches line items that are add-ons to a package
  #   matching the report class.
  # - all_report_options: returns only packages that have ALL of the
  #   report classes listed in $num.  Otherwise, will return packages that 
  #   have ANY of those classes.

  my @num = ref($opt{'report_optionnum'})
                  ? @{ $opt{'report_optionnum'} }
                  : split(/\s*,\s*/, $opt{'report_optionnum'});
  my @not_num = ref($opt{'not_report_optionnum'})
                      ? @{ $opt{'not_report_optionnum'} }
                      : split(/\s*,\s*/, $opt{'not_report_optionnum'});
  my $null;
  $null = 1 if ( grep {$_ == 0} @num );
  @num = grep {$_ > 0} @num;
  @not_num = grep {$_ > 0} @not_num;

  # brute force
  my $table = $opt{'use_override'} ? 'override' : 'part_pkg';
  my $op = ' OR ';
  if ( $opt{'all_report_options'} ) {
    if ( @num and $null ) {
      return 'false'; # mutually exclusive criteria, so just bail out
    }
    $op = ' AND ';
  }
  my @where_num = map {
    "EXISTS(SELECT 1 FROM part_pkg_option ".
    "WHERE optionname = 'report_option_$_' ".
    "AND part_pkg_option.pkgpart = $table.pkgpart)"
  } @num;
  if ( $null ) {
    push @where_num, "NOT EXISTS(SELECT 1 FROM part_pkg_option ".
                     "WHERE optionname LIKE 'report_option_%' ".
                     "AND part_pkg_option.pkgpart = $table.pkgpart)";
  }
  my @where_not_num = map {
    "NOT EXISTS(SELECT 1 FROM part_pkg_option ".
    "WHERE optionname = 'report_option_$_' ".
    "AND part_pkg_option.pkgpart = $table.pkgpart)"
  } @not_num;

  my @where;
  if (@where_num) {
    push @where, '( '.join($op, @where_num).' )';
  }
  if (@where_not_num) {
    push @where, '( '.join(' AND ', @where_not_num).' )';
  }

  return @where;
  # this messes up totals
  #if ( $opt{'use_override'} ) {
  #  # then also allow the non-override package to match
  #  delete $opt{'use_override'};
  #  $comparison = "( $comparison OR " . $self->with_report_option(%opt) . ")";
  #}

}

sub with_cust_classnum {
  my ($self, %opt) = @_;
  if ( $opt{'cust_classnum'} ) {
    my $classnums = $opt{'cust_classnum'};
    $classnums = [ $classnums ] if !ref($classnums);
    @$classnums = grep /^\d+$/, @$classnums;
    return 'cust_main.classnum in('. join(',',@$classnums) .')'
      if @$classnums;
  }
  ();
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
          (SELECT COALESCE(SUM(cust_bill_pkg_detail.amount),0)
          FROM cust_bill_pkg_detail 
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
    # What we do here:
    # Find all line items that end after the start of the period (and have 
    # recurring fees, and don't expire before they end).  Choose the latest 
    # one for each package.  If it ends before the end of the period, copy
    # it forward by one billing period.
    # Repeat this until the latest line item for each package no longer ends
    # within the period.  This is certain to happen in finitely many 
    # iterations as long as freq > 0.
    # - Pg only, obviously.
    # - Gives bad results if freq_override is used.
    my @fields = ( FS::cust_bill_pkg->fields, qw( usage _date expire ) );
    my $insert_fields = join(',', @fields);
    my $add_freq = sub { # emulate FS::part_pkg::add_freq
      my $field = shift;
      "EXTRACT( EPOCH FROM TO_TIMESTAMP($field) + (CASE WHEN freq ~ E'\\\\D' ".
      "THEN freq ELSE freq || 'mon' END)::INTERVAL) AS $field";
    };
    foreach (@fields) {
      if ($_ eq 'edate') {
        $_ = $add_freq->('edate');
      }
      elsif ($_ eq 'sdate') {
        $_ = 'edate AS sdate'
      }
      elsif ($_ eq 'setup') {
        $_ = '0 AS setup' #because recurring only
      }
      elsif ($_ eq '_date') {
        $_ = $add_freq->('_date');
      }
    }
    my $select_fields = join(',', @fields);
    my $dbh = dbh;
    my $sql =
    # Subquery here because we need to DISTINCT the whole set, select the 
    # latest charge per pkgnum, and _then_ check edate < $eperiod 
    # and edate < expire.
      "INSERT INTO v_cust_bill_pkg ($insert_fields)
        SELECT $select_fields FROM (
          SELECT DISTINCT ON (pkgnum) * FROM v_cust_bill_pkg
            WHERE edate >= $speriod 
              AND recur > 0
              AND freq IS NOT NULL
              AND freq != '0'
            ORDER BY pkgnum, edate DESC
          ) AS v1 
          WHERE edate < $eperiod AND (edate < expire OR expire IS NULL)";
    my $rows;
    do {
      warn "[extend_projection] $sql\n" if $DEBUG;
      $rows = $dbh->do($sql) or die $dbh->errstr;
      warn "[extend_projection] $rows rows\n" if $DEBUG;
    } until $rows == 0;
  }
}

=head1 BUGS

Documentation.

=head1 SEE ALSO

L<FS::Report::Table::Monthly>, reports in the web interface.

=cut

1;
