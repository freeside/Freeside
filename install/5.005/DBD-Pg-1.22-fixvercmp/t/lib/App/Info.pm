package App::Info;

# $Id: Info.pm,v 1.1 2004-04-29 09:21:28 ivan Exp $

=head1 NAME

App::Info - Information about software packages on a system

=head1 SYNOPSIS

  use App::Info::Category::FooApp;

  my $app = App::Info::Category::FooApp->new;

  if ($app->installed) {
      print "App name: ", $app->name, "\n";
      print "Version:  ", $app->version, "\n";
      print "Bin dir:  ", $app->bin_dir, "\n";
  } else {
      print "App not installed on your system. :-(\n";
  }

=head1 DESCRIPTION

App::Info is an abstract base class designed to provide a generalized
interface for subclasses that provide metadata about software packages
installed on a system. The idea is that these classes can be used in Perl
application installers in order to determine whether software dependencies
have been fulfilled, and to get necessary metadata about those software
packages.

App::Info provides an event model for handling events triggered by App::Info
subclasses. The events are classified as "info", "error", "unknown", and
"confirm" events, and multiple handlers may be specified to handle any or all
of these event types. This allows App::Info clients to flexibly handle events
in any way they deem necessary. Implementing new event handlers is
straight-forward, and use the triggering of events by App::Info subclasses is
likewise kept easy-to-use.

A few L<sample subclasses|"SEE ALSO"> are provided with the distribution, but
others are invited to write their own subclasses and contribute them to the
CPAN. Contributors are welcome to extend their subclasses to provide more
information relevant to the application for which data is to be provided (see
L<App::Info::HTTPD::Apache|App::Info::HTTPD::Apache> for an example), but are
encouraged to, at a minimum, implement the abstract methods defined here and
in the category abstract base classes (e.g.,
L<App::Info::HTTPD|App::Info::HTTPD> and L<App::Info::Lib|App::Info::Lib>).
See L<Subclassing|"SUBCLASSING"> for more information on implementing new
subclasses.

=cut

use strict;
use Carp ();
use App::Info::Handler;
use App::Info::Request;
use vars qw($VERSION);

$VERSION = '0.23';

##############################################################################
##############################################################################
# This code ref is used by the abstract methods to throw an exception when
# they're called directly.
my $croak = sub {
    my ($caller, $meth) = @_;
    $caller = ref $caller || $caller;
    if ($caller eq __PACKAGE__) {
        $meth = __PACKAGE__ . '::' . $meth;
        Carp::croak(__PACKAGE__ . " is an abstract base class. Attempt to " .
                    " call non-existent method $meth");
    } else {
        Carp::croak("Class $caller inherited from the abstract base class " .
                    __PACKAGE__ . ", but failed to redefine the $meth() " .
                    "method. Attempt to call non-existent method " .
                    "${caller}::$meth");
    }
};

##############################################################################
# This code reference is used by new() and the on_* error handler methods to
# set the error handlers.
my $set_handlers = sub {
    my $on_key = shift;
    # Default is to do nothing.
    return [] unless $on_key;
    my $ref = ref $on_key;
    if ($ref) {
        $on_key = [$on_key] unless $ref eq 'ARRAY';
        # Make sure they're all handlers.
        foreach my $h (@$on_key) {
            if (my $r = ref $h) {
                Carp::croak("$r object is not an App::Info::Handler")
                  unless UNIVERSAL::isa($h, 'App::Info::Handler');
            } else {
                # Look up the handler.
                $h = App::Info::Handler->new( key => $h);
            }
        }
        # Return 'em!
        return $on_key;
    } else {
        # Look up the handler.
        return [ App::Info::Handler->new( key => $on_key) ];
    }
};

##############################################################################
##############################################################################

=head1 INTERFACE

This section documents the public interface of App::Info.

=head2 Constructor

=head3 new

  my $app = App::Info::Category::FooApp->new(@params);

Constructs an App::Info object and returns it. The @params arguments define
how the App::Info object will respond to certain events, and correspond to
their like-named methods. See the L<"Event Handler Object Methods"> section
for more information on App::Info events and how to handle them. The
parameters to C<new()> for the different types of App::Info events are:

=over 4

=item on_info

=item on_error

=item on_unknown

=item on_confirm

=back

When passing event handlers to C<new()>, the list of handlers for each type
should be an anonymous array, for example:

  my $app = App::Info::Category::FooApp->new( on_info => \@handlers );

