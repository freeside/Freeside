package FS::Cron::breakage;

use strict;
use base 'Exporter';
use vars qw( @EXPORT_OK );
use FS::Conf;
use FS::Record qw(qsearch);
use FS::agent;
use FS::cust_main;

@EXPORT_OK = qw ( reconcile_breakage );

#freeside-daily %opt
# -v: enable debugging
# -l: debugging level

sub reconcile_breakage {
  my %opt = @_;

  my $conf = new FS::Conf;

  foreach my $agent (qsearch('agent', {})) {

    my $days = $conf->config('breakage-days', $agent->agentnum)
      or next;

    my $since = int( $^T - ($days * 86400) );

    warn 'searching '. $agent->agent.  " for customers with unapplied payments more than $days days old\n"
      if $opt{'v'};

    #find customers w/negative balance older than $days (and no activity since)
    # no invoices / payments (/credits/refunds?) newer than $since
    #  (except antother breakage invoice???)

    my $extra_sql = ' AND 0 > '. FS::cust_main->balance_sql;
    $extra_sql .= " AND ". join(' AND ',
      map {"
            NOT EXISTS ( SELECT 1 FROM $_
                           WHERE $_.custnum = cust_main.custnum
                             AND _date >= $since
                       )
          ";}
          qw( cust_bill cust_pay ) # cust_credit cust_refund );
    );

    my @customers = qsearch({
      'table'     => 'cust_main',
      'hashref'   => { 'agentnum' => $agent->agentnum,
                       'payby'    => { op=>'!=', value=>'COMP', },
                     },
      'extra_sql' => $extra_sql,
    });

    #and then create a "breakage" charge & invoice for them

    foreach my $cust_main ( @customers ) {

      warn 'reconciling breakage for customer '. $cust_main->custnum.
           ': '. $cust_main->name. "\n"
        if $opt{'v'};

      my $error =
        $cust_main->charge({
          'amount'   => sprintf('%.2f', 0 - $cust_main->balance ),
          'pkg'      => 'Breakage',
          'comment'  => 'breakage reconciliation',
          'classnum' => scalar($conf->config('breakage-pkg_class')),
          'setuptax' => 'Y',
          'bill_now' => 1,
        })
        || $cust_main->apply_payments_and_credits;

      if ( $error ) {
        warn "error charging for breakage reconciliation: $error\n";
      }

    }

  }

}

1;
