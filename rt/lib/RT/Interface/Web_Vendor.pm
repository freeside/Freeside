# Copyright (c) 2004 Ivan Kohler <ivan-rt@420.am>
# Copyright (c) 2008 Freeside Internet Services, Inc.
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

=head1 NAME

RT::Interface::Web_Vendor

=head1 SYNOPSIS

=head1 DESCRIPTION

Freeside vendor overlay for RT::Interface::Web.

=begin testing

use_ok(RT::Interface::Web_Vendor);

=end testing

=cut

#package RT::Interface::Web;
#use strict;

package HTML::Mason::Commands;
use strict;
no warnings qw(redefine);

=head2 ProcessTicketCustomers 

=cut

sub ProcessTicketCustomers {
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        Debug     => 0,
        @_
    );
    my @results = ();

    my $Ticket  = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};
    my $Debug   = $args{'Debug'};
    my $me = 'ProcessTicketCustomers';

    ### false laziness w/RT::Interface::Web::ProcessTicketLinks
    # Delete links that are gone gone gone.
    foreach my $arg ( keys %$ARGSRef ) {
        if ( $arg =~ /DeleteLink-(.*?)-(DependsOn|MemberOf|RefersTo)-(.*)$/ ) {
            my $base   = $1;
            my $type   = $2;
            my $target = $3;

            push @results,
              "Trying to delete: Base: $base Target: $target  Type $type";
            my ( $val, $msg ) = $Ticket->DeleteLink( Base   => $base,
                                                     Type   => $type,
                                                     Target => $target );

            push @results, $msg;

        }

    }
    ###

    ###
    #find new services
    ###
    
    my @svcnums = map  { /^Ticket-AddService-(\d+)$/; $1 }
                  grep { /^Ticket-AddService-(\d+)$/ && $ARGSRef->{$_} }
                  keys %$ARGSRef;

    my @custnums;
    foreach my $svcnum (@svcnums) {
        my @link = ( 'Type'   => 'MemberOf',
                     'Target' => "freeside://freeside/cust_svc/$svcnum",
                   );

        my( $val, $msg ) = $Ticket->AddLink(@link);
        push @results, $msg;
        next if !$val;

    }

    ###
    #find new customers
    ###

    push @custnums, map  { /^Ticket-AddCustomer-(\d+)$/; $1 }
                    grep { /^Ticket-AddCustomer-(\d+)$/ && $ARGSRef->{$_} }
                    keys %$ARGSRef;

    #my @delete_custnums =
    #  map  { /^Ticket-AddCustomer-(\d+)$/; $1 }
    #  grep { /^Ticket-AddCustomer-(\d+)$/ && $ARGSRef->{$_} }
    #  keys %$ARGSRef;

    ###
    #figure out if we're going to auto-link requestors, and find them if so
    ###

    my $num_cur_cust = $Ticket->Customers->Count;
    my $num_new_cust = scalar(@custnums);
    warn "$me: $num_cur_cust current customers / $num_new_cust new customers\n"
      if $Debug;

    #if we're linking the first ticket to one customer
    my $link_requestors = ( $num_cur_cust == 0 && $num_new_cust == 1 );
    warn "$me: adding a single customer to a previously customerless".
         " ticket, so linking customers to requestor too\n"
      if $Debug && $link_requestors;

    my @Requestors = ();
    if ( $link_requestors ) {

      #find any requestors without customers
      @Requestors =
        grep { ! $_->Customers->Count }
             @{ $Ticket->Requestors->UserMembersObj->ItemsArrayRef };

      warn "$me: found ". scalar(@Requestors). " requestors without".
           " customers; linking them\n"
        if $Debug;

    }

    ###
    #remove any declared non-customer addresses
    ###

    my $exclude_regexp = RT->Config->Get('NonCustomerEmailRegexp');
    @Requestors = grep { not $_->EmailAddress =~ $exclude_regexp } @Requestors
      if defined $exclude_regexp;

    ###
    #link ticket (and requestors) to customers
    ###

    foreach my $custnum ( @custnums ) {

      my @link = ( 'Type'   => 'MemberOf',
                   'Target' => "freeside://freeside/cust_main/$custnum",
                 );

      my( $val, $msg ) = $Ticket->AddLink(@link);
      push @results, $msg;

      #add customer links to requestors
      foreach my $Requestor ( @Requestors ) {
        my( $val, $msg ) = $Requestor->AddLink(@link);
        push @results, $msg;
        warn "$me: linking requestor to custnum $custnum: $msg\n"
          if $Debug > 1;
      }

    }

    return @results;

}

