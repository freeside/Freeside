package FS::ClientAPI::MyAccount;

use strict;
use vars qw($cache);
use Digest::MD5 qw(md5_hex);
use Date::Format;
use Cache::SharedMemoryCache; #store in db?
use FS::CGI qw(small_custview); #doh
use FS::Conf;
use FS::Record qw(qsearchs);
use FS::svc_acct;
use FS::svc_domain;
use FS::cust_main;
use FS::cust_bill;

use FS::ClientAPI; #hmm
FS::ClientAPI->register_handlers(
  'MyAccount/login'         => \&login,
  'MyAccount/customer_info' => \&customer_info,
  'MyAccount/invoice'       => \&invoice,
  'MyAccount/cancel'        => \&cancel,
);

#store in db?
my $cache = new Cache::SharedMemoryCache();

#false laziness w/FS::ClientAPI::passwd::passwd (needs to handle encrypted pw)
sub login {
  my $p = shift;

  my $svc_domain = qsearchs('svc_domain', { 'domain' => $p->{'domain'} } )
    or return { error => "Domain not found" };

  my $svc_acct =
    ( length($p->{'password'}) < 13
      && qsearchs( 'svc_acct', { 'username'  => $p->{'username'},
                                 'domsvc'    => $svc_domain->svcnum,
                                 '_password' => $p->{'password'}     } )
    )
    || qsearchs( 'svc_acct', { 'username'  => $p->{'username'},
                               'domsvc'    => $svc_domain->svcnum,
                               '_password' => $p->{'password'}     } );

  unless ( $svc_acct ) { return { error => 'Incorrect password.' } }

  my $session = {
    'svcnum' => $svc_acct->svcnum,
  };

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  if ( $cust_pkg ) {
    my $cust_main = $cust_pkg->cust_main;
    $session->{'custnum'} = $cust_main->custnum;
  }

  my $session_id;
  do {
    $session_id = md5_hex(md5_hex(time(). {}. rand(). $$))
  } until ( ! defined $cache->get($session_id) ); #just in case

  $cache->set( $session_id, $session, '1 hour' );

  return { 'error'      => '',
           'session_id' => $session_id,
         };
}

sub customer_info {
  my $p = shift;
  my $session = $cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my %return;

  my $custnum = $session->{'custnum'};

  if ( $custnum ) { #customer record

    my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
      or return { 'error' => "unknown custnum $custnum" };

    $return{balance} = $cust_main->balance;

    my @open = map {
                     {
                       invnum => $_->invnum,
                       date   => time2str("%b %o, %Y", $_->_date),
                       owed   => $_->owed,
                     };
                   } $cust_main->open_cust_bill;
    $return{open_invoices} = \@open;

    my $conf = new FS::Conf;
    $return{small_custview} =
      small_custview( $cust_main, $conf->config('defaultcountry') );

    $return{name} = $cust_main->first. ' '. $cust_main->get('last');

  } else { #no customer record

    my $svc_acct = qsearchs('svc_acct', { 'svcnum' => $session->{'svcnum'} } )
      or die "unknown svcnum";
    $return{name} = $svc_acct->email;

  }


  return { 'error'          => '',
           'custnum'        => $custnum,
           %return,
         };

}

sub invoice {
  my $p = shift;
  my $session = $cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $invnum = $p->{'invnum'};

  my $cust_bill = qsearchs('cust_bill', { 'invnum'  => $invnum,
                                          'custnum' => $custnum } )
    or return { 'error' => "Can't find invnum" };

  #my %return;

  return { 'error'        => '',
           'invnum'       => $invnum,
           'invoice_text' => join('', $cust_bill->print_text ),
         };

}

sub cancel {
  my $p = shift;
  my $session = $cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  my $custnum = $session->{'custnum'};

  my $cust_main = qsearchs('cust_main', { 'custnum' => $custnum } )
    or return { 'error' => "unknown custnum $custnum" };

  my @errors = $cust_main->cancel;

  my $error = scalar(@errors) ? join(' / ', @errors) : '';

  return { 'error' => $error };

}

1;

