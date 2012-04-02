package FS::part_event::Condition::has_cust_tag;

use strict;

use base qw( FS::part_event::Condition );
use FS::Record qw( qsearch );

sub description {
  'Customer has tag',
}

sub eventtable_hashref {
    { 'cust_main' => 1,
      'cust_bill' => 1,
      'cust_pkg'  => 1,
    };
}

#something like this
sub option_fields {
  (
    'tagnum'  => { 'label'    => 'Customer tag',
                   'type'     => 'select-cust_tag',
                   'multiple' => 1,
                 },
  );
}

sub condition {
  my( $self, $object ) = @_;

  my $cust_main = $self->cust_main($object);

  my $hashref = $self->option('tagnum') || {};
  grep $hashref->{ $_->tagnum }, $cust_main->cust_tag;
}

sub condition_sql {
  my( $self, $table ) = @_;

  my $matching_tags = 
    "SELECT tagnum FROM cust_tag WHERE cust_tag.custnum = $table.custnum".
    " AND cust_tag.tagnum IN ".
    $self->condition_sql_option_option_integer('tagnum');

  "EXISTS($matching_tags)";
}

1;
