package FS::part_export::domreg_net_dri;

use vars qw(@ISA %info %options $conf);
use Tie::IxHash;
use FS::part_export::null;

=head1 NAME

FS::part_export::domreg_net_dri - Register or transfer domains with Net::DRI

=head1 DESCRIPTION

This module handles registering and transferring domains with select registrars or registries supported
by L<Net::DRI>.

As a part_export, this module can be designated for use with svc_domain services.  When the svc_domain object
is inserted into the Freeside database, registration or transferring of the domain may be initiated, depending
on the setting of the svc_domain's action field.  Further operations can be performed from the View Domain screen.

Logging information is written to the Freeside log folder.

For correct operation you must add name/value pairs to the protcol and transport options fields.  The setttings
depend on the domain registry driver (DRD) selected.

=over 4

=item N - Register the domain

=item M - Transfer the domain

=item I - Ignore the domain for registration purposes

=back

=cut

@ISA = qw(FS::part_export::null);

my @tldlist = qw/com net org biz info name mobi at be ca cc ch cn de dk es eu fr it mx nl tv uk us/;

my $opensrs_protocol_opts=<<'END';
username=
password=
auto_renew=0
affiliate_id=
reseller_id=
END

my $opensrs_transport_opts=<<'END';
client_login=
client_password=
END

tie %options, 'Tie::IxHash',
  'drd'            => { label  => 'Domain Registry Driver (DRD)',
                      type => 'select',
                      options => [ qw/BookMyName CentralNic Gandi OpenSRS OVH VNDS/ ],
                      default => 'OpenSRS' },
  'log_level'  => { label  => 'Logging',
                      type => 'select',
		      options => [ qw/debug info notice warning error critical alert emergency/ ],
                      default => 'warning' },
  'protocol_opts'  => {
                      label   => 'Protocol Options',
                      type    => 'textarea',
                      default => $opensrs_protocol_opts,
                      },
  'transport_opts' => {
                      label   => 'Transport Options',
                      type    => 'textarea',
                      default => $opensrs_transport_opts,
                      },
#  'register'       => { label => 'Use for registration',
#                      type => 'checkbox',
#                      default => '1' },
#  'transfer'       => { label => 'Use for transfer',
#                      type => 'checkbox',
#                      default => '1' },
#  'delete'         => { label => 'Use for deletion',
#                      type => 'checkbox',
#                      default => '1' },
#  'renew'          => { label => 'Use for renewals',
#                      type => 'checkbox',
#                      default => '1' },
  'tlds'           => { label => 'Use this export for these top-level domains (TLDs)',
                      type => 'select',
                      multi => 1,
                      size => scalar(@tldlist),
                      options => [ @tldlist ],
                      default => 'com net org' },
;

my $opensrs_protocol_defaults = $opensrs_protocol_opts;
$opensrs_protocol_defaults =~ s|\n|\\n|g;

my $opensrs_transport_defaults = $opensrs_transport_opts;
$opensrs_transport_defaults =~ s|\n|\\n|g;

%info = (
  'svc'     => 'svc_domain',
  'desc'    => 'Domain registration via Net::DRI',
  'options' => \%options,
  'notes'   => <<"END"
Registers and transfers domains via a Net::DRI registrar or registry.
<a href="http://search.cpan.org/search?dist=Net-DRI">Net::DRI</a>
must be installed.  You must have an account at the selected registrar/registry.
<BR />
Some top-level domains have additional business rules not supported by this export. These TLDs cannot be registered or transfered with this export.
<BR><BR>Use these buttons for some useful presets:
<UL>
  <LI>
    <INPUT TYPE="button" VALUE="OpenSRS Live System (rr-n1-tor.opensrs.net)" onClick='
      document.dummy.machine.value = "rr-n1-tor.opensrs.net";
      this.form.machine.value = "rr-n1-tor.opensrs.net";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="OpenSRS Test System (horizon.opensrs.net)" onClick='
      document.dummy.machine.value = "horizon.opensrs.net";
      this.form.machine.value = "horizon.opensrs.net";
    '>
  <LI>
    <INPUT TYPE="button" VALUE="OpenSRS protocol/transport options" onClick='
      this.form.protocol_opts.value = "$opensrs_protocol_defaults";
      this.form.transport_opts.value = "$opensrs_transport_defaults";
    '>
</UL>
END
);

install_callback FS::UID sub {
  $conf = new FS::Conf;
};

#sub rebless { shift; }

# experiment: want the status of these right away, so no queueing

