package FS::TicketSystem;

use strict;
use vars qw( $conf $system $AUTOLOAD );
use FS::Conf;
use FS::UID qw( dbh driver_name );

FS::UID->install_callback( sub { 
  $conf = new FS::Conf;
  $system = $conf->config('ticket_system');
} );

sub AUTOLOAD {
  my $self = shift;

  my($sub)=$AUTOLOAD;
  $sub =~ s/.*://;

  my $conf = new FS::Conf;
  die "FS::TicketSystem::$AUTOLOAD called, but no ticket system configured\n"
    unless $system;

  eval "use FS::TicketSystem::$system;";
  die $@ if $@;

  $self .= "::$system";
  $self->$sub(@_);
}

sub _upgrade_data {
  return if $system ne 'RT_Internal';

  my ($class, %opts) = @_;
  my ($t, $exec, @fields) = map { driver_name =~ /^mysql/i ? $_ : lc($_) }
  (qw( ScripConditions ExecModule
    Name Description ExecModule ApplicableTransTypes
    Creator Created LastUpdatedBy LastUpdated));
  my $count_sql = "SELECT COUNT(*) FROM $t WHERE $exec = 'CustomFieldChange'";
  my $sth = dbh->prepare($count_sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  my $total = $sth->fetchrow_arrayref->[0];
  return if $total > 0;

  my $insert_sql = "INSERT INTO $t (".join(',',@fields).") VALUES (".
  "'On Custom Field Change', 'When a custom field is changed to some value',
  'CustomFieldChange', 'Any', 1, CURRENT_DATE, 1, CURRENT_DATE )";
  $sth = dbh->prepare($insert_sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  return;
}

1;
