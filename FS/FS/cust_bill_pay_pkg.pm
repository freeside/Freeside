package FS::cust_bill_pay_pkg;

use strict;
use vars qw( @ISA );
use FS::Conf;
use FS::Record qw( qsearch qsearchs );
use FS::cust_bill_pay;
use FS::cust_bill_pkg;

@ISA = qw(FS::Record);

=head1 NAME

FS::cust_bill_pay_pkg - Object methods for cust_bill_pay_pkg records

=head1 SYNOPSIS

  use FS::cust_bill_pay_pkg;

  $record = new FS::cust_bill_pay_pkg \%hash;
  $record = new FS::cust_bill_pay_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pay_pkg object represents application of a payment (see
L<FS::cust_bill_pay>) to a specific line item within an invoice (see
L<FS::cust_bill_pkg>).  FS::cust_bill_pay_pkg inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item billpaypkgnum - primary key

=item billpaynum - Payment application to the overall invoice (see L<FS::cust_bill_pay>)

=item billpkgnum -  Line item to which payment is applied (see L<FS::cust_bill_pkg>)

=item amount - Amount of the payment applied to this line item.

=item setuprecur - 'setup' or 'recur', designates whether the payment was applied to the setup or recurring portion of the line item.

=item sdate - starting date of recurring fee

=item edate - ending date of recurring fee

=back

sdate and edate are specified as UNIX timestamps; see L<perlfunc/"time">.  Also
see L<Time::Local> and L<Date::Parse> for conversion functions.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_bill_pay_pkg'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my($self, %options) = @_;

  #local $SIG{HUP} = 'IGNORE';
  #local $SIG{INT} = 'IGNORE';
  #local $SIG{QUIT} = 'IGNORE';
  #local $SIG{TERM} = 'IGNORE';
  #local $SIG{TSTP} = 'IGNORE';
  #local $SIG{PIPE} = 'IGNORE';
  #
  #my $oldAutoCommit = $FS::UID::AutoCommit;
  #local $FS::UID::AutoCommit = 0;
  #my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    #$dbh->rollback if $oldAutoCommit;
    return "error inserting $self: $error";
  }

  #payment receipt
  my $conf = new FS::Conf;
  my $trigger = $conf->config('payment_receipt-trigger') || 'cust_pay';
  if ( $trigger eq 'cust_bill_pay_pkg' ) {
    my $error = $self->send_receipt(
      'manual'    => $options{'manual'},
    );
    warn "can't send payment receipt/statement: $error" if $error;
  }

  '';

}

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

Checks all fields to make sure this is a valid payment application.  If there
is an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('billpaypkgnum')
    || $self->ut_foreign_key('billpaynum', 'cust_bill_pay', 'billpaynum' )
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum' )
    || $self->ut_foreign_keyn('pkgnum', 'cust_pkg', 'pkgnum')
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

=item cust_bill_pay

Returns the FS::cust_bill_pay object (payment application to the overall
invoice).

=cut

sub cust_bill_pay {
  my $self = shift;
  qsearchs('cust_bill_pay', { 'billpaynum' => $self->billpaynum } );
}

=item cust_bill_pkg

Returns the FS::cust_bill_pkg object (line item to which payment is applied).

=cut

sub cust_bill_pkg {
  my $self = shift;
  qsearchs('cust_bill_pkg', { 'billpkgnum' => $self->billpkgnum } );
}

=item send_receipt

Sends a payment receipt for the associated payment, against this specific
invoice and packages.  If there is an error, returns the error, otherwise
returns false.

=cut

sub send_receipt {
  my $self = shift;
  my $opt = ref($_[0]) ? shift : { @_ };
  $self->cust_bill_pay->send_receipt(
    'cust_pkg' => scalar($self->cust_bill_pkg->cust_pkg),
    %$opt,
  );
}


=back

=head1 BUGS

B<setuprecur> field is a kludge to compensate for cust_bill_pkg having separate
setup and recur fields.  It should be removed once that's fixed.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