=cut

sub new {
    my ($pkg, %p) = @_;
    my $class = ref $pkg || $pkg;
    # Fail if the method isn't overridden.
    $croak->($pkg, 'new') if $class eq __PACKAGE__;

    # Set up handlers.
    for (qw(on_error on_unknown on_info on_confirm)) {
        $p{$_} = $set_handlers->($p{$_});
    }

    # Do it!
    return bless \%p, $class;
}

##############################################################################
##############################################################################

=head2 Metadata Object Methods

These are abstract methods in App::Info and must be provided by its
subclasses. They provide the essential metadata of the software package
supported by the App::Info subclass.

=head3 key_name

  my $key_name = $app->key_name;

Returns a string that uniquely identifies the software for which the App::Info
subclass provides data. This value should be unique across all App::Info
classes. Typically, it's simply the name of the software.

=cut

sub key_name { $croak->(shift, 'key_name') }

=head3 installed

  if ($app->installed) {
      print "App is installed.\n"
  } else {
      print "App is not installed.\n"
  }

Returns a true value if the application is installed, and a false value if it
is not.

=cut

sub installed { $croak->(shift, 'installed') }

##############################################################################

=head3 name

  my $name = $app->name;

Returns the name of the application.

=cut

sub name { $croak->(shift, 'name') }

##############################################################################

=head3 version

  my $version = $app->version;

Returns the full version number of the application.

=cut

##############################################################################

sub version { $croak->(shift, 'version') }

=head3 major_version

  my $major_version = $app->major_version;

Returns the major version number of the application. For example, if
C<version()> returns "7.1.2", then this method returns "7".

=cut

sub major_version { $croak->(shift, 'major_version') }

##############################################################################

=head3 minor_version

  my $minor_version = $app->minor_version;

Returns the minor version number of the application. For example, if
C<version()> returns "7.1.2", then this method returns "1".

=cut

sub minor_version { $croak->(shift, 'minor_version') }

##############################################################################

=head3 patch_version

  my $patch_version = $app->patch_version;

Returns the patch version number of the application. For example, if
C<version()> returns "7.1.2", then this method returns "2".

=cut

sub patch_version { $croak->(shift, 'patch_version') }

##############################################################################

=head3 bin_dir

  my $bin_dir = $app->bin_dir;

Returns the full path the application's bin directory, if it exists.

=cut

sub bin_dir { $croak->(shift, 'bin_dir') }

##############################################################################

=head3 inc_dir

  my $inc_dir = $app->inc_dir;

Returns the full path the application's include directory, if it exists.

=cut

sub inc_dir { $croak->(shift, 'inc_dir') }

##############################################################################

=head3 lib_dir

  my $lib_dir = $app->lib_dir;

Returns the full path the application's lib directory, if it exists.

=cut

sub lib_dir { $croak->(shift, 'lib_dir') }

##############################################################################

=head3 so_lib_dir

  my $so_lib_dir = $app->so_lib_dir;

Returns the full path the application's shared library directory, if it
exists.

=cut

sub so_lib_dir { $croak->(shift, 'so_lib_dir') }

##############################################################################

=head3 home_url

  my $home_url = $app->home_url;

The URL for the software's home page.

=cut

sub home_url  { $croak->(shift, 'home_url') }

##############################################################################

=head3 download_url

  my $download_url = $app->download_url;

The URL for the software's download page.

=cut

sub download_url  { $croak->(shift, 'download_url') }

##############################################################################
##############################################################################

=head2 Event Handler Object Methods

These methods provide control over App::Info event handling. Events can be
handled by one or more objects of subclasses of App::Info::Handler. The first
to return a true value will be the last to execute. This approach allows
handlers to be stacked, and makes it relatively easy to create new handlers.
L<App::Info::Handler|App::Info::Handler> for information on writing event
handlers.

Each of the event handler methods takes a list of event handlers as its
arguments. If none are passed, the existing list of handlers for the relevant
event type will be returned. If new handlers are passed in, they will be
returned.

