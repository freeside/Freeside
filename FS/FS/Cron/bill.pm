package FS::Cron::bill;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use Date::Parse;
use DBI 1.33; #The "clone" method was added in DBI 1.33. 
use FS::UID qw(dbh);
use FS::Record qw(qsearchs);
use FS::cust_main;
use FS::part_event;
use FS::part_event_condition;

@ISA = qw( Exporter );
@EXPORT_OK = qw ( bill );

sub bill {

  my %opt = @_;

  my $check_freq = $opt{'check_freq'} || '1d';

  my $debug = 0;
  $debug = 1 if $opt{'v'};
  $debug = $opt{'l'} if $opt{'l'};
 
  $FS::cust_main::DEBUG = $debug;
  #$FS::cust_event::DEBUG = $opt{'l'} if $opt{'l'};

  my @search = ();

  push @search, "( cust_main.archived != 'Y' OR archived IS NULL )"; #disable?

  push @search, "cust_main.payby    = '". $opt{'p'}. "'"
    if $opt{'p'};
  push @search, "cust_main.agentnum =  ". $opt{'a'}
    if $opt{'a'};

  if ( @ARGV ) {
    push @search, "( ".
      join(' OR ', map "cust_main.custnum = $_", @ARGV ).
    " )";
  }

  ###
  # generate where_pkg/where_event search clause
  ###

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

  push @search, "( $where_pkg OR $where_event )";

  ###
  # get a list of custnums
  ###

  warn "searching for customers:\n". join("\n", @search). "\n"
    if $opt{'v'} || $opt{'l'};

  my $cursor_dbh = dbh->clone;

  $cursor_dbh->do(
    "DECLARE cron_bill_cursor CURSOR FOR ".
    "  SELECT custnum FROM cust_main WHERE ". join(' AND ', @search)
  ) or die $cursor_dbh->errstr;

  while ( 1 ) {

    my $sth = $cursor_dbh->prepare('FETCH 100 FROM cron_bill_cursor'); #mysql?

    $sth->execute or die $sth->errstr;

    my @custnums = map { $_->[0] } @{ $sth->fetchall_arrayref };

    last unless scalar(@custnums);

    ###
    # for each custnum, queue or make one customer object and bill
    # (one at a time, to reduce memory footprint with large #s of customers)
    ###
    
    foreach my $custnum ( @custnums ) {
    
      my %args = (
          'time'         => $time,
          'invoice_time' => $invoice_time,
          'actual_time'  => $^T, #when freeside-bill was started
                                 #(not, when using -m, freeside-queued)
          'check_freq'   => $check_freq,
          'resetup'      => ( $opt{'s'} ? $opt{'s'} : 0 ),
      );

      if ( $opt{'m'} ) {

        #add job to queue that calls bill_and_collect with options
        my $queue = new FS::queue {
          'job'      => 'FS::cust_main::queued_bill',
          'secure'   => 'Y',
          'priority' => 99, #don't get in the way of provisioning jobs
        };
        my $error = $queue->insert( 'custnum'=>$custnum, %args );

      } else {

        my $cust_main = qsearchs( 'cust_main', { 'custnum' => $custnum } );
        $cust_main->bill_and_collect( %args, 'debug' => $debug );

      }

    }

  }

  $cursor_dbh->commit or die $cursor_dbh->errstr;

}

1;
