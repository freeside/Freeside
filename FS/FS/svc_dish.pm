package FS::svc_dish;

use strict;
use base qw( FS::svc_Common );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::svc_dish - Object methods for svc_dish records

=head1 SYNOPSIS

  use FS::svc_dish;

  $record = new FS::svc_dish \%hash;
  $record = new FS::svc_dish { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::svc_dish object represents a Dish Network service.  FS::svc_dish 
inherits from FS::svc_Common.

The following fields are currently supported:

=over 4

=item svcnum - Primary key

=item acctnum - DISH account number

=item note - Installation notes: location on property, physical access, etc.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new svc_dish object.

=cut

sub table { 'svc_dish'; }

sub table_info {
  my %opts = ( 'type' => 'text', 
               'disable_select' => 1,
               'disable_inventory' => 1,
             );
  {
    'name'           => 'Dish service',
    'display_weight' => 58,
    'cancel_weight'  => 85,
    'fields' => {
      'svcnum'    => { label => 'Service' },
      'acctnum'   => { label => 'DISH account#', %opts },
      'note'      => { label => 'Installation notes', %opts },
    }
  }
}

sub label {
  my $self = shift;
  $self->acctnum;
}

sub search_sql {
  my($class, $string) = @_;
  $class->search_sql_field('acctnum', $string);
}

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref $x;

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_text('acctnum')
    || $self->ut_textn('note')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 SEE ALSO

L<FS::Record>, L<FS::svc_Common>, schema.html from the base documentation.

=cut

1;

