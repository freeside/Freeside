package FS::rate_tier;
use base qw( FS::o2m_Common FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );
use FS::rate_tier_detail;

=head1 NAME

FS::rate_tier - Object methods for rate_tier records

=head1 SYNOPSIS

  use FS::rate_tier;

  $record = new FS::rate_tier \%hash;
  $record = new FS::rate_tier { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rate_tier object represents a set of rate tiers.  FS::rate_tier inherits
 from FS::Record.  The following fields are currently supported:

=over 4

=item tiernum

primary key

=item tiername

tiername


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rate_tier'; }

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
    $self->ut_numbern('tiernum')
    || $self->ut_text('tiername')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item rate_tier_detail QUANTITY

=cut

sub rate_tier_detail {
  my $self = shift;

  if ( defined($_[0]) && length($_[0]) ) {

    my $quantity = shift;

    qsearchs({
      'table'    => 'rate_tier_detail',
      'hashref'  => { 'tiernum'  => $self->tiernum,
                      'min_quan' => { op=>'<=', value=>$quantity },
                    },
      'order_by' => 'ORDER BY min_charge ASC LIMIT 1',
    });

  } else {

    qsearch({
      'table'    => 'rate_tier_detail',
      'hashref'  => { 'tiernum' => $self->tiernum, },
      'order_by' => 'ORDER BY min_quan ASC',
    });

  }

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

