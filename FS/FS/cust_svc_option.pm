package FS::cust_svc_option;

use strict;
use vars qw( @ISA );
#use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_svc_option - Object methods for cust_svc_option records

=head1 SYNOPSIS

  use FS::cust_svc_option;

  $record = new FS::cust_svc_option \%hash;
  $record = new FS::cust_svc_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_svc_option object represents an customer service option.
  FS::cust_svc_option inherits from FS::Record.  The following fields are
 currently supported:

=over 4

=item optionnum

primary key

=item svcnum

svcnum (see L<FS::cust_svc>)

=item optionname

Option Name

=item optionvalue

Option Value


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new option.  To add the option to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_svc_option'; }

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
    || $self->ut_foreign_key('svcnum', 'cust_svc', 'svcnum')
    || $self->ut_alpha('optionname')
    || $self->ut_anything('optionvalue')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

