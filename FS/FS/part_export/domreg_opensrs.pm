package FS::part_export::domreg_opensrs;

use vars qw(@ISA %info %options $conf $me $DEBUG);
use Tie::IxHash;
use DateTime;
use FS::Record qw(qsearchs qsearch);
use FS::Conf;
use FS::part_export::null;
use FS::svc_domain;
use FS::part_pkg;

=head1 NAME

FS::part_export::domreg_opensrs - Register or transfer domains with Tucows OpenSRS

=head1 DESCRIPTION

This module handles registering and transferring domains using a registration service provider (RSP) account
at Tucows OpenSRS, an ICANN-approved domain registrar.

As a part_export, this module can be designated for use with svc_domain services.  When the svc_domain object
is inserted into the Freeside database, registration or transferring of the domain may be initiated, depending
on the setting of the svc_domain's action field.

=over 4

=item N - Register the domain

=item M - Transfer the domain

=item I - Ignore the domain for registration purposes

=back

This export uses Net::OpenSRS.  Registration and transfer attempts will fail unless Net::OpenSRS is installed
and LWP::UserAgent is able to make HTTPS posts.  You can turn on debugging messages and use the OpenSRS test
gateway when setting up this export.

=cut

@ISA = qw(FS::part_export::null);
$me = '[' .  __PACKAGE__ . ']';
$DEBUG = 0;

my @tldlist = qw/com net org biz info name mobi at be ca cc ch cn de dk es eu fr it mx nl tv uk us asn.au com.au id.au net.au org.au/;

tie %options, 'Tie::IxHash',
  'username'     => { label => 'Reseller user name at OpenSRS',
                      },
  'privatekey'   => { label => 'Private key',
                      },
  'password'     => { label => 'Password for management account',
                      },
  'masterdomain' => { label => 'Master domain at OpenSRS',
                      },
  'wait_for_pay' => { label => 'Do not provision until payment is received',
                      type => 'checkbox',
                      default => '0',
                    },
  'debug_level'  => { label => 'Net::OpenSRS debug level',
                      type => 'select',
                      options => [ 0, 1, 2, 3 ],
		      default => 0 },
#  'register'     => { label => 'Use for registration',
#                      type => 'checkbox',
#                      default => '1' },
#  'transfer'     => { label => 'Use for transfer',
#                      type => 'checkbox',
#                      default => '1' },
  'tlds'         => { label => 'Use this export for these top-level domains (TLDs)',
                      type => 'select',
                      multi => 1,
                      size => scalar(@tldlist),
                      options => [ @tldlist ],
		      default => 'com net org' },
;

%info = (
  'svc'     => 'svc_domain',
  'desc'    => 'Domain registration via Tucows OpenSRS',
  'options' => \%options,
  'notes'   => <<'END'
Registers and transfers domains via the <a href="http://opensrs.com/">Tucows OpenSRS</a> registrar (using <a href="http://search.cpan.org/dist/Net-OpenSRS">Net::OpenSRS</a>).
All of the Net::OpenSRS restrictions apply:
<UL>
  <LI>You must have a reseller account with Tucows.
  <LI>You must add the public IP address of the Freeside server to the 'Script API allow' list in the OpenSRS web interface.
  <LI>You must generate an API access key in the OpenSRS web interface and enter it below.
  <LI>All domains are managed using the same user name and password, but you can create sub-accounts for clients.
  <LI>The user name must be the same as your OpenSRS reseller ID.
  <LI>You must enter a master domain that all other domains are associated with.  That domain must be registered through your OpenSRS account.
</UL>
Some top-level domains offered by OpenSRS have additional business rules not supported by this export. These TLDs cannot be registered or transfered with this export.
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
</UL>
END
);

install_callback FS::UID sub { 
  $conf = new FS::Conf;
};

=head1 METHODS

=over 4

=item format_tel

Reformats a phone number according to registry rules.  Currently Freeside stores phone numbers
in NANPA format and the registry prefers "+CCC.NPANPXNNNN"

=cut

