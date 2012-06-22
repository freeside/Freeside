package FS::Cron::bill;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use Date::Parse;
use DBI 1.33; #The "clone" method was added in DBI 1.33. 
use FS::UID qw( dbh driver_name );
use FS::Record qw( qsearch qsearchs );
use FS::Misc::DateTime qw( day_end );
use FS::queue;
use FS::cust_main;
use FS::part_event;
use FS::part_event_condition;

@ISA = qw( Exporter );
@EXPORT_OK = qw ( bill bill_where );

#freeside-daily %opt:
#  -s: re-charge setup fees
#  -v: enable debugging
#  -l: debugging level
#  -m: Experimental multi-process mode uses the job queue for multi-process and/or multi-machine billing.
#  -r: Multi-process mode dry run option
#  -g: Don't bill these pkgparts

sub bill {
  my %opt = @_;

  my $check_freq = $opt{'check_freq'} || '1d';

  my $debug = 0;
  $debug = 1 if $opt{'v'};
  $debug = $opt{'l'} if $opt{'l'};
  $FS::cust_main::DEBUG = $debug;
  #$FS::cust_event::DEBUG = $opt{'l'} if $opt{'l'};

  my $conf = new FS::Conf;
  if ( $conf->exists('disable_cron_billing') ) {
    warn "disable_cron_billing set, skipping billing\n" if $debug;
    return;
  }

  #we're at now now (and later).
  $opt{'time'} = $opt{'d'} ? str2time($opt{'d'}) : $^T;
  $opt{'time'} += $opt{'y'} * 86400 if $opt{'y'};

  $opt{'invoice_time'} = $opt{'n'} ? $^T : $opt{'time'};

  #hashref here doesn't work with -m
  #my $not_pkgpart = $opt{g} ? { map { $_=>1 } split(/,\s*/, $opt{g}) }
  #                          : {};

  ###
  # get a list of custnums
  ###

  my $cursor_dbh = dbh->clone;

  my $select = 'SELECT custnum FROM cust_main WHERE '. bill_where( %opt );

  unless ( driver_name =~ /^mysql/ ) {
    $cursor_dbh->do( "DECLARE cron_bill_cursor CURSOR FOR $select" )
      or die $cursor_dbh->errstr;
  }

  while ( 1 ) {

    my $sql = (driver_name =~ /^mysql/)
      ? $select
      : 'FETCH 100 FROM cron_bill_cursor';

    my $sth = $cursor_dbh->prepare($sql);

    $sth->execute or die $sth->errstr;

    my @custnums = map { $_->[0] } @{ $sth->fetchall_arrayref };

    last unless scalar(@custnums);

    ###
    # for each custnum, queue or make one customer object and bill
    # (one at a time, to reduce memory footprint with large #s of customers)
    ###
    
    foreach my $custnum ( @custnums ) {
    
      my %args = (
          'time'         => $opt{'time'},
          'invoice_time' => $opt{'invoice_time'},
          'actual_time'  => $^T, #when freeside-bill was started
                                 #(not, when using -m, freeside-queued)
          'check_freq'   => $check_freq,
          'resetup'      => ( $opt{'s'} ? $opt{'s'} : 0 ),
          'not_pkgpart'  => $opt{'g'}, #$not_pkgpart,
          'one_recur'    => $opt{'o'},
      );

      if ( $opt{'m'} ) {

        if ( $opt{'r'} ) {
          warn "DRY RUN: would add custnum $custnum for queued_bill\n";
        } else {

          #avoid queuing another job if there's one still waiting to run
          next if qsearch( 'queue', { 'job'     => 'FS::cust_main::queued_bill',
                                      'custnum' => $custnum,
                                      'status'  => 'new',
                                    }
                         );

          #add job to queue that calls bill_and_collect with options
          my $queue = new FS::queue {
            'job'      => 'FS::cust_main::queued_bill',
            'secure'   => 'Y',
            'priority' => 99, #don't get in the way of provisioning jobs
          };
          my $error = $queue->insert( 'custnum'=>$custnum, %args );

        }

      } else {

        my $cust_main = qsearchs( 'cust_main', { 'custnum' => $custnum } );
        $cust_main->bill_and_collect( %args, 'debug' => $debug );

      }

    }

    last if driver_name =~ /^mysql/;

  }

  $cursor_dbh->commit or die $cursor_dbh->errstr;

}

