package FS::Cron::disable_quotation;

use vars qw( @ISA @EXPORT_OK );
use Exporter;
use FS::UID qw(dbh);
use FS::Conf;

@ISA = qw( Exporter );
@EXPORT_OK = qw( disable_quotation );

sub disable_quotation {
    if ( my $days = FS::Conf->new->config( 'quotation_disable_after_days' ) ) {
        my $sth = dbh->prepare(
            "UPDATE quotation SET disabled = 'Y' WHERE _date < ?"
        ) or die dbh->errstr;
        $sth->execute( time - ( $days * 86400 ) ) or die $sth->errstr;
        dbh->commit or die dbh->errstr if $FS::UID::AutoCommit;
    }
}

1;
