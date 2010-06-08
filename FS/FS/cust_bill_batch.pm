package FS::cust_bill_batch;

use strict;
use vars qw( @ISA $me $DEBUG );
use FS::Record qw( qsearch qsearchs dbh );

@ISA = qw( FS::option_Common );
$me = '[ FS::cust_bill_batch ]';
$DEBUG=0;

sub table { 'cust_bill_batch' }

=head1 NAME

FS::cust_bill_batch - Object methods for cust_bill_batch records

=head1 DESCRIPTION

An FS::cust_bill_batch object represents the inclusion of an invoice in a 
processing batch.  FS::cust_bill_batch inherits from FS::option_Common.  The 
following fields are currently supported:

=over 4

=item billbatchnum - primary key

=item invnum - invoice number (see C<FS::cust_bill>)

=item batchnum - batchn number (see C<FS::bill_batch>)

=back

=head1 METHODS

=over 4

=item bill_batch

Returns the C<FS::bill_batch> object.

=cut

sub bill_batch { 
  my $self = shift;
  FS::bill_batch->by_key($self->batchnum);
}

=item cust_bill

Returns the C<FS::cust_bill> object.

=cut

sub cust_bill {
  my $self = shift;
  FS::cust_bill->by_key($self->invnum);
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

