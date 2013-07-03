package FS::device_Common;

use strict;
use NEXT;
use FS::Record qw( qsearch dbh ); # qsearchs );

=head1 NAME

FS::device_Common - Base class for svc_X classes which have associated X_devices

=head1 SYNOPSIS

  package FS::svc_newservice
  use base qw( FS::device_Common FS::svc_Common );

=head1 DESCRIPTION

=cut

sub _device_table {
  my $self = shift;
  ( my $device_table = $self->table ) =~ s/^svc_//;
  $device_table.'_device';
}

sub device_table {
  my $self = shift;
  my $device_table = $self->_device_table;
  eval "use FS::$device_table;";
  die $@ if $@;
  $device_table;
}

sub device_objects {
  my $self = shift;
  qsearch($self->device_table, { 'svcnum' => $self->svcnum } );
}

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

  foreach my $device ( $self->device_objects ) {
    my $error = $device->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->NEXT::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=head1 BUGS

=head1 SEE ALSO

=cut

1;
