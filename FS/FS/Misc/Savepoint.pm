package FS::Misc::Savepoint;

use strict;
use warnings;

use Exporter;
use vars qw( @ISA @EXPORT @EXPORT_OK );
@ISA = qw( Exporter );
@EXPORT = qw( savepoint_create savepoint_release savepoint_rollback );

use FS::UID qw( dbh );
use Carp qw( croak );

=head1 NAME

FS::Misc::Savepoint - Provides methods for SQL Savepoints

=head1 SYNOPSIS

  use FS::Misc::Savepoint;
  
  # Only valid within a transaction
  local $FS::UID::AutoCommit = 0;
  
  savepoint_create( 'savepoint_label' );
  
  my $error_msg = do_some_things();
  
  if ( $error_msg ) {
    savepoint_rollback_and_release( 'savepoint_label' );
  } else {
    savepoint_release( 'savepoint_label' );
  }


=head1 DESCRIPTION

Provides methods for SQL Savepoints

Using a savepoint allows for a partial roll-back of SQL statements without
forcing a rollback of the entire enclosing transaction.

=head1 METHODS

=over 4

=item savepoint_create LABEL

=item savepoint_create { label => LABEL, dbh => DBH }

Executes SQL to create a savepoint named LABEL.

Savepoints cannot work while AutoCommit is enabled.

Savepoint labels must be valid sql identifiers.  If your choice of label
would not make a valid column name, it probably will not make a valid label.

Savepint labels must be unique within the transaction.

=cut

sub savepoint_create {
  my %param = _parse_params( @_ );

  $param{dbh}->do("SAVEPOINT $param{label}")
    or die $param{dbh}->errstr;
}

=item savepoint_release LABEL

=item savepoint_release { label => LABEL, dbh => DBH }

Release the savepoint - preserves the SQL statements issued since the
savepoint was created, but does not commit the transaction.

The savepoint label is freed for future use.

=cut

sub savepoint_release {
  my %param = _parse_params( @_ );

  $param{dbh}->do("RELEASE SAVEPOINT $param{label}")
    or die $param{dbh}->errstr;
}

=item savepoint_rollback LABEL

=item savepoint_rollback { label => LABEL, dbh => DBH }

Roll back the savepoint - forgets all SQL statements issues since the
savepoint was created, but does not commit or roll back the transaction.

The savepoint still exists.  Additional statements may be executed,
and savepoint_rollback called again.

=cut

sub savepoint_rollback {
  my %param = _parse_params( @_ );

  $param{dbh}->do("ROLLBACK TO SAVEPOINT $param{label}")
    or die $param{dbh}->errstr;
}

=item savepoint_rollback_and_release LABEL

=item savepoint_rollback_and_release { label => LABEL, dbh => DBH }

Rollback and release the savepoint

=cut

sub savepoint_rollback_and_release {
  savepoint_rollback( @_ );
  savepoint_release( @_ );
}

=back

=head1 METHODS - Internal

=over 4

=item _parse_params

Create %params from function input

Basic savepoint label validation

Complain when trying to use savepoints without disabling AutoCommit

=cut

sub _parse_params {
  my %param = ref $_[0] ? %{ $_[0] } : ( label => $_[0] );
  $param{dbh} ||= dbh;

  # Savepoints may be any valid SQL identifier up to 64 characters
  $param{label} =~ /^\w+$/
    or croak sprintf(
      'Invalid savepont label(%s) - use only numbers, letters, _',
      $param{label}
    );

  croak sprintf( 'Savepoint(%s) failed - AutoCommit=1', $param{label} )
    if $FS::UID::AutoCommit;

  %param;
}

=back

=head1 BUGS

=head1 SEE ALSO

=cut

1;