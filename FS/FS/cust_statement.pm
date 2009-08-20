package FS::cust_statement;

use strict;
use base qw( FS::cust_bill );
use FS::Record qw( dbh qsearch ); #qsearchs );
use FS::cust_main;
use FS::cust_bill;

=head1 NAME

FS::cust_statement - Object methods for cust_statement records

=head1 SYNOPSIS

  use FS::cust_statement;

  $record = new FS::cust_statement \%hash;
  $record = new FS::cust_statement { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_statement object represents an informational statement which
aggregates one or more invoices.  FS::cust_statement inherits from
FS::cust_bill.

The following fields are currently supported:

=over 4

=item statementnum

primary key

=item custnum

customer

=item _date

date

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub new { FS::Record::new(@_); }

sub table { 'cust_statement'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  FS::Record::insert($self);

  foreach my $cust_bill (
                          qsearch({
                            'table'     => 'cust_bill',
                            'hashref'   => { 'custnum'      => $self->custnum,
                                             'statementnum' => '',
                                           },
                            'extra_sql' => 'FOR UPDATE' ,
                          })
                        )
  {
    $cust_bill->statementnum( $self->statementnum );
    my $error = $cust_bill->replace;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "Error associating invoice: $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error

}

=item delete

Delete this record from the database.

=cut

sub delete { FS::Record::delete(@_); }

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace { FS::Record::replace(@_); }

sub replace_check { ''; }

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('statementnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum' )
    || $self->ut_numbern('_date')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  #don't want to call cust_bill, and Record just checks virtual fields
  #$self->SUPER::check;
  '';

}

=item cust_bill

Returns the associated invoices (cust_bill records) for this statement.

=cut

sub cust_bill {
  my $self = shift;
  qsearch('cust_bill', { 'statementnum' => $self->statementnum } );
}

sub _aggregate {
  my( $self, $method ) = ( shift, shift );

  my @agg = ();

  foreach my $cust_bill ( $self->cust_bill ) {
    push @agg, $cust_bill->$method( @_ );
  }

  @agg;
}

sub _total {
  my( $self, $method ) = ( shift, shift );

  my $total = 0;

  foreach my $cust_bill ( $self->cust_bill ) {
    $total += $cust_bill->$method( @_ );
  }

  $total;
}

=item cust_bill_pkg

Returns the line items (see L<FS::cust_bill_pkg>) for all associated invoices.

=item cust_bill_pkg_pkgnum PKGNUM

Returns the line items (see L<FS::cust_bill_pkg>) for all associated invoices
and specified pkgnum.

=item cust_bill_pay

Returns all payment applications (see L<FS::cust_bill_pay>) for all associated
invoices.

=item cust_credited

Returns all applied credits (see L<FS::cust_credit_bill>) for all associated
invoices.

=item cust_bill_pay_pkgnum PKGNUM

Returns all payment applications (see L<FS::cust_bill_pay>) for all associated
invoices with matching pkgnum.

=item cust_credited_pkgnum PKGNUM

Returns all applied credits (see L<FS::cust_credit_bill>) for all associated
invoices with matching pkgnum.

=cut

sub cust_bill_pay        { shift->_aggregate('cust_bill_pay',        @_); }
sub cust_credited        { shift->_aggregate('cust_credited',        @_); }
sub cust_bill_pay_pkgnum { shift->_aggregate('cust_bill_pay_pkgnum', @_); }
sub cust_credited_pkgnum { shift->_aggregate('cust_credited_pkgnum', @_); }

sub cust_bill_pkg        { shift->_aggregate('cust_bill_pkg',        @_); }
sub cust_bill_pkg_pkgnum { shift->_aggregate('cust_bill_pkg_pkgnum', @_); }

=item tax

Returns the total tax amount for all assoicated invoices.0

=cut

=item charged

Returns the total amount charged for all associated invoices.

=cut

=item owed

Returns the total amount owed for all associated invoices.

=cut

sub tax     { shift->_total('tax',     @_); }
sub charged { shift->_total('charged', @_); }
sub owed    { shift->_total('owed',    @_); }

#don't show previous info
sub previous {
  ( 0 ); # 0, empty list
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_bill>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

