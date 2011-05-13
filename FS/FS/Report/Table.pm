package FS::Report::Table;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Report;
use Time::Local qw( timelocal );
use FS::UID qw( dbh );
use FS::Report::Table;
use FS::CurrentUser;

$DEBUG = 0; # turning this on will trace all SQL statements, VERY noisy
@ISA = qw( FS::Report );

=head1 NAME

FS::Report::Table - Tables of report data

=head1 SYNOPSIS

See the more specific report objects, currently only FS::Report::Table::Monthly

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

sub netsales { #net sales
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

    $self->invoiced($speriod,$eperiod,$agentnum,%opt)
  - $self->netcredits($speriod,$eperiod,$agentnum,%opt);
}

#deferred revenue

sub cashflow {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

    $self->payments($speriod, $eperiod, $agentnum, %opt)
  - $self->refunds( $speriod, $eperiod, $agentnum, %opt);
}

sub netcashflow {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;

    $self->receipts($speriod, $eperiod, $agentnum)
  - $self->netrefunds( $speriod, $eperiod, $agentnum);
}

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

sub credits {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $self->scalar_sql("
    SELECT SUM(amount)
      FROM cust_credit
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum)
  );
}

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
 
sub cust_bill_pkg {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  my $where = '';
  my $comparison = '';
  if ( $opt{'classnum'} =~ /^(\d+)$/ ) {
    if ( $1 == 0 ) {
      $comparison = "IS NULL";
    } else {
      $comparison = "= $1";
    }

    if ( $opt{'use_override'} ) {
      $where = "AND (
        part_pkg.classnum $comparison AND pkgpart_override IS NULL OR
        override.classnum $comparison AND pkgpart_override IS NOT NULL
      )";
    } else {
      $where = "AND part_pkg.classnum $comparison";
    }
  }

  $agentnum ||= $opt{'agentnum'};

  my $total_sql =
    " SELECT COALESCE( SUM(cust_bill_pkg.setup + cust_bill_pkg.recur), 0 ) ";

  $total_sql .=
    " / CASE COUNT(cust_pkg.*) WHEN 0 THEN 1 ELSE COUNT(cust_pkg.*) END "
      if $opt{average_per_cust_pkg};

  $total_sql .=
    " FROM cust_bill_pkg
        LEFT JOIN cust_bill USING ( invnum )
        LEFT JOIN cust_main USING ( custnum )
        LEFT JOIN cust_pkg USING ( pkgnum )
        LEFT JOIN part_pkg USING ( pkgpart )
        LEFT JOIN part_pkg AS override ON pkgpart_override = override.pkgpart
      WHERE pkgnum != 0
        $where
        AND ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum);
  
  if ($opt{use_usage} && $opt{use_usage} eq 'recurring') {
    my $total = $self->scalar_sql($total_sql);
    my $usage = cust_bill_pkg_detail(@_); #$speriod, $eperiod, $agentnum, %opt 
    return $total-$usage;
  } elsif ($opt{use_usage} && $opt{use_usage} eq 'usage') {
    return cust_bill_pkg_detail(@_); #$speriod, $eperiod, $agentnum, %opt 
  } else {
    return $self->scalar_sql($total_sql);
  }
}

sub cust_bill_pkg_detail {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  my @where = ( "cust_bill_pkg.pkgnum != 0" );
  my $comparison = '';
  if ( $opt{'classnum'} =~ /^(\d+)$/ ) {
    if ( $1 == 0 ) {
      $comparison = "IS NULL";
    } else {
      $comparison = "= $1";
    }

    if ( $opt{'use_override'} ) {
      push @where, "(
        part_pkg.classnum $comparison AND pkgpart_override IS NULL OR
        override.classnum $comparison AND pkgpart_override IS NOT NULL
      )";
    } else {
      push @where, "part_pkg.classnum $comparison";
    }
  }

  if ( $opt{'usageclass'} =~ /^(\d+)$/ ) {
    if ( $1 == 0 ) {
      $comparison = "IS NULL";
    } else {
      $comparison = "= $1";
    }

    push @where, "cust_bill_pkg_detail.classnum $comparison";
  }

  $agentnum ||= $opt{'agentnum'};

  my $where = join( ' AND ', @where );

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
      WHERE $where
        AND ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum);

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

sub scalar_sql {
  my( $self, $sql ) = ( shift, shift );
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  warn "FS::Report::Table::Monthly\n$sql\n" if $DEBUG;
  $sth->execute
    or die "Unexpected error executing statement $sql: ". $sth->errstr;
  $sth->fetchrow_arrayref->[0] || 0;
}

=back

=head1 BUGS

Documentation.

=head1 SEE ALSO

L<FS::Report::Table::Monthly>, reports in the web interface.

=cut

1;
