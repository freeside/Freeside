package FS::upgrade_journal;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::upgrade_journal - Object methods for upgrade_journal records

=head1 SYNOPSIS

  use FS::upgrade_journal;

  $record = new FS::upgrade_journal \%hash;
  $record = new FS::upgrade_journal { 'column' => 'value' };

  $error = $record->insert;

  # Typical use case
  my $upgrade = 'rename_all_customers_to_Bob';
  if ( ! FS::upgrade_journal->is_done($upgrade) ) {
    ... # do the upgrade, then, if it succeeds
    FS::upgrade_journal->set_done($upgrade);
  }

=head1 DESCRIPTION

An FS::upgrade_journal object records an upgrade procedure that was run 
on the database.  FS::upgrade_journal inherits from FS::Record.  The 
following fields are currently supported:

=over 4

=item upgradenum - primary key

=item _date - unix timestamp when the upgrade was run

=item upgrade - string identifier for the upgrade procedure; must match /^\w+$/

=item status - either 'done' or 'failed'

=item statustext - any other message that needs to be recorded

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new upgrade record.  To add it to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'upgrade_journal'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

sub delete  { die "upgrade_journal records can't be deleted" }
sub replace { die "upgrade_journal records can't be modified" }

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  if ( !$self->_date ) {
    $self->_date(time);
  }

  my $error = 
    $self->ut_numbern('upgradenum')
    || $self->ut_number('_date')
    || $self->ut_alpha('upgrade')
    || $self->ut_text('status')
    || $self->ut_textn('statustext')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 CLASS METHODS

=over 4

=item is_done UPGRADE

Returns the upgrade entry with identifier UPGRADE and status 'done', if 
there is one.  This is an easy way to check whether an upgrade has been done.

=cut

sub is_done {
  my ($class, $upgrade) = @_;
  qsearch('upgrade_journal', { 'status' => 'done', 'upgrade' => $upgrade })
}

=item set_done UPGRADE

Creates and inserts an upgrade entry with the current time, status 'done', 
and identifier UPGRADE.  Dies on error.

=cut

sub set_done {
  my ($class, $upgrade) = @_;
  my $new = $class->new({ 'status' => 'done', 'upgrade' => $upgrade });
  my $error = $new->insert;
  die $error if $error;
  $new;
}


=head1 BUGS

Despite how it looks, this is not currently suitable for use as a mutex.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

