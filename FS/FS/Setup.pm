package FS::Setup;
use base qw( Exporter );

use strict;
use vars qw( @EXPORT_OK );
#use Tie::DxHash;
use Tie::IxHash;
use Crypt::OpenSSL::RSA;
use FS::UID qw( dbh driver_name );
#use FS::Record;

use FS::svc_domain;
$FS::svc_domain::whois_hack = 1;
$FS::svc_domain::whois_hack = 1;

#populate_locales
use Locale::Country;
use Locale::SubCountry 1.42;
use FS::cust_main_county;

#populate_access
use FS::AccessRight;
use FS::access_right;
use FS::access_groupagent;

#populate_msgcat
use FS::Record qw(qsearch);
use FS::msgcat;

@EXPORT_OK = qw( create_initial_data enable_encryption );

=head1 NAME

FS::Setup - Database setup

=head1 SYNOPSIS

  use FS::Setup;

=head1 DESCRIPTION

Currently this module simply provides a place to store common subroutines for
database setup.

=head1 SUBROUTINES

=over 4

=item

=cut

sub create_initial_data {
  my %opt = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  $FS::UID::AutoCommit = 0;

  populate_locales();

  populate_duplock();

  #initial_data data
  populate_initial_data(%opt);

  populate_access();

  populate_msgcat();

  populate_numbering();

  enable_encryption();
  
  if ( $oldAutoCommit ) {
    dbh->commit or die dbh->errstr;
  }

}

sub enable_encryption {

  eval "use FS::Conf";
  die $@ if $@;

  my $conf = new FS::Conf;

  die "encryption key(s) already in place"
    if $conf->exists('encryptionpublickey')
    || $conf->exists('encryptionprivatekey');

  my $length = 2048;
  my $rsa = Crypt::OpenSSL::RSA->generate_key($length);

  $conf->set('encryption', 1);
  $conf->set('encryptionmodule',     'Crypt::OpenSSL::RSA');
  $conf->set('encryptionpublickey',  $rsa->get_public_key_string );
  $conf->set('encryptionprivatekey', $rsa->get_private_key_string );

}

sub populate_numbering {
  eval "use FS::lata_Data;"; # this automatically populates the lata table, if unpopulated
  eval "use FS::msa_Data;"; # this automatically populates the msa table, if unpopulated
}

sub populate_locales {

  #cust_main_county
  foreach my $country ( sort map uc($_), all_country_codes ) {
    _add_country($country);
  }

}

sub populate_addl_locales {

  my %addl = (
    'US' => {
      'FM' => 'Federated States of Micronesia',
      'MH' => 'Marshall Islands',
      'PW' => 'Palau',
      'AA' => "Armed Forces Americas (except Canada)",
      'AE' => "Armed Forces Europe / Canada / Middle East / Africa",
      'AP' => "Armed Forces Pacific",
    },
  );

  foreach my $country ( keys %addl ) {
    foreach my $state ( keys %{ $addl{$country} } ) {
      # $longname = $addl{$country}{$state};
      _add_locale( 'country'=>$country, 'state'=>$state);
    }
  }

}

sub _add_country {

  my( $country ) = shift;

  my $subcountry = eval { new Locale::SubCountry($country) };
  my @states = $subcountry ? $subcountry->all_codes : undef;
  
  if ( !scalar(@states) || ( scalar(@states)==1 && !defined($states[0]) ) ) {

    _add_locale( 'country'=>$country );
  
  } else {
  
    if ( $states[0] =~ /^(\d+|\w)$/ ) {
      @states = map $subcountry->full_name($_), @states
    }
  
    foreach my $state ( @states ) {
      _add_locale( 'country'=>$country, 'state'=>$state);
    }
    
  }

}

sub _add_locale {
  my $cust_main_county = new FS::cust_main_county( { 'tax'=>0, @_ });  
  my $error = $cust_main_county->insert;
  die $error if $error;
}

sub populate_duplock {

  return unless driver_name =~ /^mysql/i;

  my $sth = dbh->prepare(
    "INSERT INTO duplicate_lock ( lockname ) VALUES ( 'svc_acct' )"
  ) or die dbh->errstr;

  $sth->execute or die $sth->errstr;

}

