package FS::did_order;

use strict;
use base qw( FS::o2m_Common FS::Record );
use FS::Record qw( qsearch qsearchs dbh );

=head1 NAME

FS::did_order - Object methods for did_order records

=head1 SYNOPSIS

  use FS::did_order;

  $record = new FS::did_order \%hash;
  $record = new FS::did_order { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::did_order object represents a bulk DID order.  FS::did_order inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item ordernum

primary key

=item vendornum

vendornum

=item vendor_order_id

vendor_order_id

=item submitted

submitted

=item confirmed

confirmed

=item received

received


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new bulk DID order.  To add it to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'did_order'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  return "Can't delete a DID order which has DIDs received"
    if qsearch( 'phone_avail', { 'ordernum' => $self->ordernum } );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my @did_order_item = $self->did_order_item;

  foreach my $did_order_item ( @did_order_item ) {
    my $error = $did_order_item->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't delete DID order item "
                                . $did_order_item->orderitemnum . ": $error";
    }
  }

  my $error = $self->SUPER::delete(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
}

=item merge SOURCE_ORDER

Merges the DID order given by SOURCE_ORDER into THIS order. 

The following fields from the source order are transferred, only if they aren't
set in this order:
-vendor order #
-submitted
-confirmed
-customer

DID order items are transferred into this order.

The source order is deleted.

The operation fails if:
-either order has a received time; or
-the DID vendors do not match between the orders

=cut

sub merge {
    my $self = shift;
    my $src = shift;
    return "invalid source order" unless $src;

    return "DIDs received for either order" 
        if $src->received || $self->received;

    return "DID vendors do not match"
        if $src->vendornum != $self->vendornum;

    my @move_if_unset = qw( vendor_order_id submitted confirmed custnum );
    foreach my $f ( @move_if_unset ) {
        $self->$f($src->$f) if !$self->$f;
    }

    my $error = '';
    my @did_order_items = qsearch('did_order_item', { 'ordernum' => $src->ordernum });
    foreach my $did_order_item ( @did_order_items ) {
        $did_order_item->ordernum($self->ordernum);
        $error = $did_order_item->replace;
        return $error if $error;
    }

    $error = $src->delete;
    return $error if !$error;

    $error = $self->replace;
    return $error if !$error;

    '';
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid bulk DID order.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('ordernum')
    || $self->ut_foreign_key('vendornum', 'did_vendor', 'vendornum' )
    || $self->ut_textn('vendor_order_id')
    || $self->ut_number('submitted')
    || $self->ut_numbern('confirmed')
    || $self->ut_numbern('received')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item did_order_item

Returns the did_order_items (see L<FS::did_order_item>) associated with this bulk DID order.

=cut

sub did_order_item {
  my $self = shift;
  qsearch( 'did_order_item', { 'ordernum' => $self->ordernum } );
}

=item cust_main

Returns all cust_main (see L<FS::cust_main>), if any, associated with this
bulk DID order.

=cut

sub cust_main {
  my $self = shift;
  my @did_order_item = $self->did_order_item;
  my @custnums;
  push @custnums, $self->custnum if $self->custnum;
  foreach my $did_order_item ( @did_order_item ) {
       push @custnums, $did_order_item->custnum if $did_order_item->custnum; 
  }
  my @cust_main;
  foreach my $custnum ( @custnums ) {
      push @cust_main, qsearchs('cust_main', { 'custnum' => $custnum } );
  }
  @cust_main; 
}


=item has_stock 

Returns true if and only if the order has any stock order items.

=cut

sub has_stock {
    my $self = shift;
    my $items_with_custnum = 0;
    my @did_order_item = $self->did_order_item;
    foreach my $did_order_item ( @did_order_item ) {
        $items_with_custnum++ if $did_order_item->custnum;
    }

    return 0 if ($items_with_custnum == scalar(@did_order_item) 
                    && $items_with_custnum != 0 && !$self->custnum) 
                || $self->custnum;
    1;
}


=item provisioned

Returns the provisioned DIDs, if any, as phone_avail (see L<FS::phone_avail>) objects.

=cut

sub provisioned {
  my $self = shift;
  qsearch({ table   => 'phone_avail',
              hashref => { 'ordernum' => $self->ordernum, },
              select  => 'phone_avail.*',
              extra_sql => ' and svcnum is not null ',
         });
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

