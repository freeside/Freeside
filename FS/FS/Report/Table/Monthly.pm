package FS::Report::Table::Monthly;

use strict;
use vars qw( @ISA $expenses_kludge );
use Time::Local;
use FS::UID qw( dbh );
use FS::Report::Table;
use FS::CurrentUser;

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
    #opt
    'agentnum'    => 54
    'params'      => [ [ 'paramsfor', 'item_one' ], [ 'item', 'two' ] ], # ...
    'remove_empty' => 1, #collapse empty rows, default 0
    'item_labels' => [ ], #useful with remove_empty
  );

  my $data = $report->data;

=head1 METHODS

=over 4

=item data

Returns a hashref of data (!! describe)

=cut

sub data {
  my $self = shift;

  #use Data::Dumper;
  #warn Dumper($self);

  my $smonth = $self->{'start_month'};
  my $syear = $self->{'start_year'};
  my $emonth = $self->{'end_month'};
  my $eyear = $self->{'end_year'};
  my $agentnum = $self->{'agentnum'};

  my %data;

  while ( $syear < $eyear || ( $syear == $eyear && $smonth < $emonth+1 ) ) {

    push @{$data{label}}, "$smonth/$syear";

    my $speriod = timelocal(0,0,0,1,$smonth-1,$syear);
    push @{$data{speriod}}, $speriod;
    if ( ++$smonth == 13 ) { $syear++; $smonth=1; }
    my $eperiod = timelocal(0,0,0,1,$smonth-1,$syear);
    push @{$data{eperiod}}, $eperiod;
  
    my $col = 0;
    my @row = ();
    foreach my $item ( @{$self->{'items'}} ) {
      my @param = $self->{'params'} ? @{ $self->{'params'}[$col] }: ();
      my $value = $self->$item($speriod, $eperiod, $agentnum, @param);
      #push @{$data{$item}}, $value;
      push @{$data{data}->[$col++]}, $value;
    }

  }

  #these need to get generalized, sheesh
  $data{'items'}       = $self->{'items'};
  $data{'item_labels'} = $self->{'item_labels'} || $self->{'items'};
  $data{'colors'}      = $self->{'colors'};
  $data{'links'}       = $self->{'links'} || [];

  #use Data::Dumper;
  #warn Dumper(\%data);

  if ( $self->{'remove_empty'} ) {

    #warn "removing empty rows\n";

    my $col = 0;
    #these need to get generalized, sheesh
    my @newitems = ();
    my @newlabels = ();
    my @newdata = ();
    my @newcolors = ();
    my @newlinks = ();
    foreach my $item ( @{$self->{'items'}} ) {

      if ( grep { $_ != 0 } @{$data{'data'}->[$col]} ) {
        push @newitems,  $data{'items'}->[$col];
        push @newlabels, $data{'item_labels'}->[$col];
        push @newdata,   $data{'data'}->[$col];
        push @newcolors, $data{'colors'}->[$col];
        push @newlinks,  $data{'links'}->[$col];
      }

      $col++;
    }

    $data{'items'}       = \@newitems;
    $data{'item_labels'} = \@newlabels;
    $data{'data'}        = \@newdata;
    $data{'colors'}      = \@newcolors;
    $data{'links'}       = \@newlinks;

  }

  #use Data::Dumper;
  #warn Dumper(\%data);

  \%data;

}

sub invoiced { #invoiced
  my( $self, $speriod, $eperiod, $agentnum ) = @_;

  $self->scalar_sql("
    SELECT SUM(charged)
      FROM cust_bill
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum)
  );
  
}

sub netsales { #net sales
  my( $self, $speriod, $eperiod, $agentnum ) = @_;

  my $credited = $self->scalar_sql("
    SELECT SUM(cust_credit_bill.amount)
      FROM cust_credit_bill
        LEFT JOIN cust_bill USING ( invnum  )
        LEFT JOIN cust_main USING ( custnum )
    WHERE ".  $self->in_time_period_and_agent( $speriod,
                                               $eperiod,
                                               $agentnum,
                                               'cust_bill._date'
                                             )
  );

  #horrible local kludge
  my $expenses = !$expenses_kludge ? 0 : $self->scalar_sql("
    SELECT SUM(cust_bill_pkg.setup)
      FROM cust_bill_pkg
        LEFT JOIN cust_bill USING ( invnum  )
        LEFT JOIN cust_main USING ( custnum )
        LEFT JOIN cust_pkg  USING ( pkgnum  )
        LEFT JOIN part_pkg  USING ( pkgpart )
      WHERE ". $self->in_time_period_and_agent( $speriod,
                                                $eperiod,
                                                $agentnum,
                                                'cust_bill._date'
                                              ). "
        AND LOWER(part_pkg.pkg) LIKE 'expense _%'
  ");

  $self->invoiced($speriod,$eperiod,$agentnum) - $credited - $expenses;
}

