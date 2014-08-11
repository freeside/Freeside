package FS::sched_avail;
use base qw( FS::Record );

use strict;
#use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::sched_avail - Object methods for sched_avail records

=head1 SYNOPSIS

  use FS::sched_avail;

  $record = new FS::sched_avail \%hash;
  $record = new FS::sched_avail { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::sched_avail object represents an availability period/interval.
FS::sched_avail inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item availnum

primary key

=item itemnum

itemnum

=item wday

wday

=item stime

stime

=item etime

etime

=item override_date

override_date


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new period.  To add the period to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'sched_avail'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid period.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('availnum')
    || $self->ut_foreign_key('itemnum', 'sched_item', 'itemnum')
    || $self->ut_number('wday')
    || $self->ut_number('stime')
    || $self->ut_number('etime')
    || $self->ut_numbern('override_date')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item stime_pretty

=item etime_pretty

=cut

sub stime_pretty { shift->_time_pretty('stime', @_); }
sub etime_pretty { shift->_time_pretty('etime', @_); }

sub _time_pretty {
  my( $self, $field ) = @_;

  pretty_time( $self->$field() );
}

#helper sub
sub pretty_time {
  my $t = shift;

  return 'Midnight' if $t == 0 || $t == 1440;
  return 'Noon'     if $t == 720;

  my $h = int( $t / 60 );
  my $m = $t % 60;

  my $ap = 'AM';
  if    ( $h == 0 || $h == 24 ) { $h = 12; }
  elsif ( $h == 12 )           { $ap = 'PM'; }
  elsif ( $h > 12 )            { $ap = 'PM'; $h -= 12; }

  sprintf('%02d:%02d'." $ap", $h, $m);

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::sched_item>, L<FS::Record>

=cut

1;

