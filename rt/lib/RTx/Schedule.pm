package RTx::Schedule;
use base qw( Exporter );

use strict;
use RTx::Calendar qw( FindTickets LocalDate );
use FS::Record qw( qsearch qsearchs );
use FS::access_user;
use FS::sched_avail;

our $VERSION = '0.01';

our @EXPORT_OK = qw( UserDaySchedule );

#ala Calendar.html
# Default Query and Format
our $DefaultFormat = "__Starts__ __Due__";
our $DefaultQuery = "( Status = 'new' OR Status = 'open' OR Status = 'stalled')
 AND ( Type = 'reminder' OR 'Type' = 'ticket' )";

sub UserDaySchedule {
  my %arg = @_;
  my $username = $arg{username};
  my $date = $arg{date};

  my $Tickets;
  if ( $arg{Tickets} ) {
    $Tickets = $arg{Tickets};
  } else {

     my $Query = $DefaultQuery;

#    # we overide them if needed
#    $TempQuery  = $Query  if $Query;
#    $TempFormat = $Format if $Format;

#    # we search all date types in Format string
#    my @Dates = grep { $TempFormat =~ m/__${_}(Relative)?__/ } @DateTypes;

     my @Dates = qw( Starts Due );

#    # used to display or not a date in Element/CalendarEvent
#    my %DateTypes = map { $_ => 1 } @Dates;
#
#    $TempQuery .= DatesClauses(\@Dates, $start->strftime("%F"), $end->strftime("%F"));

    my %t = FindTickets( $arg{CurrentUser}, $Query, \@Dates, $date x2 );

    $Tickets = $t{ $date };
  }

  #block out unavailable times
  #alas.  abstractions break, freeside-specific stuff to get availability
  # move availability to RT side?  make it all callback/pluggable?

  use Date::Parse qw( str2time );
  #my $wday = (localtime(str2time($date)))[6];

  my $access_user = qsearchs('access_user', { 'username'=>$username })#disabled?
    or die "unknown user $username";

  my @sched_item = $access_user->sched_item #disabled?
    or die "$username not an installer";
  my $sched_item = $sched_item[0];

  my @sched_avail = qsearch('sched_avail', {
                               itemnum       => $sched_item->itemnum,
                               override_date => 99, #XXX override date via $date
                           });
  @sched_avail    = qsearch('sched_avail', {
                               itemnum       => $sched_item->itemnum,
                               wday          => (localtime(str2time($date)))[6],
                               override_date => '',
                           })
    unless @sched_avail;

  return (

    #avail/unavailable times
    'avail'     => [
                     map [ $_->stime, $_->etime ],
                       @sched_avail
                   ],

    #block out / show / color code existing appointments
    'scheduled' => {
      map {
            #$_->Id => [ $_->StartsObj, $t->DueObj ];

            my($sm, $sh) = ($_->StartsObj->Localtime('user'))[1,2];
            my $starts = $sh*60 + $sm;

            my $due;
            if ( LocalDate($_->DueObj->Unix) eq $date ) { #same day, use it
              my($dm, $dh) = ($_->DueObj->Localtime('user'))[1,2];
              $due = $dh*60 + $dm;
            } else {
              $due = 1439;#not today, we don't handle multi-day appointments, so
            }
            

            #XXX color code existing appointments by... city?  proximity?  etc.
            #my $col = '99ff99'; #green for now
            my $col = 'a097ed'; #any of green/red/yellow-like would be confusing as a placeholder color, so.. blue-ish/purple

            $_->Id => [ $starts, $due, $col, $_ ];
          }
        grep {
                   LocalDate($_->StartsObj->Unix) eq $date
               and $_->OwnerObj->Name eq $username
             }
          @$Tickets
    },

  );

}

1;

__END__

=head1 NAME

RTx::Schedule - Scheduling extension for Request Tracker

=head1 DESCRIPTION

This RT extension adds scheduling functionality to Request Tracker.

=head1 CONFIGURATION

CalendarWeeklyStartMin (default 480, 8am)

CalendarWeeklyEndMin (default 1080, 6pm)

CalendarWeeklySizeMin (default 30)

CalendarWeeklySlots (unused now?)

=head1 AUTHOR

Ivan Kohler

=head1 COPYRIGHT

Copyright 2014 Freeside Internet Services, Inc.

This program is free software; you can redistribute it and/or
modify it under the same terms as Request Tracker itself.

