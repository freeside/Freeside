package FS::part_export::acct_opensrs;

use strict;
use vars qw( %info $DEBUG );
use base qw( FS::part_export );
use Tie::IxHash;
use Data::Dumper;

tie my %options, 'Tie::IxHash',
  'Environment' => { label    => 'Environment',
                     type     => 'select',
                     options  => [ 'test', 'production' ],
                     default  => 'test'
                   },
  'Domain'      => { label    => 'Administrative domain',
                     type     => 'text',
                   },
  'User'        => { label    => 'Administrative user',
                     type     => 'text',
                   },
  'Password'    => { label    => 'Password',
                     type     => 'text',
                   },
  'Debug'       => { label    => 'Debug level',
                     type     => 'select',
                     options  => [ 0, 1, 2, 3, 4 ],
                   },
;

%info = (
  'svc'     => 'svc_acct',
  'desc'    => 'Configure OpenSRS hosted email services',
  'options' => \%options,
  'no_machine' => 1,
  'notes'   => <<'END'
<p>
Provision email services (POP3/IMAP boxes) through an OpenSRS reseller account.
This requires the <b>Net::OpenSRS::Email_APP</b> library.
</p>
<p>
The <I>Domain</i>, <i>User</i>, and <i>Password</i> accounts are for an
account with company-level admin privileges (or domain-level, if you will
only manage a single domain with each export). <i>Environment</i> determines 
whether to manage test accounts or live email accounts.
</p>
<p>
OpenSRS requires every account to be assigned to a workgroup (within its
domain).  This export will create a workgroup for each service definition,
named "svc" + the I<svcpart> value.  This is somewhat arbitrary and may
change in the future.
</p>
END
);

=head2 METHODS

=item app

Returns a L<Net::OpenSRS::Email_APP> handle to the OpenSRS API.

=cut

sub app {
  my $self = shift;
  $DEBUG ||= $self->option('Debug');
  local $@;
  eval "use Net::OpenSRS::Email_APP";
  if ($@) {
    if ($@ =~ /^Can't locate/) {
      die "Net::OpenSRS::Email_APP must be installed to configure accounts.\n";
    } else {
      die $@;
    }
  }
  my %args = map { $_ => $self->option($_) } qw(
    Environment User Domain Password
  );
  warn "Creating APP session.\n" if $DEBUG;
  warn Dumper \%args if $DEBUG > 1;
  my $app = Net::OpenSRS::Email_APP->new(%args);
  if ($app) {
    $app->debug( $DEBUG - 2 ) if $DEBUG > 2;
    warn "Logging in.\n" if $DEBUG;
    my $error = $app->safe_login;
    return $error || $app;
  }
  return;
}

sub export_insert {
  my $self = shift;
  my $new = shift;
  my $app = $self->app;
  return $app if !ref($app);
  if ($new->isa('FS::svc_acct')) {
    # this may at some point support svc_forward and svc_domain
    my $domain = $new->domain;
    my $username = $new->username;
    warn "Checking mailbox availability: $username\@$domain\n" if $DEBUG;
    my $result = $app->get_mailbox_availability(
      Domain => $domain,
      Mailbox_List => $username,
    );
    if ($app->last_status_code) {
      return $app->last_status_text . ' (checking mailbox availability)';
    }
    if ($result->{AVAILABLE_LIST} eq 'T') {
      return "mailbox unavailable";
    }

    # check existence of workgroup named for the part_svc
    my $svcname = 'svc'.$new->cust_svc->svcpart;
    $result = $app->get_domain_workgroups( Domain => $domain );
    if (! grep {$_->{WORKGROUP} eq $svcname} @$result) {
      warn "Creating workgroup '$svcname'\n" if $DEBUG;
      $result = $app->create_workgroup(
        Domain => $domain,
        Workgroup => $svcname,
      );
      if ($app->last_status_code) {
        return $app->last_status_text . ' (creating workgroup)';
      }
    }
    my %args = $self->mailbox_args($new);
    warn "Creating mailbox\n" if $DEBUG;
    warn Dumper \%args if $DEBUG > 1;
    $result = $app->create_mailbox(%args);
    if ($app->last_status_code) {
      return $app->last_status_text . ' (creating mailbox)';
    }
    return;
  } else {
    return "OpenSRS export doesn't support this service type";
  }
}

sub export_delete {
  my $self = shift;
  my $old = shift;
  my $app = $self->app;
  return $app if !ref($app);
  if ( $old->isa('FS::svc_acct') ) {
    # does it exist?
    my $domain = $old->domain;
    my $username = $old->username;
    warn "Checking existence of mailbox $username\@$domain\n" if $DEBUG;
    my $result = $app->get_mailbox( Domain => $domain, Mailbox => $username );
    if (!$result) {
      warn "Mailbox not found\n" if $DEBUG;
      return; # nothing to delete
    }
    warn "Deleting mailbox\n" if $DEBUG;
    $result = $app->delete_mailbox( Domain => $domain, Mailbox => $username );
    if ($app->last_status_code) {
      return $app->last_status_text . ' (deleting mailbox)';
    }
    return;
  } else {
    return "OpenSRS export doesn't support this service type";
  }
}

