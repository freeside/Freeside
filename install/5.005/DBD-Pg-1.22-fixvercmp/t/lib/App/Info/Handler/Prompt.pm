package App::Info::Handler::Prompt;

# $Id: Prompt.pm,v 1.1 2004-04-29 09:21:29 ivan Exp $

=head1 NAME

App::Info::Handler::Prompt - Prompting App::Info event handler

=head1 SYNOPSIS

  use App::Info::Category::FooApp;
  use App::Info::Handler::Print;

  my $prompter = App::Info::Handler::Print->new;
  my $app = App::Info::Category::FooApp->new( on_unknown => $prompter );

  # Or...
  my $app = App::Info::Category::FooApp->new( on_confirm => 'prompt' );

=head1 DESCRIPTION

App::Info::Handler::Prompt objects handle App::Info events by printing their
messages to C<STDOUT> and then accepting a new value from C<STDIN>. The new
value is validated by any callback supplied by the App::Info concrete subclass
that triggered the event. If the value is valid, App::Info::Handler::Prompt
assigns the new value to the event request. If it isn't it prints the error
message associated with the event request, and then prompts for the data
again.

Although designed with unknown and confirm events in mind,
App::Info::Handler::Prompt handles info and error events as well. It will
simply print info event messages to C<STDOUT> and print error event messages
to C<STDERR>. For more interesting info and error event handling, see
L<App::Info::Handler::Print|App::Info::Handler::Print> and
L<App::Info::Handler::Carp|App::Info::Handler::Carp>.

Upon loading, App::Info::Handler::Print registers itself with
App::Info::Handler, setting up a single string, "prompt", that can be passed
to an App::Info concrete subclass constructor. This string is a shortcut that
tells App::Info how to create an App::Info::Handler::Print object for handling
events.

=cut

use strict;
use App::Info::Handler;
use vars qw($VERSION @ISA);
$VERSION = '0.22';
@ISA = qw(App::Info::Handler);

# Register ourselves.
App::Info::Handler->register_handler
  ('prompt' => sub { __PACKAGE__->new('prompt') } );

=head1 INTERFACE

=head2 Constructor

=head3 new

  my $prompter = App::Info::Handler::Prompt->new;

Constructs a new App::Info::Handler::Prompt object and returns it. No special
arguments are required.

=cut

sub new {
    my $pkg = shift;
    my $self = $pkg->SUPER::new(@_);
    $self->{tty} = -t STDIN && ( -t STDOUT || !( -f STDOUT || -c STDOUT ) );
    # We're done!
    return $self;
}

my $get_ans = sub {
    my ($prompt, $tty, $def) = @_;
    # Print the message.
    local $| = 1;
    local $\;
    print $prompt;

    # Collect the answer.
    my $ans;
    if ($tty) {
        $ans = <STDIN>;
        if (defined $ans ) {
            chomp $ans;
        } else { # user hit ctrl-D
            print "\n";
        }
    } else {
        print "$def\n" if defined $def;
    }
    return $ans;
};

sub handler {
    my ($self, $req) = @_;
    my $ans;
    my $type = $req->type;
    if ($type eq 'unknown' || $type eq 'confirm') {
        # We'll want to prompt for a new value.
        my $val = $req->value;
        my ($def, $dispdef) = defined $val ? ($val, " [$val] ") : ('', ' ');
        my $msg = $req->message or Carp::croak("No message in request");
        $msg .= $dispdef;

        # Get the answer.
        $ans = $get_ans->($msg, $self->{tty}, $def);
        # Just return if they entered an empty string or we couldnt' get an
        # answer.
        return 1 unless defined $ans && $ans ne '';

        # Validate the answer.
        my $err = $req->error;
        while (!$req->value($ans)) {
            print "$err: '$ans'\n";
            $ans = $get_ans->($msg, $self->{tty}, $def);
            return 1 unless defined $ans && $ans ne '';
        }

    } elsif ($type eq 'info') {
        # Just print the message.
        print STDOUT $req->message, "\n";
    } elsif ($type eq 'error') {
        # Just print the message.
        print STDERR $req->message, "\n";
    } else {
        # This shouldn't happen.
        Carp::croak("Invalid request type '$type'");
    }

    # Return true to indicate that we've handled the request.
    return 1;
}

1;
__END__

=head1 BUGS

Report all bugs via the CPAN Request Tracker at
L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Info>.

=head1 AUTHOR

David Wheeler <L<david@wheeler.net|"david@wheeler.net">>

=head1 SEE ALSO

L<App::Info|App::Info> documents the event handling interface.

L<App::Info::Handler::Carp|App::Info::Handler::Carp> handles events by
passing their messages Carp module functions.

L<App::Info::Handler::Print|App::Info::Handler::Print> handles events by
printing their messages to a file handle.

L<App::Info::Handler|App::Info::Handler> describes how to implement custom
App::Info event handlers.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2002, David Wheeler. All Rights Reserved.

This module is free software; you can redistribute it and/or modify it under the
same terms as Perl itself.

=cut