The event handlers may be specified as one or more objects of the
App::Info::Handler class or subclasses, as one or more strings that tell
App::Info construct such handlers itself, or a combination of the two. The
strings can only be used if the relevant App::Info::Handler subclasses have
registered strings with App::Info. For example, the App::Info::Handler::Print
class included in the App::Info distribution registers the strings "stderr"
and "stdout" when it starts up. These strings may then be used to tell
App::Info to construct App::Info::Handler::Print objects that print to STDERR
or to STDOUT, respectively. See the App::Info::Handler subclasses for what
strings they register with App::Info.

=head3 on_info

  my @handlers = $app->on_info;
  $app->on_info(@handlers);

Info events are triggered when the App::Info subclass wants to send an
informational status message. By default, these events are ignored, but a
common need is for such messages to simply print to STDOUT. Use the
L<App::Info::Handler::Print|App::Info::Handler::Print> class included with the
App::Info distribution to have info messages print to STDOUT:

  use App::Info::Handler::Print;
  $app->on_info('stdout');
  # Or:
  my $stdout_handler = App::Info::Handler::Print->new('stdout');
  $app->on_info($stdout_handler);

=cut

sub on_info {
    my $self = shift;
    $self->{on_info} = $set_handlers->(\@_) if @_;
    return @{ $self->{on_info} };
}

=head3 on_error

  my @handlers = $app->on_error;
  $app->on_error(@handlers);

Error events are triggered when the App::Info subclass runs into an unexpected
but not fatal problem. (Note that fatal problems will likely throw an
exception.) By default, these events are ignored. A common way of handling
these events is to print them to STDERR, once again using the
L<App::Info::Handler::Print|App::Info::Handler::Print> class included with the
App::Info distribution:

  use App::Info::Handler::Print;
  my $app->on_error('stderr');
  # Or:
  my $stderr_handler = App::Info::Handler::Print->new('stderr');
  $app->on_error($stderr_handler);

Another approach might be to turn such events into fatal exceptions. Use the
included L<App::Info::Handler::Carp|App::Info::Handler::Carp> class for this
purpose:

  use App::Info::Handler::Carp;
  my $app->on_error('croak');
  # Or:
  my $croaker = App::Info::Handler::Carp->new('croak');
  $app->on_error($croaker);

=cut

sub on_error {
    my $self = shift;
    $self->{on_error} = $set_handlers->(\@_) if @_;
    return @{ $self->{on_error} };
}

=head3 on_unknown

  my @handlers = $app->on_unknown;
  $app->on_uknown(@handlers);

Unknown events are trigged when the App::Info subclass cannot find the value
to be returned by a method call. By default, these events are ignored. A
common way of handling them is to have the application prompt the user for the
relevant data. The App::Info::Handler::Prompt class included with the
App::Info distribution can do just that:

  use App::Info::Handler::Prompt;
  my $app->on_unknown('prompt');
  # Or:
  my $prompter = App::Info::Handler::Prompt;
  $app->on_unknown($prompter);

See L<App::Info::Handler::Prompt|App::Info::Handler::Prompt> for information
on how it works.

=cut

sub on_unknown {
    my $self = shift;
    $self->{on_unknown} = $set_handlers->(\@_) if @_;
    return @{ $self->{on_unknown} };
}

=head3 on_confirm

  my @handlers = $app->on_confirm;
  $app->on_confirm(@handlers);

Confirm events are triggered when the App::Info subclass has found an
important piece of information (such as the location of the executable it'll
use to collect information for the rest of its methods) and wants to confirm
that the information is correct. These events will most often be triggered
during the App::Info subclass object construction. Here, too, the
App::Info::Handler::Prompt class included with the App::Info distribution can
help out:

  use App::Info::Handler::Prompt;
  my $app->on_confirm('prompt');
  # Or:
  my $prompter = App::Info::Handler::Prompt;
  $app->on_confirm($prompter);

=cut

sub on_confirm {
    my $self = shift;
    $self->{on_confirm} = $set_handlers->(\@_) if @_;
    return @{ $self->{on_confirm} };
}

##############################################################################
##############################################################################

=head1 SUBCLASSING

As an abstract base class, App::Info is not intended to be used directly.
Instead, you'll use concrete subclasses that implement the interface it
defines. These subclasses each provide the metadata necessary for a given
software package, via the interface outlined above (plus any additional
methods the class author deems sensible for a given application).

This section describes the facilities App::Info provides for subclassing. The
goal of the App::Info design has been to make subclassing straight-forward, so
that developers can focus on gathering the data they need for their
application and minimize the work necessary to handle unknown values or to
confirm values. As a result, there are essentially three concepts that
developers need to understand when subclassing App::Info: organization,
utility methods, and events.