#false laziness w/above... eventually it should go away in favor of this
sub ProcessObjectCustomers {
    my %args = (
        Object => undef,
        ARGSRef   => undef,
        @_
    );
    my @results = ();

    my $Object  = $args{'Object'};
    my $ARGSRef = $args{'ARGSRef'};

    ### false laziness w/RT::Interface::Web::ProcessTicketLinks
    # Delete links that are gone gone gone.
    foreach my $arg ( keys %$ARGSRef ) {
        if ( $arg =~ /DeleteLink-(.*?)-(DependsOn|MemberOf|RefersTo)-(.*)$/ ) {
            my $base   = $1;
            my $type   = $2;
            my $target = $3;

            push @results,
              "Trying to delete: Base: $base Target: $target  Type $type";
            my ( $val, $msg ) = $Object->DeleteLink( Base   => $base,
                                                     Type   => $type,
                                                     Target => $target );

            push @results, $msg;

        }

    }
    ###

    #my @delete_custnums =
    #  map  { /^Object-AddCustomer-(\d+)$/; $1 }
    #  grep { /^Object-AddCustomer-(\d+)$/ && $ARGSRef->{$_} }
    #  keys %$ARGSRef;

    my @custnums = map  { /^Object-AddCustomer-(\d+)$/; $1 }
                   grep { /^Object-AddCustomer-(\d+)$/ && $ARGSRef->{$_} }
                   keys %$ARGSRef;

    foreach my $custnum ( @custnums ) {
      my( $val, $msg ) =
        $Object->AddLink( 'Type'   => 'MemberOf',
                          'Target' => "freeside://freeside/cust_main/$custnum",
                        );
      push @results, $msg;
    }

    return @results;

}

=head2 ProcessTicketBasics ( TicketObj => $Ticket, ARGSRef => \%ARGS );

Updates all core ticket fields except Status, and returns an array of results
messages.

=cut

sub ProcessTicketBasics {

    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $TicketObj = $args{'TicketObj'};
    my $ARGSRef   = $args{'ARGSRef'};

    # {{{ Set basic fields
    my @attribs = qw(
        Subject
        FinalPriority
        Priority
        TimeEstimated
        TimeWorked
        TimeLeft
        Type
        Queue
        WillResolve
    );

    # the UI for editing WillResolve through Ticket Basics should allow 
    # setting it to null
    if ( exists $ARGSRef->{'WillResolve_Date'} ) {
      my $to_date = delete($ARGSRef->{'WillResolve_Date'});
      my $DateObj = RT::Date->new($session{'CurrentUser'});
      if ( $to_date ) {
          $DateObj->Set(Format => 'unknown', Value => $to_date);
          if ( $DateObj->Unix > time ) {
            $ARGSRef->{'WillResolve'} = $DateObj->ISO;
          } else {
            warn "Ticket ".$TicketObj->Id.": WillResolve date '$to_date' not accepted.\n";
            # and then don't set it in ARGSRef
          }
      } elsif ( $TicketObj and $TicketObj->WillResolveObj->Unix > 0 ) {
          $DateObj->Set(Value => 0);
          $ARGSRef->{'WillResolve'} = $DateObj->ISO;
      }
    }

    if ( $ARGSRef->{'Queue'} and ( $ARGSRef->{'Queue'} !~ /^(\d+)$/ ) ) {
        my $tempqueue = RT::Queue->new($RT::SystemUser);
        $tempqueue->Load( $ARGSRef->{'Queue'} );
        if ( $tempqueue->id ) {
            $ARGSRef->{'Queue'} = $tempqueue->id;
        }
    }

    # RT core _will_ allow Set transactions that change these 
    # fields to empty strings, but internally change the values 
    # to zero.  This is sloppy and causes some problems.
    foreach my $field (qw(TimeWorked TimeEstimated TimeLeft)) {
      if (exists $ARGSRef->{$field}) {
        $ARGSRef->{$field} =~ s/\s//g;
        $ARGSRef->{$field} ||= 0;
      }
    }

    my @results = UpdateRecordObject(
        AttributesRef => \@attribs,
        Object        => $TicketObj,
        ARGSRef       => $ARGSRef,
    );

    # We special case owner changing, so we can use ForceOwnerChange
    if ( $ARGSRef->{'Owner'} && ( $TicketObj->Owner != $ARGSRef->{'Owner'} ) ) {
        my ($ChownType);
        if ( $ARGSRef->{'ForceOwnerChange'} ) {
            $ChownType = "Force";
        } else {
            $ChownType = "Give";
        }

        my ( $val, $msg ) = $TicketObj->SetOwner( $ARGSRef->{'Owner'}, $ChownType );
        push( @results, $msg );
    }

    return (@results);
}

