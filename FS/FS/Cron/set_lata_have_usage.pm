package FS::Cron::set_lata_have_usage;

use strict;
use warnings;
use vars qw( @ISA @EXPORT_OK $me $DEBUG );
use Exporter;
use FS::UID qw(adminsuidsetup);
use FS::Record qw(qsearch qsearchs dbh);
use FS::lata;
use FS::phone_avail;
use FS::svc_phone;
use Data::Dumper;

@ISA = qw( Exporter );
@EXPORT_OK = qw ( set_lata_have_usage );
$DEBUG = 0;
$me = '[FS::Cron::set_lata_have_usage]';

sub set_lata_have_usage {
    my %opt = @_;
    
    my $debug = 0;
    $debug = 1 if $opt{'v'};
    $debug = $opt{'l'} if $opt{'l'};
  
    local $DEBUG = $debug if $debug;
  
    warn "$me set_lata_have_usage called time=".time."\n" if $DEBUG;

    local $SIG{HUP} = 'IGNORE';
    local $SIG{INT} = 'IGNORE';
    local $SIG{QUIT} = 'IGNORE';
    local $SIG{TERM} = 'IGNORE';
    local $SIG{TSTP} = 'IGNORE';
    local $SIG{PIPE} = 'IGNORE';

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;

    my %latas = map { $_->latanum => $_ } qsearch('lata', {});

    foreach my $lata ( keys %latas ) {
            next unless $latas{$lata}->have_usage > 0;
            $latas{$lata}->have_usage(0);
            my $error = $latas{$lata}->replace;
            if ( $error ) {
                $dbh->rollback if $oldAutoCommit;
                die "error replacing LATA $lata: $error";
            }
    }
    warn "$me cleared have_usage for all LATAs time=".time."\n" if $DEBUG;

    my @dids = qsearch({     'table'     => 'svc_phone',
                                    'hashref'   => 
                                        { 'latanum' =>
                                            { 'op'      => '>',
                                              'value'   => '0',
                                            },
                                        },
                                    'addl_from' => 'join phone_avail using (svcnum)',
                                      });
    warn "$me DID query finished time=".time."\n" if $DEBUG;

    my $count = 0;
    foreach my $did ( @dids ) {
        warn "$me count=$count time=".time."\n" if $DEBUG && ($count % 1000 == 0);
        my @cdrs = $did->get_cdrs;
        my $lata = $latas{$did->latanum};
        $count++;
        if ( scalar(@cdrs) ) {
            if ( !$lata->have_usage ) {
                $lata->have_usage(1);
            }
            else {
                $lata->have_usage($lata->have_usage+1);
            }
        }
    }

    warn "$me Set have_usage finished time=".time."\n" if $DEBUG;

    foreach my $lata ( keys %latas ) {
        if ( $latas{$lata}->modified ) {
            print "$lata ".$latas{$lata}->have_usage."\n";
            my $error = $latas{$lata}->replace;
            if ( $error ) {
                $dbh->rollback if $oldAutoCommit;
                die "error replacing LATA $lata: $error";
            }
        }
    }

    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    warn "$me done time=".time."\n" if $DEBUG;
}

1;
