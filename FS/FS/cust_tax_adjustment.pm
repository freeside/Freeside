package FS::cust_tax_adjustment;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );
use FS::cust_main;
use FS::cust_bill_pkg;

=head1 NAME

FS::cust_tax_adjustment - Object methods for cust_tax_adjustment records

=head1 SYNOPSIS

  use FS::cust_tax_adjustment;

  $record = new FS::cust_tax_adjustment \%hash;
  $record = new FS::cust_tax_adjustment { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_tax_adjustment object represents an taxation adjustment.
FS::cust_tax_adjustment inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item adjustmentnum

primary key

=item custnum

custnum

=item taxname

taxname

=item amount

amount

=item comment

comment

=item billpkgnum

billpkgnum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_tax_adjustment'; }

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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('adjustmentnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum' )
    || $self->ut_text('taxname')
    || $self->ut_money('amount')
    || $self->ut_textn('comment')
    || $self->ut_foreign_keyn('billpkgnum', 'cust_bill_pkg', 'billpkgnum' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub cust_bill_pkg {
  my $self = shift;
  qsearchs('cust_bill_pkg', { 'billpkgnum' => $self->billpkgnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