=head2 Organization

The organizational idea behind App::Info is to name subclasses by broad
software categories. This approach allows the categories themselves to
function as abstract base classes that extend App::Info, so that they can
specify more methods for all of their base classes to implement. For example,
App::Info::HTTPD has specified the C<httpd_root()> abstract method that its
subclasses must implement. So as you get ready to implement your own subclass,
think about what category of software you're gathering information about.
New categories can be added as necessary.

=head2 Utility Methods

Once you've decided on the proper category, you can start implementing your
App::Info concrete subclass. As you do so, take advantage of App::Info::Util,
wherein I've tried to encapsulate common functionality to make subclassing
easier. I found that most of what I was doing repetitively was looking for
files and directories, and searching through files. Thus, App::Info::Util
subclasses L<File::Spec|File::Spec> in order to offer easy access to
commonly-used methods from that class, e.g., C<path()>. Plus, it has several
of its own methods to assist you in finding files and directories in lists of
files and directories, as well as methods for searching through files and
returning the values found in those files. See
L<App::Info::Util|App::Info::Util> for more information, and the App::Info
subclasses in this distribution for usage examples.

I recommend the use of a package-scoped lexical App::Info::Util object. That
way it's nice and handy when you need to carry out common tasks. If you find
you're doing something over and over that's not already addressed by an
App::Info::Util method, consider submitting a patch to App::Info::Util to add
the functionality you need.

=head2 Events

Use the methods described below to trigger events. Events are designed to
provide a simple way for App::Info subclass developers to send status messages
and errors, to confirm data values, and to request a value when the class
caonnot determine a value itself. Events may optionally be handled by module
users who assign App::Info::Handler subclass objects to your App::Info
subclass object using the event handling methods described in the L<"Event
Handler Object Methods"> section.

=cut

##############################################################################
# This code reference is used by the event methods to manage the stack of
# event handlers that may be available to handle each of the events.
my $handler = sub {
    my ($self, $meth, $params) = @_;

    # Sanity check. We really want to keep control over this.
    Carp::croak("Cannot call protected method $meth()")
      unless UNIVERSAL::isa($self, scalar caller(1));

    # Create the request object.
    $params->{type} ||= $meth;
    my $req = App::Info::Request->new(%$params);

    # Do the deed. The ultimate handling handler may die.
    foreach my $eh (@{$self->{"on_$meth"}}) {
        last if $eh->handler($req);
    }

    # Return the requst.
    return $req;
};

##############################################################################

=head3 info

  $self->info(@message);

Use this method to display status messages for the user. You may wish to use
it to inform users that you're searching for a particular file, or attempting
to parse a file or some other resource for the data you need. For example, a
common use might be in the object constructor: generally, when an App::Info
object is created, some important initial piece of information is being
sought, such as an executable file. That file may be in one of many locations,
so it makes sense to let the user know that you're looking for it:

  $self->info("Searching for executable");

Note that, due to the nature of App::Info event handlers, your informational
message may be used or displayed any number of ways, or indeed not at all (as
is the default behavior).

The C<@message> will be joined into a single string and stored in the
C<message> attribute of the App::Info::Request object passed to info event
handlers.

=cut

sub info {
    my $self = shift;
    # Execute the handler sequence.
    my $req = $handler->($self, 'info', { message => join '', @_ });
}

##############################################################################

=head3 error

  $self->error(@error);

Use this method to inform the user that something unexpected has happened. An
example might be when you invoke another program to parse its output, but it's
output isn't what you expected:

  $self->error("Unable to parse version from `/bin/myapp -c`");

As with all events, keep in mind that error events may be handled in any
number of ways, or not at all.

The C<@erorr> will be joined into a single string and stored in the C<message>
attribute of the App::Info::Request object passed to error event handlers. If
that seems confusing, think of it as an "error message" rather than an "error
error." :-)

=cut

sub error {
    my $self = shift;
    # Execute the handler sequence.
    my $req = $handler->($self, 'error', { message => join '', @_ });
}

##############################################################################

=head3 unknown

  my $val = $self->unknown(@params);

Use this method when a value is unknown. This will give the user the option --
assuming the appropriate handler handles the event -- to provide the needed
data. The value entered will be returned by C<unknown()>. The parameters are
as follows:

