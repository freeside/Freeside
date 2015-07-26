package FS::Cron::backup;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use File::Copy;
use Date::Format;
use FS::UID qw(driver_name datasrc);
use FS::Misc qw( send_email );

@ISA = qw( Exporter );
@EXPORT_OK = qw( backup );

sub backup {
  my $conf = new FS::Conf;
  my $localdest = $conf->config('dump-localdest');
  my $scpdest = $conf->config('dump-scpdest');
  return unless $localdest || $scpdest;

  my $filename = time2str('%Y%m%d%H%M%S',time);

  datasrc =~ /dbname=([\w\.]+)$/
    or backup_email_and_die($conf,$filename,"unparsable datasrc ". datasrc);
  my $database = $1;

  my $ext;
  if ( driver_name eq 'Pg' ) {
    system("pg_dump -Fc $database >/var/tmp/$database.Pg");
    $ext = 'Pg';
  } elsif ( driver_name eq 'mysql' ) {
    system("mysqldump $database >/var/tmp/$database.sql");
    $ext = 'sql';
  } else {
    backup_email_and_die($conf,$filename,"database dumps not yet supported for ". driver_name);
  }
  chmod 0600, "/var/tmp/$database.$ext";

  if ( $conf->config('dump-pgpid') ) {
    eval 'use GnuPG;';
    backup_email_and_die($conf,$filename,$@) if $@;
    my $gpg = new GnuPG;
    $gpg->encrypt( plaintext => "/var/tmp/$database.$ext",
                   output    => "/var/tmp/$database.gpg",
                   recipient => $conf->config('dump-pgpid'),
                 );
    unlink "/var/tmp/$database.$ext"
      or backup_email_and_die($conf,$filename,$!);
    chmod 0600, "/var/tmp/$database.gpg";
    $ext = 'gpg';
  }

  if ( $localdest ) {
    copy("/var/tmp/$database.$ext", "$localdest/$filename.$ext")
      or backup_email_and_die($conf,$filename,$!);
    chmod 0600, "$localdest/$filename.$ext";
  }

  if ( $scpdest ) {
    eval "use Net::SCP qw(scp);";
    backup_email_and_die($conf,$filename,$@) if $@;
    scp("/var/tmp/$database.$ext", "$scpdest/$filename.$ext");
  }

  unlink "/var/tmp/$database.$ext" or backup_email_and_die($conf,$filename,$!); #or just warn?

  backup_email($conf,$filename);

}

#runs backup_email and dies with same error message
sub backup_email_and_die {
  my ($conf,$filename,$error) = @_;
  backup_email($conf,$filename,$error);
  warn "backup_email_and_die called without error message" unless $error;
  die $error;
}

#checks if email should be sent, sends it
sub backup_email {
  my ($conf,$filename,$error) = @_;
  my $to = $conf->config('dump-email_to');
  return unless $to;
  my $result = $error ? 'FAILED' : 'succeeded';
  my $email_error = send_email(
    'from'    => $conf->config('invoice_from'), #or whatever, don't think it matters
    'to'      => $to,
    'subject' => 'FREESIDE NOTIFICATION: Backup ' . $result,
    'body'    => [ 
      "This is an automatic message from your Freeside installation.\n",
      "Freeside backup $filename $result",
      ($error ? " with the following error:\n\n" : "\n"),
      ($error || ''),      
      "\n",
    ],
    'msgtype' => 'admin',
  );
  warn $email_error if $email_error;
  return;
}

1;
