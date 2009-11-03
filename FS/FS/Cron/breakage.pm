package FS::Cron::breakage;

use strict;
use base 'Exporter';
use vars qw( @EXPORT_OK );
use FS::Conf;
use FS::Record qw(qsearch);
use FS::agent;
#use FS::cust_main;

@EXPORT_OK = qw ( reconcile_breakage );

#freeside-daily %opt
# -v: enable debugging
# -l: debugging level

sub reconcile_breakage {
  return;
  #nothing yet

  my $conf = new FS::Conf;

  foreach my $agent (qsearch('agent', {})) {

    my $days = $conf->config('breakage-days', $agent->agentnum)
      or next;

    #find customers w/a balance older than $days (and no activity since)

    # - do a one time charge in the total amount of old unapplied payments.
    #     'pkg' => 'Breakage', #or whatever.
    #     'setuptax' => 'Y',
    #     'classnum' => scalar($conf->config('breakage-pkg_class')),
    # - use the new $cust_main->charge( 'bill_now' => 1 ) option to generate an invoice, etc.
    # - apply_payments_and_credits

  }

}

1;