sub format_tel {
  my $tel = shift;

  #if ($tel =~ /^(\d{3})-(\d{3})-(\d{4})( x(\d+))?$/) {
  if ($tel =~ /^(\d{3})-(\d{3})-(\d{4})$/) {
    $tel = "+1.$1$2$3";
#    if $tel .= "$4" if $4;
  }
  return $tel;
}

=item gen_contact_info

Generates contact data for the domain based on the customer data.

Currently relies on Net::OpenSRS to format the telephone number for OpenSRS.

=cut

sub gen_contact_info
{
  my ($co)=@_;

  my @invoicing_list = $co->invoicing_list_emailonly;
  if ( $conf->exists('emailinvoiceautoalways')
       || $conf->exists('emailinvoiceauto') && ! @invoicing_list
       || ( $conf->exists('emailinvoiceonly') && ! @invoicing_list ) ) {
    push @invoicing_list, $co->all_emails;
  }

  my $email = ($conf->exists('business-onlinepayment-email-override'))
              ? $conf->config('business-onlinepayment-email-override')
              : $invoicing_list[0];

  my $c = {
    firstname => $co->first,
    lastname  => $co->last,
    company   => $co->company,
    address   => $co->address1,
    city      => $co->city(),
    state     => $co->state(),
    zip       => $co->zip(),
    country   => uc($co->country()),
    email     => $email,
    #phone     => format_tel($co->daytime()),
    phone     => $co->daytime() || $co->night,
  };
  return $c;
}

=item validate_contact_info

Attempts to validate contact data for the domain based on OpenSRS rules.

Returns undef if the contact data is acceptable, an error message if the contact
data lacks one or more required fields.

=cut

sub validate_contact_info {
  my $c = shift;

  my %fields = (
    firstname => "first name",
    lastname => "last name",
    address => "street address",
    city => "city", 
    state => "state",
    zip => "ZIP/postal code",
    country => "country",
    email => "email address",
    phone => "phone number",
  );
  my @err = ();
  foreach (keys %fields) {
    if (!defined($c->{$_}) || !$c->{$_}) {
      push @err, $fields{$_};
    }
  }
  if (scalar(@err) > 0) {
    return "Contact information needs: " . join(', ', @err);
  }
  undef;
}

=item testmode

Returns the Net::OpenSRS-required test mode string based on whether the export
is configured to use the live or the test gateway.

=cut

sub testmode {
  my $self = shift;

  return 'live' if $self->machine eq "rr-n1-tor.opensrs.net";
  return 'test' if $self->machine eq "horizon.opensrs.net";
  undef;

}

=item _export_insert

Attempts to "export" the domain, i.e. register or transfer it if the user selected
that option when editing the domain.

Returns an error message on failure or undef on success.

May also return an error message if it cannot load the required Perl module Net::OpenSRS,
or if the domain is not registerable, or if insufficient data is provided in the customer
record to generate the required contact information to register or transfer the domain.

=cut

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

sub _export_insert_on_payment {
  my( $self, $svc_domain ) = ( shift, shift );
  warn "$me:_export_insert_on_payment called\n" if $DEBUG;
  return '' unless $self->option('wait_for_pay');

  my $queue = new FS::queue {
    'svcnum' => $svc_domain->svcnum,
    'job'    => 'FS::part_export::domreg_opensrs::renew_through',
  };
  $queue->insert( $self, $svc_domain ); #_export_insert with 'R' action?
}

## Domain registration exports do nothing on replace.  Mainly because we haven't decided what they should do.
#sub _export_replace {
#  my( $self, $new, $old ) = (shift, shift, shift);
#
#  return '';
#
#}

## Domain registration exports do nothing on delete.  You're just removing the domain from Freeside, not the registry
#sub _export_delete {
#  my( $self, $svc_domain ) = ( shift, shift );
#
#  return '';
#}

=item is_supported_domain

Return undef if the domain name uses a TLD or SLD that is supported by this registrar.
Otherwise return an error message explaining what's wrong.

=cut

