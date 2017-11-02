package FS::part_event::Action::removetag;

use strict;
use base qw( FS::part_event::Action );
use FS::Record qw( qsearch );

sub description { 'Remove customer tag'; }

sub eventtable_hashref {
    { 'cust_main'      => 1,
      'cust_bill'      => 1,
      'cust_pkg'       => 1,
      'cust_pay'       => 1,
      'cust_pay_batch' => 1,
      'cust_statement' => 1,
    };
}

sub option_fields {
  (
    'tagnum'  => { 'label'    => 'Customer tag',
                   'type'     => 'select-cust_tag',
                   'multiple' => 1,
                 },
  );
}

sub default_weight { 21; }

sub do_action {
  my( $self, $object, $tagnum ) = @_;

  # Get hashref of tags applied to selected customer record
  my %cust_tag = map { $_->tagnum => $_ } qsearch({
    table     => 'cust_tag',
    hashref   => { custnum  => $object->custnum, },
  });

  # Remove tags chosen for this billing event from the customer record
  foreach my $tagnum ( split(/\,/, $self->option('tagnum') ) ) {
    if ( exists $cust_tag{$tagnum} ) {
      my $error = $cust_tag{$tagnum}->delete;
      die $error if $error;
    }
  }
  '';
}

1;
