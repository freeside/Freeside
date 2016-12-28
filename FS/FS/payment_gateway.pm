package FS::payment_gateway;
use base qw( FS::option_Common );

use strict;
use vars qw( $me $DEBUG );
use FS::Record qw( qsearch dbh ); #qw( qsearch qsearchs dbh );

$me = '[ FS::payment_gateway ]';
$DEBUG=0;

=head1 NAME

FS::payment_gateway - Object methods for payment_gateway records

=head1 SYNOPSIS

  use FS::payment_gateway;

  $record = new FS::payment_gateway \%hash;
  $record = new FS::payment_gateway { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::payment_gateway object represents an payment gateway.
FS::payment_gateway inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item gatewaynum - primary key

=item gateway_namespace - Business::OnlinePayment, Business::OnlineThirdPartyPayment, or Business::BatchPayment

=item gateway_module - Business::OnlinePayment:: (or other) module name

=item gateway_username - payment gateway username

=item gateway_password - payment gateway password

=item gateway_action - optional action or actions (multiple actions are separated with `,': for example: `Authorization Only, Post Authorization').  Defaults to `Normal Authorization'.

=item disabled - Disabled flag, empty or 'Y'

=item gateway_callback_url - For ThirdPartyPayment only, set to the URL that 
the user should be redirected to on a successful payment.  This will be sent
as a transaction parameter named "return_url".

=item gateway_cancel_url - For ThirdPartyPayment only, set to the URL that 
the user should be redirected to if they cancel the transaction.  This will 
be sent as a transaction parameter named "cancel_url".

=item auto_resolve_status - For BatchPayment only, set to 'approve' to 
auto-approve unresolved payments after some number of days, 'reject' to 
auto-decline them, or null to do nothing.

=item auto_resolve_days - For BatchPayment, the number of days to wait before 
auto-resolving the batch.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new payment gateway.  To add the payment gateway to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'payment_gateway'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid payment gateway.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('gatewaynum')
    || $self->ut_alpha('gateway_module')
    || $self->ut_enum('gateway_namespace', ['Business::OnlinePayment',
                                            'Business::OnlineThirdPartyPayment',
                                            'Business::BatchPayment',
                                           ] )
    || $self->ut_textn('gateway_username')
    || $self->ut_anything('gateway_password')
    || $self->ut_textn('gateway_callback_url')  # a bit too permissive
    || $self->ut_textn('gateway_cancel_url')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
    || $self->ut_enum('auto_resolve_status', [ '', 'approve', 'reject' ])
    || $self->ut_numbern('auto_resolve_days')
    #|| $self->ut_textn('gateway_action')
  ;
  return $error if $error;

  if ( $self->gateway_namespace eq 'Business::BatchPayment' ) {
    $self->gateway_action('Payment');
  } elsif ( $self->gateway_action ) {
    my @actions = split(/,\s*/, $self->gateway_action);
    $self->gateway_action(
      join( ',', map { /^(Normal Authorization|Authorization Only|Credit|Post Authorization)$/
                         or return "Unknown action $_";
                       $1
                     }
                     @actions
          )
   );
  } else {
    $self->gateway_action('Normal Authorization');
  }

  # this little kludge mimics FS::CGI::popurl
  #$self->gateway_callback_url($self->gateway_callback_url. '/')
  #  if ( $self->gateway_callback_url && $self->gateway_callback_url !~ /\/$/ );

  $self->SUPER::check;
}

=item agent_payment_gateway

Returns any agent overrides for this payment gateway.

=item disable

Disables this payment gateway: deletes all associated agent_payment_gateway
overrides and sets the I<disabled> field to "B<Y>".

=cut

sub disable {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $agent_payment_gateway ( $self->agent_payment_gateway ) {
    my $error = $agent_payment_gateway->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error deleting agent_payment_gateway override: $error";
    }
  }

  $self->disabled('Y');
  my $error = $self->replace();
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "error disabling payment_gateway: $error";
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item label

Returns a semi-friendly label for the gateway.

=cut

sub label {
  my $self = shift;
  $self->gatewaynum . ': ' . 
  ($self->gateway_username ? $self->gateway_username . '@' : '') . 
  $self->gateway_module
}

=item namespace_description

returns a friendly name for the namespace

=cut

my %namespace2description = (
  '' => 'Direct',
  'Business::OnlinePayment' => 'Direct',
  'Business::OnlineThirdPartyPayment' => 'Hosted',
  'Business::BatchPayment' => 'Batch',
);

sub namespace_description {
  $namespace2description{shift->gateway_namespace} || 'Unknown';
}

=item batch_processor OPTIONS

For BatchPayment gateways only.  Returns a 
L<Business::BatchPayment::Processor> object to communicate with the 
gateway.

OPTIONS will be passed to the constructor, along with any gateway 
options in the database for this L<FS::payment_gateway>.  Useful things
to include there may include 'input' and 'output' (to direct transport
to files), 'debug', and 'test_mode'.

If the global 'business-batchpayment-test_transaction' flag is set, 
'test_mode' will be forced on, and gateways that don't support test
mode will be disabled.

=cut

sub batch_processor {
  local $@;
  my $self = shift;
  my %opt = @_;
  my $batch = $opt{batch};
  my $output = $opt{output};
  die 'gateway '.$self->gatewaynum.' is not a Business::BatchPayment gateway'
    unless $self->gateway_namespace eq 'Business::BatchPayment';
  eval "use Business::BatchPayment;";
  die "couldn't load Business::BatchPayment: $@" if $@;

  #false laziness with processor
  foreach (qw(username password)) {
    if (length($self->get("gateway_$_"))) {
      $opt{$_} = $self->get("gateway_$_");
    }
  }

  my $module = $self->gateway_module;
  my $processor = eval { 
    Business::BatchPayment->create($module, $self->options, %opt)
  };
  die "failed to create Business::BatchPayment::$module object: $@"
    if $@;

  die "$module does not support test mode"
    if $opt{'test_mode'}
      and not $processor->does('Business::BatchPayment::TestMode');

  return $processor;
}

=item processor OPTIONS

Loads the module for the processor and returns an instance of it.

=cut

sub processor {
  local $@;
  my $self = shift;
  my %opt = @_;
  foreach (qw(action username password)) {
    if (length($self->get("gateway_$_"))) {
      $opt{$_} = $self->get("gateway_$_");
    }
  }
  $opt{'return_url'} = $self->gateway_callback_url;
  $opt{'cancel_url'} = $self->gateway_cancel_url;

  my $conf = new FS::Conf;
  my $test_mode = $conf->exists('business-batchpayment-test_transaction');
  $opt{'test_mode'} = 1 if $test_mode;

  my $namespace = $self->gateway_namespace;
  eval "use $namespace";
  die "couldn't load $namespace: $@" if $@;

  if ( $namespace eq 'Business::BatchPayment' ) {
    # at some point we can merge these, but there's enough special behavior...
    return $self->batch_processor(%opt);
  } else {
    return $namespace->new( $self->gateway_module, $self->options, %opt );
  }
}

=item default_gateway OPTIONS

Class method.

Returns default gateway (from business-onlinepayment conf) as a payment_gateway object.

Accepts options

conf - existing conf object

nofatal - return blank instead of dying if no default gateway is configured

method - if set to CHEK or ECHECK, returns object for business-onlinepayment-ach if available

Before using this, be sure you wouldn't rather be using L</by_key_or_default> or,
more likely, L<FS::agent/payment_gateway>.

=cut

# the standard settings from the config could be moved to a null agent
# agent_payment_gateway referenced payment_gateway

sub default_gateway {
  my ($self,%options) = @_;

  $options{'conf'} ||= new FS::Conf;
  my $conf = $options{'conf'};

  unless ( $conf->exists('business-onlinepayment') ) {
    if ( $options{'nofatal'} ) {
      return '';
    } else {
      die "Real-time processing not enabled\n";
    }
  }

  #load up config
  my $bop_config = 'business-onlinepayment';
  $bop_config .= '-ach'
    if ( $options{method}
         && $options{method} =~ /^(ECHECK|CHEK)$/
         && $conf->exists($bop_config. '-ach')
       );
  my ( $processor, $login, $password, $action, @bop_options ) =
    $conf->config($bop_config);
  $action ||= 'normal authorization';
  pop @bop_options if scalar(@bop_options) % 2 && $bop_options[-1] =~ /^\s*$/;
  die "No real-time processor is enabled - ".
      "did you set the business-onlinepayment configuration value?\n"
    unless $processor;

  my $payment_gateway = new FS::payment_gateway;
  $payment_gateway->gateway_namespace( $conf->config('business-onlinepayment-namespace') ||
                                       'Business::OnlinePayment');
  $payment_gateway->gateway_module($processor);
  $payment_gateway->gateway_username($login);
  $payment_gateway->gateway_password($password);
  $payment_gateway->gateway_action($action);
  $payment_gateway->set('options', [ @bop_options ]);
  return $payment_gateway;
}

=item by_key_with_namespace GATEWAYNUM

Like usual by_key, but makes sure namespace is set,
and dies if not found.

=cut

sub by_key_with_namespace {
  my $self = shift;
  my $payment_gateway = $self->by_key(@_);
  die "payment_gateway not found"
    unless $payment_gateway;
  $payment_gateway->gateway_namespace('Business::OnlinePayment')
    unless $payment_gateway->gateway_namespace;
  return $payment_gateway;
}

=item by_key_or_default OPTIONS

Either returns the gateway specified by option gatewaynum, or the default gateway.

Accepts the same options as L</default_gateway>.

Also ensures that the gateway_namespace has been set.

=cut

sub by_key_or_default {
  my ($self,%options) = @_;

  if ($options{'gatewaynum'}) {
    return $self->by_key_with_namespace($options{'gatewaynum'});
  } else {
    return $self->default_gateway(%options);
  }
}

# if it weren't for the way gateway_namespace default is set, this method would not be necessary
# that should really go in check() with an accompanying upgrade, so we could just use qsearch safely,
# but currently short on time to test deeper changes...
#
# if no default gateway is set and nofatal is passed, first value returned is blank string
sub all_gateways {
  my ($self,%options) = @_;
  my @out;
  foreach my $gatewaynum ('',( map {$_->gatewaynum} qsearch('payment_gateway') )) {
    push @out, $self->by_key_or_default( %options, gatewaynum => $gatewaynum );
  }
  return @out;
}

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.
#
#

sub _upgrade_data {
  my ($class, %opts) = @_;
  my $dbh = dbh;

  warn "$me upgrading $class\n" if $DEBUG;

  foreach ( qsearch( 'payment_gateway', { 'gateway_namespace' => '' } ) ) {
    $_->gateway_namespace('Business::OnlinePayment');  #defaulting
    my $error = $_->replace;
    die "$class had error during upgrade replacement: $error" if $error;
  }
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

