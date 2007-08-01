package FS::Cron::expire_user_pref;

use vars qw( @ISA @EXPORT_OK);
use Exporter;
use FS::UID qw(dbh);

@ISA = qw( Exporter );
@EXPORT_OK = qw( expire_user_pref );

sub expire_user_pref {
  my $sql = "DELETE FROM access_user_pref WHERE expiration IS NOT NULL".
                                          " AND expiration < ?";
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute(time) or die $sth->errstr;
}

1;