#deferred revenue

sub receipts { #cashflow
  my( $self, $speriod, $eperiod, $agentnum ) = @_;

  my $refunded = $self->scalar_sql("
    SELECT SUM(refund)
      FROM cust_refund
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum)
  );

  #horrible local kludge that doesn't even really work right
  my $expenses = !$expenses_kludge ? 0 : $self->scalar_sql("
    SELECT SUM(cust_bill_pay.amount)
      FROM cust_bill_pay
        LEFT JOIN cust_bill USING ( invnum  )
        LEFT JOIN cust_main USING ( custnum )
    WHERE ". $self->in_time_period_and_agent( $speriod,
                                              $eperiod,
                                              $agentnum,
                                              'cust_bill_pay._date'
                                            ). "
    AND 0 < ( SELECT COUNT(*) from cust_bill_pkg, cust_pkg, part_pkg
              WHERE cust_bill.invnum = cust_bill_pkg.invnum
              AND cust_pkg.pkgnum = cust_bill_pkg.pkgnum
              AND cust_pkg.pkgpart = part_pkg.pkgpart
              AND LOWER(part_pkg.pkg) LIKE 'expense _%'
            )
  ");
  #    my $expenses_sql2 = "SELECT SUM(cust_bill_pay.amount) FROM cust_bill_pay, cust_bill_pkg, cust_bill, cust_pkg, part_pkg WHERE cust_bill_pay.invnum = cust_bill.invnum AND cust_bill.invnum = cust_bill_pkg.invnum AND cust_bill_pay._date >= $speriod AND cust_bill_pay._date < $eperiod AND cust_pkg.pkgnum = cust_bill_pkg.pkgnum AND cust_pkg.pkgpart = part_pkg.pkgpart AND LOWER(part_pkg.pkg) LIKE 'expense _%'";
  
  $self->payments($speriod, $eperiod, $agentnum) - $refunded - $expenses;
}

sub payments {
  my( $self, $speriod, $eperiod, $agentnum ) = @_;
  $self->scalar_sql("
    SELECT SUM(paid)
      FROM cust_pay
        LEFT JOIN cust_main USING ( custnum )
      WHERE ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum)
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

#not being too bad with the false laziness
use Time::Local qw(timelocal);
sub _subtract_11mo {
  my($self, $time) = @_;
  my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($time) )[0,1,2,3,4,5];
  $mon -= 11;
  if ( $mon < 0 ) { $mon+=12; $year--; }
  timelocal($sec,$min,$hour,$mday,$mon,$year);
}

sub cust_bill_pkg {
  my( $self, $speriod, $eperiod, $agentnum, %opt ) = @_;

  my $where = '';
  if ( $opt{'classnum'} =~ /^(\d+)$/ ) {
    if ( $1 == 0 ) {
      $where = "classnum IS NULL";
    } else {
      $where = "classnum = $1";
    }
  }

  $agentnum ||= $opt{'agentnum'};

  $self->scalar_sql("
    SELECT SUM(cust_bill_pkg.setup + cust_bill_pkg.recur)
      FROM cust_bill_pkg
        LEFT JOIN cust_bill USING ( invnum )
        LEFT JOIN cust_main USING ( custnum )
        LEFT JOIN cust_pkg USING ( pkgnum )
        LEFT JOIN part_pkg USING ( pkgpart )
      WHERE pkgnum != 0
        AND $where
        AND ". $self->in_time_period_and_agent($speriod, $eperiod, $agentnum)
  );
  
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
  $sql .= " AND agentnum = $agentnum"
    if $agentnum;

  #agent virtualization
  $sql .= ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql;

  $sql;
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

