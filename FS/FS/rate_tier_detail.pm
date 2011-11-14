package FS::rate_tier_detail;
use base qw( FS::Record );

use strict;
use FS::Record; # qw( qsearch qsearchs );
use FS::rate_tier;

=head1 NAME

FS::rate_tier_detail - Object methods for rate_tier_detail records

=head1 SYNOPSIS

  use FS::rate_tier_detail;

  $record = new FS::rate_tier_detail \%hash;
  $record = new FS::rate_tier_detail { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rate_tier_detail object represents rate tier pricing.
FS::rate_tier_detail inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item tierdetailnum

primary key

=item tiernum

tiernum

=item min_quan

min_quan

=item min_charge

min_charge


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rate_tier_detail'; }

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

  my $min_quan = $self->min_quan;
  $min_quan =~ s/[ ,]//g;
  $self->min_quan($min_quan);

  $self->min_quan(0) if $self->min_quan eq '';

  my $error = 
    $self->ut_numbern('tierdetailnum')
    || $self->ut_foreign_key('tiernum', 'rate_tier', 'tiernum')
    || $self->ut_number('min_quan')
    || $self->ut_textn('min_charge') #XXX money?  but we use 4 decimal places
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

