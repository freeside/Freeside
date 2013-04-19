package FS::part_event::Condition::once_perinv;

use strict;
use FS::Record qw( qsearch );
use FS::part_event;
use FS::cust_event;

use base qw( FS::part_event::Condition );

sub description { "Run only once for each time the package has been billed"; }

# Run the event, at most, a number of times equal to the number of 
# distinct invoices that contain line items from this package.

sub option_fields {
  (
    'paid' => { 'label' => 'Only count paid bills',
                'type'  => 'checkbox',
                'value' => 'Y',
              },
  )
}

sub eventtable_hashref {
    { 'cust_main' => 0,
      'cust_bill' => 0,
      'cust_pkg'  => 1,
    };
}

sub condition {
  my($self, $cust_pkg, %opt) = @_;

  my @cust_bill_pkg = qsearch('cust_bill_pkg', { pkgnum=>$cust_pkg->pkgnum });

  @cust_bill_pkg = grep { ($_->owed_setup + $_->owed_recur) == 0 }
                     @cust_bill_pkg
    if $self->option('paid');

  my %invnum = ();
  $invnum{$_->invnum} = 1 foreach @cust_bill_pkg;

  my @events = qsearch( {
      'table'     => 'cust_event', 
      'hashref'   => { 'eventpart' => $self->eventpart,
                       'status'    => { op=>'!=', value=>'failed' },
                       'tablenum'  => $cust_pkg->pkgnum,
                     },
      'extra_sql' => ( $opt{'cust_event'}->eventnum =~ /^(\d+)$/
                       ? " AND eventnum != $1 " : '' ),
  } );
  scalar(@events) < scalar(keys %invnum);
}

sub condition_sql {
  my( $self, $table ) = @_;

  #paid flag not yet implemented here, but that's okay, a partial optimization
  # is better than none

  "( 
    ( SELECT COUNT(distinct(invnum)) 
      FROM cust_bill_pkg
      WHERE cust_bill_pkg.pkgnum = cust_pkg.pkgnum )
    >
    ( SELECT COUNT(*)
      FROM cust_event
      WHERE cust_event.eventpart = part_event.eventpart
        AND cust_event.tablenum = cust_pkg.pkgnum
        AND status != 'failed' )
  )"

}

1;
