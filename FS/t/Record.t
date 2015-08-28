use strict;
use warnings;
use FS::Conf;
use Data::Dumper qw( Dumper );
use FS::UID qw( adminsuidsetup );
use Digest::SHA qw(sha256_hex);
use Test::More tests => 11;

# Stock freeside does equivalent of the following
BEGIN { use_ok('FS::Record') }

# If adminuser passed in, assume this is being run in foreground
my $freeside_uid = getpwnam('freeside');
my $adminuser = shift || '';
if (!length $adminuser) {
    note <<"USAGE";
Syntax for longer user-initiated tests:
    prove $0 :: [admin-user_name]
        OR
    perl  $0 [admin-user_name]

USAGE
}

SKIP: {
    skip 'test(s) if not run as freeside user or if DB adminuser unspecified', 10 
        if ($< != $freeside_uid) || !length($adminuser);

    require_ok('FS::access_user_session');

    my $dbh = adminsuidsetup $adminuser;

    my $conf = FS::Conf->new;

    # 1. Without salt
    local $FS::Record::conf_hashsalt = '';
    my $cookie = 'this is a test '. time();
    my $record1 = new FS::access_user_session {
        usernum => 3,
        sessionkey => $cookie,
        start_date => 0,
    };

    my $error = $record1->insert;
    ok(!$error, 'Insert unhashed record in access_user_session') or diag explain $error,$record1;
    my @records = FS::Record::qsearch( access_user_session => { sessionkey => $cookie } );
    ok(scalar @records == 1,'qsearch finds single matching record just inserted');
    cmp_ok($records[0]->sessionkey,'eq',$cookie,'Unhashed sessionkey matches');

    # 2. First salt
    local $FS::Record::conf_hashsalt = 'test it'; 
    my $saltrecord1 = new FS::access_user_session {
        usernum => 3,
        sessionkey => $cookie,
        start_date => 0,
    };

    $error = $saltrecord1->insert;
    ok(!$error, 'Insert record in access_user_session with first salt') or diag explain $error,$saltrecord1;
    my $shacookie1 = sha256_hex($cookie.$FS::Record::conf_hashsalt);
    @records = FS::Record::qsearch( access_user_session => { sessionkey => $cookie } );
    ok(scalar @records == 1,'qsearch finds single matching record just inserted with first salt');
    cmp_ok($records[0]->sessionkey,'eq',$shacookie1,'First salted sessionkey matches');

    # 3. Salt no. 2
    local $FS::Record::conf_hashsalt = 'test it2'; 
    my $salt2record1 = new FS::access_user_session {
    usernum => 3,
    sessionkey => $cookie,
    start_date => 0,
    };

    $error = $salt2record1->insert;
    ok(!$error, 'Insert record in access_user_session with 2nd salt') or diag explain $error,$salt2record1;
    my $shacookie2 = sha256_hex($cookie.$FS::Record::conf_hashsalt);
    @records = FS::Record::qsearch( access_user_session => { sessionkey => $cookie } );
    ok(scalar @records == 1,'qsearch finds single matching record (salted with 2nd salt) just inserted with second salt');
    cmp_ok($records[0]->sessionkey,'eq',$shacookie2,'Second salted sessionkey matches (salted with 2nd salt) matches');
}

