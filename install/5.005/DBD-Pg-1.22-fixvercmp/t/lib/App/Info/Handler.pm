package App::Info::Handler;

# $Id: Handler.pm,v 1.1 2004-04-29 09:21:28 ivan Exp $

=head1 NAME

App::Info::Handler - App::Info event handler base class

=head1 SYNOPSIS

  use App::Info::Category::FooApp;
  use App::Info::Handler;

  my $app = App::Info::Category::FooApp->new( on_info => ['default'] );

=head1 DESCRIPTION

This class defines the interface for subclasses that wish to handle events
triggered by App::Info concrete subclasses. The different types of events
triggered by App::Info can all be handled by App::Info::Handler (indeed, by
default they're all handled by a single App::Info::Handler object), and
App::Info::Handler subclasses may be designed to handle whatever events they
wish.

If you're interested in I<using> an App::Info event handler, this is probably
not the class you should look at, since all it does is define a simple handler
that does nothing with an event. Look to the L<App::Info::Handler
subclasses|"SEE ALSO"> included in this distribution to do more interesting
things with App::Info events.

If, on the other hand, you're interested in implementing your own event
handlers, read on!

=cut

use strict;
use vars qw($VERSION);
$VERSION = '0.22';

my %handlers;

=head1 INTERFACE

This section documents the public interface of App::Info::Handler.

=head2 Class Method

=head3 register_handler

  App::Info::Handler->register_handler( $key => $code_ref );

This class method may be used by App::Info::Handler subclasses to register
themselves with App::Info::Handler. Multiple registrations are supported. The
idea is that a subclass can define different functionality by specifying
different strings that represent different modes of constructing an
App::Info::Handler subclass object. The keys are case-sensitve, and should be
unique across App::Info::Handler subclasses so that many subclasses can be
loaded and used separately. If the C<$key> is already registered,
C<register_handler()> will throw an exception. The values are code references
that, when executed, return the appropriate App::Info::Handler subclass
object.

=cut

sub register_handler {
    my ($pkg, $key, $code) = @_;
    Carp::croak("Handler '$key' already exists")
      if $handlers{$key};
    $handlers{$key} = $code;
}

# Register ourself.
__PACKAGE__->register_handler('default', sub { __PACKAGE__->new } );

##############################################################################

=head2 Constructor

=head3 new

  my $handler = App::Info::Handler->new;
  $handler =  App::Info::Handler->new( key => $key);

Constructs an App::Info::Handler object and returns it. If the key parameter
is provided and has been registered by an App::Info::Handler subclass via the
C<register_handler()> class method, then the relevant code reference will be
executed and the resulting App::Info::Handler subclass object returned. This
approach provides a handy shortcut for having C<new()> behave as an abstract
factory method, returning an object of the subclass appropriate to the key
parameter.

=cut

sub new {
    my ($pkg, %p) = @_;
    my $class = ref $pkg || $pkg;
    $p{key} ||= 'default';
    if ($class eq __PACKAGE__ && $p{key} ne 'default') {
        # We were called directly! Handle it.
        Carp::croak("No such handler '$p{key}'") unless $handlers{$p{key}};
        return $handlers{$p{key}}->();
    } else {
        # A subclass called us -- just instantiate and return.
        return bless \%p, $class;
    }
}

=head2 Instance Method

=head3 handler

  $handler->handler($req);

App::Info::Handler defines a single instance method that must be defined by
its subclasses, C<handler()>. This is the method that will be executed by an
event triggered by an App::Info concrete subclass. It takes as its single
argument an App::Info::Request object, and returns a true value if it has
handled the event request. Returning a false value declines the request, and
App::Info will then move on to the next handler in the chain.

The C<handler()> method implemented in App::Info::Handler itself does nothing
more than return a true value. It thus acts as a very simple default event
handler. See the App::Info::Handler subclasses for more interesting handling
of events, or create your own!

=cut

sub handler { 1 }

1;
__END__

=head1 SUBCLASSING

I hatched the idea of the App::Info event model with its subclassable handlers
as a way of separating the aggregation of application metadata from writing a
user interface for handling certain conditions. I felt it a better idea to
allow people to create their own user interfaces, and instead to provide only
a few examples. The App::Info::Handler class defines the API interface for
handling these conditions, which App::Info refers to as "events".

There are various types of events defined by App::Info ("info", "error",
"unknown", and "confirm"), but the App::Info::Handler interface is designed to
be flexible enough to handle any and all of them. If you're interested in
creating your own App::Info event handler, this is the place to learn how.

=head2 The Interface

To create an App::Info event handler, all one need do is subclass
App::Info::Handler and then implement the C<new()> constructor and the
C<handler()> method. The C<new()> constructor can do anything you like, and
take any arguments you like. However, I do recommend that the first thing
you do in your implementation is to call the super constructor:

  sub new {
      my $pkg = shift;
      my $self = $pkg->SUPER::new(@_);
      # ... other stuff.
      return $self;
  }

Although the default C<new()> constructor currently doesn't do much, that may
change in the future, so this call will keep you covered. What it does do is
take the parameterized arguments and assign them to the App::Info::Handler
object. Thus if you've specified a "mode" argument, where clients can
construct objects of you class like this:

  my $handler = FooHandler->new( mode => 'foo' );

You can access the mode parameter directly from the object, like so:

  sub new {
      my $pkg = shift;
      my $self = $pkg->SUPER::new(@_);
      if ($self->{mode} eq 'foo') {
          # ...
      }
      return $self;
  }

Just be sure not to use a parameter key name required by App::Info::Handler
itself. At the moment, the only parameter accepted by App::Info::Handler is
"key", so in general you'll be pretty safe.

Next, I recommend that you take advantage of the C<register_handler()> method
to create some shortcuts for creating handlers of your class. For example, say
we're creating a handler subclass FooHandler. It has two modes, a default
"foo" mode and an advanced "bar" mode. To allow both to be constructed by
stringified shortcuts, the FooHandler class implementation might start like
this:

  package FooHandler;

  use strict;
  use App::Info::Handler;
  use vars qw(@ISA);
  @ISA = qw(App::Info::Handler);

  foreach my $c (qw(foo bar)) {
      App::Info::Handler->register_handler
        ( $c => sub { __PACKAGE__->new( mode => $c) } );
  }

The strings "foo" and "bar" can then be used by clients as shortcuts to have
App::Info objects automatically create and use handlers for certain events.
For example, if a client wanted to use a "bar" event handler for its info
events, it might do this:

  use App::Info::Category::FooApp;
  use FooHandler;

  my $app = App::Info::Category::FooApp->new(on_info => ['bar']);

Take a look at App::Info::Handler::Print and App::Info::Handler::Carp to see
concrete examples of C<register_handler()> usage.

The final step in creating a new App::Info event handler is to implement the
C<handler()> method itself. This method takes a single argument, an
App::Info::Request object, and is expected to return true if it handled the
request, and false if it did not. The App::Info::Request object contains all
the metadata relevant to a request, including the type of event that triggered
it; see L<App::Info::Request|App::Info::Request> for its documentation.

Use the App::Info::Request object however you like to handle the request
however you like. You are, however, expected to abide by a a few guidelines:

=over 4

=item *

For error and info events, you are expected (but not required) to somehow
display the info or error message for the user. How your handler chooses to do
so is up to you and the handler.

=item *

For unknown and confirm events, you are expected to prompt the user for a
value. If it's a confirm event, offer the known value (found in
C<$req-E<gt>value>) as a default.

