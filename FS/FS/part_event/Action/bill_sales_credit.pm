package FS::part_event::Action::bill_sales_credit;

# in this order:
# - pkg_sales_credit invokes NEXT, then appends the 'cust_main_sales' param
# - credit_bill contains the core _calc_credit logic, and also defines other
# params

use base qw( FS::part_event::Action::Mixin::pkg_sales_credit
             FS::part_event::Action::Mixin::credit_bill
             FS::part_event::Action );
use FS::Record qw(qsearch qsearchs);
use FS::Conf;
use Date::Format qw(time2str);

use strict;

sub description { 'Credit the sales person based on the billed amount'; }

sub eventtable_hashref {
  { 'cust_bill' => 1 };
}

our $date_format;

sub do_action {
  my( $self, $cust_bill, $cust_event ) = @_;

  $date_format ||= FS::Conf->new->config('date_format') || '%x';

  my $cust_main = $self->cust_main($cust_bill);

  my %salesnum_sales; # salesnum => FS::sales object
  my %salesnum_amount; # salesnum => credit amount
  my %pkgnum_pkg; # pkgnum => FS::cust_pkg
  my %salesnum_pkgnums; # salesnum => [ pkgnum, ... ]

  my @items = qsearch('cust_bill_pkg', { invnum => $cust_bill->invnum,
                                         pkgnum => { op => '>', value => '0' }
                                       });

  foreach my $cust_bill_pkg (@items) {
    my $pkgnum = $cust_bill_pkg->pkgnum;
    my $cust_pkg = $pkgnum_pkg{$pkgnum} ||= $cust_bill_pkg->cust_pkg;

    my $salesnum = $cust_pkg->salesnum;
    $salesnum ||= $cust_main->salesnum
      if $self->option('cust_main_sales');
    my $sales = $salesnum_sales{$salesnum}
            ||= FS::sales->by_key($salesnum);

    next if !$sales; #no sales person, no credit

    my $amount = $self->_calc_credit($cust_bill_pkg, $sales);

    if ($amount > 0) {
      $salesnum_amount{$salesnum} ||= 0;
      $salesnum_amount{$salesnum} += $amount;
      push @{ $salesnum_pkgnums{$salesnum} ||= [] }, $pkgnum;
    }
  }

  foreach my $salesnum (keys %salesnum_amount) {
    my $amount = sprintf('%.2f', $salesnum_amount{$salesnum});
    next if $amount < 0.005;

    my $sales = $salesnum_sales{$salesnum};

    my $sales_cust_main = $sales->sales_cust_main;
    die "No customer record for sales person ". $sales->salesperson
      unless $sales->sales_custnum;

    my $reasonnum = $self->option('reasonnum');

    my $desc = 'from invoice #'. $cust_bill->display_invnum .
               ' ('. time2str($date_format, $cust_bill->_date) . ')';
               # could also show custnum and pkgnums here?
    my $error = $sales_cust_main->credit(
      $amount, 
      \$reasonnum,
      'eventnum'            => $cust_event->eventnum,
      'addlinfo'            => $desc,
      'commission_salesnum' => $sales->salesnum,
    );
    die "Error crediting customer ". $sales_cust_main->custnum.
        " for sales commission: $error"
      if $error;
  } # foreach $salesnum

}

1;
