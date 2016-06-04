package FS::part_event::Condition::has_cust_payby_auto;
use base qw( FS::part_event::Condition );

use strict;
use Tie::IxHash;
use FS::payby;
use FS::Record qw(qsearch);

sub description {
  'Customer has automatic payment information';
}

tie my %payby, 'Tie::IxHash', FS::payby->cust_payby2shortname;
delete $payby{'DCRD'};
delete $payby{'DCHK'};

sub option_fields {
  (
    'payby' => { 
                 label         => 'Has automatic payment info',
                 type          => 'select',
                 options       => [ keys %payby ],
                 option_labels => \%payby,
               },
  );
}

sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  #handle multiple (HASH) type options migrated from a v3 payby.pm condition
  # (and maybe we should be a select-multiple or checkbox-multiple too?)
  my @payby = ();
  my $payby = $self->option('payby');
  if ( ref($payby) ) {
    @payby = keys %$payby;
  } elsif ( $payby ) {
    @payby = ( $payby );
  }

  scalar( qsearch({ 
    'table'     => 'cust_payby',
    'hashref'   => { 'custnum' => $cust_main->custnum,
                     #'payby'   => $self->option('payby')
                   },
    'extra_sql' => 'AND payby IN ( '.
                     join(',', map dbh->quote($_), @payby).
                   ' ) ',
    'order_by'  => 'LIMIT 1',
  }) );

}

1;