sub is_supported_domain {
  my $self = shift;
  my $svc_domain = shift;

  # Get the TLD of the new domain
  my @bits = split /\./, $svc_domain->domain;

  return "Can't register subdomains: " . $svc_domain->domain 
    if (scalar(@bits) != 2 && scalar(@bits) != 3);

  my $tld = pop @bits;
  my $sld = pop @bits;

  # See if it's one this export supports
  my @tlds = split /\s+/, $self->option('tlds');
  @tlds =  map { s/\.//; $_ } @tlds;
  return "Can't register top-level domain $tld, restricted to: " 
	    . $self->option('tlds') if ! grep { $_ eq $tld || $_ eq "$sld$tld" } @tlds;
  return undef;
}

=item get_srs

=cut

sub get_srs {
  my $self = shift;

  my $srs = Net::OpenSRS->new();

  $srs->debug_level( $self->option('debug_level') ); # Output should be in the Apache error log

  $srs->environment( $self->testmode() );
  $srs->set_key( $self->option('privatekey') );

  $srs->set_manage_auth( $self->option('username'), $self->option('password') );
  return $srs;
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
  my $rslt = {};

  eval "use Net::OpenSRS;";
  return $@ if $@;

  my $srs = $self->get_srs;

  if ($srs->is_available( $svc_domain->domain )) {
    $rslt->{'unregistered'} = 1;
  } else {
    $rslt = $srs->check_transfer( $svc_domain->domain );
    if (defined($rslt->{'reason'})) {
      my $rv = $srs->make_request(
        {
          action     => 'belongs_to_rsp',
          object     => 'domain',
          attributes => {
            domain => $svc_domain->domain
          }
        }
      );
      if ($rv) {
        $self->_set_response;
        if ( $rv->{attributes}->{'domain_expdate'} ) {
	  $rslt->{'expdate'} = $rv->{attributes}->{'domain_expdate'};
        }
      }
    }
  }

  return $rslt; # Success
}

=item register

Attempts to register the domain through the reseller account associated with this export.

Like most export functions, returns an error message on failure or undef on success.

=cut

sub register {
  my ( $self, $svc_domain, $years ) = @_;

  $years = 1 unless $years; #default to 1 year since we don't seem to pass it

  return "Net::OpenSRS does not support period other than 1 year" if $years != 1;

  eval "use Net::OpenSRS;";
  return $@ if $@;

  my $err = $self->is_supported_domain( $svc_domain );
  return $err if $err;

  my $cust_main = $svc_domain->cust_svc->cust_pkg->cust_main;

  my $c = gen_contact_info($cust_main);

  $err = validate_contact_info($c);
  return $err if $err;

  my $srs = $self->get_srs;

#  cookie not required for registration
#  my $cookie = $srs->get_cookie( $self->option('masterdomain') );
#  if (!$cookie) {
#     return "Unable to get cookie at OpenSRS: " . $srs->last_response();
#  }

#  return "Domain registration not enabled" if !$self->option('register');
  return $srs->last_response() if !$srs->register_domain( $svc_domain->domain, $c);

  return ''; # Should only get here if register succeeded
}

=item transfer

Attempts to transfer the domain into the reseller account associated with this export.

Like most export functions, returns an error message on failure or undef on success.

=cut

sub transfer {
  my ( $self, $svc_domain ) = @_;

  eval "use Net::OpenSRS;";
  return $@ if $@;

  my $err = $self->is_supported_domain( $svc_domain );
  return $err if $err;

  my $cust_main = $svc_domain->cust_svc->cust_pkg->cust_main;

  my $c = gen_contact_info($cust_main);

  $err = validate_contact_info($c);
  return $err if $err;

  my $srs = $self->get_srs;

  my $cookie = $srs->get_cookie( $self->option('masterdomain') );
  if (!$cookie) {
     return "Unable to get cookie at OpenSRS: " . $srs->last_response();
  }

#  return "Domain transfer not enabled" if !$self->option('transfer');
  return $srs->last_response() if !$srs->transfer_domain( $svc_domain->domain, $c);

  return ''; # Should only get here if transfer succeeded
}

=item renew

Attempts to renew the domain for the specified number of years.

Like most export functions, returns an error message on failure or undef on success.

=cut

sub renew {
  my ( $self, $svc_domain, $years ) = @_;

  eval "use Net::OpenSRS;";
  return $@ if $@;

  my $err = $self->is_supported_domain( $svc_domain );
  return $err if $err;

  my $srs = $self->get_srs;

  my $cookie = $srs->get_cookie( $self->option('masterdomain') );
  if (!$cookie) {
     return "Unable to get cookie at OpenSRS: " . $srs->last_response();
  }

#  return "Domain renewal not enabled" if !$self->option('renew');
  return $srs->last_response() if !$srs->renew_domain( $svc_domain->domain, $years );

  return ''; # Should only get here if renewal succeeded
}

=item renew_through [ EPOCH_DATE ]

Attempts to renew the domain through the specified date.  If no date is
provided it is gleaned from the associated cust_pkg bill date

Like some export functions, dies on failure or returns undef on success.
It is always called from the queue.

=cut

sub renew_through {
  my ( $self, $svc_domain, $date ) = @_;

  warn "$me: renew_through called\n" if $DEBUG;
  eval "use Net::OpenSRS;";
  die $@ if $@;

  unless ( $date ) {
    my $cust_pkg = $svc_domain->cust_svc->cust_pkg;
    die "Can't renew: no date specified and domain is not in a package."
      unless $cust_pkg;
    $date = $cust_pkg->bill;
  }

  my $err = $self->is_supported_domain( $svc_domain );
  die $err if $err;

  warn "$me: checking status\n" if $DEBUG;
  my $rv = $self->get_status($svc_domain);
  die "Domain ". $svc_domain->domain. " is not renewable"
    unless $rv->{expdate};

  die "Can't parse expiration date for ". $svc_domain->domain
    unless $rv->{expdate} =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/;

  my ($year,$month,$day,$hour,$minute,$second) = ($1,$2,$3,$4,$5,$6);
  my $exp = DateTime->new( year   => $year,
                           month  => $month,
                           day    => $day,
                           hour   => $hour,
                           minute => $minute,
                           second => $second,
                           time_zone => 'America/New_York',#timezone of opensrs
                         );

  my $bill = DateTime->
   from_epoch( 'epoch'     => $date,
               'time_zone' => DateTime::TimeZone->new( name => 'local' ),
  );

  my $years = 0;
  while ( DateTime->compare( $bill, $exp ) > 0 ) {
    $years++;
    $exp->add( 'years' => 1 );

    die "Can't renew ". $svc_domain->domain. " for more than 10 years."
      if $years > 10; #no infinite loop
  }

  return '' unless $years;

  warn "$me: renewing ". $svc_domain->domain. " for $years years\n" if $DEBUG;
  my $srs = $self->get_srs;
  $rv = $srs->make_request(
    {
      action     => 'renew',
      object     => 'domain',
      attributes => {
        domain                => $svc_domain->domain,
        auto_renew            => 0,
        handle                => 'process',
        period                => $years,
        currentexpirationyear => $year,
      }
    }
  );
  die $rv->{response_text} unless $rv->{is_success};

  return ''; # Should only get here if renewal succeeded
}

=item revoke

Attempts to revoke the domain registration.  Only succeeds if invoked during the OpenSRS
grace period immediately after registration.

Like most export functions, returns an error message on failure or undef on success.

=cut

sub revoke {
  my ( $self, $svc_domain ) = @_;

  eval "use Net::OpenSRS;";
  return $@ if $@;

  my $err = $self->is_supported_domain( $svc_domain );
  return $err if $err;

  my $srs = $self->get_srs;

  my $cookie = $srs->get_cookie( $self->option('masterdomain') );
  if (!$cookie) {
     return "Unable to get cookie at OpenSRS: " . $srs->last_response();
  }

#  return "Domain registration revocation not enabled" if !$self->option('revoke');
  return $srs->last_response() if !$srs->revoke_domain( $svc_domain->domain);

  return ''; # Should only get here if transfer succeeded
}

=item registrar

Should return a full-blown object representing OpenSRS, but current just returns a hashref
containing the registrar name.

=cut

sub registrar {
  return {
  	name => 'OpenSRS',
  };
}

=back

=head1 SEE ALSO

L<Net::OpenSRS>, L<FS::part_export_option>, L<FS::export_svc>, L<FS::svc_domain>,
L<FS::Record>, schema.html from the base documentation.


=cut

1;

