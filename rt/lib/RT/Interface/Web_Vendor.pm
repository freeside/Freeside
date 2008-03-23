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

=head2 ProcessTicketCustomers 

=cut

sub ProcessTicketCustomers {
    my %args = (
        TicketObj => undef,
        ARGSRef   => undef,
        @_
    );
    my @results = ();

    my $Ticket  = $args{'TicketObj'};
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
            my ( $val, $msg ) = $Ticket->DeleteLink( Base   => $base,
                                                     Type   => $type,
                                                     Target => $target );

            push @results, $msg;

        }

    }
    ###

    my @delete_custnums =
      map  { /^Ticket-AddCustomer-(\d+)$/; $1 }
      grep { /^Ticket-AddCustomer-(\d+)$/ && $ARGSRef->{$_} }
      keys %$ARGSRef;

    my @custnums = map  { /^Ticket-AddCustomer-(\d+)$/; $1 }
                   grep { /^Ticket-AddCustomer-(\d+)$/ && $ARGSRef->{$_} }
                   keys %$ARGSRef;

    foreach my $custnum ( @custnums ) {
      my( $val, $msg ) =
        $Ticket->AddLink( 'Type'   => 'MemberOf',
                          'Target' => "freeside://freeside/cust_main/$custnum",
                        );
      push @results, $msg;
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

    my @delete_custnums =
      map  { /^Object-AddCustomer-(\d+)$/; $1 }
      grep { /^Object-AddCustomer-(\d+)$/ && $ARGSRef->{$_} }
      keys %$ARGSRef;

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

1;

