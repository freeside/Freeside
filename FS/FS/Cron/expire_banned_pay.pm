package FS::Cron::expire_banned_pay;

use vars qw( @ISA @EXPORT_OK );
use Exporter;
use FS::UID qw(dbh);

@ISA = qw( Exporter );
@EXPORT_OK = qw( expire_banned_pay );

sub expire_banned_pay {
  my $sql = "DELETE FROM banned_pay WHERE end_date IS NOT NULL".
                                    " AND end_date < ?";
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute(time) or die $sth->errstr;

  dbh->commit or die dbh->errstr if $FS::UID::AutoCommit

}

1;
