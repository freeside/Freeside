package FS::Cron::vacuum;

use vars qw( @ISA @EXPORT_OK);
use Exporter;
use FS::UID qw(driver_name dbh);
use FS::Schema qw(dbdef);

@ISA = qw( Exporter );
@EXPORT_OK = qw( vacuum );

sub vacuum {

  if ( driver_name eq 'Pg' ) {
    dbh->{AutoCommit} = 1; #so we can vacuum
    foreach my $table ( dbdef->tables ) {
      my $sth = dbh->prepare("VACUUM ANALYZE $table") or die dbh->errstr;
      $sth->execute or die $sth->errstr;
    }
  }

}

1;
