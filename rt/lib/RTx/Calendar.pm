package RTx::Calendar;

use strict;
use DateTime;
use DateTime::Set;

our $VERSION = "0.07";

sub FirstMonday {
    my ($year, $month) = (shift, shift);
    my $set = DateTime::Set->from_recurrence(
	next => sub { $_[0]->truncate( to => 'day' )->subtract( days => 1 ) }
    );

    my $day = DateTime->new( year => $year, month => $month );

    $day = $set->next($day) while $day->day_of_week != 1;
    $day;

}

sub LastSunday {
    my ($year, $month) = (shift, shift);
    my $set = DateTime::Set->from_recurrence(
	next => sub { $_[0]->truncate( to => 'day' )->add( days => 1 ) }
    );

    my $day = DateTime->last_day_of_month( year => $year, month => $month );

    $day = $set->next($day) while $day->day_of_week != 7;
    $day;
}

# we can't use RT::Date::Date because it uses gmtime
# and we need localtime
sub LocalDate {
  my $ts = shift;
  my ($d,$m,$y) = (localtime($ts))[3..5];
  sprintf "%4d-%02d-%02d", ($y + 1900), ++$m, $d;
}

sub DatesClauses {
    my ($Dates, $begin, $end) = @_;

    my $clauses = "";

    my @DateClauses = map {
	"($_ >= '" . $begin . "' AND $_ <= '" . $end . "')"
    } @$Dates;
    $clauses  .= " AND " . " ( " . join(" OR ", @DateClauses) . " ) "
	if @DateClauses;

    return $clauses
}

sub FindTickets {
    my ($CurrentUser, $Query, $Dates, $begin, $end) = @_;

    $Query .= DatesClauses($Dates, $begin, $end)
	if $begin and $end;

    my $Tickets = RT::Tickets->new($CurrentUser);
    $Tickets->FromSQL($Query);

    my %Tickets;
    my %AlreadySeen;

    while ( my $Ticket = $Tickets->Next()) {

	# How to find the LastContacted date ?
	for my $Date (@$Dates) {
	    my $DateObj = $Date . "Obj";
	    push @{ $Tickets{ LocalDate($Ticket->$DateObj->Unix) } }, $Ticket
		# if reminder, check it's refering to a ticket
		unless ($Ticket->Type eq 'reminder' and not $Ticket->RefersTo->First)
		    or $AlreadySeen{  LocalDate($Ticket->$DateObj->Unix) }{ $Ticket }++;
	}
    }
    return %Tickets;
}

# 
# Take a user object and return the search with Description "calendar" if it exists
# 
sub SearchDefaultCalendar {
    my $CurrentUser = shift;
    my $Description = "calendar";

    # I'm quite sure the loop isn't usefull but...
    my @Objects = $CurrentUser->UserObj;
    for my $object (@Objects) {
	next unless ref($object) eq 'RT::User' && $object->id == $CurrentUser->Id;
	my @searches = $object->Attributes->Named('SavedSearch');
	for my $search (@searches) {
	    next if ($search->SubValue('SearchType')
			 && $search->SubValue('SearchType') ne 'Ticket');

	    return $search
		if "calendar" eq $search->Description;
	}
    }
}


1;

__END__

=head1 NAME

RTx::Calendar - Calendar for RT due tasks

=head1 VERSION

This document describes version 0.07 of RTx::Calendar

=head1 DESCRIPTION

This RT extension provides a calendar view for your tickets and your
reminders so you see when is your next due ticket. You can find it in
the menu Search->Calendar.

There's a portlet to put on your home page (see Prefs/MyRT.html)

You can also enable ics (ICal) feeds for your default calendar and all
your private searches in Prefs/Calendar.html. Authentication is magic
number based so that you can give those feeds to other people.

You can find screenshots on
http://gaspard.mine.nu/dotclear/index.php?tag/rtx-calendar

=head1 INSTALLATION

If you upgrade from 0.02, see next part before.

You need to install those three modules :

  * Date::ICal
  * Data::ICal
  * DateTime::Set

Install it like a standard perl module

 perl Makefile.PL
 make
 make install

If your RT is not in the default path (/opt/rt3) you must set RTHOME
before doing the Makefile.PL

=head1 CONFIGURATION

=head2 Base configuration

In RT 3.8 and later, to enable calendar plugin, you must add something
like that in your etc/RT_SiteConfig.pm :

  Set(@Plugins,(qw(RTx::Calendar)));

To use MyCalendar portlet you must add MyCalendar to
$HomepageComponents in etc/RT_SiteConfig.pm like that :

  Set($HomepageComponents, [qw(QuickCreate Quicksearch MyCalendar
     MyAdminQueues MySupportQueues MyReminders RefreshHomepage)]);

To enable private searches ICal feeds, you need to give
CreateSavedSearch and LoadSavedSearch rights to your users.

=head2 Display configuration

You can show the owner in each day box by adding this line to your
etc/RT_SiteConfig.pm :

    Set($CalendarDisplayOwner, 1);

You can change which fields show up in the popup display when you
mouse over a date in etc/RT_SiteConfig.pm :

    @CalendarPopupFields = ('Status', 'OwnerObj->Name', 'DueObj->ISO');

=head2 ICAL feed configuration

By default, tickets are todo and reminders event. You can change this
by setting $RT::ICalTicketType and $RT::ICalReminderType in etc/RT_SiteConfig.pm :

  Set($ICalTicketType,   "Data::ICal::Entry::Event");
  Set($ICalReminderType ,"Data::ICal::Entry::Todo");

=head1 USAGE

A small help section is available in /Prefs/Calendar.html

=head1 UPGRADE FROM 0.02

As I've change directory structure, if you upgrade from 0.02 you need
to delete old files manually. Go in RTHOME/share/html (by default
/opt/rt3/share/html) and delete those files :

  rm -rf Callbacks/RTx-Calendar
  rm Tools/Calendar.html

RTx-Calendar may work without this but it's not very clean.

=head1 BUGS

=over

=item *
compatible only with RT 3.6 for the moment. If someone need
compatibility with 3.4 I can work on this. And I will work on 3.7
compatibility later.

=back

=head1 AUTHORS

Nicolas Chuche E<lt>nchuche@barna.beE<gt>

Idea borrowed from redmine's calendar (Thanks Jean-Philippe).

=head1 COPYRIGHT

Copyright 2007 by Nicolas Chuche E<lt>nchuche@barna.beE<gt>

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