sub export_replace {
  my $self = shift;
  my ($new, $old) = @_;
  my $app = $self->app;
  return $app if !ref($app);
  if ($new->isa('FS::svc_acct')) {
    my $domain = $old->domain;
    my $username = $old->username;
    warn "Checking existence of mailbox $username\@$domain\n" if $DEBUG;
    my $result = $app->get_mailbox( Domain => $domain, Mailbox => $username );
    if ($app->last_status_code) {
      return $app->last_status_text . ' (checking existence of mailbox)';
    }
    if (!$result) {
      # then the old mailbox was never created; just handle this as an insert
      return $self->export_insert($new);
    }
    # check validity of the change
    if ($new->domain ne $domain) {
      # OpenSRS doesn't allow moving a mailbox across domains.  We could 
      # delete the old account and create a new one but that risks losing 
      # mail, so we're going to just refuse the request.
      return "can't move mailbox across domains";
    }
    # rename account if necessary
    if ($new->username ne $username) {
      warn "Checking mailbox availability: ".$new->username."\@$domain\n"
        if $DEBUG;
      my $result = $app->get_mailbox_availability(
        Domain => $domain,
        Mailbox_List => $new->username,
      );
      if ($app->last_status_code) {
        return $app->last_status_text . ' (checking mailbox availability)';
      }
      if ($result->{AVAILABLE_LIST} eq 'T') {
        return "mailbox unavailable";
      }
      warn "Renaming mailbox $username to ".$new->username."\n" if $DEBUG;
      $app->rename_mailbox(
        Domain => $domain,
        Old_Mailbox => $old->username,
        New_Mailbox => $new->username,
      );
      if ($app->last_status_code) {
        return $app->last_status_text . ' (renaming mailbox)';
      }
    }
    # then make other changes
    warn "Modifying mailbox\n" if $DEBUG;
    my %args = $self->mailbox_args($new);
    warn Dumper \%args if $DEBUG > 1;
    $app->change_mailbox(%args);
    if ($app->last_status_code) {
      return $app->last_status_text . ' (changing mailbox properties)';
    }
    return;
  } else {
    return "OpenSRS export doesn't support this service type";
  }
}

sub export_suspend {
  my $self = shift;
  my $svc = shift;
  my $unsuspend = shift || 0;
  my $app = $self->app;
  return $app if !ref($app);
  # XXX apply this to all mail services? or should we have an option
  # to restrict it?
  warn "Changing mailbox suspension state\n" if $DEBUG;
  my %args = ( Domain  => $svc->domain, Mailbox => $svc->username );
  foreach (qw(SMTPIn SMTPRelay IMAP POP Webmail)) {
    $args{$_} = $unsuspend ? 'F' : 'T'; # True = suspended
  }
  warn Dumper \%args if $DEBUG > 1;
  $app->set_mailbox_suspension(%args);
  if ($app->last_status_code) {
    return $app->last_status_text . ' (setting mailbox suspension)';
  }
  return;
}

sub export_unsuspend {
  my ($self, $svc) = @_;
  $self->export_suspend($svc, 1);
}

=item mailbox_args SVC_ACCT

Returns a list of arguments to the C<create_mailbox> or C<change_mailbox>
methods for the supplied service.

=cut

sub mailbox_args {
  my ($self, $svc) = @_;
  my $cust_pkg = $svc->cust_svc->cust_pkg;
  my $cust = $cust_pkg->contact_obj || $cust_pkg->cust_main;
  return (
    Domain        => $svc->domain,
    Workgroup     => 'svc'.$svc->cust_svc->svcpart,
    Mailbox       => $svc->username,
    Password      => $svc->_password,
    First_Name    => $cust->first,
    Last_Name     => $cust->last,
    # other optional fields: FilterOnly, Title, Timezone, Lang,
    # Phone, Fax, Spam_Tag, Spam_Folder, Spam_Level
    # can add these if necessary...
  );
}

# convenience methods on $app

sub Net::OpenSRS::Email_APP::last_status_code {
  my $self = shift;
  $self->{status_code};
}

sub Net::OpenSRS::Email_APP::last_status_text {
  my $self = shift;
  $self->{status_text};
}

# workaround for a serious bug
sub Net::OpenSRS::Email_APP::safe_login {
  my $self = shift;
  local $Net::OpenSRS::Email_APP::Debug = 1;
  local $Net::OpenSRS::Email_APP::Emit_Debug = sub {
    if ($_[0] =~ /^read: \[ER (\d+) (.*)\r/) {
      die "$2\n";
    }
  };
  local $@ = '';
  local $SIG{__DIE__};
  eval { $self->login; };
  return $@;
}

1;
