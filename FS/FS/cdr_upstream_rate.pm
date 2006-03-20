package FS::cdr_upstream_rate;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );
use FS::rate_detail;

@ISA = qw(FS::Record);

=head1 NAME

FS::cdr_upstream_rate - Object methods for cdr_upstream_rate records

=head1 SYNOPSIS

  use FS::cdr_upstream_rate;

  $record = new FS::cdr_upstream_rate \%hash;
  $record = new FS::cdr_upstream_rate { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cdr_upstream_rate object represents an upstream rate mapping to 
internal rate detail (see L<FS::rate_detail>).  FS::cdr_upstream_rate inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item upstreamratenum - primary key

=item upstream_rateid - CDR upstream Rate ID (cdr.upstream_rateid - see L<FS::cdr>)

=item ratedetailnum - Rate detail - see L<FS::rate_detail>

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new upstream rate mapping.  To add the upstream rate to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cdr_upstream_rate'; }

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

Checks all fields to make sure this is a valid upstream rate.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('upstreamratenum')
    #|| $self->ut_number('upstream_rateid')
    || $self->ut_alpha('upstream_rateid')
    #|| $self->ut_text('upstream_rateid')
    || $self->ut_foreign_key('ratedetailnum', 'rate_detail', 'ratedetailnum' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item rate_detail

Returns the internal rate detail object for this upstream rate (see
L<FS::rate_detail>).

=cut

sub rate_detail {
  my $self = shift;
  qsearchs('rate_detail', { 'ratedetailnum' => $self->ratedetailnum } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

