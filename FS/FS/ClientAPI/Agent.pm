package FS::ClientAPI::Agent;

#some false laziness w/MyAccount

use strict;
use vars qw($cache);
use subs qw(_cache);
use Digest::MD5 qw(md5_hex);
use FS::Record qw(qsearchs); # qsearch dbdef dbh);
use FS::ClientAPI_SessionCache;
use FS::agent;
use FS::cust_main::Search qw(smart_search);
use FS::svc_domain;
use FS::svc_acct;

sub _cache {
  $cache ||= new FS::ClientAPI_SessionCache( {
               'namespace' => 'FS::ClientAPI::Agent',
             } );
}

sub new_agent {
  my $p = shift;

  my $conf = new FS::Conf;
  return { error=>'Disabled' } unless $conf->exists('selfservice-agent_signup');

  #add a customer record and set agent_custnum?

  my $agent = new FS::agent {
    'typenum'   => $conf->config('selfservice-agent_signup-agent_type'),
    'agent'     => $p->{'agent'},
    'username'  => $p->{'username'},
    '_password' => $p->{'password'},
    #
  };

  my $error = $agent->insert;
  
  return { 'error' => $error } if $error;

  agent_login({ 'username' => $p->{'username'},
                'password' => $p->{'password'},
             });
}

sub agent_login {
  my $p = shift;

  #don't allow a blank login to first unconfigured agent with no user/pass
  return { error => 'Must specify your reseller username and password.' }
    unless length($p->{'username'}) && length($p->{'password'});

  my $agent = qsearchs( 'agent', {
    'username'  => $p->{'username'},
    '_password' => $p->{'password'},
  } );

  unless ( $agent ) { return { error => 'Incorrect password.' } }

  my $session = { 
    'agentnum' => $agent->agentnum,
    'agent'    => $agent->agent,
  };

  my $session_id;
  do {
    $session_id = md5_hex(md5_hex(time(). {}. rand(). $$))
  } until ( ! defined _cache->get($session_id) ); #just in case

  _cache->set( $session_id, $session, '1 hour' );

  { 'error'      => '',
    'session_id' => $session_id,
  };
}

sub agent_logout {
  my $p = shift;
  if ( $p->{'session_id'} ) {
    _cache->remove($p->{'session_id'});
    return { 'error' => '' };
  } else {
    return { 'error' => "Can't resume session" }; #better error message
  }
}

sub agent_info {
  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  #my %return;

  my $agentnum = $session->{'agentnum'};

  my $agent = qsearchs( 'agent', { 'agentnum' => $agentnum } )
    or return { 'error' => "unknown agentnum $agentnum" };

  { 'error'        => '',
    'agentnum'     => $agentnum,
    'agent'        => $agent->agent,
    'num_prospect' => $agent->num_prospect_cust_main,
    'num_active'   => $agent->num_active_cust_main,
    'num_susp'     => $agent->num_susp_cust_main,
    'num_cancel'   => $agent->num_cancel_cust_main,
    #%return,
  };

}

sub agent_list_customers {
  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return { 'error' => "Can't resume session" }; #better error message

  #my %return;

  my $agentnum = $session->{'agentnum'};

  my $agent = qsearchs( 'agent', { 'agentnum' => $agentnum } )
    or return { 'error' => "unknown agentnum $agentnum" };

  my @cust_main = smart_search( 'search'   => $p->{'search'},
                                'agentnum' => $agentnum,
                              );

  #aggregate searches
  push @cust_main,
    map $agent->$_(), map $_.'_cust_main',
      grep $p->{$_}, qw( prospect active susp cancel );

  #eliminate dups?
  my %saw = ();
  @cust_main = grep { !$saw{$_->custnum}++ } @cust_main;

  { customers => [ map {
                         my $cust_main = $_;
                         my $hashref = $cust_main->hashref;
                         $hashref->{$_} = $cust_main->$_()
                           foreach qw(name status statuscolor);
                         delete $hashref->{$_} foreach qw( payinfo paycvv );
                         $hashref;
                   } @cust_main
                 ],
  }

}

sub check_username {
  my $p = shift;
  my($session, $agentnum, $svc_acct) = _session_agentnum_svc_acct_check($p);
  return { 'error' => $session } unless ref($session);

  { 'error'     => '',
    #'username'  => $username,
    #'domain'    => $domain,
    'available' => $svc_acct ? 0 : 1,
  };

}

sub _session_agentnum_svc_acct {
  my $p = shift;

  my $session = _cache->get($p->{'session_id'})
    or return "Can't resume session"; #better error message

  my $username = $p->{'username'};

  #XXX some way to default this per agent (by default product's service def?)
  my $domain = $p->{'domain'};

  my $svc_domain = qsearchs('svc_domain', { 'domain' => $domain } )
    or return { 'error' => 'Unknown domain' };

  my $svc_acct = qsearchs('svc_acct', { 'username' => $username,
                                        'domsvc'   => $svc_domain->svcnum, } );

  ( $session, $session->{'agentnum'}, $svc_acct );

}

sub _session_agentnum_cust_pkg {
  my $p = shift;
  my($session, $agentnum, $svc_acct) = _session_agentnum_svc_acct($p);
  return $session unless ref($session);
  return 'Account not found' unless $svc_acct;
  my $cust_svc = $svc_acct->cust_svc;
  return 'Unlinked account' unless $cust_svc->pkgnum;
  my $cust_pkg = $cust_svc->cust_pkg;
  return 'Not your account' unless $cust_pkg->cust_main->agentnum == $agentnum;
  ($session, $agentnum, $cust_pkg);
}

sub suspend_username {
  my $p = shift;
  my($session, $agentnum, $cust_pkg) = _session_agentnum_cust_pkg($p);
  return { 'error' => $session } unless ref($session);

  return { 'error' => $cust_pkg->suspend };
}

sub unsuspend_username {
  my $p = shift;
  my($session, $agentnum, $cust_pkg) = _session_agentnum_cust_pkg($p);
  return { 'error' => $session } unless ref($session);

  return { 'error' => $cust_pkg->unsuspend };
}

1;