=over 4

=item key

The C<key> parameter uniquely identifies the data point in your class, and is
used by App::Info to ensure that an unknown event is handled only once, no
matter how many times the method is called. The same value will be returned by
subsequent calls to C<unknown()> as was returned by the first call, and no
handlers will be activated. Typical values are "version" and "lib_dir".

=item prompt

The C<prompt> parameter is the prompt to be displayed should an event handler
decide to prompt for the appropriate value. Such a prompt might be something
like "Path to your httpd executable?". If this parameter is not provided,
App::Info will construct one for you using your class' C<key_name()> method
and the C<key> parameter. The result would be something like "Enter a valid
FooApp version". The C<prompt> parameter value will be stored in the
C<message> attribute of the App::Info::Request object passed to event
handlers.

=item callback

Assuming a handler has collected a value for your unknown data point, it might
make sense to validate the value. For example, if you prompt the user for a
directory location, and the user enters one, it makes sense to ensure that the
directory actually exists. The C<callback> parameter allows you to do this. It
is a code reference that takes the new value or values as its arguments, and
returns true if the value is valid, and false if it is not. For the sake of
convenience, the first argument to the callback code reference is also stored
in C<$_> .This makes it easy to validate using functions or operators that,
er, operate on C<$_> by default, but still allows you to get more information
from C<@_> if necessary. For the directory example, a good callback might be
C<sub { -d }>. The C<callback> parameter code reference will be stored in the
C<callback> attribute of the App::Info::Request object passed to event
handlers.

=item error

The error parameter is the error message to display in the event that the
C<callback> code reference returns false. This message may then be used by the
event handler to let the user know what went wrong with the data she entered.
For example, if the unknown value was a directory, and the user entered a
value that the C<callback> identified as invalid, a message to display might
be something like "Invalid directory path". Note that if the C<error>
parameter is not provided, App::Info will supply the generic error message
"Invalid value". This value will be stored in the C<error> attribute of the
App::Info::Request object passed to event handlers.

=back

This may be the event method you use most, as it should be called in every
metadata method if you cannot provide the data needed by that method. It will
typically be the last part of the method. Here's an example demonstrating each
of the above arguments:

  my $dir = $self->unknown( key      => 'lib_dir',
                            prompt   => "Enter lib directory path",
                            callback => sub { -d },
                            error    => "Not a directory");

=cut

sub unknown {
    my ($self, %params) = @_;
    my $key = delete $params{key}
      or Carp::croak("No key parameter passed to unknown()");
    # Just return the value if we've already handled this value. Ideally this
    # shouldn't happen.
    return $self->{__unknown__}{$key} if exists $self->{__unknown__}{$key};

    # Create a prompt and error message, if necessary.
    $params{message} = delete $params{prompt} ||
      "Enter a valid " . $self->key_name . " $key";
    $params{error} ||= 'Invalid value';

    # Execute the handler sequence.
    my $req = $handler->($self, "unknown", \%params);

    # Mark that we've provided this value and then return it.
    $self->{__unknown__}{$key} = $req->value;
    return $self->{__unknown__}{$key};
}

##############################################################################

=head3 confirm

  my $val = $self->confirm(@params);

This method is very similar to C<unknown()>, but serves a different purpose.
Use this method for significant data points where you've found an appropriate
value, but want to ensure it's really the correct value. A "significant data
point" is usually a value essential for your class to collect metadata values.
For example, you might need to locate an executable that you can then call to
collect other data. In general, this will only happen once for an object --
during object construction -- but there may be cases in which it is needed
more than that. But hopefully, once you've confirmed in the constructor that
you've found what you need, you can use that information to collect the data
needed by all of the metadata methods and can assume that they'll be right
because that first, significant data point has been confirmed.

Other than where and how often to call C<confirm()>, its use is quite similar
to that of C<unknown()>. Its parameters are as follows:

=over

=item key

Same as for C<unknown()>, a string that uniquely identifies the data point in
your class, and ensures that the event is handled only once for a given key.
The same value will be returned by subsequent calls to C<confirm()> as was
returned by the first call for a given key.

=item prompt

Same as for C<unknown()>. Although C<confirm()> is called to confirm a value,
typically the prompt should request the relevant value, just as for
C<unknown()>. The difference is that the handler I<should> use the C<value>
parameter as the default should the user not provide a value. The C<prompt>
parameter will be stored in the C<message> attribute of the App::Info::Request
object passed to event handlers.

