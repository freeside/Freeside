package FS::cust_bill_batch_option;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_bill_batch_option - Object methods for cust_bill_batch_option records

=head1 SYNOPSIS

  use FS::cust_bill_batch_option;

  $record = new FS::cust_bill_batch_option \%hash;
  $record = new FS::cust_bill_batch_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_batch_option object represents an option key and value for
an invoice batch entry.  FS::cust_bill_batch_option inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item optionnum - primary key

=item billbatchnum - 

=item optionname - 

=item optionvalue - 


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new option.  To add the option to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_bill_batch_option'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid option.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('optionnum')
    || $self->ut_foreign_key('billbatchnum', 'cust_bill_batch', 'billbatchnum')
    || $self->ut_text('optionname')
    || $self->ut_textn('optionvalue')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

