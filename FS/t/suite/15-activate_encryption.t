#!/usr/bin/perl

use strict;
use FS::Test;
use Test::More tests => 14;
use FS::Conf;
use FS::UID qw( dbh );
use DateTime;
use FS::cust_main; # to load all other tables

my $fs = FS::Test->new( user => 'admin' );
my $conf = FS::Conf->new;
my $err;
my @tables = qw(cust_main cust_pay_pending cust_pay cust_pay_void cust_refund);

### can only run on test database (company name "Freeside Test")
like( $conf->config('company_name'), qr/^Freeside Test/, 'using test database' ) or BAIL_OUT('');

### upgrade test db schema
$err = system('freeside-upgrade','-s','admin');
ok( !$err, 'schema upgrade ran' ) or BAIL_OUT('Error string: '.$!);

### we need to unencrypt our test db before we can test turning it on

# temporarily load all payinfo into memory
my %payinfo = ();
foreach my $table (@tables) {
  $payinfo{$table} = {};
  foreach my $record ($fs->qsearch({ table => $table })) {
    next unless grep { $record->payby eq $_ } @FS::Record::encrypt_payby;
    $payinfo{$table}{$record->get($record->primary_key)} = $record->get('payinfo');
  }
}

# turn off encryption
foreach my $config ( qw(encryption encryptionmodule encryptionpublickey encryptionprivatekey) ) {
  $conf->delete($config);
  ok( !$conf->exists($config), "deleted $config" ) or BAIL_OUT('');
}
$FS::Record::conf_encryption           = $conf->exists('encryption');
$FS::Record::conf_encryptionmodule     = $conf->config('encryptionmodule');
$FS::Record::conf_encryptionpublickey  = join("\n",$conf->config('encryptionpublickey'));
$FS::Record::conf_encryptionprivatekey = join("\n",$conf->config('encryptionprivatekey'));

# save unencrypted values
foreach my $table (@tables) {
  local $FS::payinfo_Mixin::allow_closed_replace = 1;
  local $FS::Record::no_update_diff = 1;
  local $FS::UID::AutoCommit = 1;
  my $tclass = 'FS::'.$table;
  foreach my $key (keys %{$payinfo{$table}}) {
    my $record = $tclass->by_key($key);
    $record->payinfo($payinfo{$table}{$key});
    $err = $record->replace;
    last if $err;
  }
}
ok( !$err, "save unencrypted values" ) or BAIL_OUT($err);

# make sure it worked
CHECKDECRYPT:
foreach my $table (@tables) {
  my $tclass = 'FS::'.$table;
  foreach my $key (sort {$a <=> $b} keys %{$payinfo{$table}}) {
    my $sql = 'SELECT * FROM '.$table.
              ' WHERE payinfo LIKE \'M%\''.
              ' AND char_length(payinfo) > 80'.
              ' AND '.$tclass->primary_key.' = '.$key;
    my $sth = dbh->prepare($sql) or BAIL_OUT(dbh->errstr);
    $sth->execute or BAIL_OUT($sth->errstr);
    if (my $hashrec = $sth->fetchrow_hashref) {
      $err = $table.' '.$key.' encrypted';
      last CHECKDECRYPT;
    }
  }
}
ok( !$err, "all values unencrypted" ) or BAIL_OUT($err);

### now, run upgrade
$err = system('freeside-upgrade','admin');
ok( !$err, 'upgrade ran' ) or BAIL_OUT('Error string: '.$!);

# check that confs got set
foreach my $config ( qw(encryption encryptionmodule encryptionpublickey encryptionprivatekey) ) {
  ok( $conf->exists($config), "$config was set" ) or BAIL_OUT('');
}

# check that known records got encrypted
CHECKENCRYPT:
foreach my $table (@tables) {
  my $tclass = 'FS::'.$table;
  foreach my $key (sort {$a <=> $b} keys %{$payinfo{$table}}) {
    my $sql = 'SELECT * FROM '.$table.
              ' WHERE payinfo LIKE \'M%\''.
              ' AND char_length(payinfo) > 80'.
              ' AND '.$tclass->primary_key.' = '.$key;
    my $sth = dbh->prepare($sql) or BAIL_OUT(dbh->errstr);
    $sth->execute or BAIL_OUT($sth->errstr);
    unless ($sth->fetchrow_hashref) {
      $err = $table.' '.$key.' not encrypted';
      last CHECKENCRYPT;
    }
  }
}
ok( !$err, "all values encrypted" ) or BAIL_OUT($err);

exit;

1;