sub populate_initial_data {
  my %opt = @_;

  my $data = initial_data(%opt);

  foreach my $table ( keys %$data ) {

    #warn "popuilating $table\n";

    my $class = "FS::$table";
    eval "use $class;";
    die $@ if $@;

    $class->_populate_initial_data(%opt)
      if $class->can('_populate_initial_data');

    my @records = @{ $data->{$table} };

    foreach my $record ( @records ) {

      my $args = delete($record->{'_insert_args'}) || [];
      my $object = $class->new( $record );
      my $error = $object->insert( @$args );
      die "error inserting record into $table: $error\n"
        if $error;

      #my $pkey = $object->primary_key;
      #my $pkeyvalue = $object->$pkey();
      #warn "  inserted $pkeyvalue\n";

    }

  }

}

sub initial_data {
  my %opt = @_;

  my $cust_location = FS::cust_location->new({
      'address1'  => '1234 System Lane',
      'city'      => 'Systemtown',
      'state'     => 'CA',
      'zip'       => '54321',
      'country'   => 'US',
  });

  #tie my %hash, 'Tie::DxHash', 
  tie my %hash, 'Tie::IxHash', 

    #bootstrap user
    'access_user' => [
      { 'username'  => 'fs_bootstrap',
        '_password' => 'changeme', #will trigger warning if you try to enable
        'last'      => 'User',
        'first'     => 'Bootstrap',
        'disabled'  => 'Y',
      },
    ],

    #superuser group
    'access_group' => [
      { 'groupname' => 'Superuser' },
    ],

    #reason types
    'reason_type' => [],

#XXX need default new-style billing events
#    #billing events
#    'part_bill_event' => [
#      { 'payby'     => 'CARD',
#        'event'     => 'Batch card',
#        'seconds'   => 0,
#        'eventcode' => '$cust_bill->batch_card(%options);',
#        'weight'    => 40,
#        'plan'      => 'batch-card',
#      },
#      { 'payby'     => 'BILL',
#        'event'     => 'Send invoice',
#        'seconds'   => 0,
#        'eventcode' => '$cust_bill->send();',
#        'weight'    => 50,
#        'plan'      => 'send',
#      },
#      { 'payby'     => 'DCRD',
#        'event'     => 'Send invoice',
#        'seconds'   => 0,
#        'eventcode' => '$cust_bill->send();',
#        'weight'    => 50,
#        'plan'      => 'send',
#      },
#      { 'payby'     => 'DCHK',
#        'event'     => 'Send invoice',
#        'seconds'   => 0,
#        'eventcode' => '$cust_bill->send();',
#        'weight'    => 50,
#        'plan'      => 'send',
#      },
#      { 'payby'     => 'DCLN',
#        'event'     => 'Suspend',
#        'seconds'   => 0,
#        'eventcode' => '$cust_bill->suspend();',
#        'weight'    => 40,
#        'plan'      => 'suspend',
#      },
#      #{ 'payby'     => 'DCLN',
#      #  'event'     => 'Retriable',
#      #  'seconds'   => 0,
#      #  'eventcode' => '$cust_bill_event->retriable();',
#      #  'weight'    => 60,
#      #  'plan'      => 'retriable',
#      #},
#    ],
    
    #you must create a service definition. An example of a service definition
    #would be a dial-up account or a domain. First, it is necessary to create a
    #domain definition. Click on View/Edit service definitions and Add a new
    #service definition with Table svc_domain (and no modifiers).
    'part_svc' => [
      { 'svc'   => 'Domain',
        'svcdb' => 'svc_domain',
      }
    ],

    #Now that you have created your first service, you must create a package
    #including this service which you can sell to customers. Zero, one, or many
    #services are bundled into a package. Click on View/Edit package
    #definitions and Add a new package definition which includes quantity 1 of
    #the svc_domain service you created above.
    'part_pkg' => [
      { 'pkg'     => 'System Domain',
        'comment' => '(NOT FOR CUSTOMERS)',
        'freq'    => '0',
        'plan'    => 'flat',
        '_insert_args' => [
          'pkg_svc'     => { 1 => 1 }, # XXX
          'primary_svc' => 1, #XXX
          'options'     => {
            'setup_fee' => '0',
            'recur_fee' => '0',
          },
        ],
      },
    ],

    #After you create your first package, then you must define who is able to
    #sell that package by creating an agent type. An example of an agent type
    #would be an internal sales representitive which sells regular and
    #promotional packages, as opposed to an external sales representitive
    #which would only sell regular packages of services. Click on View/Edit
    #agent types and Add a new agent type.
    'agent_type' => [
      { 'atype' => 'Internal' },
    ],

    #Allow this agent type to sell the package you created above.
    'type_pkgs' => [
      { 'typenum' => 1, #XXX
        'pkgpart' => 1, #XXX
      },
    ],

    #After creating a new agent type, you must create an agent. Click on
    #View/Edit agents and Add a new agent.
    'agent' => [
      { 'agent'   => 'Internal',
        'typenum' => 1, # XXX
      },
    ],

    #Set up at least one Advertising source. Advertising sources will help you
    #keep track of how effective your advertising is, tracking where customers
    #heard of your service offerings. You must create at least one advertising
    #source. If you do not wish to use the referral functionality, simply
    #create a single advertising source only. Click on View/Edit advertising
    #sources and Add a new advertising source.
    'part_referral' => [
      { 'referral' => 'Internal', },
    ],
    
    #Click on New Customer and create a new customer for your system accounts
    #with billing type Complimentary. Leave the First package dropdown set to
    #(none).
    'cust_main' => [
      { 'agentnum'  => 1, #XXX
        'refnum'    => 1, #XXX
        'first'     => 'System',
        'last'      => 'Accounts',
        'payby'     => 'COMP',
        'payinfo'   => 'system', #or something
        'paydate'   => '1/2037',
        'bill_location' => $cust_location,
        'ship_location' => $cust_location,
      },
    ],

    #From the Customer View screen of the newly created customer, order the
    #package you defined above.
    'cust_pkg' => [
      { 'custnum' => 1, #XXX
        'pkgpart' => 1, #XXX
      },
    ],

    #From the Package View screen of the newly created package, choose
    #(Provision) to add the customer's service for this new package.
    #Add your own domain.
    'svc_domain' => [
      { 'domain'  => $opt{'domain'},
        'pkgnum'  => 1, #XXX
        'svcpart' => 1, #XXX
        'action'  => 'N', #pseudo-field
      },
    ],

    #Go back to View/Edit service definitions on the main menu, and Add a new
    #service definition with Table svc_acct. Select your domain in the domsvc
    #Modifier. Set Fixed to define a service locked-in to this domain, or
    #Default to define a service which may select from among this domain and
    #the customer's domains.

    #not yet....

    #usage classes
    'usage_class' => [],

    #phone types
    'phone_type' => [],

    #message templates
    'msg_template' => [],

  ;

  \%hash;

}

