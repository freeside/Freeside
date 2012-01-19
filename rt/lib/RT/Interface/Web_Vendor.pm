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
    #find new customers
    ###

    my @custnums = map  { /^Ticket-AddCustomer-(\d+)$/; $1 }
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
    );

    if ( $ARGSRef->{'Queue'} and ( $ARGSRef->{'Queue'} !~ /^(\d+)$/ ) ) {
        my $tempqueue = RT::Queue->new($RT::SystemUser);
        $tempqueue->Load( $ARGSRef->{'Queue'} );
        if ( $tempqueue->id ) {
            $ARGSRef->{'Queue'} = $tempqueue->id;
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

=head2 ProcessUpdateMessage

Takes paramhash with fields ARGSRef, TicketObj and SkipSignatureOnly.

Don't write message if it only contains current user's signature and
SkipSignatureOnly argument is true. Function anyway adds attachments
and updates time worked field even if skips message. The default value
is true.

=cut

# change from stock: if txn custom fields are set but there's no content
# or attachment, create a Touch txn instead of doing nothing

sub ProcessUpdateMessage {

    my %args = (
        ARGSRef           => undef,
        TicketObj         => undef,
        SkipSignatureOnly => 1,
        @_
    );

    if ( $args{ARGSRef}->{'UpdateAttachments'}
        && !keys %{ $args{ARGSRef}->{'UpdateAttachments'} } )
    {
        delete $args{ARGSRef}->{'UpdateAttachments'};
    }

    # Strip the signature
    $args{ARGSRef}->{UpdateContent} = RT::Interface::Web::StripContent(
        Content        => $args{ARGSRef}->{UpdateContent},
        ContentType    => $args{ARGSRef}->{UpdateContentType},
        StripSignature => $args{SkipSignatureOnly},
        CurrentUser    => $args{'TicketObj'}->CurrentUser,
    );

    my %txn_customfields;

    foreach my $key ( keys %{ $args{ARGSRef} } ) {
      if ( $key =~ /^(?:Object-RT::Transaction--)?CustomField-(\d+)/ ) {
        next if $key =~ /(TimeUnits|Magic)$/;
        $txn_customfields{$key} = $args{ARGSRef}->{$key};
      }
    }

    # If, after stripping the signature, we have no message, create a 
    # Touch transaction if necessary
    if (    not $args{ARGSRef}->{'UpdateAttachments'}
        and not length $args{ARGSRef}->{'UpdateContent'} )
    {
        #if ( $args{ARGSRef}->{'UpdateTimeWorked'} ) {
        #      $args{ARGSRef}->{TimeWorked} = $args{TicketObj}->TimeWorked +
        #          delete $args{ARGSRef}->{'UpdateTimeWorked'};
        #  }

        my $timetaken = $args{ARGSRef}->{'UpdateTimeWorked'};
        if ( $timetaken or grep {length $_} values %txn_customfields ) {
            my ( $Transaction, $Description, $Object ) =
                $args{TicketObj}->Touch( 
                  CustomFields => \%txn_customfields,
                  TimeTaken => $timetaken
                );
            return $Description;
        }

        return;
    }

    if ( $args{ARGSRef}->{'UpdateSubject'} eq $args{'TicketObj'}->Subject ) {
        $args{ARGSRef}->{'UpdateSubject'} = undef;
    }

    my $Message = MakeMIMEEntity(
        Subject => $args{ARGSRef}->{'UpdateSubject'},
        Body    => $args{ARGSRef}->{'UpdateContent'},
        Type    => $args{ARGSRef}->{'UpdateContentType'},
    );

    $Message->head->add( 'Message-ID' => Encode::encode_utf8(
        RT::Interface::Email::GenMessageId( Ticket => $args{'TicketObj'} )
    ) );
    my $old_txn = RT::Transaction->new( $session{'CurrentUser'} );
    if ( $args{ARGSRef}->{'QuoteTransaction'} ) {
        $old_txn->Load( $args{ARGSRef}->{'QuoteTransaction'} );
    } else {
        $old_txn = $args{TicketObj}->Transactions->First();
    }

    if ( my $msg = $old_txn->Message->First ) {
        RT::Interface::Email::SetInReplyTo(
            Message   => $Message,
            InReplyTo => $msg
        );
    }

    if ( $args{ARGSRef}->{'UpdateAttachments'} ) {
        $Message->make_multipart;
        $Message->add_part($_) foreach values %{ $args{ARGSRef}->{'UpdateAttachments'} };
    }

    if ( $args{ARGSRef}->{'AttachTickets'} ) {
        require RT::Action::SendEmail;
        RT::Action::SendEmail->AttachTickets( RT::Action::SendEmail->AttachTickets,
            ref $args{ARGSRef}->{'AttachTickets'}
            ? @{ $args{ARGSRef}->{'AttachTickets'} }
            : ( $args{ARGSRef}->{'AttachTickets'} ) );
    }

    my $bcc = $args{ARGSRef}->{'UpdateBcc'};
    my $cc  = $args{ARGSRef}->{'UpdateCc'};

    my %message_args = (
        CcMessageTo  => $cc,
        BccMessageTo => $bcc,
        Sign         => $args{ARGSRef}->{'Sign'},
        Encrypt      => $args{ARGSRef}->{'Encrypt'},
        MIMEObj      => $Message,
        TimeTaken    => $args{ARGSRef}->{'UpdateTimeWorked'},
        CustomFields => \%txn_customfields,
    );

    my @temp_squelch;
    foreach my $type (qw(Cc AdminCc)) {
        if (grep $_ eq $type || $_ eq ( $type . 's' ), @{ $args{ARGSRef}->{'SkipNotification'} || [] }) {
            push @temp_squelch, map $_->address, Email::Address->parse( $message_args{$type} );
            push @temp_squelch, $args{TicketObj}->$type->MemberEmailAddresses;
            push @temp_squelch, $args{TicketObj}->QueueObj->$type->MemberEmailAddresses;
        }
    }
    if (grep $_ eq 'Requestor' || $_ eq 'Requestors', @{ $args{ARGSRef}->{'SkipNotification'} || [] }) {
            push @temp_squelch, map $_->address, Email::Address->parse( $message_args{Requestor} );
            push @temp_squelch, $args{TicketObj}->Requestors->MemberEmailAddresses;
    }

    if (@temp_squelch) {
        require RT::Action::SendEmail;
        RT::Action::SendEmail->SquelchMailTo( RT::Action::SendEmail->SquelchMailTo, @temp_squelch );
    }

    unless ( $args{'ARGSRef'}->{'UpdateIgnoreAddressCheckboxes'} ) {
        foreach my $key ( keys %{ $args{ARGSRef} } ) {
            next unless $key =~ /^Update(Cc|Bcc)-(.*)$/;

            my $var   = ucfirst($1) . 'MessageTo';
            my $value = $2;
            if ( $message_args{$var} ) {
                $message_args{$var} .= ", $value";
            } else {
                $message_args{$var} = $value;
            }
        }
    }

    my @results;
    # Do the update via the appropriate Ticket method
    if ( $args{ARGSRef}->{'UpdateType'} =~ /^(private|public)$/ ) {
        my ( $Transaction, $Description, $Object ) =
            $args{TicketObj}->Comment(%message_args);
        push( @results, $Description );
        #$Object->UpdateCustomFields( ARGSRef => $args{ARGSRef} ) if $Object;
    } elsif ( $args{ARGSRef}->{'UpdateType'} eq 'response' ) {
        my ( $Transaction, $Description, $Object ) =
            $args{TicketObj}->Correspond(%message_args);
        push( @results, $Description );
        #$Object->UpdateCustomFields( ARGSRef => $args{ARGSRef} ) if $Object;
    } else {
        push( @results,
            loc("Update type was neither correspondence nor comment.") . " " . loc("Update not recorded.") );
    }
    return @results;
}

1;

