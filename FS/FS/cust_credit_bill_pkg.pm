package FS::cust_credit_bill_pkg;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs ); # qsearch );
use FS::cust_main_Mixin;
use FS::cust_credit_bill;
use FS::cust_bill_pkg;
use FS::cust_bill_pkg_tax_location;
use FS::cust_bill_pkg_tax_rate_location;

@ISA = qw( FS::cust_main_Mixin FS::Record );

=head1 NAME

FS::cust_credit_bill_pkg - Object methods for cust_credit_bill_pkg records

=head1 SYNOPSIS

  use FS::cust_credit_bill_pkg;

  $record = new FS::cust_credit_bill_pkg \%hash;
  $record = new FS::cust_credit_bill_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_credit_bill_pkg object represents application of a credit (see 
L<FS::cust_credit_bill>) to a specific line item within an invoice
(see L<FS::cust_bill_pkg>).  FS::cust_credit_bill_pkg inherits from FS::Record.
The following fields are currently supported:

=over 4

=item creditbillpkgnum -  primary key

=item creditbillnum - Credit application to the overall invoice (see L<FS::cust_credit::bill>)

=item billpkgnum - Line item to which credit is applied (see L<FS::cust_bill_pkg>)

=item amount - Amount of the credit applied to this line item.

=item setuprecur - 'setup' or 'recur', designates whether the payment was applied to the setup or recurring portion of the line item.

=item sdate - starting date of recurring fee

=item edate - ending date of recurring fee

=back

sdate and edate are specified as UNIX timestamps; see L<perlfunc/"time">.  Also
see L<Time::Local> and L<Date::Parse> for conversion functions.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_credit_bill_pkg'; }

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

Checks all fields to make sure this is a valid credit applicaiton.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('creditbillpkgnum')
    || $self->ut_foreign_key('creditbillnum', 'cust_credit_bill', 'creditbillnum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum' )
    || $self->ut_foreign_keyn('billpkgtaxlocationnum',
                              'cust_bill_pkg_tax_location',
                              'billpkgtaxlocationnum')
    || $self->ut_foreign_keyn('billpkgtaxratelocationnum',
                              'cust_bill_pkg_tax_rate_location',
                              'billpkgtaxratelocationnum')
    || $self->ut_money('amount')
    || $self->ut_enum('setuprecur', [ 'setup', 'recur' ] )
    || $self->ut_numbern('sdate')
    || $self->ut_numbern('edate')
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub cust_credit_bill {
  my $self = shift;
  qsearchs('cust_credit_bill', { 'creditbillnum' => $self->creditbillnum } );
}

=back

=head1 BUGS

B<setuprecur> field is a kludge to compensate for cust_bill_pkg having separate
setup and recur fields.  It should be removed once that's fixed.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

