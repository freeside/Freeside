package FS::part_event::Action::Mixin::pkg_sales_credit;

use strict;
use NEXT;

sub option_fields {
  my $class = shift;
  my %option_fields = $class->NEXT::option_fields;

  $option_fields{'cust_main_sales'} = {
    'label' => "Credit the customer sales person if there is no package sales person",
    'type'  => 'checkbox',
    'value' => 'Y',
  };

  %option_fields;
}

1;
