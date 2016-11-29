#!/usr/bin/perl

use FS::Test;
use Test::More tests => 8;
use FS::Conf;

### can only run on test database (company name "Freeside Test")
### will run upgrade, which uses lots of prints & warns beyond regular test output

my $fs = FS::Test->new( user => 'admin' );
my $conf = new_ok('FS::Conf');
my $err;
my $bopconf;

like( $conf->config('company_name'), qr/^Freeside Test/, 'using test database' ) or BAIL_OUT('');

# some pre-upgrade cleanup, upgrade will fail if these are still configured
foreach my $cust_main ( $fs->qsearch('cust_main') ) {
  my @count = $fs->qsearch('agent_payment_gateway', { agentnum => $cust_main->agentnum } );
  if (@count > 1) {
    note("DELETING CARDTYPE GATEWAYS");
    foreach my $apg (@count) {
      $err = $apg->delete if $apg->cardtype;
      last if $err;
    }
    @count = $fs->qsearch('agent_payment_gateway', { agentnum => $cust_main->agentnum } );
    if (@count > 1) {
      $err = "Still found ".@count." gateways for custnum ".$cust_main->custnum;
      last;
    }
  }
}
ok( !$err, "remove obsolete payment gateways" ) or BAIL_OUT($err);

$bopconf = 
'IPPay
TESTTERMINAL';
$conf->set('business-onlinepayment' => $bopconf);
is( join("\n",$conf->config('business-onlinepayment')), $bopconf, "setting first default gateway" ) or BAIL_OUT('');

$err = system('freeside-upgrade','admin');
ok( !$err, 'initial upgrade' ) or BAIL_OUT('Error string: '.$!);

$bopconf =
'CardFortress
cardfortresstest
(TEST54)
Normal Authorization
gateway
IPPay
gateway_login
TESTTERMINAL
gateway_password

private_key
/usr/local/etc/freeside/cardfortresstest.txt';
$conf->set('business-onlinepayment' => $bopconf);
is( join("\n",$conf->config('business-onlinepayment')), $bopconf, "setting tokenizable default gateway" ) or BAIL_OUT('');

foreach my $pg ($fs->qsearch('payment_gateway')) {
  unless ($pg->gateway_module eq 'CardFortress') {
    note('UPGRADING NON-CF PAYMENT GATEWAY');
    my %pgopts = (
      gateway          => $pg->gateway_module,
      gateway_login    => $pg->gateway_username,
      gateway_password => $pg->gateway_password,
      private_key      => '/usr/local/etc/freeside/cardfortresstest.txt',
    );
    $pg->gateway_module('CardFortress');
    $pg->gateway_username('cardfortresstest');
    $pg->gateway_password('(TEST54)');
    $err = $pg->replace(\%pgopts);
    last if $err;
  }
}
ok( !$err, "remove non-CF payment gateways" ) or BAIL_OUT($err);

$err = system('freeside-upgrade','admin');
ok( !$err, 'tokenizable upgrade' ) or BAIL_OUT('Error string: '.$!);

1;