sub _export_insert {
  my( $self, $svc_domain ) = ( shift, shift );

  return if $svc_domain->action eq 'I';  # Ignoring registration, just doing DNS

  if ($svc_domain->action eq 'N') {
    return $self->register( $svc_domain );
  } elsif ($svc_domain->action eq 'M') {
    return $self->transfer( $svc_domain );
  }
  return "Unknown domain action " . $svc_domain->action;
}

=item get_portfolio_credentials

Returns, in list context, the user name and password for the domain portfolio.

This is currently specified via the username and password keys in the protocol options.

=cut

sub get_portfolio_credentials {
  my $self = shift;

  my %opts = $self->get_protocol_options();
  return ($opts{username}, $opts{password});
}

=item format_tel

Reformats a phone number according to registry rules.  Currently Freeside stores phone numbers
in NANPA format and most registries prefer "+CCC.NPANPXNNNN"

=cut

sub format_tel {
  my $tel = shift;

  #if ($tel =~ /^(\d{3})-(\d{3})-(\d{4})\s*(x\s*(\d+))?$/) {
  if ($tel =~ /^(\d{3})-(\d{3})-(\d{4})$/) {
    $tel = "+1.$1$2$3"; # TBD: other country codes
#    if $tel .= "$4" if $4;
  }
  return $tel;
}

sub gen_contact_set {
  my ($self, $dri, $cust_main) = @_;

  my @invoicing_list = $cust_main->invoicing_list_emailonly;
  if ( $conf->exists('emailinvoiceautoalways')
       || $conf->exists('emailinvoiceauto') && ! @invoicing_list
       || ( $conf->exists('emailinvoiceonly') && ! @invoicing_list ) ) {
    push @invoicing_list, $cust_main->all_emails;
  }

  my $email = ($conf->exists('business-onlinepayment-email-override'))
              ? $conf->config('business-onlinepayment-email-override')
              : $invoicing_list[0];

  my $cs=$dri->local_object('contactset');
  my $co=$dri->local_object('contact');

  my ($user, $pass) = $self->get_portfolio_credentials();

  $co->srid($user);	# Portfolio user name for OpenSRS?
  $co->auth($pass);	# Portfolio password for OpenSRS?

  $co->firstname($cust_main->first);
  $co->name($cust_main->last);
  $co->org($cust_main->company || '-');
  $co->street([$cust_main->address1, $cust_main->address2]);
  $co->city($cust_main->city);
  $co->sp($cust_main->state);
  $co->pc($cust_main->zip);
  $co->cc($cust_main->country);
  $co->voice(format_tel($cust_main->daytime()));
  $co->email($email);

  $cs->set($co, 'registrant');
  $cs->set($co, 'admin');
  $cs->set($co, 'billing');

  return $cs;
}

=item validate_contact_set

Attempts to validate contact data for the domain based on OpenSRS rules.

Returns undef if the contact data is acceptable, an error message if the contact
data lacks one or more required fields.

=cut

sub validate_contact_set {
  my $c = shift;

  my %fields = (
    firstname => "first name",
    name => "last name",
    street => "street address",
    city => "city",
    sp => "state",
    pc => "ZIP/postal code",
    cc => "country",
    email => "email address",
    voice => "phone number",
  );
  my @err = ();
  foreach my $which (qw/registrant admin billing/) {
    my $co = $c->get($which);
    foreach (keys %fields) {
      if (!$co->$_()) {
        push @err, $fields{$_};
      }
    }
  }
  if (scalar(@err) > 0) {
    return "Contact information needs: " . join(', ', @err);
  }
  undef;
}

#sub _export_replace {
#  my( $self, $new, $old ) = (shift, shift, shift);
#
#  return '';
#
#}

## Domain registration exports do nothing on delete.  You're just removing the domain from Freeside, not the registry
#sub _export_delete {
#  my( $self, $www ) = ( shift, shift );
#
#  return '';
#}

=item split_textarea_options

Split textarea contents into lines, split lines on =, and then trim the results;

=cut

sub split_textarea_options {
  my ($self, $optname) = @_;
  my %opts =  map {
    my ($key, $value) = split /=/, $_;
    $key =~ s/^\s*//;
    $key =~ s/\s*$//;
    $value =~ s/^\s*//;
    $value =~ s/\s*$//;
    $key => $value } split /\n/, $self->option($optname);
  %opts;
}

=item get_protocol_options

Return a hash of protocol options

=cut

sub get_protocol_options {
  my $self = shift;
  my %opts = $self->split_textarea_options('protocol_opts');
  if ($self->machine =~ /opensrs\.net/) {
   my %topts = $self->get_transport_options;
   $opts{reseller_id} = $topts{client_login};
  }
  %opts;
}

=item get_transport_options

Return a hash of transport options

=cut

