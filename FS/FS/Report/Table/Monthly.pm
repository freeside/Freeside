package FS::Report::Table::Monthly;

use strict;
use vars qw( @ISA $expenses_kludge );
use Time::Local;
use FS::UID qw( dbh );
use FS::Report::Table;

@ISA = qw( FS::Report::Table );

$expenses_kludge = 0;

=head1 NAME

FS::Report::Table::Monthly - Tables of report data, indexed monthly

=head1 SYNOPSIS

  use FS::Report::Table::Monthly;

  my $report = new FS::Report::Table::Monthly (
    'items' => [ 'invoiced', 'netsales', 'credits', 'receipts', ],
    'start_month' => 4,
    'start_year'  => 2000,
    'end_month'   => 4,
    'end_year'    => 2020,
  );

  my $data = $report->data;

=head1 METHODS

=over 4

=item data

Returns a hashref of data (!! describe)

=cut

sub data {
  my $self = shift;

  my $smonth = $self->{'start_month'};
  my $syear = $self->{'start_year'};
  my $emonth = $self->{'end_month'};
  my $eyear = $self->{'end_year'};

  my %data;

  while ( $syear < $eyear || ( $syear == $eyear && $smonth < $emonth+1 ) ) {

    push @{$data{label}}, "$smonth/$syear";

    my $speriod = timelocal(0,0,0,1,$smonth-1,$syear);
    push @{$data{speriod}}, $speriod;
    if ( ++$smonth == 13 ) { $syear++; $smonth=1; }
    my $eperiod = timelocal(0,0,0,1,$smonth-1,$syear);
    push @{$data{eperiod}}, $eperiod;
  
    foreach my $item ( @{$self->{'items'}} ) {
      push @{$data{$item}}, $self->$item($speriod, $eperiod);
    }

  }

  \%data;

}

sub invoiced { #invoiced
  my( $self, $speriod, $eperiod ) = ( shift, shift, shift );
  $self->scalar_sql("
    SELECT SUM(charged) FROM cust_bill
    WHERE ". $self->in_time_period($speriod, $eperiod)
  );
}

