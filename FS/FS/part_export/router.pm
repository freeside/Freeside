package FS::part_export::router;

=head1 FS::part_export::router

This export connects to a router and transmits commands via telnet or SSH.
It requires the following custom router fields:

=head1 Required custom fields

=over 4

=item admin_address - IP address (or hostname) to connect.

=item admin_user - Username for the router.

=item admin_password - Password for the  router.

=item admin_protocol - Protocol to use for the router.  'telnet' or 'ssh'.  The ssh protocol only support password-less (ie. RSA key) authentication.  As such, the admin_password field isn't used if ssh is specified.

=item admin_timeout - Time in seconds to wait for a connection.

=item admin_prompt - A regular expression matching the router's prompt.  See Net::Telnet for details.  Only applies to the 'telnet' protocol.

=item admin_cmd_insert - Insert export command.

=item admin_cmd_insert_error - Insert export command error pattern.

=item admin_cmd_delete - Delete export command.

=item admin_cmd_delete_error - Delete export command error pattern.

=item admin_cmd_replace - Replace export command.

=item admin_cmd_replace_error - Replace export command error pattern.

=item admin_cmd_suspend - Suspend export command.

=item admin_cmd_suspend_error - Support export command error pattern.

=item admin_cmd_unsuspend - Unsuspend export command.

=item admin_cmd_unsuspend_error - Unsuspend export command error pattern.

The admin_cmd_* virtual fields, if set, will be processed in one of two ways.  After being expanded, they will be run on the router specified by admin_address using the protocol specified by admin_protocol.

=over 4

=item Text::Template

