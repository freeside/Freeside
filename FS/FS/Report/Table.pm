package FS::Report::Table;

use strict;
use base 'FS::Report';
use Time::Local qw( timelocal );
use FS::UID qw( dbh driver_name );
use FS::Report::Table;
use FS::CurrentUser;
use Cache::FileCache;

our $DEBUG = 0; # turning this on will trace all SQL statements, VERY noisy

our $CACHE; # feel free to use this for whatever

FS::UID->install_callback(sub {
    $CACHE = Cache::FileCache->new( {
      'namespace'   => __PACKAGE__,
      'cache_root'  => "$FS::UID::cache_dir/cache.$FS::UID::datasrc",
    } );
    # reset this on startup (causes problems with database backups, etc.)
    $CACHE->remove('tower_pkg_cache_update');
});

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

'average_per_cust_pkg': divide the result by the number of distinct packages.

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

  if ($opt{'average_per_cust_pkg'}) {
    my $count = $self->cust_bill_pkg_count_pkgnum(@_);
    return '' if $count == 0;
    $sum = sprintf('%.2f', $sum / $count);
  }
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
    $self->with_refnum(%opt),
    $self->with_cust_classnum(%opt)
  );

  my $total_sql = "SELECT COALESCE(SUM(cust_bill_pkg.setup),0)
  FROM cust_bill_pkg
  $cust_bill_pkg_join
  WHERE " . join(' AND ', grep $_, @where);

  $self->scalar_sql($total_sql);
}

sub _cust_bill_pkg_recurring {
  # returns the FROM/WHERE part of the statement to query all recurring 
  # line items in the period
  my $self = shift;
  my ($speriod, $eperiod, $agentnum, %opt) = @_;

  $agentnum ||= $opt{'agentnum'};
  my $cust_bill_pkg = $opt{'project'} ? 'v_cust_bill_pkg' : 'cust_bill_pkg';

  my @where = (
    '(pkgnum != 0 OR feepart IS NOT NULL)',
    $self->with_classnum($opt{'classnum'}, $opt{'use_override'}),
    $self->with_report_option(%opt),
    $self->with_refnum(%opt),
    $self->with_cust_classnum(%opt)
  );

  if ( $opt{'distribute'} ) {
    $where[0] = 'pkgnum != 0'; # specifically exclude fees
    push @where, "cust_main.agentnum = $agentnum" if $agentnum;
    push @where,
      "$cust_bill_pkg.sdate <  $eperiod",
      "$cust_bill_pkg.edate >= $speriod",
    ;
  }
  else {
    # we don't want to have to create v_cust_bill
    my $_date = $opt{'project'} ? 'v_cust_bill_pkg._date' : 'cust_bill._date';
    push @where, 
      $self->in_time_period_and_agent($speriod, $eperiod, $agentnum, $_date);
  }

  return "
  FROM $cust_bill_pkg 
  $cust_bill_pkg_join
  WHERE ".join(' AND ', grep $_, @where);

}

sub cust_bill_pkg_recur {
  my $self = shift;
  my ($speriod, $eperiod, $agentnum, %opt) = @_;

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
  
  my $cust_bill_pkg = $opt{'project'} ? 'v_cust_bill_pkg' : 'cust_bill_pkg';

  my $recur_fraction = '';
  if ($opt{'distribute'}) {
    # the fraction of edate - sdate that's within [speriod, eperiod]
    $recur_fraction = " * 
      CAST(LEAST($eperiod, $cust_bill_pkg.edate) - 
       GREATEST($speriod, $cust_bill_pkg.sdate) AS DECIMAL) / 
      ($cust_bill_pkg.edate - $cust_bill_pkg.sdate)";
  }

  my $total_sql = 
    "SELECT COALESCE(SUM(($cust_bill_pkg.recur - $item_usage) $recur_fraction),0)" .
    $self->_cust_bill_pkg_recurring(@_);

  $self->scalar_sql($total_sql);
}

