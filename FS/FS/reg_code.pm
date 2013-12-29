package FS::reg_code;
use base qw(FS::Record);

use strict;
use FS::Record qw( dbh ); # qsearch qsearchs dbh );
use FS::reg_code_pkg;

=head1 NAME

FS::reg_code - One-time registration codes

=head1 SYNOPSIS

  use FS::reg_code;

  $record = new FS::reg_code \%hash;
  $record = new FS::reg_code { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::reg_code object is a one-time registration code.  FS::reg_code inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item codenum - primary key

=item code - registration code string

=item agentnum - Agent (see L<FS::agent>)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new registration code.  To add the code to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'reg_code'; }

=item insert [ PKGPART_ARRAYREF ] 

Adds this record to the database.  If an arrayref of pkgparts
(see L<FS::part_pkg>) is specified, the appropriate reg_code_pkg records
(see L<FS::reg_code_pkg>) will be inserted.

If there is an error, returns the error, otherwise returns false.

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

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( @_ ) {
    my $pkgparts = shift;
    foreach my $pkgpart ( @$pkgparts ) {
      my $reg_code_pkg = new FS::reg_code_pkg ( {
        'codenum' => $self->codenum,
        'pkgpart' => $pkgpart,
      } );
      $error = $reg_code_pkg->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete

Delete this record (and all associated reg_code_pkg records) from the database.

=cut

sub delete {
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

  foreach my $reg_code_pkg ( $self->reg_code_pkg ) {
    my $error = $reg_code_pkg->delete;
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

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid registration code.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('codenum')
    || $self->ut_alpha('code')
    || $self->ut_foreign_key('agentnum', 'agent', 'agentnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item part_pkg

Returns all package definitions (see L<FS::part_pkg> for this registration
code.

=cut

sub part_pkg {
  my $self = shift;
  map { $_->part_pkg } $self->reg_code_pkg;
}

=item reg_code_pkg

Returns all FS::reg_code_pkg records for this registration code.

=back

=head1 BUGS

Feeping creaturitis.

=head1 SEE ALSO

L<FS::reg_code_pkg>, L<FS::Record>, schema.html from the base documentation.

=cut

1;


