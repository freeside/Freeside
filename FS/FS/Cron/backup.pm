package FS::Cron::backup;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use File::Copy;
use Date::Format;
use FS::UID qw(driver_name datasrc);
use FS::Log

@ISA = qw( Exporter );
@EXPORT_OK = qw( backup );

sub backup {
  my $conf = new FS::Conf;
  my $localdest = $conf->config('dump-localdest');
  my $scpdest = $conf->config('dump-scpdest');
  return unless $localdest || $scpdest;

  my $filename = time2str('%Y%m%d%H%M%S',time);

  datasrc =~ /dbname=([\w\.]+)$/
    or backup_log_and_die($filename,"unparsable datasrc ". datasrc);
  my $database = $1;

  my $ext;
  if ( driver_name eq 'Pg' ) {
    system("pg_dump -Fc $database >/var/tmp/$database.Pg");
    $ext = 'Pg';
  } elsif ( driver_name eq 'mysql' ) {
    system("mysqldump $database >/var/tmp/$database.sql");
    $ext = 'sql';
  } else {
    backup_log_and_die($filename,"database dumps not yet supported for ". driver_name);
  }
  chmod 0600, "/var/tmp/$database.$ext";

  if ( $conf->config('dump-pgpid') ) {
    eval 'use GnuPG;';
    backup_log_and_die($filename,$@) if $@;
    my $gpg = new GnuPG;
    $gpg->encrypt( plaintext => "/var/tmp/$database.$ext",
                   output    => "/var/tmp/$database.gpg",
                   recipient => $conf->config('dump-pgpid'),
                 );
    unlink "/var/tmp/$database.$ext"
      or backup_log_and_die($filename,$!);
    chmod 0600, "/var/tmp/$database.gpg";
    $ext = 'gpg';
  }

  if ( $localdest ) {
    copy("/var/tmp/$database.$ext", "$localdest/$filename.$ext")
      or backup_log_and_die($filename,$!);
    chmod 0600, "$localdest/$filename.$ext";
  }

  if ( $scpdest ) {
    eval "use Net::SCP qw(scp);";
    backup_log_and_die($filename,$@) if $@;
    scp("/var/tmp/$database.$ext", "$scpdest/$filename.$ext");
  }

  unlink "/var/tmp/$database.$ext" or backup_log_and_die($filename,$!); #or just warn?

  backup_log($filename);

}

#runs backup_log and dies with same error message
sub backup_log_and_die {
  my ($filename,$error) = @_;
  $error = "backup_log_and_die called without error message" unless $error;
  backup_log($filename,$error);
  die $error;
}

#logs result
sub backup_log {
  my ($filename,$error) = @_;
  my $result = $error ? "FAILED: $error" : 'succeeded';
  my $message = "backup $filename $result\n";
  my $log = FS::Log->new('Cron::backup');
  if ($error) {
    $log->error($message);
  } else {
    $log->info($message);
  }
  return;
}

1;