=item *

For unknown and confirm events, you are expected to call C<$req-E<gt>callback>
and pass in the new value. If C<$req-E<gt>callback> returns a false value, you
are expected to display the error message in C<$req-E<gt>error> and prompt the
user again. Note that C<$req-E<gt>value> calls C<$req-E<gt>callback>
internally, and thus assigns the value and returns true if
C<$req-E<gt>callback> returns true, and does not assign the value and returns
false if C<$req-E<gt>callback> returns false.

=item *

For unknown and confirm events, if you've collected a new value and
C<$req-E<gt>callback> returns true for that value, you are expected to assign
the value by passing it to C<$req-E<gt>value>. This allows App::Info to give
the value back to the calling App::Info concrete subclass.

=back

Probably the easiest way to get started creating new App::Info event handlers
is to check out the simple handlers provided with the distribution and follow
their logical examples. Consult the App::Info documentation of the L<event
methods|App::Info/"Events"> for details on how App::Info constructs the
App::Info::Request object for each event type.

=head1 BUGS

Report all bugs via the CPAN Request Tracker at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Info>.

=head1 AUTHOR

David Wheeler <L<david@wheeler.net|"david@wheeler.net">>

=head1 SEE ALSO

L<App::Info|App::Info> thoroughly documents the client interface for setting
event handlers, as well as the event triggering interface for App::Info
concrete subclasses.

L<App::Info::Request|App::Info::Request> documents the interface for the
request objects passed to App::Info::Handler C<handler()> methods.

The following App::Info::Handler subclasses offer examples for event handler
authors, and, of course, provide actual event handling functionality for
App::Info clients.

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
