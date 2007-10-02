package FS::Cron::bill;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use Date::Parse;
use FS::Record qw(qsearch qsearchs);
use FS::cust_main;
use FS::part_event;
use FS::part_event_condition;

@ISA = qw( Exporter );
@EXPORT_OK = qw ( bill );

sub bill {

  my %opt = @_;

  my $check_freq = $opt{'check_freq'} || '1d';

  $FS::cust_main::DEBUG = 1 if $opt{'v'};
  $FS::cust_main::DEBUG = $opt{'l'} if $opt{'l'};
  #$FS::cust_event::DEBUG = $opt{'l'} if $opt{'l'};
  
  my %search = ();
  $search{'payby'}    = $opt{'p'} if $opt{'p'};
  $search{'agentnum'} = $opt{'a'} if $opt{'a'};
  
  #we're at now now (and later).
  my($time)= $opt{'d'} ? str2time($opt{'d'}) : $^T;
  $time += $opt{'y'} * 86400 if $opt{'y'};

  my $invoice_time = $opt{'n'} ? $^T : $time;

  # select * from cust_main where
  my $where_pkg = <<"END";
    0 < ( select count(*) from cust_pkg
            where cust_main.custnum = cust_pkg.custnum
              and ( cancel is null or cancel = 0 )
              and (    setup is null or setup =  0
                    or bill  is null or bill  <= $time 
                    or ( expire is not null and expire <= $^T )
                    or ( adjourn is not null and adjourn <= $^T )
                  )
        )
END

  my $where_event = join(' OR ', map {
    my $eventtable = $_;

    my $join  = FS::part_event_condition->join_conditions_sql(  $eventtable );
    my $where = FS::part_event_condition->where_conditions_sql( $eventtable,
                                                                'time'=>$time,
                                                              );

    my $are_part_event = 
      "0 < ( SELECT COUNT(*) FROM part_event $join
               WHERE check_freq = '$check_freq'
                 AND eventtable = '$eventtable'
                 AND ( disabled = '' OR disabled IS NULL )
                 AND $where
           )
      ";

    if ( $eventtable eq 'cust_main' ) { 
      $are_part_event;
    } else {
      "0 < ( SELECT COUNT(*) FROM $eventtable
               WHERE cust_main.custnum = $eventtable.custnum
                 AND $are_part_event
           )
      ";
    }

  } FS::part_event->eventtables);

  my $extra_sql = ( scalar(%search) ? ' AND ' : ' WHERE ' ).
                  "( $where_pkg OR $where_event )";

  my @cust_main;
  if ( @ARGV ) {
    @cust_main = map { qsearchs('cust_main', { custnum => $_, %search } ) } @ARGV
  } else {

    warn "searching for customers:\n".
         join("\n", map "  $_ => ".$search{$_}, keys %search). "\n".
         "  $extra_sql\n"
      if $opt{'v'} || $opt{'l'};

    @cust_main = qsearch({
      'table'     => 'cust_main',
      'hashref'   => \%search,
      'extra_sql' => $extra_sql,
    });

  }
  
  foreach my $cust_main ( @cust_main ) {

    if ( $opt{'m'} ) {

      #add job to queue that calls bill_and_collect with options
        my $queue = new FS::queue {
          'job'    => 'FS::cust_main::queued_bill',
          'secure' => 'Y',
        };
        my $error = $queue->insert(
        'custnum'      => $cust_main->custnum,
        'time'         => $time,
        'invoice_time' => $invoice_time,
        'check_freq'   => $check_freq,
        'resetup'      => $opt{'s'} ? $opt{'s'} : 0,
      );

    } else {

      $cust_main->bill_and_collect(
        'time'         => $time,
        'invoice_time' => $invoice_time,
        'check_freq'   => $check_freq,
        'resetup'      => $opt{'s'},
      );

    }

  }

}
