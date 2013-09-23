package FS::vend_bill;

use strict;
use base qw( FS::Record );
use FS::Record qw( dbh qsearch qsearchs );
use FS::vend_main;
use FS::vend_pay;
use FS::vend_bill_pay;

=head1 NAME

FS::vend_bill - Object methods for vend_bill records

=head1 SYNOPSIS

  use FS::vend_bill;

  $record = new FS::vend_bill \%hash;
  $record = new FS::vend_bill { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::vend_bill object represents a vendor invoice or payable.  FS::vend_bill
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item vendbillnum

primary key

=item vendnum

vendnum

=item _date

_date

=item charged

charged


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'vend_bill'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "inserting vend_bill: $error";
  }

  #magically auto-inserting for the simple case
  my $vend_pay = new FS::vend_pay {
    'vendnum'    => $self->vendnum,
    'vendbillnum' => $self->vendbillnum,
    '_date'       => $self->get('payment_date') || $self->_date,
    'paid'        => $self->charged,
  };

  $error = $vend_pay->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "auto-inserting vend_pay: $error";
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $vend_bill_pay ( $self->vend_bill_pay ) {
    my $error = $vend_bill_pay->delete;
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

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('vendbillnum')
    || $self->ut_foreign_key('vendnum', 'vend_main', 'vendnum')
    || $self->ut_numbern('_date')
    || $self->ut_money('charged')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item vend_main

=cut

sub vend_main {
  my $self = shift;
  qsearchs('vend_main', { 'vendnum', $self->vendnum });
}

=item vend_bill_pay

=cut

sub vend_bill_pay {
  my $self = shift;
  qsearch('vend_bill_pay', { 'vendbillnum', $self->vendbillnum });
}

=item search

=cut

sub search {
  my ($class, $param) = @_;

  my @where = ();
  my $addl_from = '';

  #_date
  if ( $param->{_date} ) {
    my($beginning, $ending) = @{$param->{_date}};

    push @where, "vend_bill._date >= $beginning",
                 "vend_bill._date <  $ending";
  }

  #payment_date
  if ( $param->{payment_date} ) {
    my($beginning, $ending) = @{$param->{payment_date}};

    push @where, "vend_pay._date >= $beginning",
                 "vend_pay._date <  $ending";
  }

  if ( $param->{'classnum'} =~ /^(\d+)$/ ) {
    #also simplistic, but good for now
    $addl_from .= ' LEFT JOIN vend_main USING (vendnum) ';
    push @where, "vend_main.classnum = $1";
  }

  my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

  #simplistic, but how we are for now
  $addl_from .= ' LEFT JOIN vend_bill_pay USING (vendbillnum) '.
                ' LEFT JOIN vend_pay      USING (vendpaynum)  ';

  my $count_query = "SELECT COUNT(*), SUM(charged) FROM vend_bill $addl_from $extra_sql";

  +{
    'table'         => 'vend_bill',
    'select'        => 'vend_bill.*, vend_pay._date as payment_date',
    'addl_from'     => $addl_from,
    'hashref'       => {},
    'extra_sql'     => $extra_sql,
    'order_by'      => 'ORDER BY _date',
    'count_query'   => $count_query,
    #'extra_headers' => \@extra_headers,
    #'extra_fields'  => \@extra_fields,
  };
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

