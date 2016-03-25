package FS::ClientAPI::Freeside;

use strict;
#use vars qw($DEBUG $me);
use FS::Record qw(qsearchs);
use FS::Conf;
use FS::svc_external;
use FS::webservice_log;

#$DEBUG = 0;
#$me = '[FS::ClientAPI::PrepaidPhone]';

# inputs:
#   support-key
#   method
#   quantity (i.e. pages) - defaults to 1
#
# returns:
#   error (empty, or error message)

sub freesideinc_service {
  my $packet = shift;

  my $svcpart = FS::Conf->new->config('freesideinc-webservice-svcpart')
    or return { 'error' => 'guru meditation #pow' };
  die 'no' unless $svcpart =~ /^\d+$/;

  ( my $support_key = $packet->{'support-key'} ) =~ /^\s*([^:]+):(.+)\s*$/
    or return { 'error' => 'bad support-key' };
  my($username, $_password) = ($1,$2);

  my $svc_external = qsearchs({
    'table'     => 'svc_external',
    'addl_from' => 'LEFT JOIN cust_svc USING ( svcnum )',
    'hashref'   => { 'username'  => $username,
                     '_password' => $_password,
                   },
    'extra_sql' => " AND svcpart = $svcpart",
  })
    or return { 'error' => 'bad support-key' };

  #XXX check if some customers can use some API calls, rate-limiting, etc.
  # but for now, everybody can use everything

  #record it happened
  my $webservice_log = new FS::webservice_log {
    'custnum'  => $svc_external->cust_svc->cust_pkg->custnum,
    'svcnum'   => $svc_external->svcnum,
    'method'   => $packet->{'method'},
    'quantity' => $packet->{'quantity'} || 1,
  };
  my $error = $webservice_log->insert;
  return { 'error' => $error } if $error;

  return { 'error' => '' };

}

1;
