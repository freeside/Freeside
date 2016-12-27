package FS::ClientAPI::Freeside;

use strict;
#use vars qw($DEBUG $me);
use FS::Record qw(qsearchs);
use FS::Conf;
use FS::svc_acct;
use FS::webservice_log;

#$DEBUG = 0;
#$me = '[FS::ClientAPI:Freeside]';

# inputs:
#   support-key
#   method
#   quantity (i.e. pages) - defaults to 1
#
# returns:
#   error (empty, or error message)
#   custnum

sub freesideinc_service {
  my $packet = shift;

  my $svcpart = FS::Conf->new->config('freesideinc-webservice-svcpart')
    or return { 'error' => 'guru meditation #pow' };
  die 'no' unless $svcpart =~ /^\d+$/;

  ( my $support_key = $packet->{'support-key'} ) =~ /^\s*([^:]+):(.+)\s*$/
    or return { 'error' => 'bad support-key' };
  my($username, $_password) = ($1,$2);

  my $svc_acct = qsearchs({
    'table'     => 'svc_acct',
    'addl_from' => 'LEFT JOIN cust_svc USING ( svcnum )',
    'hashref'   => { 'username'  => $username,
                     '_password' => $_password,
                   },
    'extra_sql' => "AND svcpart = $svcpart",
  });
  unless ( $svc_acct ) {
    warn "bad support-key for $username from $ENV{REMOTE_IP}\n";
    sleep 5; #ideally also rate-limit and eventually ban their IP
    return { 'error' => 'bad support-key' };
  }

  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  my $custnum = $cust_pkg->custnum;

  my $quantity = $packet->{'quantity'} || 1;

  #false laziness w/webservice_log.pm
  my $color = 1.10;
  my $page = 0.10;

  #XXX check if some customers can use some API calls, rate-limiting, etc.
  # but for now, everybody can use everything
  if ( $packet->{method} eq 'print' ) {
    my $avail_credit = $cust_pkg->cust_main->credit_limit
                       - $color - $quantity * $page
                       - FS::webservice_log->price_print(
                           'custnum' => $custnum,
                         );

    return { 'error' => 'Over credit limit' }
      if $avail_credit <= 0;
  }

  #record it happened
  my $webservice_log = new FS::webservice_log {
    'custnum'  => $custnum,
    'svcnum'   => $svc_acct->svcnum,
    'method'   => $packet->{'method'},
    'quantity' => $quantity,
  };
  my $error = $webservice_log->insert;
  return { 'error' => $error } if $error;

  return { 'error'   => '',
           'custnum' => $custnum,
         };
}

1;
