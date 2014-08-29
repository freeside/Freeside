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
    'no_late' => { 'label' => "But don't consider paid bills which were late.",
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

  if ( $self->option('paid') ) {
    @cust_bill_pkg = grep { ($_->owed_setup + $_->owed_recur) == 0 }
                       @cust_bill_pkg;

    if ( $self->option('no_late') ) {
      @cust_bill_pkg = grep {
        my $cust_bill_pkg = $_;

        my @cust_bill_pay_pkg = ();
        push @cust_bill_pay_pkg, $cust_bill_pkg->cust_bill_pay_pkg($_)
          for qw( setup recur );
        return 1 unless @cust_bill_pay_pkg; #no payments?  must be credits then
                                            #not considering those "late"

        my @cust_pay = sort { $a->_date <=> $b->_date }
                         map { $_->cust_bill_pay->cust_pay }
                           @cust_bill_pay_pkg;

        #most recent payment less than due date?  okay, we were paid on time
        $cust_pay[-1] <= $cust_bill_pkg->cust_bill->due_date;
                 
      } @cust_bill_pkg;
    }

  }

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
