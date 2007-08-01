package FS::part_event::Condition::payby;

use strict;
use Tie::IxHash;
use FS::payby;

use base qw( FS::part_event::Condition );

sub description {
  #'customer payment types: ';
  'Customer payment type';
}

#something like this
tie my %payby, 'Tie::IxHash', FS::payby->cust_payby2longname;
sub option_fields {
  (
    'payby' => { 
                 label         => 'Customer payment type',
                 #type          => 'select-multiple',
                 type          => 'checkbox-multiple',
                 options       => [ keys %payby ],
                 option_labels => \%payby,
               },
  );
}

sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  #uuh.. all right?  test this.
  my $hashref = $self->option('payby') || {};
  $hashref->{ $cust_main->payby };

}

#sub condition_sql {
#  my( $self, $table ) = @_;
#
#  #uuh... yeah... something like this.  test it for sure.
#
#  my @payby = keys %{ $self->option('payby') };
#
#  ' ( '. join(' OR ', map { "cust_main.payby = '$_'" } @payby ). ' ) ';
#
#}

1;
