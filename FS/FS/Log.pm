package FS::Log;

use base 'Log::Dispatch';
use FS::Record qw(qsearch qsearchs);
use FS::Conf;
use FS::Log::Output;
use FS::log;
use vars qw(@STACK @LEVELS);

# override the stringification of @_ with something more sensible.
BEGIN {
  @LEVELS = qw(debug info notice warning error critical alert emergency);

  foreach my $l (@LEVELS) {
    my $sub = sub {
      my $self = shift;
      $self->log( level => $l, message => @_ );
    };
    no strict 'refs';
    *{$l} = $sub;
  }
}

=head1 NAME

FS::Log - Freeside event log

=head1 SYNOPSIS

use FS::Log;

sub do_something {
  my $log = FS::Log->new('do_something'); # set log context to 'do_something'

  ...
  if ( $error ) {
    $log->error('something is wrong: '.$error);
    return $error;
  }
  # at this scope exit, do_something is removed from context
}

=head1 DESCRIPTION

FS::Log provides an interface for logging errors and profiling information
to the database.  FS::Log inherits from L<Log::Dispatch>.

=head1 CLASS METHODS

=over 4

new CONTEXT

Constructs and returns a log handle.  CONTEXT must be a known context tag
indicating what activity is going on, such as the name of the function or
script that is executing.

Log context is a stack, and each element is removed from the stack when it
goes out of scope.  So don't keep log handles in persistent places (i.e. 
package variables or class-scoped lexicals).

=cut

sub new {
  my $class = shift;
  my $context = shift;

  my $min_level = FS::Conf->new->config('event_log_level') || 'info';

  my $self = $class->SUPER::new(
    outputs => [ [ '+FS::Log::Output', min_level => $min_level ] ],
  );
  $self->{'index'} = scalar(@STACK);
  push @STACK, $context;
  return $self;
}

=item context

Returns the current context stack.

=cut

sub context { @STACK };

=item log LEVEL, MESSAGE[, OPTIONS ]

Like L<Log::Dispatch::log>, but OPTIONS may include:

- agentnum
- object (an <FS::Record> object to reference in this log message)
- tablename and tablenum (an alternate way of specifying 'object')

=cut

# inherited

sub DESTROY {
  my $self = shift;
  splice(@STACK, $self->{'index'}, 1); # delete the stack entry
}

1;
