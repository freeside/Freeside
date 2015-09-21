package FS::part_event_option;

use strict;
use vars qw( @ISA );
use Scalar::Util qw( blessed );
use FS::UID qw( dbh );
use FS::Record qw( qsearch qsearchs );
use FS::part_event;
use FS::reason;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_event_option - Object methods for part_event_option records

=head1 SYNOPSIS

  use FS::part_event_option;

  $record = new FS::part_event_option \%hash;
  $record = new FS::part_event_option { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_event_option object represents an event definition option (action
option).  FS::part_event_option inherits from FS::Record.  The following fields
are currently supported:

=over 4

=item optionnum - primary key

=item eventpart - Event definition (see L<FS::part_event>)

=item optionname - Option name

=item optionvalue - Option value

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_event_option'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $self->optionname eq 'reasonnum' && $self->optionvalue eq 'HASH' ) {

    my $error = $self->insert_reason(@_);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace [ OLD_RECORD ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $old = ( blessed($_[0]) && $_[0]->isa('FS::Record') )
              ? shift
              : $self->replace_old;

  if ( $self->optionname eq 'reasonnum' ) {
    warn "reasonnum: ". $self->optionvalue;
  }
  if ( $self->optionname eq 'reasonnum' && $self->optionvalue eq 'HASH' ) {

    my $error = $self->insert_reason(@_);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  my $error = $self->SUPER::replace($old);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

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
    $self->ut_numbern('optionnum')
    || $self->ut_foreign_key('eventpart', 'part_event', 'eventpart' )
    || $self->ut_text('optionname')
    #|| $self->ut_textn('optionvalue')
    || $self->ut_anything('optionvalue') #http.pm content has \n
  ;
  return $error if $error;

  $self->SUPER::check;
}

sub insert_reason {
  my( $self, $reason ) = @_;

  my $reason_obj = new FS::reason({
    'reason_type' => $reason->{'typenum'},
    'reason'      => $reason->{'reason'},
  });

  $reason_obj->insert or $self->optionvalue( $reason_obj->reasonnum ) and '';

}

=back

=head1 SEE ALSO

L<FS::part_event>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