=item value

The value to be confirmed. This is the value you've found, and it will be
provided to the user as the default option when they're prompted for a new
value. This value will be stored in the C<value> attribute of the
App::Info::Request object passed to event handlers.

=item callback

Same as for C<unknown()>. Because the user can enter data to replace the
default value provided via the C<value> parameter, you might want to validate
it. Use this code reference to do so. The callback will be stored in the
C<callback> attribute of the App::Info::Request object passed to event
handlers.

=item error

Same as for C<unknown()>: an error message to display in the event that a
value entered by the user isn't validated by the C<callback> code reference.
This value will be stored in the C<error> attribute of the App::Info::Request
object passed to event handlers.

=back

Here's an example usage demonstrating all of the above arguments:

  my $exe = $self->confirm( key      => 'shell',
                            prompt   => 'Path to your shell?',
                            value    => '/bin/sh',
                            callback => sub { -x },
                            error    => 'Not an executable');


=cut

sub confirm {
    my ($self, %params) = @_;
    my $key = delete $params{key}
      or Carp::croak("No key parameter passed to confirm()");
    return $self->{__confirm__}{$key} if exists $self->{__confirm__}{$key};

    # Create a prompt and error message, if necessary.
    $params{message} = delete $params{prompt} ||
      "Enter a valid " . $self->key_name . " $key";
    $params{error} ||= 'Invalid value';

    # Execute the handler sequence.
    my $req = $handler->($self, "confirm", \%params);

    # Mark that we've confirmed this value.
    $self->{__confirm__}{$key} = $req->value;

    return $self->{__confirm__}{$key}
}

1;
__END__

=head2 Event Examples

Below I provide some examples demonstrating the use of the event methods.
These are meant to emphasize the contexts in which it's appropriate to use
them.

Let's start with the simplest, first. Let's say that to find the version
number for an application, you need to search a file for the relevant data.
Your App::Info concrete subclass might have a private method that handles this
work, and this method is the appropriate place to use the C<info()> and, if
necessary, C<error()> methods.

  sub _find_version {
      my $self = shift;

      # Try to find the revelant file. We cover this method below.
      # Just return if we cant' find it.
      my $file = $self->_find_file('version.conf') or return;

      # Send a status message.
      $self->info("Searching '$file' file for version");

      # Search the file. $util is an App::Info::Util object.
      my $ver = $util->search_file($file, qr/^Version\s+(.*)$/);

      # Trigger an error message, if necessary. We really think we'll have the
      # value, but we have to cover our butts in the unlikely event that we're
      # wrong.
      $self->error("Unable to find version in file '$file'") unless $ver;

      # Return the version number.
      return $ver;
  }

Here we've used the C<info()> method to display a status message to let the
user know what we're doing. Then we used the C<error()> method when something
unexpected happened, which in this case was that we weren't able to find the
version number in the file.

Note the C<_find_file()> method we've thrown in. This might be a method that
we call whenever we need to find a file that might be in one of a list of
directories. This method, too, will be an appropriate place for an C<info()>
method call. But rather than call the C<error()> method when the file can't be
found, you might want to give an event handler a chance to supply that value
for you. Use the C<unknown()> method for a case such as this:

  sub _find_file {
      my ($self, $file) = @_;

      # Send a status message.
      $self->info("Searching for '$file' file");

      # Look for the file. See App::Info:Utility for its interface.
      my @paths = qw(/usr/conf /etc/conf /foo/conf);
      my $found = $util->first_cat_path($file, @paths);

      # If we didn't find it, trigger an unknown event to
      # give a handler a chance to get the value.
      $found ||= $self->unknown( key      => "file_$file",
                                 prompt   => "Location of '$file' file?",
                                 callback => sub { -f },
                                 error    => "Not a file");

      # Now return the file name, regardless of whether we found it or not.
      return $found;
  }

Note how in this method, we've tried to locate the file ourselves, but if we
can't find it, we trigger an unknown event. This allows clients of our
App::Info subclass to try to establish the value themselves by having an
App::Info::Handler subclass handle the event. If a value is found by an
App::Info::Handler subclass, it will be returned by C<unknown()> and we can
continue. But we can't assume that the unknown event will even be handled, and
thus must expect that an unknown value may remain unknown. This is why the
C<_find_version()> method above simply returns if C<_find_file()> doesn't
return a file name; there's no point in searching through a file that doesn't
exist.

