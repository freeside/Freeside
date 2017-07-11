package FS::part_event::Action::addtag;

use strict;
use base qw( FS::part_event::Action );
use FS::Record qw( qsearch );

sub description { 'Add customer tag'; }

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

sub default_weight { 20; }

sub do_action {
  my( $self, $object, $tagnum ) = @_;

  my %exists = map { $_->tagnum => $_->tagnum } 
        qsearch({
          table     => 'cust_tag',
          hashref   => { custnum  => $object->custnum, },
        });

  my @tags = split(/\,/, $self->option('tagnum'));
  foreach my $tagnum ( split(/\,/, $self->option('tagnum') ) ) {
    if ( !$exists{$tagnum} ) {
      my $cust_tag = new FS::cust_tag { 'tagnum'  => $tagnum,
                                        'custnum' => $object->custnum, };
      my $error = $cust_tag->insert;
      if ( $error ) {
        return $error;
      }
    }
  }
  '';
}

1;