=head2 ProcessTicketDates (TicketObj => RT::Ticket, ARGSRef => {}) 

Process updates to the Starts, Started, Told, Resolved, and WillResolve 
fields.

=cut

sub ProcessTicketDates {
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $Ticket  = $args{'TicketObj'};
    my $ARGSRef = $args{'ARGSRef'};

    my (@results);

    # {{{ Set date fields
    my @date_fields = qw(
        Told
        Resolved
        Starts
        Started
        Due
        WillResolve
    );

    #Run through each field in this list. update the value if apropriate
    foreach my $field (@date_fields) {
        next unless exists $ARGSRef->{ $field . '_Date' };
        next if $ARGSRef->{ $field . '_Date' } eq '';

        my ( $code, $msg );

        my $DateObj = RT::Date->new( $session{'CurrentUser'} );
        $DateObj->Set(
            Format => 'unknown',
            Value  => $ARGSRef->{ $field . '_Date' }
        );

        if ( $field eq 'WillResolve'
              and $DateObj->Unix > 0 
              and $DateObj->Unix <= time ) {
            push @results, "Can't set WillResolve date in the past.";
            next;
        }

        my $obj = $field . "Obj";
        if (    ( defined $DateObj->Unix )
            and ( $DateObj->Unix != $Ticket->$obj()->Unix() ) )
        {
            my $method = "Set$field";
            my ( $code, $msg ) = $Ticket->$method( $DateObj->ISO );
            push @results, "$msg";
        }
    }

    # }}}
    return (@results);
}

=head2 ProcessTicketStatus (TicketObj => RT::Ticket, ARGSRef => {})

Process updates to the 'Status' field of the ticket.  If the new value 
of Status is 'resolved', this will check required custom fields before 
allowing the update.

=cut

sub ProcessTicketStatus {
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );

    my $TicketObj = $args{'TicketObj'};
    my $ARGSRef   = $args{'ARGSRef'};
    my @results;

    return () if !$ARGSRef->{'Status'};

    if ( lc( $ARGSRef->{'Status'} ) eq 'resolved' ) {
        foreach my $field ( $TicketObj->MissingRequiredFields ) {
            push @results, loc('Missing required field: [_1]', $field->Name);
        }
    }
    if ( @results ) {
        $m->notes('RedirectToBasics' => 1);
        return @results;
    }

    return UpdateRecordObject(
        AttributesRef => [ 'Status' ],
        Object        => $TicketObj,
        ARGSRef       => $ARGSRef,
    );
}

sub default_FormatDate { $_[0]->AsString }

sub ProcessColumnMapValue {
    my $value = shift;
    my %args = ( Arguments => [],
                 Escape => 1,
                 FormatDate => \&default_FormatDate,
                 @_ );

    if ( ref $value ) {
        if ( ref $value eq 'RT::Date' ) {
            return $args{FormatDate}->($value);
        } elsif ( UNIVERSAL::isa( $value, 'CODE' ) ) {
            my @tmp = $value->( @{ $args{'Arguments'} } );
            return ProcessColumnMapValue( ( @tmp > 1 ? \@tmp : $tmp[0] ), %args );
        } elsif ( UNIVERSAL::isa( $value, 'ARRAY' ) ) {
            return join '', map ProcessColumnMapValue( $_, %args ), @$value;
        } elsif ( UNIVERSAL::isa( $value, 'SCALAR' ) ) {
            return $$value;
        }
    }

    return $m->interp->apply_escapes( $value, 'h' ) if $args{'Escape'};
    return $value;
}


1;

