package FS::vend_main;
use base qw( FS::Record );

use strict;

=head1 NAME

FS::vend_main - Object methods for vend_main records

=head1 SYNOPSIS

  use FS::vend_main;

  $record = new FS::vend_main \%hash;
  $record = new FS::vend_main { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::vend_main object represents a vendor.  FS::vend_main inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item vendnum

primary key

=item vendname

vendname

=item classnum

classnum

=item disabled

disabled


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new vendor.  To add the vendor to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'vend_main'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid vendor.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('vendnum')
    || $self->ut_text('vendname')
    || $self->ut_foreign_key('classnum', 'vend_class', 'classnum')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item vend_class

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
    push @where, "vend_main.classnum = $1";
  }

  my $extra_sql = scalar(@where) ? ' WHERE '. join(' AND ', @where) : '';

  my $group_by = ' GROUP BY vend_main.vendnum ';

  my $addl_from_vend_bill = ' LEFT JOIN vend_bill_pay USING (vendbillnum) '.
                            ' LEFT JOIN vend_pay      USING (vendpaynum)  ';

  $addl_from .= " LEFT JOIN vend_bill USING ( vendnum ) $addl_from_vend_bill";

  #simplistic, but how we are for now

  my $count_query = "
    SELECT COUNT(*),
           ( SELECT SUM(charged) from vend_bill $addl_from_vend_bill $extra_sql
           ) AS sum_charged
      FROM vend_main "; #XXX classnum, sum_charged > 0

  +{
    'table'         => 'vend_main',
    'select'        => 'vend_main.*, sum(vend_bill.charged) as sum_charged',
    'addl_from'     => $addl_from,
    'hashref'       => {},
    'extra_sql'     => "$extra_sql $group_by",
    'order_by'      => 'ORDER BY sum_charged desc',
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

