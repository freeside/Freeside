package Statistics;

use vars qw(
$MultiQueueStatus $MultiQueueDateFormat @MultiQueueQueueList $MultiQueueMaxRows $MultiQueueWeekends $MultiQueueLabelDateFormat
$PerDayStatus $PerDayDateFormat $PerDayQueue $PerDayMaxRows $PerDayWeekends $PerDayLabelDateFormat $PerDayPeriod
$DayOfWeekQueue
@OpenStalledQueueList $OpenStalledWeekends
$TimeToResolveDateFormat $TimeToResolveQueue $TimeToResolveMaxRows $TimeToResolveWeekends $TimeToResolveLabelDateFormat
$TimeToResolveGraphQueue
@years @months %monthsMaxDay
$secsPerDay
$RestrictAccess
$GraphWidth $GraphHeight
);

use Time::Local;

# I couldn't figure out a way to override these in RT_SiteConfig, which would be
# preferable.

# Width and Height of all graphics
$GraphWidth=500;
$GraphHeight=400;

# Initial settings for the CallsMultiQueue stat page
$MultiQueueStatus = "resolved";
$MultiQueueDateFormat = "%a %b %d %Y";  # format for dates on Multi Queue report, see "man strftime" for options
@MultiQueueQueueList = ("General"); # list of queues to start Multi Queue per day reports
$MultiQueueMaxRows = 10;
$MultiQueueWeekends = 1;
$MultiQueueLabelDateFormat = "%a";

# Initial settings for the CallsQueueDay stat page
$PerDayStatus = "resolved";
$PerDayDateFormat = "%a %b %d %Y";
$PerDayQueue = "General";
$PerDayMaxRows = 10;
$PerDayWeekends = 1;
$PerDayLabelDateFormat = "%a";
$PerDayPeriod = 10;

# Initial settings for the DayOfWeek stat page
$DayOfWeekQueue = "General";

# Initial settings for the OpenStalled stat page
@OpenStalledQueueList = ("General");
$OpenStalledWeekends = 1;

# Initial settings for the TimeToResolve stat page
$TimeToResolveDateFormat = "%a %b %d"; 
$TimeToResolveQueue = "General";
$TimeToResolveMaxRows = 10;
$TimeToResolveWeekends = 1;
$TimeToResolveLabelDateFormat = "%a";

# Initial settings for the TimeToResolve Graph page
$TimeToResolveGraphQueue = "General";

$secsPerDay = 86400;

# List of years and months to populate drop down lists
my @lt = localtime;
@years = reverse( 2002 .. ($lt[5]+1900) );
@months=qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;	  
%monthsMaxDay = (
		 0 => 31,  # January
		 1 => 29,  # February, allow for leap year
		 2 => 31,  # March
		 3 => 30,  # April
		 4 => 31,  # May
		 5 => 30,  # June
		 6 => 31,  # July
		 7 => 31,  # August
		 8 => 30,  # September
		 9 => 31,  # October
		 10=> 30,  # November
		 11=> 31   # December
		 );

# Set to one to prevent users without the ShowConfigTab right from seeing Statistics
$RestrictAccess = 0;

# Variables to control debugging
my $debugging=0;  # set to 1 to enable debugging
my $debugtext="";

=head2 FormatDate 

Returns a string representing the specified date formatted by the specified string

=cut
sub FormatDate {
    my $fmt = shift;
    my $self = shift;
    return POSIX::strftime($fmt, localtime($self->Unix));
}


=head2 RTDateSetToLocalMidnight

Sets the date to midnight (at the beginning of the day) local time
Returns the unixtime at midnight.

=cut
sub RTDateSetToLocalMidnight {
    my $self = shift;
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($self->Unix);
    $self->Unix(timelocal (0,0,0,$mday,$mon,$year,$wday,$yday));
    
    return ($self->Unix);
}

=head2 RTDateIsWeekend

Returns 1 if the date is on saturday or sunday

=cut
sub RTDateIsWeekend {
    my $self = shift;
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($self->Unix);
    return 1 if (($wday==6) || ($wday==0));
    0;
}

=head2 RTDateGetDateWeekday

Returns the localized name of the day specified by date

=cut
sub RTDateGetDateWeekday {
    my $self = shift;
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = localtime($self->Unix);
    return $self->GetWeekday($wday);
}

=head2 RTDateSubDay

Subtracts 24 hours from the current time

=cut

sub RTDateSubDay {
    my $self = shift;
    $self->AddSeconds(0 - $DAY);
}

=head2 RTDateSubDays $DAYS

Subtracts 24 hours * $DAYS from the current time

=cut

sub RTDateSubDays {
    my $self = shift;
    my $days = shift;
    $self->AddSeconds(0 - ($days * $DAY));
}

=head2 DebugInit

Creates a text area on the page if debugging is on.

=cut

sub DebugInit {
    if($debugging) {
	my $m = shift;
	$m->print("<TEXTAREA NAME=debugarea COLS=120 ROWS=50>$debugtext</TEXTAREA>\n");
    }
}

=head2 DebugLog $logmsg

Adds a message to the debug area

=cut

sub DebugLog {
    if($debugging) {
	my $line = shift;
	$debugtext .= $line;
	$RT::Logger->debug($line);
    }
}

=head2 DebugClear

Clears the current debug string, otherwise it builds from page to page

=cut

sub DebugClear {
    if($debugging) {
	$debugtext = undef;
    }
}

=head2 DurationAsString 

Returns a string representing the specified duration

=cut

sub DurationAsString {
  my $Duration = shift;
  my $MINUTE = 60;
  my $HOUR =  $MINUTE*60;
  my $DAY = $HOUR * 24;
  my $WEEK = $DAY * 7;
  my $days = int($Duration / $DAY);
  $Duration = $Duration % $DAY;
  my $hours = int($Duration / $HOUR);
  $hours = sprintf("%02d", $hours);
  $Duration = $Duration % $HOUR;
  my $minutes = int($Duration/$MINUTE);
  $minutes = sprintf("%02d", $minutes);
  $Duration = $Duration % $MINUTE;
  my $secs = sprintf("%02d", $Duration);

  if(!$days) {
      $days = "00";
  }
  if(!$hours) {
      $hours = "00";
  }
  if(!$minutes) {
      $minutes = "00";
  }
  if(!$secs) {
      $secs = "00";
  }
  return "$days days $hours:$minutes:$secs";
}

1;


