package FS::part_export::domreg_opensrs;

use vars qw(@ISA %info %options $conf);
use Tie::IxHash;
use FS::Record qw(qsearchs qsearch);
use FS::Conf;
use FS::part_export::null;
use FS::svc_domain;
use FS::part_pkg;
use Net::OpenSRS;

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

=cut

@ISA = qw(FS::part_export::null);

my @tldlist = qw/com net org biz info name mobi at be ca cc ch cn de dk es eu fr it mx nl tv uk us/;

tie %options, 'Tie::IxHash',
  'username'     => { label => 'Reseller user name at OpenSRS',
                      },
  'privatekey'   => { label => 'Private key',
                      },
  'password'     => { label => 'Password for management account',
                      },
  'masterdomain' => { label => 'Master domain at OpenSRS',
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

sub testmode {
  my $self = shift;

  return 'live' if $self->machine eq "rr-n1-tor.opensrs.net";
  return 'test' if $self->machine eq "horizon.opensrs.net";
  undef;
}

sub _export_insert {
  my( $self, $svc_domain ) = ( shift, shift );

  return if $svc_domain->action eq 'I';  # Ignoring registration, just doing DNS

  # Get the TLD of the new domain
  my @bits = split /\./, $svc_domain->domain;

  return "Can't register subdomains: " . $svc_domain->domain if scalar(@bits) != 2;

  my $tld = pop @bits;

  # See if it's one this export supports
  my @tlds = split /\s+/, $self->option('tlds');
  @tlds =  map { s/\.//; $_ } @tlds;
  return "Can't register top-level domain $tld, restricted to: " . $self->option('tlds') if ! grep { $_ eq $tld } @tlds;

  my $cust_main = $svc_domain->cust_svc->cust_pkg->cust_main;

  my $c = gen_contact_info($cust_main);

  my $err = validate_contact_info($c);
  return $err if $err;

  my $srs = Net::OpenSRS->new();

  $srs->debug_level( $self->option('debug_level') ); # Output should be in the Apache error log

  $srs->environment( $self->testmode() );
  $srs->set_key( $self->option('privatekey') );

  $srs->set_manage_auth( $self->option('username'), $self->option('password') );

  my $cookie = $srs->get_cookie( $self->option('masterdomain') );
  if (!$cookie) {
     return "Unable to get cookie at OpenSRS: " . $srs->last_response();
  }

  if ($svc_domain->action eq 'N') {
#    return "Domain registration not enabled" if !$self->option('register');
    return $srs->last_response() if !$srs->register_domain( $svc_domain->domain, $c);
  } elsif ($svc_domain->action eq 'M') {
#    return "Domain transfer not enabled" if !$self->option('transfer');
    return $srs->last_response() if !$srs->transfer_domain( $svc_domain->domain, $c);
  } else {
    return "Unknown domain action " . $svc_domain->action;
  }

  return ''; # Should only get here if register or transfer succeeded

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

sub registrar {
  return {
  	name => 'OpenSRS',
  };
}

=back

=head1 SEE ALSO

L<FS::part_export_option>, L<FS::export_svc>, L<FS::svc_domain>,
L<FS::Record>, schema.html from the base documentation.

=cut

1;