# freeside-daily %opt:
#  -d: Pretend it's 'date'.  Date is in any format Date::Parse is happy with,
#      but be careful.
#
#  -y: In addition to -d, which specifies an absolute date, the -y switch
#      specifies an offset, in days.  For example, "-y 15" would increment the
#      "pretend date" 15 days from whatever was specified by the -d switch
#      (or now, if no -d switch was given).
#
#  -n: When used with "-d" and/or "-y", specifies that invoices should be dated
#      with today's date, regardless of the pretend date used to pre-generate
#      the invoices.
#
#  -p: Only process customers with the specified payby (I<CARD>, I<DCRD>, I<CHEK>, I<DCHK>, I<BILL>, I<COMP>, I<LECB>)
#
#  -a: Only process customers with the specified agentnum
#
#  -v: enable debugging
#
#  -l: debugging level

sub bill_where {
  my( %opt ) = @_;

  my $time = $opt{'time'};
  my $invoice_time = $opt{'invoice_time'};

  my $check_freq = $opt{'check_freq'} || '1d';

  my @search = ();

  push @search, "( cust_main.archived != 'Y' OR archived IS NULL )"; #disable?

  push @search, "cust_main.payby    = '". $opt{'p'}. "'"
    if $opt{'p'};
  push @search, "cust_main.agentnum IN ( ". $opt{'a'}. " ) "
    if $opt{'a'};

  #it would be useful if i recognized $opt{g} / $not_pkgpart...

  if ( @ARGV ) {
    push @search, "( ".
      join(' OR ', map "cust_main.custnum = $_", @ARGV ).
    " )";
  }

  ###
  # generate where_pkg/where_event search clause
  ###

  my $billtime = day_end($time);

  # select * from cust_main where
  my $where_pkg = <<"END";
    EXISTS(
      SELECT 1 FROM cust_pkg LEFT JOIN part_pkg USING ( pkgpart )
        WHERE cust_main.custnum = cust_pkg.custnum
          AND ( cancel IS NULL OR cancel = 0 )
          AND (    ( ( cust_pkg.setup IS NULL OR cust_pkg.setup =  0 )
                     AND ( start_date IS NULL OR start_date = 0
                           OR ( start_date IS NOT NULL AND start_date <= $^T )
                         )
                   )
                OR ( freq != '0' AND ( bill IS NULL OR bill  <= $billtime ) )
                OR ( expire  IS NOT NULL AND expire  <= $^T )
                OR ( adjourn IS NOT NULL AND adjourn <= $^T )
                OR ( resume  IS NOT NULL AND resume  <= $^T )
              )
    )
END

  #some false laziness w/cust_main::Billing due_cust_event
  my $where_event = join(' OR ', map {
    my $eventtable = $_;

    my $join  = FS::part_event_condition->join_conditions_sql(  $eventtable );
    my $where = FS::part_event_condition->where_conditions_sql( $eventtable,
                                                                'time'=>$time,
                                                              );
    $where = $where ? "AND $where" : '';

    my $are_part_event = 
      "EXISTS ( SELECT 1 FROM part_event $join
                  WHERE check_freq = '$check_freq'
                    AND eventtable = '$eventtable'
                    AND ( disabled = '' OR disabled IS NULL )
                    $where
              )
      ";

    if ( $eventtable eq 'cust_main' ) { 
      $are_part_event;
    } else {
      "EXISTS ( SELECT 1 FROM $eventtable
                  WHERE cust_main.custnum = $eventtable.custnum
                    AND $are_part_event
              )
      ";
    }

  } FS::part_event->eventtables);

  push @search, "( $where_pkg OR $where_event )";

  warn "searching for customers:\n". join("\n", @search). "\n"
    if $opt{'v'} || $opt{'l'};

  join(' AND ', @search);

}

1;
