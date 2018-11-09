package FS::cust_event_fee;
use base qw( FS::cust_main_Mixin FS::Record FS::FeeOrigin_Mixin );

use strict;
use FS::Record qw( qsearch dbh );
use FS::cust_event;

=head1 NAME

FS::cust_event_fee - Object methods for cust_event_fee records

=head1 SYNOPSIS

  use FS::cust_event_fee;

  $record = new FS::cust_event_fee \%hash;
  $record = new FS::cust_event_fee { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_event_fee object links a billing event that charged a fee
(an L<FS::cust_event>) to the resulting invoice line item (an 
L<FS::cust_bill_pkg> object).  FS::cust_event_fee inherits from FS::Record 
and FS::FeeOrigin_Mixin.  The following fields are currently supported:

=over 4

=item eventfeenum - primary key

=item eventnum - key of the cust_event record that required the fee to be 
created.  This is a unique column; there's no reason for a single event 
instance to create more than one fee.

=item billpkgnum - key of the cust_bill_pkg record representing the fee 
on an invoice.  This is also a unique column but can be NULL to indicate
a fee that hasn't been billed yet.  In that case it will be billed the next
time billing runs for the customer.

=item feepart - key of the fee definition (L<FS::part_fee>).

=item nextbill - 'Y' if the fee should be charged on the customer's next
bill, rather than causing a bill to be produced immediately.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new event-fee link.  To add the record to the database, 
see L<"insert">.

=cut

sub table { 'cust_event_fee'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $cust_bill_pkg = $self->cust_bill_pkg;
  if ( $cust_bill_pkg ) {
    my $error = $cust_bill_pkg->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('eventfeenum')
    || $self->ut_foreign_key('eventnum', 'cust_event', 'eventnum')
    || $self->ut_foreign_keyn('billpkgnum', 'cust_bill_pkg', 'billpkgnum')
    || $self->ut_foreign_key('feepart', 'part_fee', 'feepart')
    || $self->ut_flag('nextbill')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 CLASS METHODS

=over 4

=item _by_cust CUSTNUM[, PARAMS]

See L<FS::FeeOrigin_Mixin/by_cust>. This is the implementation for 
event-triggered fees.

=cut

sub _by_cust {
  my $class = shift;
  my $custnum = shift or return;
  my %params = @_;
  $custnum =~ /^\d+$/ or die "bad custnum $custnum";

  # silliness
  my $where = ($params{hashref} && keys (%{ $params{hashref} }))
              ? 'AND'
              : 'WHERE';
  qsearch({
    table     => 'cust_event_fee',
    addl_from => 'JOIN cust_event USING (eventnum) ' .
                 'JOIN part_event USING (eventpart) ',
    extra_sql => "$where eventtable = 'cust_main' ".
                 "AND cust_event.tablenum = $custnum",
    %params
  }),
  qsearch({
    table     => 'cust_event_fee',
    addl_from => 'JOIN cust_event USING (eventnum) ' .
                 'JOIN part_event USING (eventpart) ' .
                 'JOIN cust_bill ON (cust_event.tablenum = cust_bill.invnum)',
    extra_sql => "$where eventtable = 'cust_bill' ".
                 "AND cust_bill.custnum = $custnum",
    %params
  }),
  qsearch({
    table     => 'cust_event_fee',
    addl_from => 'JOIN cust_event USING (eventnum) ' .
                 'JOIN part_event USING (eventpart) ' .
                 'JOIN cust_pay_batch ON (cust_event.tablenum = cust_pay_batch.paybatchnum)',
    extra_sql => "$where eventtable = 'cust_pay_batch' ".
                 "AND cust_pay_batch.custnum = $custnum",
    %params
  }),
  qsearch({
    table     => 'cust_event_fee',
    addl_from => 'JOIN cust_event USING (eventnum) ' .
                 'JOIN part_event USING (eventpart) ' .
                 'JOIN cust_pkg ON (cust_event.tablenum = cust_pkg.pkgnum)',
    extra_sql => "$where eventtable = 'cust_pkg' ".
                 "AND cust_pkg.custnum = $custnum",
    %params
  })
}

=item cust_bill

See L<FS::FeeOrigin_Mixin/cust_bill>. This version simply returns the event
object if the event is an invoice event.

=cut

sub cust_bill {
  my $self = shift;
  my $object = $self->cust_event->cust_X;
  if ( $object->isa('FS::cust_bill') ) {
    return $object;
  } else {
    return '';
  }
}

=item cust_pkg

See L<FS::FeeOrigin_Mixin/cust_bill>. This version simply returns the event
object if the event is a package event.

=cut

sub cust_pkg {
  my $self = shift;
  my $object = $self->cust_event->cust_X;
  if ( $object->isa('FS::cust_pkg') ) {
    return $object;
  } else {
    return '';
  }
}

# stubs - remove in 4.x

sub cust_event {
  my $self = shift;
  FS::cust_event->by_key($self->eventnum);
}

=item search_sql_where

=cut

sub search_sql_where {
  my($class, $param) = @_;

  my $where = FS::cust_event->search_sql_where( $param );

  if ( $param->{'billpkgnum'} eq 'NULL' ) {
    $where .= ' AND billpkgnum IS NULL';
  } elsif ( $param->{'billpkgnum'} eq 'NOT NULL' ) {
    $where .= ' AND billpkgnum IS NOT NULL';
  }

  $where;

}

=item join_sql

=cut

sub join_sql {
  #my $class = shift;

  ' LEFT JOIN cust_event USING (eventnum)
    LEFT JOIN cust_bill_pkg USING (billpkgnum)
    LEFT JOIN cust_bill AS fee_cust_bill USING (invnum)
    LEFT JOIN part_fee ON (cust_event_fee.feepart = part_fee.feepart )
  '. FS::cust_event->join_sql();

}

=back
 
=head1 SUBROUTINES

=over 4

=item process_delete

=cut
 
sub process_delete {
  my( $job, $param ) = @_;

  my $search_sql = FS::cust_event_fee->search_sql_where($param);
  my $where = $search_sql ? " WHERE $search_sql" : '';

  my @cust_event_fee = qsearch({
    'table'     => 'cust_event_fee',
    'addl_from' => FS::cust_event_fee->join_sql(),
    'hashref'   => {},
    'extra_sql' => $where,
  });

  my( $num, $last, $min_sec ) = (0, time, 5); #progresbar foo
  foreach my $cust_event_fee ( @cust_event_fee ) {

    my $error = $cust_event_fee->delete;
    die $error if $error;

    if ( $job ) { #progressbar foo
      $num++;
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $num / scalar(@cust_event_fee) )
        );
        die $error if $error;
        $last = time;
      }
    }

  }

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_event>, L<FS::FeeOrigin_Mixin>, L<FS::Record>

=cut

1;