Attentive readers may be left to wonder how to decide when to use C<error()>
and when to use C<unknown()>. To a large extent, this decision must be based
on one's own understanding of what's most appropriate. Nevertheless, I offer
the following simple guidelines: Use C<error()> when you expect something to
work and then it just doesn't (as when a file exists and should contain the
information you seek, but then doesn't). Use C<unknown()> when you're less
sure of your processes for finding the value, and also for any of the values
that should be returned by any of the L<metadata object methods|"Metadata
Object Methods">. And of course, C<error()> would be more appropriate when you
encounter an unexpected condition and don't think that it could be handled in
any other way.

Now, more than likely, a method such C<_find_version()> would be called by the
C<version()> method, which is a metadata method mandated by the App::Info
abstract base class. This is an appropriate place to handle an unknown version
value. Indeed, every one of your metadata methods should make use of the
C<unknown()> method. The C<version()> method then should look something like
this:

  sub version {
      my $self = shift;

      unless (exists $self->{version}) {
          # Try to find the version number.
          $self->{version} = $self->_find_version ||
            $self->unknown( key    => 'version',
                            prompt => "Enter the version number");
      }

      # Now return the version number.
      return $self->{version};
  }

Note how this method only tries to find the version number once. Any
subsequent calls to C<version()> will return the same value that was returned
the first time it was called. Of course, thanks to the C<key> parameter in the
call to C<unknown()>, we could have have tried to enumerate the version number
every time, as C<unknown()> will return the same value every time it is called
(as, indeed, should C<_find_version()>. But by checking for the C<version> key
in C<$self> ourselves, we save some of the overhead.

But as I said before, every metadata method should make use of the
C<unknown()> method. Thus, the C<major()> method might looks something like
this:

  sub major {
      my $self = shift;

      unless (exists $self->{major}) {
          # Try to get the major version from the full version number.
          ($self->{major}) = $self->version =~ /^(\d+)\./;
          # Handle an unknown value.
          $self->{major} = $self->unknown( key      => 'major',
                                           prompt   => "Enter major version",
                                           callback => sub { /^\d+$/ },
                                           error    => "Not a number")
            unless defined $self->{major};
      }

      return $self->{version};
  }

Finally, the C<confirm()> method should be used to verify core pieces of data
that significant numbers of other methods rely on. Typically such data are
executables or configuration files from which will be drawn other metadata.
Most often, such major data points will be sought in the object constructor.
Here's an example:

  sub new {
      # Construct the object so that handlers will work properly.
      my $self = shift->SUPER::new(@_);

      # Try to find the executable.
      $self->info("Searching for executable");
      if (my $exe = $util->first_exe('/bin/myapp', '/usr/bin/myapp')) {
          # Confirm it.
          $self->{exe} =
            $self->confirm( key      => 'binary',
                            prompt   => 'Path to your executable?',
                            value    => $exe,
                            callback => sub { -x },
                            error    => 'Not an executable');
      } else {
          # Handle an unknown value.
          $self->{exe} =
            $self->unknown( key      => 'binary',
                            prompt   => 'Path to your executable?',
                            callback => sub { -x },
                            error    => 'Not an executable');
      }

      # We're done.
      return $self;
  }

By now, most of what's going on here should be quite familiar. The use of the
C<confirm()> method is quite similar to that of C<unknown()>. Really the only
difference is that the value is known, but we need verification or a new value
supplied if the value we found isn't correct. Such may be the case when
multiple copies of the executable have been installed on the system, we found
F</bin/myapp>, but the user may really be interested in F</usr/bin/myapp>.
Thus the C<confirm()> event gives the user the chance to change the value if
the confirm event is handled.

The final thing to note about this constructor is the first line:

  my $self = shift->SUPER::new(@_);

The first thing an App::Info subclass should do is execute this line to allow
the super class to construct the object first. Doing so allows any event
handling arguments to set up the event handlers, so that when we call
C<confirm()> or C<unknown()> the event will be handled as the client expects.

If we needed our subclass constructor to take its own parameter argumente, the
approach is to specify the same C<key => $arg> syntax as is used by
App::Info's C<new()> method. Say we wanted to allow clients of our App::Info
subclass to pass in a list of alternate executable locations for us to search.
Such an argument would most make sense as an array reference. So we specify
that the key be C<alt_paths> and allow the user to construct an object like
this:

  my $app = App::Info::Category::FooApp->new( alt_paths => \@paths );

This approach allows the super class constructor arguments to pass unmolested
(as long as we use unique keys!):

  my $app = App::Info::Category::FooApp->new( on_error  => \@handlers,
                                              alt_paths => \@paths );

Then, to retrieve these paths inside our C<new()> constructor, all we need do
is access them directly from the object:

  my $self = shift->SUPER::new(@_);
  my $alt_paths = $self->{alt_paths};

=head2 Subclassing Guidelines

To summarize, here are some guidelines for subclassing App::Info.

=over 4

=item *

Always subclass an App::Info category subclass. This will help to keep the
App::Info namespace well-organized. New categories can be added as needed.

=item *

When you create the C<new()> constructor, always call C<SUPER::new(@_)>. This
ensures that the event handling methods methods defined by the App::Info base
classes (e.g., C<error()>) will work properly.

=item *

Use a package-scoped lexical App::Info::Util object to carry out common tasks.
If you find you're doing something over and over that's not already addressed
by an App::Info::Util method, and you think that others might find your
solution useful, consider submitting a patch to App::Info::Util to add the
functionality you need. See L<App::Info::Util|App::Info::Util> for complete
documentation of its interface.

=item *

Use the C<info()> event triggering method to send messages to users of your
subclass.

=item *

Use the C<error()> event triggering method to alert users of unexpected
conditions. Fatal errors should still be fatal; use C<Carp::croak()> to throw
exceptions for fatal errors.

=item *

Use the C<unknown()> event triggering method when a metadata or other
important value is unknown and you want to give any event handlers the chance
to provide the data.

=item *

Use the C<confirm()> event triggering method when a core piece of data is
known (such as the location of an executable in the C<new()> constructor) and
you need to make sure that you have the I<correct> information.

=item *

Be sure to implement B<all> of the abstract methods defined by App::Info and
by your category abstract base class -- even if they don't do anything. Doing
so ensures that all App::Info subclasses share a common interface, and can, if
necessary, be used without regard to subclass. Any method not implemented but
called on an object will generate a fatal exception.

=back

Otherwise, have fun! There are a lot of software packages for which relevant
information might be collected and aggregated into an App::Info concrete
subclass (witness all of the Automake macros in the world!), and folks who are
knowledgeable about particular software packages or categories of software are
warmly invited to contribute. As more subclasses are implemented, it will make
sense, I think, to create separate distributions based on category -- or even,
when necessary, on a single software package. Broader categories can then be
aggregated in Bundle distributions.

But I get ahead of myself...

=head1 BUGS

Report all bugs via the CPAN Request Tracker at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Info>.

=head1 AUTHOR

David Wheeler <L<david@wheeler.net|"david@wheeler.net">>

=head1 SEE ALSO

The following classes define a few software package categories in which
App::Info subclasses can be placed. Check them out for ideas on how to
create new category subclasses.

=over 4

=item L<App::Info::HTTP|App::Info::HTTPD>

=item L<App::Info::RDBMS|App::Info::RDBMS>

=item L<App::Info::Lib|App::Info::Lib>

=back

The following classes implement the App::Info interface for various software
packages. Check them out for examples of how to implement new App::Info
concrete subclasses.

=over

=item L<App::Info::HTTPD::Apache|App::Info::HTTPD::Apache>

=item L<App::Info::RDBMS::PostgreSQL|App::Info::RDBMS::PostgreSQL>

=item L<App::Info::Lib::Expat|App::Info::Lib::Expat>

=item L<App::Info::Lib::Iconv|App::Info::Lib::Iconv>

=back

L<App::Info::Util|App::Info::Util> provides utility methods for App::Info
subclasses.

L<App::Info::Handler|App::Info::Handler> defines an interface for event
handlers to subclass. Consult its documentation for information on creating
custom event handlers.

The following classes implement the App::Info::Handler interface to offer some
simple event handling. Check them out for examples of how to implement new
App::Info::Handler subclasses.

=over 4

=item L<App::Info::Handler::Print|App::Info::Handler::Print>

=item L<App::Info::Handler::Carp|App::Info::Handler::Carp>

=item L<App::Info::Handler::Prompt|App::Info::Handler::Prompt>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002, David Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