sub populate_access {

  foreach my $rightname ( FS::AccessRight->default_superuser_rights ) {
    my $access_right = new FS::access_right {
      'righttype'   => 'FS::access_group',
      'rightobjnum' => 1, #$supergroup->groupnum,
      'rightname'   => $rightname,
    };
    my $ar_error = $access_right->insert;
    die $ar_error if $ar_error;
  }

  #foreach my $agent ( qsearch('agent', {} ) ) {
    my $access_groupagent = new FS::access_groupagent {
      'groupnum' => 1, #$supergroup->groupnum,
      'agentnum' => 1, #$agent->agentnum,
    };
    my $aga_error = $access_groupagent->insert;
    die $aga_error if $aga_error;
  #}

}

sub populate_msgcat {

  foreach my $del_msgcat ( qsearch('msgcat', {}) ) {
    my $error = $del_msgcat->delete;
    die $error if $error;
  }

  my %messages = FS::msgcat::_legacy_messages();

  foreach my $msgcode ( keys %messages ) {
    foreach my $locale ( keys %{$messages{$msgcode}} ) {
      my $msgcat = new FS::msgcat( {
        'msgcode' => $msgcode,
        'locale'  => $locale,
        'msg'     => $messages{$msgcode}{$locale},
      });
      my $error = $msgcat->insert;
      die $error if $error;
    }
  }

}

=back

=head1 BUGS

Sure.

=head1 SEE ALSO

=cut

1;

