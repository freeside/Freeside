package FS::Cron::backup;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use Date::Format;
use FS::UID qw(driver_name datasrc);

@ISA = qw( Exporter );
@EXPORT_OK = qw( backup_scp );

sub backup_scp {
  my $conf = new FS::Conf;
  my $dest = $conf->config('dump-scpdest');
  if ( $dest ) {
    $dest .= time2str('/%Y%m%d%H%M%S',time);
    datasrc =~ /dbname=([\w\.]+)$/ or die "unparsable datasrc ". datasrc;
    my $database = $1;
    eval "use Net::SCP qw(scp);";
    die $@ if $@;
    if ( driver_name eq 'Pg' ) {
      system("pg_dump $database >/var/tmp/$database.sql")
    } else {
      die "database dumps not yet supported for ". driver_name;
    }
    if ( $conf->config('dump-pgpid') ) {
      eval 'use GnuPG;';
      die $@ if $@;
      my $gpg = new GnuPG;
      $gpg->encrypt( plaintext => "/var/tmp/$database.sql",
                     output    => "/var/tmp/$database.gpg",
                     recipient => $conf->config('dump-pgpid'),
                   );
      chmod 0600, '/var/tmp/$database.gpg';
      scp("/var/tmp/$database.gpg", "$dest.gpg");
      unlink "/var/tmp/$database.gpg" or die $!;
    } else {
      chmod 0600, '/var/tmp/$database.sql';
      scp("/var/tmp/$database.sql", "$dest.sql");
    }
    unlink "/var/tmp/$database.sql" or die $!;
  }
}

1;