sub get_transport_options {
  my $self = shift;
  my %opts = $self->split_textarea_options('transport_opts');
  $opts{remote_url} = "https://" . $self->machine . ":55443/resellers" if $self->machine =~ /opensrs\.net/;
  %opts;
}

=item is_supported_domain

Return undef if the domain name uses a TLD or SLD that is supported by this registrar.
Otherwise return an error message explaining what's wrong.

=cut

sub is_supported_domain {
  my $self = shift;
  my $svc_domain = shift;

  # Get the TLD of the new domain
  my @bits = split /\./, $svc_domain->domain;

  return "Can't register subdomains: " . $svc_domain->domain if scalar(@bits) != 2;

  my $tld = pop @bits;

  # See if it's one this export supports
  my @tlds = split /\s+/, $self->option('tlds');
  @tlds =  map { s/\.//; $_ } @tlds;
  return "Can't register top-level domain $tld, restricted to: " . $self->option('tlds') if ! grep { $_ eq $tld } @tlds;
  return undef;
}

=item get_dri

=cut

sub get_dri {
  my $self = shift;
  my $dri;

#  return $self->{dri} if $self->{dri}; #!!!TBD!!! connection caching.

  eval "use Net::DRI 0.95;";
  return $@ if $@;

# $dri=Net::DRI->new(...) to create the global object. Save the result,

  eval {
    #$dri = Net::DRI::TrapExceptions->new(10);
    $dri = Net::DRI->new({logging => [ 'files', { output_directory => '%%%FREESIDE_LOG%%%' } ]}); #!!!TBD!!!
    $dri->logging->level( $self->option('log_level') );
    $dri->add_registry( $self->option('drd') );
    my $protocol;
    $protocol = 'xcp' if $self->option('drd') eq 'OpenSRS';

    $dri->target( $self->option('drd') )->add_current_profile($self->option('drd') . '1',
#      'Net::DRI::Protocol::' . $self->option('protocol_type'),
#      $self->option('protocol_type'),
#	'xcp', #TBD!!!!
	$protocol, # Implies transport
#      'Net::DRI::Transport::' . $self->option('transport_type'),
      { $self->get_transport_options() },
#      [ $self->get_protocol_options() ]
      );
  };
  return $@ if $@;

  $self->{dri} = $dri;
  return $dri;
}

=item get_status

Returns a reference to a hashref containing information on the domain's status.  The keys
defined depend on the status.

'unregistered' means the domain is not registered.

Otherwise, if the domain is in an asynchronous operation such as a transfer, returns the state
of that operation.

Otherwise returns a value indicating if the domain can be managed through our reseller account.

=cut

sub get_status {
  my ( $self, $svc_domain ) = @_;
  my $rc;
  my $rslt = {};

  my $dri = $self->get_dri;

    if (UNIVERSAL::isa($dri, 'Net::DRI::Exception')) {
      $rslt->{'message'} = $dri->as_string;
      return $rslt;
    }
  eval {
    $rc = $dri->domain_check( $svc_domain->domain );
    if (!$rc->is_success()) {
      # Problem accessing the registry/registrar
      $rslt->{'message'} = $rc->message;
    } elsif (!$dri->get_info('exist')) {
      # Domain is not registered
      $rslt->{'unregistered'} = 1;
    } else {
      $rc = $dri->domain_transfer_query( $svc_domain->domain );
      if ($rc->is_success() && $dri->get_info('status')) {
        # Transfer in progress
      	$rslt->{status} = $dri->get_info('status');
	$rslt->{contact_email} = $dri->get_info('request_address');
	$rslt->{last_update_time} = $dri->get_info('unixtime');
      } elsif ($dri->get_info('reason')) {
	$rslt->{'reason'} = $dri->get_info('reason');
        # Domain is not being transferred...
        $rc = $dri->domain_info( $svc_domain->domain, { $self->get_protocol_options() } );
        if ($rc->is_success() && $dri->get_info('exDate')) {
            $rslt->{'expdate'} = $dri->get_info('exDate');
	}
      } else {
        $rslt->{status} = 'Unknown';
      }
    }
  };
#  rslt->{'message'} = $@->as_string if $@;
  if ($@) {
    $rslt->{'message'} = (UNIVERSAL::isa($@, 'Net::DRI::Exception')) ? $@->as_string : $@->message;
  }

  return $rslt; # Success
}

=item register

Attempts to register the domain through the reseller account associated with this export.

Like most export functions, returns an error message on failure or undef on success.

=cut

sub register {
  my ( $self, $svc_domain, $years ) = @_;

  my $err = $self->is_supported_domain( $svc_domain );
  return $err if $err;

  my $dri = $self->get_dri;
  return $dri->as_string if (UNIVERSAL::isa($dri, 'Net::DRI::Exception'));

  eval { # All $dri methods can throw an exception.

# Call methods
    my $cust_main = $svc_domain->cust_svc->cust_pkg->cust_main;

    my $cs = $self->gen_contact_set($dri, $cust_main);

    $err = validate_contact_set($cs);
    return $err if $err;

# !!!TBD!!! add custom name servers when supported; add ns => $ns to hash passed to domain_create

    $res = $dri->domain_create($svc_domain->domain, { $self->get_protocol_options(), pure_create => 1, contact => $cs, duration => DateTime::Duration->new(years => $years) });
    $err = $res->is_success ? '' : $res->message;
  };
  if ($@) {
    $err = (UNIVERSAL::isa($@, 'Net::DRI::Exception')) ? $@->msg : $@->message;
  }

  return $err;
}

=item transfer

Attempts to transfer the domain into the reseller account associated with this export.

Like most export functions, returns an error message on failure or undef on success.

=cut

sub transfer {
  my ( $self, $svc_domain ) = @_;

  my $err = $self->is_supported_domain( $svc_domain );
  return $err if $err;

# $dri=Net::DRI->new(...) to create the global object. Save the result,
  my $dri = $self->get_dri;
  return $dri->as_string if (UNIVERSAL::isa($dri, 'Net::DRI::Exception'));

  eval { # All $dri methods can throw an exception

# Call methods
    my $cust_main = $svc_domain->cust_svc->cust_pkg->cust_main;

    my $cs = $self->gen_contact_set($dri, $cust_main);

    $err = validate_contact_set($cs);
    return $err if $err;

# !!!TBD!!! add custom name servers when supported; add ns => $ns to hash passed to domain_transfer_start

    $res = $dri->domain_transfer_start($svc_domain->domain, { $self->get_protocol_options(), contact => $cs });
    $err = $res->is_success ? '' : $res->message;
  };
  if ($@) {
    $err = (UNIVERSAL::isa($@, 'Net::DRI::Exception')) ? $@->msg : $@->message;
  }

  return $err;
}

=item renew

Attempts to renew the domain for the specified number of years.

Like most export functions, returns an error message on failure or undef on success.

=cut

sub renew {
  my ( $self, $svc_domain, $years ) = @_;

  my $err = $self->is_supported_domain( $svc_domain );
  return $err if $err;

  my $dri = $self->get_dri;
  return $dri->as_string if (UNIVERSAL::isa($dri, 'Net::DRI::Exception'));

  eval { # All $dri methods can throw an exception
    my $expdate;
    my $res = $dri->domain_info( $svc_domain->domain, { $self->get_protocol_options() } );
    if ($res->is_success() && $dri->get_info('exDate')) {
      $expdate = $dri->get_info('exDate');

#    return "Domain renewal not enabled" if !$self->option('renew');
      $res = $dri->domain_renew( $svc_domain->domain, { $self->get_protocol_options(), duration => DateTime::Duration->new(years => $years), current_expiration => $expdate });
    }
    $err = $res->is_success ? '' : $res->message;
  };
  if ($@) {
    $err = (UNIVERSAL::isa($@, 'Net::DRI::Exception')) ? $@->msg : $@->message;
  }

  return $err;
}

=item revoke

Attempts to revoke the domain registration.  Only succeeds if invoked during the DRI
grace period immediately after registration.

Like most export functions, returns an error message on failure or undef on success.

=cut

sub revoke {
  my ( $self, $svc_domain ) = @_;

  my $err = $self->is_supported_domain( $svc_domain );
  return $err if $err;

  my $dri = $self->get_dri;
  return $dri->as_string if (UNIVERSAL::isa($dri, 'Net::DRI::Exception'));

  eval { # All $dri methods can throw an exception

#    return "Domain registration revocation not enabled" if !$self->option('revoke');
    my $res = $dri->domain_delete( $svc_domain->domain, { $self->get_protocol_options(), domain => $svc_domain->domain, pure_delete => 1 });
    $err = $res->is_success ? '' : $res->message;
  };
  if ($@) {
    $err = (UNIVERSAL::isa($@, 'Net::DRI::Exception')) ? $@->msg : $@->message;
  }

  return $err;
}

=item registrar

Should return a full-blown object representing the Net::DRI DRD, but current just returns a hashref
containing the registrar name.

=cut

sub registrar {
  my $self = shift;
  return {
  	name => $self->option('drd'),
  };
}

=head1 SEE ALSO

L<FS::part_export_option>, L<FS::export_svc>, L<FS::svc_domain>,
L<FS::Record>, schema.html from the base documentation.

=cut

1;