If the export command contains the string [@--, then it will be processed with Text::Template using [@-- and --@] as delimeters.

=item eval

If the export command does not contain [@--, it will be double quoted and eval'd.

=back

The admin_cmd_*_error virtual fields, if set, define a regular expression that will be matched against the output of the command being run.  If the pattern matches, an error will be raised using the output as the error.

If any of the required router virtual fields are not defined, then the export silently declines.

=back

The export itself takes no options.

=cut

use strict;
use vars qw(@ISA %info $me $DEBUG);
use Tie::IxHash;
use Text::Template;

use FS::Record qw(qsearchs);
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'protocol' => {
	  label=>'Protocol',
	  type =>'select',
	  options => [qw(telnet ssh)],
	  default => 'telnet'},
;

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'Send a command to a router.',
  'options' => \%options,
  'notes'   => 'Installation of Net::Telnet from CPAN is required for telnet connections.  This export will execute if the following virtual fields are set on the router: admin_user, admin_password, admin_address, admin_timeout, admin_prompt.  Option virtual fields are: admin_cmd_insert, admin_cmd_replace, admin_cmd_delete, admin_cmd_suspend, admin_cmd_unsuspend.  See the module documentation for a full list of required/supported router virtual fields.',
);

$me = '[' . __PACKAGE__ . ']';
$DEBUG = 1;


sub rebless { shift; }

sub _field_prefix { 'admin'; }

sub _req_router_fields {
  map {
    $_[0]->_field_prefix . '_' . $_
  } (qw(address prompt user));
}

sub _export_insert {
  my($self) = shift;
  warn "Running insert for " . ref($self);
  $self->_export_command('insert', @_);
}

sub _export_delete {
  my($self) = shift;
  $self->_export_command('delete', @_);
}

sub _export_suspend {
  my($self) = shift;
  $self->_export_command('suspend', @_);
}

sub _export_unsuspend {
  my($self) = shift;
  $self->_export_command('unsuspend', @_);
}

sub _export_replace {
  my($self) = shift;
  $self->_export_command('replace', @_);
}

sub _export_command {
  my ($self, $action, $svc_broadband) = (shift, shift, shift);
  my ($error, $old);
  
  if ($action eq 'replace') {
    $old = shift;
  }

 warn "[debug]$me Processing action '$action'" if $DEBUG;

  # fetch router info
  my $router = $self->_get_router($svc_broadband, @_);
  unless ($router) {
    return "Unable to lookup router for $action export";
  }

  unless ($self->_check_router_fields($router)) {
    # Virtual fields aren't defined.  Exit silently.
    warn "[debug]$me Required router virtual fields not defined.  Returning..."
      if $DEBUG;
    return '';
  }

  my $args;
  ($error, $args) = $self->_prepare_args(
    $action,
    $router,
    $svc_broadband,
    ($old ? $old : ()),
    @_
  );

  if ($error) {
    # Error occured while preparing args.
    return $error;
  } elsif (not defined $args) {
    # Silently decline.
    warn "[debug]$me Declining '$action' export" if $DEBUG;
    return '';
  } # else ... queue the export.

  warn "[debug]$me Queueing with args: " . join(', ', @$args) if $DEBUG;

  return(
    $self->_queue(
      $svc_broadband->svcnum,
      $self->_get_cmd_sub($svc_broadband, $router),
      @$args
    )
  );

}

sub _prepare_args {

  my ($self, $action, $router, $svc_broadband) = (shift, shift, shift, shift);
  my $old = shift if ($action eq 'replace');
  my $error = '';

  my $field_prefix = $self->_field_prefix;
  my $command = $router->getfield("${field_prefix}_cmd_${action}");
  unless ($command) {
    warn "[debug]$me router custom field '${field_prefix}_cmd_$action' "
      . "is not defined." if $DEBUG;
    return '';
  }

  if ($command =~ /\[\@--/) { # Use Text::Template

    my $template_data = {};

    if ($action eq 'replace') {
      $template_data->{"old_$_"} = $old->getfield($_) foreach $old->fields;
      $template_data->{"new_$_"} = $svc_broadband->getfield($_)
        foreach $svc_broadband->fields;
    } else {
      $template_data->{$_} = $svc_broadband->getfield($_)
        foreach $svc_broadband->fields;
    }

    my $template = new Text::Template (
      TYPE => 'STRING',
      SOURCE => $command,
      DELIMITERS => [ '[@--', '--@]' ],
    ) or return "Unable to construct template for router command: "
                . $Text::Template::ERROR;

    $command = $template->fill_in(
      HASH => $template_data,
      BROKEN_ARG => \$error,
      BROKEN => sub {
        my %bargs = @_;
        my $err = $bargs{'arg'};
        $$err = $bargs{'error'};
        return undef;
      },
    );

    if (not defined $command or $error) {
      $error ||= $Text::Template::ERROR;
      return "Unable to fill-in template for router command: $error";
    }

  } else { # Use eval
    no strict 'vars';
    no strict 'refs';

    if ($action eq 'replace') {
      ${"old_$_"} = $old->getfield($_) foreach $old->fields;
      ${"new_$_"} = $svc_broadband->getfield($_) foreach $svc_broadband->fields;
      $command = eval(qq("$command"));
    } else {
      ${$_} = $svc_broadband->getfield($_) foreach $svc_broadband->fields;
      $command = eval(qq("$command"));
    }
    return $@ if $@;
  }

  my $args = [
    'user' => $router->getfield($field_prefix . '_user'),
    'password' => $router->getfield($field_prefix . '_password'),
    'host' => $router->getfield($field_prefix . '_address'),
    'Timeout' => $router->getfield($field_prefix . '_timeout'),
    'Prompt' => $router->getfield($field_prefix . '_prompt'),
    'command' => $command,
  ];

  my $error_check = $router->getfield("${field_prefix}_cmd_${action}_error");
  push(@$args, ('error_check' => $error_check)) if ($error_check);

  return('', $args);

}

sub _get_cmd_sub {

  my ($self, $svc_broadband, $router) = (shift, shift, shift);

  my $protocol = (
    $router->getfield($self->_field_prefix . '_protocol') =~ /^(telnet|ssh)$/
  ) ? $1 : 'telnet';

  return(ref($self)."::".$protocol."_cmd");

}

sub _check_router_fields {

  my ($self, $router, $action) = (shift, shift, shift);
  my @check_fields = $self->_req_router_fields;

  foreach (@check_fields) {
    if ($router->getfield($_) eq '') {
      warn "[debug]$me Required field '$_' is unset" if $DEBUG;
      return 0;
    } else {
      return 1;
    }
  }

}

sub _queue {
  my( $self, $svcnum, $cmd_sub ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
  };
  $queue->job($cmd_sub);
  $queue->insert(@_);
}

sub _get_router {
  my ($self, $svc_broadband, %args) = (shift, shift, @_);

  my $router;
  if ($args{'routernum'}) {
    $router = qsearchs('router', { routernum => $args{'routernum'}});
  } else {
    $router = $svc_broadband->router;
  }

  return($router);

}


# Subroutines
sub ssh_cmd {
  my %arg = @_;

  eval 'use Net::SSH \'0.08\'';
  die $@ if $@;

  my @out = &Net::SSH::ssh_cmd( { @_ } );
  my $error = &_cmd_error_check(\%arg, \@out);

  die ("Error while processing ssh command: $error") if $error;

  return '';

}

sub telnet_cmd {
  my %arg = @_;

  eval 'use Net::Telnet';
  die $@ if $@;

  my $t = new Net::Telnet (Timeout => $arg{'Timeout'},
                           Prompt  => $arg{'Prompt'});
  $t->open($arg{'host'});
  $t->login($arg{'user'}, $arg{'password'});
  my @out  = $t->cmd($arg{'command'});
  my $error = &_cmd_error_check(\%arg, \@out);

  die ("Error while processing telnet command: $error") if $error;

  return '';

}

sub _cmd_error_check {
  my ($arg, $out) = (shift, shift);

  die "_cmd_error_check called without proper arguments"
    unless (ref($arg) eq 'HASH' and ref($out) eq 'ARRAY');

  unless (exists($arg->{'error_check'}) and $arg->{'error_check'} ne '') {
    #Preserve default behaviour and return output if a check isn't defined.
    warn "Output from router command: " . join('', @$out) if $DEBUG;
    return '';
  }

  my $error_check = $arg->{'error_check'};
  foreach (@$out) {
    return $_ if /$error_check/;
  }

  return '';

}

1;