sub cust_bill_pkg_count_pkgnum {
  # for ARPU calculation
  my $self = shift;
  my $total_sql = 'SELECT COUNT(DISTINCT pkgnum) '.
    $self->_cust_bill_pkg_recurring(@_);

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

  $agentnum ||= $opt{'agentnum'};

  push @where,
    $self->with_classnum($opt{'classnum'}, $opt{'use_override'}),
    $self->with_usageclass($opt{'usageclass'}),
    $self->with_report_option(%opt),
    $self->with_refnum(%opt),
    $self->with_cust_classnum(%opt)
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

##### package churn report #####

=item active_pkg: The number of packages that were active at the start of 
the period. The end date of the period is ignored. Options:

- refnum: Limit to customers with this advertising source.
- classnum: Limit to packages with this class.
- towernum: Limit to packages that have a broadband service with this tower.
- zip: Limit to packages with this service location zip code.

Except for zip, any of these can be an arrayref to allow multiple values for
the field.

=item setup_pkg: The number of packages with setup dates in the period. This 
excludes packages created by package changes. Options are as for active_pkg.

=item susp_pkg: The number of packages that were suspended in the period
(and not canceled).  Options are as for active_pkg.

=item unsusp_pkg: The number of packages that were unsuspended in the period.
Options are as for active_pkg.

=item cancel_pkg: The number of packages with cancel dates in the period.
Excludes packages that were canceled to be changed to a new package. Options
are as for active_pkg.

=cut

sub active_pkg {
  my $self = shift;
  $self->churn_pkg('active', @_);
}

sub setup_pkg {
  my $self = shift;
  $self->churn_pkg('setup', @_);
}

sub cancel_pkg {
  my $self = shift;
  $self->churn_pkg('cancel', @_);
}

sub susp_pkg {
  my $self = shift;
  $self->churn_pkg('susp', @_);
}

sub unsusp_pkg {
  my $self = shift;
  $self->churn_pkg('unsusp', @_);
}

sub churn_pkg {
  my $self = shift;
  my ( $status, $speriod, $eperiod, $agentnum, %opt ) = @_;
  my ($from, @where) =
    FS::h_cust_pkg->churn_fromwhere_sql( $status, $speriod, $eperiod);

  push @where, $self->pkg_where(%opt, 'agentnum' => $agentnum);

  my $sql = "SELECT COUNT(*) FROM $from
    JOIN part_pkg ON (cust_pkg.pkgpart = part_pkg.pkgpart)
    JOIN cust_main ON (cust_pkg.custnum = cust_main.custnum)";
  $sql .= ' WHERE '.join(' AND ', @where)
    if scalar(@where);

  $self->scalar_sql($sql);
}

sub pkg_where {
  my $self = shift;
  my %opt = @_;
  my @where = (
    "part_pkg.freq != '0'",
    $self->with_refnum(%opt),
    $self->with_towernum(%opt),
    $self->with_zip(%opt),
  );
  if ($opt{agentnum} =~ /^(\d+)$/) {
    push @where, "cust_main.agentnum = $1";
  }
  if ($opt{classnum}) {
    my $classnum = $opt{classnum};
    $classnum = [ $classnum ] if !ref($classnum);
    @$classnum = grep /^\d+$/, @$classnum;
    my $in = 'IN ('. join(',', @$classnum). ')';
    push @where, "COALESCE(part_pkg.classnum, 0) $in" if scalar @$classnum;
  }
  @where;
}

##### end of package churn report stuff #####

##### customer churn report #####

=item active_cust: The number of customers who had any active recurring 
packages at the start of the period. The end date is ignored, agentnum is 
mandatory, and no other parameters are accepted.

=item started_cust: The number of customers who had no active packages at 
the start of the period, but had active packages at the end. Like
active_cust, agentnum is mandatory and no other parameters are accepted.

=item suspended_cust: The number of customers who had active packages at
the start of the period, and at the end had no active packages but some
suspended packages. Note that this does not necessarily mean that their 
packages were suspended during the period.

=item resumed_cust: The inverse of suspended_cust: the number of customers
who had suspended packages and no active packages at the start of the 
period, and active packages at the end.

=item cancelled_cust: The number of customers who had active packages
at the start of the period, and only cancelled packages at the end.

=cut

sub active_cust {
  my $self = shift;
  $self->churn_cust(@_)->{active};
}
sub started_cust {
  my $self = shift;
  $self->churn_cust(@_)->{started};
}
sub suspended_cust {
  my $self = shift;
  $self->churn_cust(@_)->{suspended};
}
sub resumed_cust {
  my $self = shift;
  $self->churn_cust(@_)->{resumed};
}
sub cancelled_cust {
  my $self = shift;
  $self->churn_cust(@_)->{cancelled};
}

sub churn_cust {
  my $self = shift;
  my ( $speriod ) = @_;

  # run one query for each interval
  return $self->{_interval}{$speriod} ||= $self->calculate_churn_cust(@_);
}

sub calculate_churn_cust {
  my $self = shift;
  my ($speriod, $eperiod, $agentnum, %opt) = @_;

  my $churn_sql = FS::cust_main::Status->churn_sql($speriod, $eperiod);
  my $where = '';
  $where = " WHERE cust_main.agentnum = $agentnum " if $agentnum;
  my $cust_sql =
    "SELECT churn.* ".
    "FROM cust_main JOIN ($churn_sql) AS churn USING (custnum)".
    $where;

  # query to count the ones with certain status combinations
  my $total_sql = "
    SELECT SUM((s_active > 0)::int)                   as active,
           SUM((s_active = 0 and e_active > 0)::int)  as started,
           SUM((s_active > 0 and e_active = 0 and e_suspended > 0)::int)
                                                      as suspended,
           SUM((s_active = 0 and s_suspended > 0 and e_active > 0)::int)
                                                      as resumed,
           SUM((s_active > 0 and e_active = 0 and e_suspended = 0)::int)
                                                      as cancelled
    FROM ($cust_sql) AS x
  ";

  my $sth = dbh->prepare($total_sql);
  $sth->execute or die "failed to execute churn query: " . $sth->errstr;

  $self->{_interval}{$speriod} = $sth->fetchrow_hashref;
}

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
    if ( $opt{'refnum'} ) {
      my $refnum = $opt{'refnum'};
      $refnum = [ $refnum ] if !ref($refnum);
      my $in = join(',', grep /^\d+$/, @$refnum);
      $sql .= " and refnum IN ($in)" if length $in;
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

  if ( $use_override ) {
    # then include packages if their base package is in the set and they are 
    # not overridden,
    # or if they are overridden and their override package is in the set,
    # or fees if they are in the set
    return "(
         ( COALESCE(part_pkg.classnum, 0) $in AND cust_pkg.pkgpart IS NOT NULL AND pkgpart_override IS NULL )
      OR ( COALESCE(override.classnum, 0) $in AND pkgpart_override IS NOT NULL )
      OR ( COALESCE(part_fee.classnum, 0) $in AND cust_bill_pkg.feepart IS NOT NULL )
    )";
  } else {
    # include packages if their base package is in the set,
    # or fees if they are in the set
    return "(
         ( COALESCE(part_pkg.classnum, 0) $in AND cust_pkg.pkgpart IS NOT NULL )
      OR ( COALESCE(part_fee.classnum, 0) $in AND cust_bill_pkg.feepart IS NOT NULL )
    )";
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

sub with_refnum {
  my ($self, %opt) = @_;
  if ( $opt{'refnum'} ) {
    my $refnum = $opt{'refnum'};
    $refnum = [ $refnum ] if !ref($refnum);
    my $in = join(',', grep /^\d+$/, @$refnum);
    return "cust_main.refnum IN ($in)" if length $in;
  }
  return;
}

sub with_towernum {
  my ($self, %opt) = @_;
  if ( $opt{'towernum'} ) {
    my $towernum = $opt{'towernum'};
    $towernum = [ $towernum ] if !ref($towernum);
    my $in = join(',', grep /^\d+$/, @$towernum);
    return unless length($in); # if no towers are specified, don't restrict

    # materialize/cache the set of pkgnums that, as of the last
    # svc_broadband history record, had a certain towernum
    # (because otherwise this is painfully slow)
    $self->_init_tower_pkg_cache;

    return "EXISTS(
            SELECT 1 FROM tower_pkg_cache
              WHERE towernum IN($in)
              AND cust_pkg.pkgnum = tower_pkg_cache.pkgnum
            )";
  }
  return;
}