sub netsales { #net sales
  my( $self, $speriod, $eperiod ) = ( shift, shift, shift );

  my $credited = $self->scalar_sql("
    SELECT SUM(cust_credit_bill.amount)
    FROM cust_credit_bill, cust_bill
    WHERE cust_bill.invnum = cust_credit_bill.invnum
      AND ".  $self->in_time_period($speriod, $eperiod, 'cust_bill')
  );

  #horrible local kludge
  my $expenses = !$expenses_kludge ? 0 : $self->scalar_sql("
    SELECT SUM(cust_bill_pkg.setup)
    FROM cust_bill_pkg, cust_bill, cust_pkg, part_pkg
    WHERE cust_bill.invnum = cust_bill_pkg.invnum
    AND ". $self->in_time_period($speriod, $eperiod, 'cust_bill'). "
    AND cust_pkg.pkgnum = cust_bill_pkg.pkgnum
    AND cust_pkg.pkgpart = part_pkg.pkgpart
    AND LOWER(part_pkg.pkg) LIKE 'expense _%'
  ");

  $self->invoiced($speriod,$eperiod) - $credited - $expenses;
}

#deferred revenue

sub receipts { #cashflow
  my( $self, $speriod, $eperiod ) = ( shift, shift, shift );

  my $refunded = $self->scalar_sql("
    SELECT SUM(refund) FROM cust_refund
    WHERE ". $self->in_time_period($speriod, $eperiod)
  );

  #horrible local kludge that doesn't even really work right
  my $expenses = !$expenses_kludge ? 0 : $self->scalar_sql("
    SELECT SUM(cust_bill_pay.amount)
    FROM cust_bill_pay, cust_bill
    WHERE cust_bill_pay.invnum = cust_bill.invnum
    AND ". $self->in_time_period($speriod, $eperiod, 'cust_bill_pay'). "
    AND 0 < ( SELECT COUNT(*) from cust_bill_pkg, cust_pkg, part_pkg
              WHERE cust_bill.invnum = cust_bill_pkg.invnum
              AND cust_pkg.pkgnum = cust_bill_pkg.pkgnum
              AND cust_pkg.pkgpart = part_pkg.pkgpart
              AND LOWER(part_pkg.pkg) LIKE 'expense _%'
            )
  ");
  #    my $expenses_sql2 = "SELECT SUM(cust_bill_pay.amount) FROM cust_bill_pay, cust_bill_pkg, cust_bill, cust_pkg, part_pkg WHERE cust_bill_pay.invnum = cust_bill.invnum AND cust_bill.invnum = cust_bill_pkg.invnum AND cust_bill_pay._date >= $speriod AND cust_bill_pay._date < $eperiod AND cust_pkg.pkgnum = cust_bill_pkg.pkgnum AND cust_pkg.pkgpart = part_pkg.pkgpart AND LOWER(part_pkg.pkg) LIKE 'expense _%'";
  
  $self->payments($speriod, $eperiod) - $refunded - $expenses;
}

sub payments {
  my( $self, $speriod, $eperiod ) = ( shift, shift, shift );
  $self->scalar_sql("
    SELECT SUM(paid) FROM cust_pay
    WHERE ". $self->in_time_period($speriod, $eperiod)
  );
}

sub credits {
  my( $self, $speriod, $eperiod ) = ( shift, shift, shift );
  $self->scalar_sql("
    SELECT SUM(amount) FROM cust_credit
    WHERE ". $self->in_time_period($speriod, $eperiod)
  );
}

sub canceled { #active
  my( $self, $speriod, $eperiod ) = ( shift, shift, shift );
  $self->scalar_sql("
    SELECT COUNT(*) FROM cust_pkg
    WHERE cust_pkg.custnum = cust_main.custnum
    AND 0 = ( SELECT COUNT(*) FROM cust_pkg
              WHERE cust_pkg.custnum = cust_main.custnum
              AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
            )
    AND cust_pkg.cancel > $speriod AND cust_pkg.cancel < $eperiod
  ");
}
 
sub newaccount { #newaccount
  my( $self, $speriod, $eperiod ) = ( shift, shift, shift );
  $self->scalar_sql("
     SELECT COUNT(*) FROM cust_pkg
     WHERE cust_pkg.custnum = cust_main.custnum
     AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
     AND ( cust_pkg.susp IS NULL OR cust_pkg.susp = 0 )
     AND cust_pkg.setup > $speriod AND cust_pkg.setup < $eperiod
  ");
}
 
sub suspended { #suspended
  my( $self, $speriod, $eperiod ) = ( shift, shift, shift );
  $self->scalar_sql("
     SELECT COUNT(*) FROM cust_pkg
     WHERE cust_pkg.custnum = cust_main.custnum
     AND ( cust_pkg.cancel IS NULL OR cust_pkg.cancel = 0 )
     AND 0 = ( SELECT COUNT(*) FROM cust_pkg
               WHERE cust_pkg.custnum = cust_main.custnum
               AND ( cust_pkg.susp IS NULL OR cust_pkg.susp = 0 )
             )
     AND cust_pkg.susp > $speriod AND cust_pkg.susp < $eperiod
  ");
}

sub in_time_period {
  my( $self, $speriod, $eperiod ) = ( shift, shift, shift );
  my $table = @_ ? shift().'.' : '';
  "${table}_date >= $speriod AND ${table}_date < $eperiod";
}

sub scalar_sql {
  my( $self, $sql ) = ( shift, shift );
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute
    or die "Unexpected error executing statement $sql: ". $sth->errstr;
  $sth->fetchrow_arrayref->[0] || 0;
}

=back

=head1 BUGS

Documentation.

=head1 SEE ALSO

=cut

1;

