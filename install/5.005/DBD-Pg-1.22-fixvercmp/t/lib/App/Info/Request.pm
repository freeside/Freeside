package App::Info::Request;

# $Id: Request.pm,v 1.1 2004-04-29 09:21:28 ivan Exp $

=head1 NAME

App::Info::Request - App::Info event handler request object

=head1 SYNOPSIS

  # In an App::Info::Handler subclass:
  sub handler {
      my ($self, $req) = @_;
      print "Event Type:  ", $req->type;
      print "Message:     ", $req->message;
      print "Error:       ", $req->error;
      print "Value:       ", $req->value;
  }

=head1 DESCRIPTION

Objects of this class are passed to the C<handler()> method of App::Info event
handlers. Generally, this class will be of most interest to App::Info::Handler
subclass implementers.

The L<event triggering methods|App::Info/"Events"> in App::Info each construct
a new App::Info::Request object and initialize it with their arguments. The
App::Info::Request object is then the sole argument passed to the C<handler()>
method of any and all App::Info::Handler objects in the event handling chain.
Thus, if you'd like to create your own App::Info event handler, this is the
object you need to be familiar with. Consult the
L<App::Info::Handler|App::Info::Handler> documentation for details on creating
custom event handlers.

Each of the App::Info event triggering methods constructs an
App::Info::Request object with different attribute values. Be sure to consult
the documentation for the L<event triggering methods|App::Info/"Events"> in
App::Info, where the values assigned to the App::Info::Request object are
documented. Then, in your event handler subclass, check the value returned by
the C<type()> method to determine what type of event request you're handling
to handle the request appropriately.

=cut

use strict;
use vars qw($VERSION);
$VERSION = '0.23';

##############################################################################

=head1 INTERFACE

The following sections document the App::Info::Request interface.

=head2 Constructor

=head3 new

  my $req = App::Info::Request->new(%params);

This method is used internally by App::Info to construct new
App::Info::Request objects to pass to event handler objects. Generally, you
won't need to use it, other than perhaps for testing custom App::Info::Handler
classes.

The parameters to C<new()> are passed as a hash of named parameters that
correspond to their like-named methods. The supported parameters are:

=over 4

=item type

=item message

=item error

=item value

=item callback

=back

See the object methods documentation below for details on these object
attributes.

=cut

sub new {
    my $pkg = shift;

    # Make sure we've got a hash of arguments.
    Carp::croak("Odd number of parameters in call to " . __PACKAGE__ .
                "->new() when named parameters expected" ) if @_ % 2;
    my %params = @_;

    # Validate the callback.
    if ($params{callback}) {
        Carp::croak("Callback parameter '$params{callback}' is not a code ",
                    "reference")
            unless UNIVERSAL::isa($params{callback}, 'CODE');
    } else {
        # Otherwise just assign a default approve callback.
        $params{callback} = sub { 1 };
    }

    # Validate type parameter.
    if (my $t = $params{type}) {
        Carp::croak("Invalid handler type '$t'")
          unless $t eq 'error' or $t eq 'info' or $t eq 'unknown'
          or $t eq 'confirm';
    } else {
        $params{type} = 'info';
    }

    # Return the request object.
    bless \%params, ref $pkg || $pkg;
}

##############################################################################

=head2 Object Methods

=head3 message

  my $message = $req->message;

Returns the message stored in the App::Info::Request object. The message is
typically informational, or an error message, or a prompt message.

=cut

sub message { $_[0]->{message} }

##############################################################################

=head3 error

  my $error = $req->error;

Returns any error message associated with the App::Info::Request object. The
error message is typically there to display for users when C<callback()>
returns false.

=cut

sub error { $_[0]->{error} }

##############################################################################

=head3 type

  my $type = $req->type;

Returns a string representing the type of event that triggered this request.
The types are the same as the event triggering methods defined in App::Info.
As of this writing, the supported types are:

=over

=item info

=item error

=item unknown

=item confirm

=back

Be sure to consult the App::Info documentation for more details on the event
types.

=cut

sub type { $_[0]->{type} }

##############################################################################

=head3 callback

  if ($req->callback($value)) {
      print "Value '$value' is valid.\n";
  } else {
      print "Value '$value' is not valid.\n";
  }

Executes the callback anonymous subroutine supplied by the App::Info concrete
base class that triggered the event. If the callback returns false, then
C<$value> is invalid. If the callback returns true, then C<$value> is valid
and can be assigned via the C<value()> method.

Note that the C<value()> method itself calls C<callback()> if it was passed a
value to assign. See its documentation below for more information.

=cut

sub callback {
    my $self = shift;
    my $code = $self->{callback};
    local $_ = $_[0];
    $code->(@_);
}

##############################################################################

=head3 value

  my $value = $req->value;
  if ($req->value($value)) {
      print "Value '$value' successfully assigned.\n";
  } else {
      print "Value '$value' not successfully assigned.\n";
  }

When called without an argument, C<value()> simply returns the value currently
stored by the App::Info::Request object. Typically, the value is the default
value for a confirm event, or a value assigned to an unknown event.

When passed an argument, C<value()> attempts to store the the argument as a
new value. However, C<value()> calls C<callback()> on the new value, and if
C<callback()> returns false, then C<value()> returns false and does not store
the new value. If C<callback()> returns true, on the other hand, then
C<value()> goes ahead and stores the new value and returns true.

=cut

sub value {
    my $self = shift;
    if ($#_ >= 0) {
        # grab the value.
        my $value = shift;
        # Validate the value.
        if ($self->callback($value)) {
            # The value is good. Assign it and return true.
            $self->{value} = $value;
            return 1;
        } else {
            # Invalid value. Return false.
            return;
        }
    }
    # Just return the value.
    return $self->{value};
}

1;
__END__

=head1 BUGS

Report all bugs via the CPAN Request Tracker at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Info>.

=head1 AUTHOR

David Wheeler <L<david@wheeler.net|"david@wheeler.net">>

=head1 SEE ALSO

L<App::Info|App::Info> documents the event triggering methods and how they
construct App::Info::Request objects to pass to event handlers.

L<App::Info::Handler:|App::Info::Handler> documents how to create custom event
handlers, which must make use of the App::Info::Request object passed to their
C<handler()> object methods.

The following classes subclass App::Info::Handler, and thus offer good
exemplars for using App::Info::Request objects when handling events.

=over 4

=item L<App::Info::Handler::Carp|App::Info::Handler::Carp>

=item L<App::Info::Handler::Print|App::Info::Handler::Print>

=item L<App::Info::Handler::Prompt|App::Info::Handler::Prompt>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002, David Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