sub with_zip {
  my ($self, %opt) = @_;
  if (length($opt{'zip'})) {
    return "(SELECT zip FROM cust_location 
             WHERE cust_location.locationnum = cust_pkg.locationnum
            ) = " . dbh->quote($opt{'zip'});
  }
  return;
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
  return; 
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

=item _init_tower_pkg_cache

Internal method: creates a temporary table relating pkgnums to towernums.
A (pkgnum, towernum) record indicates that this package once had a 
svc_broadband service which, as of its last insert or replace_new history 
record, had a sectornum associated with that towernum.

This is expensive, so it won't be done more than once an hour. Historical 
data about package churn shouldn't be changing in realtime anyway.

=cut

sub _init_tower_pkg_cache {
  my $self = shift;
  my $dbh = dbh;

  my $current = $CACHE->get('tower_pkg_cache_update');
  return if $current;
 
  # XXX or should this be in the schema?
  my $sql = "DROP TABLE IF EXISTS tower_pkg_cache";
  $dbh->do($sql) or die $dbh->errstr;
  $sql = "CREATE TABLE tower_pkg_cache (towernum int, pkgnum int)";
  $dbh->do($sql) or die $dbh->errstr;

  # assumptions:
  # sectornums never get reused, or move from one tower to another
  # all service history is intact
  # svcnums never get reused (this would be bad)
  # pkgnums NEVER get reused (this would be extremely bad)
  $sql = "INSERT INTO tower_pkg_cache (
    SELECT COALESCE(towernum,0), pkgnum
    FROM ( SELECT DISTINCT pkgnum, svcnum FROM h_cust_svc ) AS pkgnum_svcnum
    LEFT JOIN (
      SELECT DISTINCT ON(svcnum) svcnum, sectornum
        FROM h_svc_broadband
        WHERE (history_action = 'replace_new'
               OR history_action = 'replace_old')
        ORDER BY svcnum ASC, history_date DESC
    ) AS svcnum_sectornum USING (svcnum)
    LEFT JOIN tower_sector USING (sectornum)
  )";
  $dbh->do($sql) or die $dbh->errstr;

  $CACHE->set('tower_pkg_cache_update', 1, 3600);

};

=head1 BUGS

Documentation.

=head1 SEE ALSO

L<FS::Report::Table::Monthly>, reports in the web interface.

=cut

1;
