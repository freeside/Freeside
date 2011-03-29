package FS::Cron::backup;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use File::Copy;
use Date::Format;
use FS::UID qw(driver_name datasrc);

@ISA = qw( Exporter );
@EXPORT_OK = qw( backup );

sub backup {
  my $conf = new FS::Conf;
  my $localdest = $conf->config('dump-localdest');
  my $scpdest = $conf->config('dump-scpdest');
  return unless $localdest || $scpdest;

  my $filename = time2str('%Y%m%d%H%M%S',time);

  datasrc =~ /dbname=([\w\.]+)$/ or die "unparsable datasrc ". datasrc;
  my $database = $1;

  my $ext;
  if ( driver_name eq 'Pg' ) {
    system("pg_dump -Fc $database >/var/tmp/$database.Pg");
    $ext = 'Pg';
  } elsif ( driver_name eq 'mysql' ) {
    system("mysqldump $database >/var/tmp/$database.sql");
    $ext = 'sql';
  } else {
    die "database dumps not yet supported for ". driver_name;
  }
  chmod 0600, "/var/tmp/$database.$ext";

  if ( $conf->config('dump-pgpid') ) {
    eval 'use GnuPG;';
    die $@ if $@;
    my $gpg = new GnuPG;
    $gpg->encrypt( plaintext => "/var/tmp/$database.$ext",
                   output    => "/var/tmp/$database.gpg",
                   recipient => $conf->config('dump-pgpid'),
                 );
    unlink "/var/tmp/$database.$ext" or die $!;
    chmod 0600, "/var/tmp/$database.gpg";
    $ext = 'gpg';
  }

  if ( $localdest ) {
    copy("/var/tmp/$database.$ext", "$localdest/$filename.$ext") or die $!;
    chmod 0600, "$localdest/$filename.$ext";
  }

  if ( $scpdest ) {
    eval "use Net::SCP qw(scp);";
    die $@ if $@;
    scp("/var/tmp/$database.$ext", "$scpdest/$filename.$ext");
  }

  unlink "/var/tmp/$database.$ext" or die $!;

}

1;
