package FS::Conf;

use vars qw($base_dir @config_items @base_items @card_types $DEBUG);
use Carp;
use IO::File;
use File::Basename;
use MIME::Base64;
use FS::ConfItem;
use FS::ConfDefaults;
use FS::Conf_compat17;
use FS::Locales;
use FS::payby;
use FS::conf;
use FS::Record qw(qsearch qsearchs);
use FS::UID qw(dbh datasrc use_confcompat);

$base_dir = '%%%FREESIDE_CONF%%%';

$DEBUG = 0;

=head1 NAME

FS::Conf - Freeside configuration values

=head1 SYNOPSIS

  use FS::Conf;

  $conf = new FS::Conf;

  $value = $conf->config('key');
  @list  = $conf->config('key');
  $bool  = $conf->exists('key');

  $conf->touch('key');
  $conf->set('key' => 'value');
  $conf->delete('key');

  @config_items = $conf->config_items;

=head1 DESCRIPTION

Read and write Freeside configuration values.  Keys currently map to filenames,
but this may change in the future.

=head1 METHODS

=over 4

=item new [ HASHREF ]

Create a new configuration object.

HASHREF may contain options to set the configuration context.  Currently 
accepts C<locale>, and C<localeonly> to disable fallback to the null locale.

=cut

sub new {
  my($proto) = shift;
  my $opts = shift || {};
  my($class) = ref($proto) || $proto;
  my $self = {
    'base_dir'    => $base_dir,
    'locale'      => $opts->{locale},
    'localeonly'  => $opts->{localeonly}, # for config-view.cgi ONLY
  };
  warn "FS::Conf created with no locale fallback.\n" if $self->{localeonly};
  bless ($self, $class);
}

=item base_dir

Returns the base directory.  By default this is /usr/local/etc/freeside.

=cut

sub base_dir {
  my($self) = @_;
  my $base_dir = $self->{base_dir};
  -e $base_dir or die "FATAL: $base_dir doesn't exist!";
  -d $base_dir or die "FATAL: $base_dir isn't a directory!";
  -r $base_dir or die "FATAL: Can't read $base_dir!";
  -x $base_dir or die "FATAL: $base_dir not searchable (executable)!";
  $base_dir =~ /^(.*)$/;
  $1;
}

=item conf KEY [ AGENTNUM [ NODEFAULT ] ]

Returns the L<FS::conf> record for the key and agent.

=cut

sub conf {
  my $self = shift;
  $self->_config(@_);
}

=item config KEY [ AGENTNUM [ NODEFAULT ] ]

Returns the configuration value or values (depending on context) for key.
The optional agent number selects an agent specific value instead of the
global default if one is present.  If NODEFAULT is true only the agent
specific value(s) is returned.

=cut

sub _usecompat {
  my ($self, $method) = (shift, shift);
  carp "NO CONFIGURATION RECORDS FOUND -- USING COMPATIBILITY MODE"
    if use_confcompat;
  my $compat = new FS::Conf_compat17 ("$base_dir/conf." . datasrc);
  $compat->$method(@_);
}

sub _config {
  my($self,$name,$agentnum,$agentonly)=@_;
  my $hashref = { 'name' => $name };
  local $FS::Record::conf = undef;  # XXX evil hack prevents recursion
  my $cv;
  my @a = (
    ($agentnum || ()),
    ($agentonly && $agentnum ? () : '')
  );
  my @l = (
    ($self->{locale} || ()),
    ($self->{localeonly} && $self->{locale} ? () : '')
  );
  # try with the agentnum first, then fall back to no agentnum if allowed
  foreach my $a (@a) {
    $hashref->{agentnum} = $a;
    foreach my $l (@l) {
      $hashref->{locale} = $l;
      $cv = FS::Record::qsearchs('conf', $hashref);
      return $cv if $cv;
    }
  }
  return undef;
}

sub config {
  my $self = shift;
  return $self->_usecompat('config', @_) if use_confcompat;

  carp "FS::Conf->config(". join(', ', @_). ") called"
    if $DEBUG > 1;

  my $cv = $self->_config(@_) or return;

  if ( wantarray ) {
    my $v = $cv->value;
    chomp $v;
    (split "\n", $v, -1);
  } else {
    (split("\n", $cv->value))[0];
  }
}

=item config_binary KEY [ AGENTNUM [ NODEFAULT ] ]

Returns the exact scalar value for key.

=cut

sub config_binary {
  my $self = shift;
  return $self->_usecompat('config_binary', @_) if use_confcompat;

  my $cv = $self->_config(@_) or return;
  length($cv->value) ? decode_base64($cv->value) : '';
}

=item exists KEY [ AGENTNUM [ NODEFAULT ] ]

Returns true if the specified key exists, even if the corresponding value
is undefined.

=cut

sub exists {
  my $self = shift;
  return $self->_usecompat('exists', @_) if use_confcompat;

  my($name, $agentnum)=@_;

  carp "FS::Conf->exists(". join(', ', @_). ") called"
    if $DEBUG > 1;

  defined($self->_config(@_));
}

=item config_orbase KEY SUFFIX

Returns the configuration value or values (depending on context) for 
KEY_SUFFIX, if it exists, otherwise for KEY

=cut

# outmoded as soon as we shift to agentnum based config values
# well, mostly.  still useful for e.g. late notices, etc. in that we want
# these to fall back to standard values
sub config_orbase {
  my $self = shift;
  return $self->_usecompat('config_orbase', @_) if use_confcompat;

  my( $name, $suffix ) = @_;
  if ( $self->exists("${name}_$suffix") ) {
    $self->config("${name}_$suffix");
  } else {
    $self->config($name);
  }
}

=item key_orbase KEY SUFFIX

If the config value KEY_SUFFIX exists, returns KEY_SUFFIX, otherwise returns
KEY.  Useful for determining which exact configuration option is returned by
config_orbase.

=cut

sub key_orbase {
  my $self = shift;
  #no compat for this...return $self->_usecompat('config_orbase', @_) if use_confcompat;

  my( $name, $suffix ) = @_;
  if ( $self->exists("${name}_$suffix") ) {
    "${name}_$suffix";
  } else {
    $name;
  }
}

=item invoice_templatenames

Returns all possible invoice template names.

=cut

sub invoice_templatenames {
  my( $self ) = @_;

  my %templatenames = ();
  foreach my $item ( $self->config_items ) {
    foreach my $base ( @base_items ) {
      my( $main, $ext) = split(/\./, $base);
      $ext = ".$ext" if $ext;
      if ( $item->key =~ /^${main}_(.+)$ext$/ ) {
      $templatenames{$1}++;
      }
    }
  }
  
  map { $_ } #handle scalar context
  sort keys %templatenames;

}

=item touch KEY [ AGENT ];

Creates the specified configuration key if it does not exist.

=cut

sub touch {
  my $self = shift;
  return $self->_usecompat('touch', @_) if use_confcompat;

  my($name, $agentnum) = @_;
  unless ( $self->exists($name, $agentnum) ) {
    $self->set($name, '', $agentnum);
  }
}

=item set KEY VALUE [ AGENTNUM ];

Sets the specified configuration key to the given value.

=cut

sub set {
  my $self = shift;
  return $self->_usecompat('set', @_) if use_confcompat;

  my($name, $value, $agentnum) = @_;
  $value =~ /^(.*)$/s;
  $value = $1;

  warn "[FS::Conf] SET $name\n" if $DEBUG;

  my $hashref = {
    name => $name,
    agentnum => $agentnum,
    locale => $self->{locale}
  };

  my $old = FS::Record::qsearchs('conf', $hashref);
  my $new = new FS::conf { $old ? $old->hash : %$hashref };
  $new->value($value);

  my $error;
  if ($old) {
    $error = $new->replace($old);
  } else {
    $error = $new->insert;
  }

  die "error setting configuration value: $error \n"
    if $error;

}

=item set_binary KEY VALUE [ AGENTNUM ]

Sets the specified configuration key to an exact scalar value which
can be retrieved with config_binary.

=cut

sub set_binary {
  my $self  = shift;
  return if use_confcompat;

  my($name, $value, $agentnum)=@_;
  $self->set($name, encode_base64($value), $agentnum);
}

=item delete KEY [ AGENTNUM ];

Deletes the specified configuration key.

=cut

sub delete {
  my $self = shift;
  return $self->_usecompat('delete', @_) if use_confcompat;

  my($name, $agentnum) = @_;
  if ( my $cv = FS::Record::qsearchs('conf', {name => $name, agentnum => $agentnum, locale => $self->{locale}}) ) {
    warn "[FS::Conf] DELETE $name\n" if $DEBUG;

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;

    my $error = $cv->delete;

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      die "error setting configuration value: $error \n"
    }

    $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  }
}

=item import_config_item CONFITEM DIR 

  Imports the item specified by the CONFITEM (see L<FS::ConfItem>) into
the database as a conf record (see L<FS::conf>).  Imports from the file
in the directory DIR.

=cut

sub import_config_item { 
  my ($self,$item,$dir) = @_;
  my $key = $item->key;
  if ( -e "$dir/$key" && ! use_confcompat ) {
    warn "Inserting $key\n" if $DEBUG;
    local $/;
    my $value = readline(new IO::File "$dir/$key");
    if ($item->type =~ /^(binary|image)$/ ) {
      $self->set_binary($key, $value);
    }else{
      $self->set($key, $value);
    }
  }else {
    warn "Not inserting $key\n" if $DEBUG;
  }
}

=item verify_config_item CONFITEM DIR 

  Compares the item specified by the CONFITEM (see L<FS::ConfItem>) in
the database to the legacy file value in DIR.

=cut

sub verify_config_item { 
  return '' if use_confcompat;
  my ($self,$item,$dir) = @_;
  my $key = $item->key;
  my $type = $item->type;

  my $compat = new FS::Conf_compat17 $dir;
  my $error = '';
  
  $error .= "$key fails existential comparison; "
    if $self->exists($key) xor $compat->exists($key);

  if ( $type !~ /^(binary|image)$/ ) {

    {
      no warnings;
      $error .= "$key fails scalar comparison; "
        unless scalar($self->config($key)) eq scalar($compat->config($key));
    }

    my (@new) = $self->config($key);
    my (@old) = $compat->config($key);
    unless ( scalar(@new) == scalar(@old)) { 
      $error .= "$key fails list comparison; ";
    }else{
      my $r=1;
      foreach (@old) { $r=0 if ($_ cmp shift(@new)); }
      $error .= "$key fails list comparison; "
        unless $r;
    }

  } else {

    no warnings 'uninitialized';
    $error .= "$key fails binary comparison; "
      unless scalar($self->config_binary($key)) eq scalar($compat->config_binary($key));

  }

#remove deprecated config on our own terms, not freeside-upgrade's
#  if ($error =~ /existential comparison/ && $item->section eq 'deprecated') {
#    my $proto;
#    for ( @config_items ) { $proto = $_; last if $proto->key eq $key;  }
#    unless ($proto->key eq $key) { 
#      warn "removed config item $error\n" if $DEBUG;
#      $error = '';
#    }
#  }

  $error;
}

#item _orbase_items OPTIONS
#
#Returns all of the possible extensible config items as FS::ConfItem objects.
#See #L<FS::ConfItem>.  OPTIONS consists of name value pairs.  Possible
#options include
#
# dir - the directory to search for configuration option files instead
#       of using the conf records in the database
#
#cut

#quelle kludge
sub _orbase_items {
  my ($self, %opt) = @_; 

  my $listmaker = sub { my $v = shift;
                        $v =~ s/_/!_/g;
                        if ( $v =~ /\.(png|eps)$/ ) {
                          $v =~ s/\./!_%./;
                        }else{
                          $v .= '!_%';
                        }
                        map { $_->name }
                          FS::Record::qsearch( 'conf',
                                               {},
                                               '',
                                               "WHERE name LIKE '$v' ESCAPE '!'"
                                             );
                      };

  if (exists($opt{dir}) && $opt{dir}) {
    $listmaker = sub { my $v = shift;
                       if ( $v =~ /\.(png|eps)$/ ) {
                         $v =~ s/\./_*./;
                       }else{
                         $v .= '_*';
                       }
                       map { basename $_ } glob($opt{dir}. "/$v" );
                     };
  }

  ( map { 
          my $proto;
          my $base = $_;
          for ( @config_items ) { $proto = $_; last if $proto->key eq $base;  }
          die "don't know about $base items" unless $proto->key eq $base;

          map { new FS::ConfItem { 
                  'key'         => $_,
                  'base_key'    => $proto->key,
                  'section'     => $proto->section,
                  'description' => 'Alternate ' . $proto->description . '  See the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:2.1:Documentation:Administration#Invoice_templates">billing documentation</a> for details.',
                  'type'        => $proto->type,
                };
              } &$listmaker($base);
        } @base_items,
  );
}

=item config_items

Returns all of the possible global/default configuration items as
FS::ConfItem objects.  See L<FS::ConfItem>.

=cut

sub config_items {
  my $self = shift; 
  return $self->_usecompat('config_items', @_) if use_confcompat;

  ( @config_items, $self->_orbase_items(@_) );
}

=back

=head1 SUBROUTINES

=over 4

=item init-config DIR

Imports the configuration items from DIR (1.7 compatible)
to conf records in the database.

=cut

sub init_config {
  my $dir = shift;

  {
    local $FS::UID::use_confcompat = 0;
    my $conf = new FS::Conf;
    foreach my $item ( $conf->config_items(dir => $dir) ) {
      $conf->import_config_item($item, $dir);
      my $error = $conf->verify_config_item($item, $dir);
      return $error if $error;
    }
  
    my $compat = new FS::Conf_compat17 $dir;
    foreach my $item ( $compat->config_items ) {
      my $error = $conf->verify_config_item($item, $dir);
      return $error if $error;
    }
  }

  $FS::UID::use_confcompat = 0;
  '';  #success
}

=back

=head1 BUGS

If this was more than just crud that will never be useful outside Freeside I'd
worry that config_items is freeside-specific and icky.

=head1 SEE ALSO

"Configuration" in the web interface (config/config.cgi).

=cut

#Business::CreditCard
@card_types = (
  "VISA card",
  "MasterCard",
  "Discover card",
  "American Express card",
  "Diner's Club/Carte Blanche",
  "enRoute",
  "JCB",
  "BankCard",
  "Switch",
  "Solo",
);

@base_items = qw(
invoice_template
invoice_latex
invoice_latexreturnaddress
invoice_latexfooter
invoice_latexsmallfooter
invoice_latexnotes
invoice_latexcoupon
invoice_html
invoice_htmlreturnaddress
invoice_htmlfooter
invoice_htmlnotes
logo.png
logo.eps
);

my %msg_template_options = (
  'type'        => 'select-sub',
  'options_sub' => sub { 
    my @templates = qsearch({
        'table' => 'msg_template', 
        'hashref' => { 'disabled' => '' },
        'extra_sql' => ' AND '. 
          $FS::CurrentUser::CurrentUser->agentnums_sql(null => 1),
        });
    map { $_->msgnum, $_->msgname } @templates;
  },
  'option_sub'  => sub { 
                         my $msg_template = FS::msg_template->by_key(shift);
                         $msg_template ? $msg_template->msgname : ''
                       },
  'per_agent' => 1,
);

my $_gateway_name = sub {
  my $g = shift;
  return '' if !$g;
  ($g->gateway_username . '@' . $g->gateway_module);
};

my %payment_gateway_options = (
  'type'        => 'select-sub',
  'options_sub' => sub {
    my @gateways = qsearch({
        'table' => 'payment_gateway',
        'hashref' => { 'disabled' => '' },
      });
    map { $_->gatewaynum, $_gateway_name->($_) } @gateways;
  },
  'option_sub'  => sub {
    my $gateway = FS::payment_gateway->by_key(shift);
    $_gateway_name->($gateway);
  },
);

#Billing (81 items)
#Invoicing (50 items)
#UI (69 items)
#Self-service (29 items)
#...
#Unclassified (77 items)

@config_items = map { new FS::ConfItem $_ } (

  {
    'key'         => 'address',
    'section'     => 'deprecated',
    'description' => 'This configuration option is no longer used.  See <a href="#invoice_template">invoice_template</a> instead.',
    'type'        => 'text',
  },

  {
    'key'         => 'log_sent_mail',
    'section'     => 'notification',
    'description' => 'Enable logging of template-generated email.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'alert_expiration',
    'section'     => 'notification',
    'description' => 'Enable alerts about billing method expiration (i.e. expiring credit cards).',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'alerter_template',
    'section'     => 'deprecated',
    'description' => 'Template file for billing method expiration alerts (i.e. expiring credit cards).',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },
  
  {
    'key'         => 'alerter_msgnum',
    'section'     => 'notification',
    'description' => 'Template to use for credit card expiration alerts.',
    %msg_template_options,
  },

  {
    'key'         => 'apacheip',
    #not actually deprecated yet
    #'section'     => 'deprecated',
    #'description' => '<b>DEPRECATED</b>, add an <i>apache</i> <a href="../browse/part_export.cgi">export</a> instead.  Used to be the current IP address to assign to new virtual hosts',
    'section'     => '',
    'description' => 'IP address to assign to new virtual hosts',
    'type'        => 'text',
  },
  
  {
    'key'         => 'credits-auto-apply-disable',
    'section'     => 'billing',
    'description' => 'Disable the "Auto-Apply to invoices" UI option for new credits',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'credit-card-surcharge-percentage',
    'section'     => 'billing',
    'description' => 'Add a credit card surcharge to invoices, as a % of the invoice total. WARNING: this is usually prohibited by merchant account / other agreements and/or law, but is currently lawful in AU and UK.',
    'type'        => 'text',
  },

  {
    'key'         => 'discount-show-always',
    'section'     => 'billing',
    'description' => 'Generate a line item on an invoice even when a package is discounted 100%',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'discount-show_available',
    'section'     => 'billing',
    'description' => 'Show available prepayment discounts on invoices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice-barcode',
    'section'     => 'billing',
    'description' => 'Display a barcode on HTML and PDF invoices',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'cust_main-select-billday',
    'section'     => 'billing',
    'description' => 'When used with a specific billing event, allows the selection of the day of month on which to charge credit card / bank account automatically, on a per-customer basis',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'encryption',
    'section'     => 'billing',
    'description' => 'Enable encryption of credit cards and echeck numbers',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'encryptionmodule',
    'section'     => 'billing',
    'description' => 'Use which module for encryption?',
    'type'        => 'select',
    'select_enum' => [ '', 'Crypt::OpenSSL::RSA', ],
  },

  {
    'key'         => 'encryptionpublickey',
    'section'     => 'billing',
    'description' => 'Encryption public key',
    'type'        => 'textarea',
  },

  {
    'key'         => 'encryptionprivatekey',
    'section'     => 'billing',
    'description' => 'Encryption private key',
    'type'        => 'textarea',
  },

  {
    'key'         => 'billco-url',
    'section'     => 'billing',
    'description' => 'The url to use for performing uploads to the invoice mailing service.',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'billco-username',
    'section'     => 'billing',
    'description' => 'The login name to use for uploads to the invoice mailing service.',
    'type'        => 'text',
    'per_agent'   => 1,
    'agentonly'   => 1,
  },

  {
    'key'         => 'billco-password',
    'section'     => 'billing',
    'description' => 'The password to use for uploads to the invoice mailing service.',
    'type'        => 'text',
    'per_agent'   => 1,
    'agentonly'   => 1,
  },

  {
    'key'         => 'billco-clicode',
    'section'     => 'billing',
    'description' => 'The clicode to use for uploads to the invoice mailing service.',
    'type'        => 'text',
    'per_agent'   => 1,
  },
  
  {
    'key'         => 'next-bill-ignore-time',
    'section'     => 'billing',
    'description' => 'Ignore the time portion of next bill dates when billing, matching anything from 00:00:00 to 23:59:59 on the billing day.',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'business-onlinepayment',
    'section'     => 'billing',
    'description' => '<a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> support, at least three lines: processor, login, and password.  An optional fourth line specifies the action or actions (multiple actions are separated with `,\': for example: `Authorization Only, Post Authorization\').    Optional additional lines are passed to Business::OnlinePayment as %processor_options.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'business-onlinepayment-ach',
    'section'     => 'billing',
    'description' => 'Alternate <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> support for ACH transactions (defaults to regular <b>business-onlinepayment</b>).  At least three lines: processor, login, and password.  An optional fourth line specifies the action or actions (multiple actions are separated with `,\': for example: `Authorization Only, Post Authorization\').    Optional additional lines are passed to Business::OnlinePayment as %processor_options.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'business-onlinepayment-namespace',
    'section'     => 'billing',
    'description' => 'Specifies which perl module namespace (which group of collection routines) is used by default.',
    'type'        => 'select',
    'select_hash' => [
                       'Business::OnlinePayment' => 'Direct API (Business::OnlinePayment)',
		       'Business::OnlineThirdPartyPayment' => 'Web API (Business::ThirdPartyPayment)',
                     ],
  },

  {
    'key'         => 'business-onlinepayment-description',
    'section'     => 'billing',
    'description' => 'String passed as the description field to <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a>.  Evaluated as a double-quoted perl string, with the following variables available: <code>$agent</code> (the agent name), and <code>$pkgs</code> (a comma-separated list of packages for which these charges apply - not available in all situations)',
    'type'        => 'text',
  },

  {
    'key'         => 'business-onlinepayment-email-override',
    'section'     => 'billing',
    'description' => 'Email address used instead of customer email address when submitting a BOP transaction.',
    'type'        => 'text',
  },

  {
    'key'         => 'business-onlinepayment-email_customer',
    'section'     => 'billing',
    'description' => 'Controls the "email_customer" flag used by some Business::OnlinePayment processors to enable customer receipts.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'business-onlinepayment-test_transaction',
    'section'     => 'billing',
    'description' => 'Turns on the Business::OnlinePayment test_transaction flag.  Note that not all gateway modules support this flag; if yours does not, transactions will still be sent live.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'business-onlinepayment-currency',
    'section'     => 'billing',
    'description' => 'Currency parameter for Business::OnlinePayment transactions.',
    'type'        => 'select',
    'select_enum' => [ '', qw( USD AUD CAD DKK EUR GBP ILS JPY NZD ) ],
  },

  {
    'key'         => 'countrydefault',
    'section'     => 'UI',
    'description' => 'Default two-letter country code (if not supplied, the default is `US\')',
    'type'        => 'text',
  },

  {
    'key'         => 'date_format',
    'section'     => 'UI',
    'description' => 'Format for displaying dates',
    'type'        => 'select',
    'select_hash' => [
                       '%m/%d/%Y' => 'MM/DD/YYYY',
                       '%d/%m/%Y' => 'DD/MM/YYYY',
		       '%Y/%m/%d' => 'YYYY/MM/DD',
                     ],
  },

  {
    'key'         => 'date_format_long',
    'section'     => 'UI',
    'description' => 'Verbose format for displaying dates',
    'type'        => 'select',
    'select_hash' => [
                       '%b %o, %Y' => 'Mon DDth, YYYY',
                       '%e %b %Y'  => 'DD Mon YYYY',
                     ],
  },

  {
    'key'         => 'deletecustomers',
    'section'     => 'UI',
    'description' => 'Enable customer deletions.  Be very careful!  Deleting a customer will remove all traces that the customer ever existed!  It should probably only be used when auditing a legacy database.  Normally, you cancel all of a customers\' packages if they cancel service.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'deleteinvoices',
    'section'     => 'UI',
    'description' => 'Enable invoices deletions.  Be very careful!  Deleting an invoice will remove all traces that the invoice ever existed!  Normally, you would apply a credit against the invoice instead.',  #invoice voiding?
    'type'        => 'checkbox',
  },

  {
    'key'         => 'deletepayments',
    'section'     => 'billing',
    'description' => 'Enable deletion of unclosed payments.  Really, with voids this is pretty much not recommended in any situation anymore.  Be very careful!  Only delete payments that were data-entry errors, not adjustments.  Optionally specify one or more comma-separated email addresses to be notified when a payment is deleted.',
    'type'        => [qw( checkbox text )],
  },

  {
    'key'         => 'deletecredits',
    #not actually deprecated yet
    #'section'     => 'deprecated',
    #'description' => '<B>DEPRECATED</B>, now controlled by ACLs.  Used to enable deletion of unclosed credits.  Be very careful!  Only delete credits that were data-entry errors, not adjustments.  Optionally specify one or more comma-separated email addresses to be notified when a credit is deleted.',
    'section'     => '',
    'description' => 'One or more comma-separated email addresses to be notified when a credit is deleted.',
    'type'        => [qw( checkbox text )],
  },

  {
    'key'         => 'deleterefunds',
    'section'     => 'billing',
    'description' => 'Enable deletion of unclosed refunds.  Be very careful!  Only delete refunds that were data-entry errors, not adjustments.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'unapplypayments',
    'section'     => 'deprecated',
    'description' => '<B>DEPRECATED</B>, now controlled by ACLs.  Used to enable "unapplication" of unclosed payments.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'unapplycredits',
    'section'     => 'deprecated',
    'description' => '<B>DEPRECATED</B>, now controlled by ACLs.  Used to nable "unapplication" of unclosed credits.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'dirhash',
    'section'     => 'shell',
    'description' => 'Optional numeric value to control directory hashing.  If positive, hashes directories for the specified number of levels from the front of the username.  If negative, hashes directories for the specified number of levels from the end of the username.  Some examples: <ul><li>1: user -> <a href="#home">/home</a>/u/user<li>2: user -> <a href="#home">/home</a>/u/s/user<li>-1: user -> <a href="#home">/home</a>/r/user<li>-2: user -> <a href="#home">home</a>/r/e/user</ul>',
    'type'        => 'text',
  },

  {
    'key'         => 'disable_cust_attachment',
    'section'     => '',
    'description' => 'Disable customer file attachments',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'max_attachment_size',
    'section'     => '',
    'description' => 'Maximum size for customer file attachments (leave blank for unlimited)',
    'type'        => 'text',
  },

  {
    'key'         => 'disable_customer_referrals',
    'section'     => 'UI',
    'description' => 'Disable new customer-to-customer referrals in the web interface',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'editreferrals',
    'section'     => 'UI',
    'description' => 'Enable advertising source modification for existing customers',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'emailinvoiceonly',
    'section'     => 'invoicing',
    'description' => 'Disables postal mail invoices',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'disablepostalinvoicedefault',
    'section'     => 'invoicing',
    'description' => 'Disables postal mail invoices as the default option in the UI.  Be careful not to setup customers which are not sent invoices.  See <a href ="#emailinvoiceauto">emailinvoiceauto</a>.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'emailinvoiceauto',
    'section'     => 'invoicing',
    'description' => 'Automatically adds new accounts to the email invoice list',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'emailinvoiceautoalways',
    'section'     => 'invoicing',
    'description' => 'Automatically adds new accounts to the email invoice list even when the list contains email addresses',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'emailinvoice-apostrophe',
    'section'     => 'invoicing',
    'description' => 'Allows the apostrophe (single quote) character in the email addresses in the email invoice list.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'exclude_ip_addr',
    'section'     => '',
    'description' => 'Exclude these from the list of available broadband service IP addresses. (One per line)',
    'type'        => 'textarea',
  },
  
  {
    'key'         => 'auto_router',
    'section'     => '',
    'description' => 'Automatically choose the correct router/block based on supplied ip address when possible while provisioning broadband services',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'hidecancelledpackages',
    'section'     => 'UI',
    'description' => 'Prevent cancelled packages from showing up in listings (though they will still be in the database)',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'hidecancelledcustomers',
    'section'     => 'UI',
    'description' => 'Prevent customers with only cancelled packages from showing up in listings (though they will still be in the database)',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'home',
    'section'     => 'shell',
    'description' => 'For new users, prefixed to username to create a directory name.  Should have a leading but not a trailing slash.',
    'type'        => 'text',
  },

  {
    'key'         => 'invoice_from',
    'section'     => 'required',
    'description' => 'Return address on email invoices',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_subject',
    'section'     => 'invoicing',
    'description' => 'Subject: header on email invoices.  Defaults to "Invoice".  The following substitutions are available: $name, $name_short, $invoice_number, and $invoice_date.',
    'type'        => 'text',
    'per_agent'   => 1,
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_usesummary',
    'section'     => 'invoicing',
    'description' => 'Indicates that html and latex invoices should be in summary style and make use of invoice_latexsummary.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice_template',
    'section'     => 'invoicing',
    'description' => 'Text template file for invoices.  Used if no invoice_html template is defined, and also seen by users using non-HTML capable mail clients.  See the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:2.1:Documentation:Administration#Plaintext_invoice_templates">billing documentation</a> for details.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_html',
    'section'     => 'invoicing',
    'description' => 'Optional HTML template for invoices.  See the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:2.1:Documentation:Administration#HTML_invoice_templates">billing documentation</a> for details.',

    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_htmlnotes',
    'section'     => 'invoicing',
    'description' => 'Notes section for HTML invoices.  Defaults to the same data in invoice_latexnotes if not specified.',
    'type'        => 'textarea',
    'per_agent'   => 1,
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_htmlfooter',
    'section'     => 'invoicing',
    'description' => 'Footer for HTML invoices.  Defaults to the same data in invoice_latexfooter if not specified.',
    'type'        => 'textarea',
    'per_agent'   => 1,
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_htmlsummary',
    'section'     => 'invoicing',
    'description' => 'Summary initial page for HTML invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_htmlreturnaddress',
    'section'     => 'invoicing',
    'description' => 'Return address for HTML invoices.  Defaults to the same data in invoice_latexreturnaddress if not specified.',
    'type'        => 'textarea',
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_latex',
    'section'     => 'invoicing',
    'description' => 'Optional LaTeX template for typeset PostScript invoices.  See the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:2.1:Documentation:Administration#Typeset_.28LaTeX.29_invoice_templates">billing documentation</a> for details.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_latextopmargin',
    'section'     => 'invoicing',
    'description' => 'Optional LaTeX invoice topmargin setting. Include units.',
    'type'        => 'text',
    'per_agent'   => 1,
    'validate'    => sub { shift =~
                             /^-?\d*\.?\d+(in|mm|cm|pt|em|ex|pc|bp|dd|cc|sp)$/
                             ? '' : 'Invalid LaTex length';
                         },
  },

  {
    'key'         => 'invoice_latexheadsep',
    'section'     => 'invoicing',
    'description' => 'Optional LaTeX invoice headsep setting. Include units.',
    'type'        => 'text',
    'per_agent'   => 1,
    'validate'    => sub { shift =~
                             /^-?\d*\.?\d+(in|mm|cm|pt|em|ex|pc|bp|dd|cc|sp)$/
                             ? '' : 'Invalid LaTex length';
                         },
  },

  {
    'key'         => 'invoice_latexaddresssep',
    'section'     => 'invoicing',
    'description' => 'Optional LaTeX invoice separation between invoice header
and customer address. Include units.',
    'type'        => 'text',
    'per_agent'   => 1,
    'validate'    => sub { shift =~
                             /^-?\d*\.?\d+(in|mm|cm|pt|em|ex|pc|bp|dd|cc|sp)$/
                             ? '' : 'Invalid LaTex length';
                         },
  },

  {
    'key'         => 'invoice_latextextheight',
    'section'     => 'invoicing',
    'description' => 'Optional LaTeX invoice textheight setting. Include units.',
    'type'        => 'text',
    'per_agent'   => 1,
    'validate'    => sub { shift =~
                             /^-?\d*\.?\d+(in|mm|cm|pt|em|ex|pc|bp|dd|cc|sp)$/
                             ? '' : 'Invalid LaTex length';
                         },
  },

  {
    'key'         => 'invoice_latexnotes',
    'section'     => 'invoicing',
    'description' => 'Notes section for LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_latexfooter',
    'section'     => 'invoicing',
    'description' => 'Footer for LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_latexsummary',
    'section'     => 'invoicing',
    'description' => 'Summary initial page for LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_latexcoupon',
    'section'     => 'invoicing',
    'description' => 'Remittance coupon for LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_latexextracouponspace',
    'section'     => 'invoicing',
    'description' => 'Optional LaTeX invoice textheight space to reserve for a tear off coupon. Include units.',
    'type'        => 'text',
    'per_agent'   => 1,
    'validate'    => sub { shift =~
                             /^-?\d*\.?\d+(in|mm|cm|pt|em|ex|pc|bp|dd|cc|sp)$/
                             ? '' : 'Invalid LaTex length';
                         },
  },

  {
    'key'         => 'invoice_latexcouponfootsep',
    'section'     => 'invoicing',
    'description' => 'Optional LaTeX invoice separation between tear off coupon and footer. Include units.',
    'type'        => 'text',
    'per_agent'   => 1,
    'validate'    => sub { shift =~
                             /^-?\d*\.?\d+(in|mm|cm|pt|em|ex|pc|bp|dd|cc|sp)$/
                             ? '' : 'Invalid LaTex length';
                         },
  },

  {
    'key'         => 'invoice_latexcouponamountenclosedsep',
    'section'     => 'invoicing',
    'description' => 'Optional LaTeX invoice separation between total due and amount enclosed line. Include units.',
    'type'        => 'text',
    'per_agent'   => 1,
    'validate'    => sub { shift =~
                             /^-?\d*\.?\d+(in|mm|cm|pt|em|ex|pc|bp|dd|cc|sp)$/
                             ? '' : 'Invalid LaTex length';
                         },
  },
  {
    'key'         => 'invoice_latexcoupontoaddresssep',
    'section'     => 'invoicing',
    'description' => 'Optional LaTeX invoice separation between invoice data and the to address (usually invoice_latexreturnaddress).  Include units.',
    'type'        => 'text',
    'per_agent'   => 1,
    'validate'    => sub { shift =~
                             /^-?\d*\.?\d+(in|mm|cm|pt|em|ex|pc|bp|dd|cc|sp)$/
                             ? '' : 'Invalid LaTex length';
                         },
  },

  {
    'key'         => 'invoice_latexreturnaddress',
    'section'     => 'invoicing',
    'description' => 'Return address for LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_latexverticalreturnaddress',
    'section'     => 'invoicing',
    'description' => 'Place the return address under the company logo rather than beside it.',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_latexcouponaddcompanytoaddress',
    'section'     => 'invoicing',
    'description' => 'Add the company name to the To address on the remittance coupon because the return address does not contain it.',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_latexsmallfooter',
    'section'     => 'invoicing',
    'description' => 'Optional small footer for multi-page LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
    'per_locale'  => 1,
  },

  {
    'key'         => 'invoice_email_pdf',
    'section'     => 'invoicing',
    'description' => 'Send PDF invoice as an attachment to emailed invoices.  By default, includes the plain text invoice as the email body, unless invoice_email_pdf_note is set.',
    'type'        => 'checkbox'
  },

  {
    'key'         => 'invoice_email_pdf_note',
    'section'     => 'invoicing',
    'description' => 'If defined, this text will replace the default plain text invoice as the body of emailed PDF invoices.',
    'type'        => 'textarea'
  },

  {
    'key'         => 'invoice_print_pdf',
    'section'     => 'invoicing',
    'description' => 'For all invoice print operations, store postal invoices for download in PDF format rather than printing them directly.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice_print_pdf-spoolagent',
    'section'     => 'invoicing',
    'description' => 'Store postal invoices PDF downloads in per-agent spools.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'invoice_default_terms',
    'section'     => 'invoicing',
    'description' => 'Optional default invoice term, used to calculate a due date printed on invoices.',
    'type'        => 'select',
    'select_enum' => [ '', 'Payable upon receipt', 'Net 0', 'Net 3', 'Net 9', 'Net 10', 'Net 15', 'Net 20', 'Net 21', 'Net 30', 'Net 45', 'Net 60', 'Net 90' ],
  },

  { 
    'key'         => 'invoice_show_prior_due_date',
    'section'     => 'invoicing',
    'description' => 'Show previous invoice due dates when showing prior balances.  Default is to show invoice date.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'invoice_include_aging',
    'section'     => 'invoicing',
    'description' => 'Show an aging line after the prior balance section.  Only valud when invoice_sections is enabled.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'invoice_sections',
    'section'     => 'invoicing',
    'description' => 'Split invoice into sections and label according to package category when enabled.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'usage_class_as_a_section',
    'section'     => 'invoicing',
    'description' => 'Split usage into sections and label according to usage class name when enabled.  Only valid when invoice_sections is enabled.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'phone_usage_class_summary',
    'section'     => 'invoicing',
    'description' => 'Summarize usage per DID by usage class and display all CDRs together regardless of usage class. Only valid when svc_phone_sections is enabled.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'svc_phone_sections',
    'section'     => 'invoicing',
    'description' => 'Create a section for each svc_phone when enabled.  Only valid when invoice_sections is enabled.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'finance_pkgclass',
    'section'     => 'billing',
    'description' => 'The default package class for late fee charges, used if the fee event does not specify a package class itself.',
    'type'        => 'select-pkg_class',
  },

  { 
    'key'         => 'separate_usage',
    'section'     => 'invoicing',
    'description' => 'Split the rated call usage into a separate line from the recurring charges.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice_send_receipts',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, this used to send an invoice copy on payments and credits.  See the payment_receipt_email and XXXX instead.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'payment_receipt',
    'section'     => 'notification',
    'description' => 'Send payment receipts.',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'payment_receipt_msgnum',
    'section'     => 'notification',
    'description' => 'Template to use for payment receipts.',
    %msg_template_options,
  },
  
  {
    'key'         => 'payment_receipt_from',
    'section'     => 'notification',
    'description' => 'From: address for payment receipts, if not specified in the template.',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'payment_receipt_email',
    'section'     => 'deprecated',
    'description' => 'Template file for payment receipts.  Payment receipts are sent to the customer email invoice destination(s) when a payment is received.',
    'type'        => [qw( checkbox textarea )],
  },

  {
    'key'         => 'payment_receipt-trigger',
    'section'     => 'notification',
    'description' => 'When payment receipts are triggered.  Defaults to when payment is made.',
    'type'        => 'select',
    'select_hash' => [
                       'cust_pay'          => 'When payment is made.',
                       'cust_bill_pay_pkg' => 'When payment is applied.',
                     ],
    'per_agent'   => 1,
  },

  {
    'key'         => 'trigger_export_insert_on_payment',
    'section'     => 'billing',
    'description' => 'Enable exports on payment application.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'lpr',
    'section'     => 'required',
    'description' => 'Print command for paper invoices, for example `lpr -h\'',
    'type'        => 'text',
  },

  {
    'key'         => 'lpr-postscript_prefix',
    'section'     => 'billing',
    'description' => 'Raw printer commands prepended to the beginning of postscript print jobs (evaluated as a double-quoted perl string - backslash escapes are available)',
    'type'        => 'text',
  },

  {
    'key'         => 'lpr-postscript_suffix',
    'section'     => 'billing',
    'description' => 'Raw printer commands added to the end of postscript print jobs (evaluated as a double-quoted perl string - backslash escapes are available)',
    'type'        => 'text',
  },

  {
    'key'         => 'money_char',
    'section'     => '',
    'description' => 'Currency symbol - defaults to `$\'',
    'type'        => 'text',
  },

  {
    'key'         => 'defaultrecords',
    'section'     => 'BIND',
    'description' => 'DNS entries to add automatically when creating a domain',
    'type'        => 'editlist',
    'editlist_parts' => [ { type=>'text' },
                          { type=>'immutable', value=>'IN' },
                          { type=>'select',
                            select_enum => {
                              map { $_=>$_ }
                                  #@{ FS::domain_record->rectypes }
                                  qw(A AAAA CNAME MX NS PTR SPF SRV TXT)
                            },
                          },
                          { type=> 'text' }, ],
  },

  {
    'key'         => 'passwordmin',
    'section'     => 'password',
    'description' => 'Minimum password length (default 6)',
    'type'        => 'text',
  },

  {
    'key'         => 'passwordmax',
    'section'     => 'password',
    'description' => 'Maximum password length (default 8) (don\'t set this over 12 if you need to import or export crypt() passwords)',
    'type'        => 'text',
  },

  {
    'key'         => 'password-noampersand',
    'section'     => 'password',
    'description' => 'Disallow ampersands in passwords',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'password-noexclamation',
    'section'     => 'password',
    'description' => 'Disallow exclamations in passwords (Not setting this could break old text Livingston or Cistron Radius servers)',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'default-password-encoding',
    'section'     => 'password',
    'description' => 'Default storage format for passwords',
    'type'        => 'select',
    'select_hash' => [
      'plain'       => 'Plain text',
      'crypt-des'   => 'Unix password (DES encrypted)',
      'crypt-md5'   => 'Unix password (MD5 digest)',
      'ldap-plain'  => 'LDAP (plain text)',
      'ldap-crypt'  => 'LDAP (DES encrypted)',
      'ldap-md5'    => 'LDAP (MD5 digest)',
      'ldap-sha1'   => 'LDAP (SHA1 digest)',
      'legacy'      => 'Legacy mode',
    ],
  },

  {
    'key'         => 'referraldefault',
    'section'     => 'UI',
    'description' => 'Default referral, specified by refnum',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::part_referral;
                           map { $_->refnum => $_->referral }
                               FS::Record::qsearch( 'part_referral', 
			                            { 'disabled' => '' }
						  );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::part_referral;
                           my $part_referral = FS::Record::qsearchs(
			     'part_referral', { 'refnum'=>shift } );
                           $part_referral ? $part_referral->referral : '';
			 },
  },

#  {
#    'key'         => 'registries',
#    'section'     => 'required',
#    'description' => 'Directory which contains domain registry information.  Each registry is a directory.',
#  },

  {
    'key'         => 'report_template',
    'section'     => 'deprecated',
    'description' => 'Deprecated template file for reports.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'maxsearchrecordsperpage',
    'section'     => 'UI',
    'description' => 'If set, number of search records to return per page.',
    'type'        => 'text',
  },

  {
    'key'         => 'session-start',
    'section'     => 'session',
    'description' => 'If defined, the command which is executed on the Freeside machine when a session begins.  The contents of the file are treated as a double-quoted perl string, with the following variables available: <code>$ip</code>, <code>$nasip</code> and <code>$nasfqdn</code>, which are the IP address of the starting session, and the IP address and fully-qualified domain name of the NAS this session is on.',
    'type'        => 'text',
  },

  {
    'key'         => 'session-stop',
    'section'     => 'session',
    'description' => 'If defined, the command which is executed on the Freeside machine when a session ends.  The contents of the file are treated as a double-quoted perl string, with the following variables available: <code>$ip</code>, <code>$nasip</code> and <code>$nasfqdn</code>, which are the IP address of the starting session, and the IP address and fully-qualified domain name of the NAS this session is on.',
    'type'        => 'text',
  },

  {
    'key'         => 'shells',
    'section'     => 'shell',
    'description' => 'Legal shells (think /etc/shells).  You probably want to `cut -d: -f7 /etc/passwd | sort | uniq\' initially so that importing doesn\'t fail with `Illegal shell\' errors, then remove any special entries afterwords.  A blank line specifies that an empty shell is permitted.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'showpasswords',
    'section'     => 'UI',
    'description' => 'Display unencrypted user passwords in the backend (employee) web interface',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'report-showpasswords',
    'section'     => 'UI',
    'description' => 'This is a terrible idea.  Do not enable it.  STRONGLY NOT RECOMMENDED.  Enables display of passwords on services reports.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signupurl',
    'section'     => 'UI',
    'description' => 'if you are using customer-to-customer referrals, and you enter the URL of your <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:2.1:Documentation:Self-Service_Installation">signup server CGI</a>, the customer view screen will display a customized link to the signup server with the appropriate customer as referral',
    'type'        => 'text',
  },

  {
    'key'         => 'smtpmachine',
    'section'     => 'required',
    'description' => 'SMTP relay for Freeside\'s outgoing mail',
    'type'        => 'text',
  },

  {
    'key'         => 'smtp-username',
    'section'     => '',
    'description' => 'Optional SMTP username for Freeside\'s outgoing mail',
    'type'        => 'text',
  },

  {
    'key'         => 'smtp-password',
    'section'     => '',
    'description' => 'Optional SMTP password for Freeside\'s outgoing mail',
    'type'        => 'text',
  },

  {
    'key'         => 'smtp-encryption',
    'section'     => '',
    'description' => 'Optional SMTP encryption method.  The STARTTLS methods require smtp-username and smtp-password to be set.',
    'type'        => 'select',
    'select_hash' => [ '25'           => 'None (port 25)',
                       '25-starttls'  => 'STARTTLS (port 25)',
                       '587-starttls' => 'STARTTLS / submission (port 587)',
                       '465-tls'      => 'SMTPS (SSL) (port 465)',
                     ],
  },

  {
    'key'         => 'soadefaultttl',
    'section'     => 'BIND',
    'description' => 'SOA default TTL for new domains.',
    'type'        => 'text',
  },

  {
    'key'         => 'soaemail',
    'section'     => 'BIND',
    'description' => 'SOA email for new domains, in BIND form (`.\' instead of `@\'), with trailing `.\'',
    'type'        => 'text',
  },

  {
    'key'         => 'soaexpire',
    'section'     => 'BIND',
    'description' => 'SOA expire for new domains',
    'type'        => 'text',
  },

  {
    'key'         => 'soamachine',
    'section'     => 'BIND',
    'description' => 'SOA machine for new domains, with trailing `.\'',
    'type'        => 'text',
  },

  {
    'key'         => 'soarefresh',
    'section'     => 'BIND',
    'description' => 'SOA refresh for new domains',
    'type'        => 'text',
  },

  {
    'key'         => 'soaretry',
    'section'     => 'BIND',
    'description' => 'SOA retry for new domains',
    'type'        => 'text',
  },

  {
    'key'         => 'statedefault',
    'section'     => 'UI',
    'description' => 'Default state or province (if not supplied, the default is `CA\')',
    'type'        => 'text',
  },

  {
    'key'         => 'unsuspendauto',
    'section'     => 'billing',
    'description' => 'Enables the automatic unsuspension of suspended packages when a customer\'s balance due changes from positive to zero or negative as the result of a payment or credit',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'unsuspend-always_adjust_next_bill_date',
    'section'     => 'billing',
    'description' => 'Global override that causes unsuspensions to always adjust the next bill date under any circumstances.  This is now controlled on a per-package bases - probably best not to use this option unless you are a legacy installation that requires this behaviour.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'usernamemin',
    'section'     => 'username',
    'description' => 'Minimum username length (default 2)',
    'type'        => 'text',
  },

  {
    'key'         => 'usernamemax',
    'section'     => 'username',
    'description' => 'Maximum username length',
    'type'        => 'text',
  },

  {
    'key'         => 'username-ampersand',
    'section'     => 'username',
    'description' => 'Allow the ampersand character (&amp;) in usernames.  Be careful when using this option in conjunction with <a href="../browse/part_export.cgi">exports</a> which execute shell commands, as the ampersand will be interpreted by the shell if not quoted.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'username-letter',
    'section'     => 'username',
    'description' => 'Usernames must contain at least one letter',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'username-letterfirst',
    'section'     => 'username',
    'description' => 'Usernames must start with a letter',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'username-noperiod',
    'section'     => 'username',
    'description' => 'Disallow periods in usernames',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'username-nounderscore',
    'section'     => 'username',
    'description' => 'Disallow underscores in usernames',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'username-nodash',
    'section'     => 'username',
    'description' => 'Disallow dashes in usernames',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'username-uppercase',
    'section'     => 'username',
    'description' => 'Allow uppercase characters in usernames.  Not recommended for use with FreeRADIUS with MySQL backend, which is case-insensitive by default.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'username-percent',
    'section'     => 'username',
    'description' => 'Allow the percent character (%) in usernames.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'username-colon',
    'section'     => 'username',
    'description' => 'Allow the colon character (:) in usernames.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'username-slash',
    'section'     => 'username',
    'description' => 'Allow the slash character (/) in usernames.  When using, make sure to set "Home directory" to fixed and blank in all svc_acct service definitions.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'username-equals',
    'section'     => 'username',
    'description' => 'Allow the equal sign character (=) in usernames.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'safe-part_bill_event',
    'section'     => 'UI',
    'description' => 'Validates invoice event expressions against a preset list.  Useful for webdemos, annoying to powerusers.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'show_ss',
    'section'     => 'UI',
    'description' => 'Turns on display/collection of social security numbers in the web interface.  Sometimes required by electronic check (ACH) processors.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'show_stateid',
    'section'     => 'UI',
    'description' => "Turns on display/collection of driver's license/state issued id numbers in the web interface.  Sometimes required by electronic check (ACH) processors.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'show_bankstate',
    'section'     => 'UI',
    'description' => "Turns on display/collection of state for bank accounts in the web interface.  Sometimes required by electronic check (ACH) processors.",
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'agent_defaultpkg',
    'section'     => 'UI',
    'description' => 'Setting this option will cause new packages to be available to all agent types by default.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'legacy_link',
    'section'     => 'UI',
    'description' => 'Display options in the web interface to link legacy pre-Freeside services.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'legacy_link-steal',
    'section'     => 'UI',
    'description' => 'Allow "stealing" an already-audited service from one customer (or package) to another using the link function.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'queue_dangerous_controls',
    'section'     => 'UI',
    'description' => 'Enable queue modification controls on account pages and for new jobs.  Unless you are a developer working on new export code, you should probably leave this off to avoid causing provisioning problems.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'security_phrase',
    'section'     => 'password',
    'description' => 'Enable the tracking of a "security phrase" with each account.  Not recommended, as it is vulnerable to social engineering.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'locale',
    'section'     => 'UI',
    'description' => 'Default locale',
    'type'        => 'select',
    'options_sub' => sub {
      map { $_ => FS::Locales->description($_) } FS::Locales->locales;
    },
    'option_sub'  => sub {
      FS::Locales->description(shift)
    },
  },

  {
    'key'         => 'signup_server-payby',
    'section'     => 'self-service',
    'description' => 'Acceptable payment types for the signup server',
    'type'        => 'selectmultiple',
    'select_enum' => [ qw(CARD DCRD CHEK DCHK LECB PREPAY BILL COMP) ],
  },

  {
    'key'         => 'selfservice-payment_gateway',
    'section'     => 'self-service',
    'description' => 'Force the use of this payment gateway for self-service.',
    %payment_gateway_options,
  },

  {
    'key'         => 'selfservice-save_unchecked',
    'section'     => 'self-service',
    'description' => 'In self-service, uncheck "Remember information" checkboxes by default (normally, they are checked by default).',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'default_agentnum',
    'section'     => 'UI',
    'description' => 'Default agent for the backoffice',
    'type'        => 'select-agent',
  },

  {
    'key'         => 'signup_server-default_agentnum',
    'section'     => 'self-service',
    'description' => 'Default agent for the signup server',
    'type'        => 'select-agent',
  },

  {
    'key'         => 'signup_server-default_refnum',
    'section'     => 'self-service',
    'description' => 'Default advertising source for the signup server',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::part_referral;
                           map { $_->refnum => $_->referral }
                               FS::Record::qsearch( 'part_referral', 
			                            { 'disabled' => '' }
						  );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::part_referral;
                           my $part_referral = FS::Record::qsearchs(
			     'part_referral', { 'refnum'=>shift } );
                           $part_referral ? $part_referral->referral : '';
			 },
  },

  {
    'key'         => 'signup_server-default_pkgpart',
    'section'     => 'self-service',
    'description' => 'Default package for the signup server',
    'type'        => 'select-part_pkg',
  },

  {
    'key'         => 'signup_server-default_svcpart',
    'section'     => 'self-service',
    'description' => 'Default service definition for the signup server - only necessary for services that trigger special provisioning widgets (such as DID provisioning).',
    'type'        => 'select-part_svc',
  },

  {
    'key'         => 'signup_server-mac_addr_svcparts',
    'section'     => 'self-service',
    'description' => 'Service definitions which can receive mac addresses (current mapped to username for svc_acct).',
    'type'        => 'select-part_svc',
    'multiple'    => 1,
  },

  {
    'key'         => 'signup_server-nomadix',
    'section'     => 'self-service',
    'description' => 'Signup page Nomadix integration',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signup_server-service',
    'section'     => 'self-service',
    'description' => 'Service for the signup server - "Account (svc_acct)" is the default setting, or "Phone number (svc_phone)" for ITSP signup',
    'type'        => 'select',
    'select_hash' => [
                       'svc_acct'  => 'Account (svc_acct)',
                       'svc_phone' => 'Phone number (svc_phone)',
                       'svc_pbx'   => 'PBX (svc_pbx)',
                     ],
  },
  
  {
    'key'         => 'signup_server-prepaid-template-custnum',
    'section'     => 'self-service',
    'description' => 'When the signup server is used with prepaid cards and customer info is not required for signup, the contact/address info will be copied from this customer, if specified',
    'type'        => 'text',
  },

  {
    'key'         => 'selfservice_server-base_url',
    'section'     => 'self-service',
    'description' => 'Base URL for the self-service web interface - necessary for some widgets to find their way, including retrieval of non-US state information and phone number provisioning.',
    'type'        => 'text',
  },

  {
    'key'         => 'show-msgcat-codes',
    'section'     => 'UI',
    'description' => 'Show msgcat codes in error messages.  Turn this option on before reporting errors to the mailing list.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signup_server-realtime',
    'section'     => 'self-service',
    'description' => 'Run billing for signup server signups immediately, and do not provision accounts which subsequently have a balance.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signup_server-classnum2',
    'section'     => 'self-service',
    'description' => 'Package Class for first optional purchase',
    'type'        => 'select-pkg_class',
  },

  {
    'key'         => 'signup_server-classnum3',
    'section'     => 'self-service',
    'description' => 'Package Class for second optional purchase',
    'type'        => 'select-pkg_class',
  },

  {
    'key'         => 'signup_server-third_party_as_card',
    'section'     => 'self-service',
    'description' => 'Allow customer payment type to be set to CARD even when using third-party credit card billing.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice-xmlrpc',
    'section'     => 'self-service',
    'description' => 'Run a standalone self-service XML-RPC server on the backend (on port 8080).',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'backend-realtime',
    'section'     => 'billing',
    'description' => 'Run billing for backend signups immediately.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'decline_msgnum',
    'section'     => 'notification',
    'description' => 'Template to use for credit card and electronic check decline messages.',
    %msg_template_options,
  },

  {
    'key'         => 'declinetemplate',
    'section'     => 'deprecated',
    'description' => 'Template file for credit card and electronic check decline emails.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'emaildecline',
    'section'     => 'notification',
    'description' => 'Enable emailing of credit card and electronic check decline notices.',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'emaildecline-exclude',
    'section'     => 'notification',
    'description' => 'List of error messages that should not trigger email decline notices, one per line.',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'cancel_msgnum',
    'section'     => 'notification',
    'description' => 'Template to use for cancellation emails.',
    %msg_template_options,
  },

  {
    'key'         => 'cancelmessage',
    'section'     => 'deprecated',
    'description' => 'Template file for cancellation emails.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cancelsubject',
    'section'     => 'deprecated',
    'description' => 'Subject line for cancellation emails.',
    'type'        => 'text',
  },

  {
    'key'         => 'emailcancel',
    'section'     => 'notification',
    'description' => 'Enable emailing of cancellation notices.  Make sure to select the template in the cancel_msgnum option.',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'bill_usage_on_cancel',
    'section'     => 'billing',
    'description' => 'Enable automatic generation of an invoice for usage when a package is cancelled.  Not all packages can do this.  Usage data must already be available.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'require_cardname',
    'section'     => 'billing',
    'description' => 'Require an "Exact name on card" to be entered explicitly; don\'t default to using the first and last name.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'enable_taxclasses',
    'section'     => 'billing',
    'description' => 'Enable per-package tax classes',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'require_taxclasses',
    'section'     => 'billing',
    'description' => 'Require a taxclass to be entered for every package',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'enable_taxproducts',
    'section'     => 'billing',
    'description' => 'Enable per-package mapping to vendor tax data from CCH or elsewhere.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'taxdatadirectdownload',
    'section'     => 'billing',  #well
    'description' => 'Enable downloading tax data directly from the vendor site. at least three lines: URL, username, and password.j',
    'type'        => 'textarea',
  },

  {
    'key'         => 'ignore_incalculable_taxes',
    'section'     => 'billing',
    'description' => 'Prefer to invoice without tax over not billing at all',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'welcome_msgnum',
    'section'     => 'notification',
    'description' => 'Template to use for welcome messages when a svc_acct record is created.',
    %msg_template_options,
  },
  
  {
    'key'         => 'svc_acct_welcome_exclude',
    'section'     => 'notification',
    'description' => 'A list of svc_acct services for which no welcome email is to be sent.',
    'type'        => 'select-part_svc',
    'multiple'    => 1,
  },

  {
    'key'         => 'welcome_email',
    'section'     => 'deprecated',
    'description' => 'Template file for welcome email.  Welcome emails are sent to the customer email invoice destination(s) each time a svc_acct record is created.',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'welcome_email-from',
    'section'     => 'deprecated',
    'description' => 'From: address header for welcome email',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'welcome_email-subject',
    'section'     => 'deprecated',
    'description' => 'Subject: header for welcome email',
    'type'        => 'text',
    'per_agent'   => 1,
  },
  
  {
    'key'         => 'welcome_email-mimetype',
    'section'     => 'deprecated',
    'description' => 'MIME type for welcome email',
    'type'        => 'select',
    'select_enum' => [ 'text/plain', 'text/html' ],
    'per_agent'   => 1,
  },

  {
    'key'         => 'welcome_letter',
    'section'     => '',
    'description' => 'Optional LaTex template file for a printed welcome letter.  A welcome letter is printed the first time a cust_pkg record is created.  See the <a href="http://search.cpan.org/dist/Text-Template/lib/Text/Template.pm">Text::Template</a> documentation and the billing documentation for details on the template substitution language.  A variable exists for each fieldname in the customer record (<code>$first, $last, etc</code>).  The following additional variables are available<ul><li><code>$payby</code> - a friendler represenation of the field<li><code>$payinfo</code> - the masked payment information<li><code>$expdate</code> - the time at which the payment method expires (a UNIX timestamp)<li><code>$returnaddress</code> - the invoice return address for this customer\'s agent</ul>',
    'type'        => 'textarea',
  },

#  {
#    'key'         => 'warning_msgnum',
#    'section'     => 'notification',
#    'description' => 'Template to use for warning messages, sent to the customer email invoice destination(s) when a svc_acct record has its usage drop below a threshold.',
#    %msg_template_options,
#  },

  {
    'key'         => 'warning_email',
    'section'     => 'notification',
    'description' => 'Template file for warning email.  Warning emails are sent to the customer email invoice destination(s) each time a svc_acct record has its usage drop below a threshold or 0.  See the <a href="http://search.cpan.org/dist/Text-Template/lib/Text/Template.pm">Text::Template</a> documentation for details on the template substitution language.  The following variables are available<ul><li><code>$username</code> <li><code>$password</code> <li><code>$first</code> <li><code>$last</code> <li><code>$pkg</code> <li><code>$column</code> <li><code>$amount</code> <li><code>$threshold</code></ul>',
    'type'        => 'textarea',
  },

  {
    'key'         => 'warning_email-from',
    'section'     => 'notification',
    'description' => 'From: address header for warning email',
    'type'        => 'text',
  },

  {
    'key'         => 'warning_email-cc',
    'section'     => 'notification',
    'description' => 'Additional recipient(s) (comma separated) for warning email when remaining usage reaches zero.',
    'type'        => 'text',
  },

  {
    'key'         => 'warning_email-subject',
    'section'     => 'notification',
    'description' => 'Subject: header for warning email',
    'type'        => 'text',
  },
  
  {
    'key'         => 'warning_email-mimetype',
    'section'     => 'notification',
    'description' => 'MIME type for warning email',
    'type'        => 'select',
    'select_enum' => [ 'text/plain', 'text/html' ],
  },

  {
    'key'         => 'payby',
    'section'     => 'billing',
    'description' => 'Available payment types.',
    'type'        => 'selectmultiple',
    'select_enum' => [ qw(CARD DCRD CHEK DCHK LECB BILL CASH WEST MCRD COMP) ],
  },

  {
    'key'         => 'payby-default',
    'section'     => 'UI',
    'description' => 'Default payment type.  HIDE disables display of billing information and sets customers to BILL.',
    'type'        => 'select',
    'select_enum' => [ '', qw(CARD DCRD CHEK DCHK LECB BILL CASH WEST MCRD COMP HIDE) ],
  },

  {
    'key'         => 'paymentforcedtobatch',
    'section'     => 'deprecated',
    'description' => 'See batch-enable_payby and realtime-disable_payby.  Used to (for CHEK): Cause per customer payment entry to be forced to a batch processor rather than performed realtime.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-notes',
    'section'     => 'deprecated',
    'description' => 'Extra HTML to be displayed on the Account View screen.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'radius-password',
    'section'     => '',
    'description' => 'RADIUS attribute for plain-text passwords.',
    'type'        => 'select',
    'select_enum' => [ 'Password', 'User-Password', 'Cleartext-Password' ],
  },

  {
    'key'         => 'radius-ip',
    'section'     => '',
    'description' => 'RADIUS attribute for IP addresses.',
    'type'        => 'select',
    'select_enum' => [ 'Framed-IP-Address', 'Framed-Address' ],
  },

  #http://dev.coova.org/svn/coova-chilli/doc/dictionary.chillispot
  {
    'key'         => 'radius-chillispot-max',
    'section'     => '',
    'description' => 'Enable ChilliSpot (and CoovaChilli) Max attributes, specifically ChilliSpot-Max-{Input,Output,Total}-{Octets,Gigawords}.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_broadband-radius',
    'section'     => '',
    'description' => 'Enable RADIUS groups for broadband services.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-alldomains',
    'section'     => '',
    'description' => 'Allow accounts to select any domain in the database.  Normally accounts can only select from the domain set in the service definition and those purchased by the customer.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'dump-localdest',
    'section'     => '',
    'description' => 'Destination for local database dumps (full path)',
    'type'        => 'text',
  },

  {
    'key'         => 'dump-scpdest',
    'section'     => '',
    'description' => 'Destination for scp database dumps: user@host:/path',
    'type'        => 'text',
  },

  {
    'key'         => 'dump-pgpid',
    'section'     => '',
    'description' => "Optional PGP public key user or key id for database dumps.  The public key should exist on the freeside user's public keyring, and the gpg binary and GnuPG perl module should be installed.",
    'type'        => 'text',
  },

  {
    'key'         => 'users-allow_comp',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, enable the <i>Complimentary customer</i> access right instead.  Was: Usernames (Freeside users, created with <a href="../docs/man/bin/freeside-adduser.html">freeside-adduser</a>) which can create complimentary customers, one per line.  If no usernames are entered, all users can create complimentary accounts.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'credit_card-recurring_billing_flag',
    'section'     => 'billing',
    'description' => 'This controls when the system passes the "recurring_billing" flag on credit card transactions.  If supported by your processor (and the Business::OnlinePayment processor module), passing the flag indicates this is a recurring transaction and may turn off the CVV requirement. ',
    'type'        => 'select',
    'select_hash' => [
                       'actual_oncard' => 'Default/classic behavior: set the flag if a customer has actual previous charges on the card.',
		       'transaction_is_recur' => 'Set the flag if the transaction itself is recurring, irregardless of previous charges on the card.',
                     ],
  },

  {
    'key'         => 'credit_card-recurring_billing_acct_code',
    'section'     => 'billing',
    'description' => 'When the "recurring billing" flag is set, also set the "acct_code" to "rebill".  Useful for reporting purposes with supported gateways (PlugNPay, others?)',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cvv-save',
    'section'     => 'billing',
    'description' => 'Save CVV2 information after the initial transaction for the selected credit card types.  Enabling this option may be in violation of your merchant agreement(s), so please check them carefully before enabling this option for any credit card types.',
    'type'        => 'selectmultiple',
    'select_enum' => \@card_types,
  },

  {
    'key'         => 'manual_process-pkgpart',
    'section'     => 'billing',
    'description' => 'Package to add to each manual credit card and ACH payments entered from the backend.  Enabling this option may be in violation of your merchant agreement(s), so please check them carefully before enabling this option.',
    'type'        => 'select-part_pkg',
  },

  {
    'key'         => 'manual_process-display',
    'section'     => 'billing',
    'description' => 'When using manual_process-pkgpart, add the fee to the amount entered (default), or subtract the fee from the amount entered.',
    'type'        => 'select',
    'select_hash' => [
                       'add'      => 'Add fee to amount entered',
                       'subtract' => 'Subtract fee from amount entered',
                     ],
  },

  {
    'key'         => 'manual_process-skip_first',
    'section'     => 'billing',
    'description' => "When using manual_process-pkgpart, omit the fee if it is the customer's first payment.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'allow_negative_charges',
    'section'     => 'billing',
    'description' => 'Allow negative charges.  Normally not used unless importing data from a legacy system that requires this.',
    'type'        => 'checkbox',
  },
  {
      'key'         => 'auto_unset_catchall',
      'section'     => '',
      'description' => 'When canceling a svc_acct that is the email catchall for one or more svc_domains, automatically set their catchall fields to null.  If this option is not set, the attempt will simply fail.',
      'type'        => 'checkbox',
  },

  {
    'key'         => 'system_usernames',
    'section'     => 'username',
    'description' => 'A list of system usernames that cannot be edited or removed, one per line.  Use a bare username to prohibit modification/deletion of the username in any domain, or username@domain to prohibit modification/deletetion of a specific username and domain.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cust_pkg-change_svcpart',
    'section'     => '',
    'description' => "When changing packages, move services even if svcparts don't match between old and new pacakge definitions.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_pkg-change_pkgpart-bill_now',
    'section'     => '',
    'description' => "When changing packages, bill the new package immediately.  Useful for prepaid situations with RADIUS where an Expiration attribute based on the package must be present at all times.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'disable_autoreverse',
    'section'     => 'BIND',
    'description' => 'Disable automatic synchronization of reverse-ARPA entries.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_www-enable_subdomains',
    'section'     => '',
    'description' => 'Enable selection of specific subdomains for virtual host creation.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_www-usersvc_svcpart',
    'section'     => '',
    'description' => 'Allowable service definition svcparts for virtual hosts, one per line.',
    'type'        => 'select-part_svc',
    'multiple'    => 1,
  },

  {
    'key'         => 'selfservice_server-primary_only',
    'section'     => 'self-service',
    'description' => 'Only allow primary accounts to access self-service functionality.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice_server-phone_login',
    'section'     => 'self-service',
    'description' => 'Allow login to self-service with phone number and PIN.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice_server-single_domain',
    'section'     => 'self-service',
    'description' => 'If specified, only use this one domain for self-service access.',
    'type'        => 'text',
  },

  {
    'key'         => 'selfservice_server-login_svcpart',
    'section'     => 'self-service',
    'description' => 'If specified, only allow the specified svcparts to login to self-service.',
    'type'        => 'select-part_svc',
    'multiple'    => 1,
  },

  {
    'key'         => 'selfservice-svc_forward_svcpart',
    'section'     => 'self-service',
    'description' => 'Service for self-service forward editing.',
    'type'        => 'select-part_svc',
  },

  {
    'key'         => 'selfservice-password_reset_verification',
    'section'     => 'self-service',
    'description' => 'If enabled, specifies the type of verification required for self-service password resets.',
    'type'        => 'select',
    'select_hash' => [ '' => 'Password reset disabled',
                       'paymask,amount,zip' => 'Verify with credit card (or bank account) last 4 digits, payment amount and zip code',
                     ],
  },

  {
    'key'         => 'selfservice-password_reset_msgnum',
    'section'     => 'self-service',
    'description' => 'Template to use for password reset emails.',
    %msg_template_options,
  },

  {
    'key'         => 'selfservice-hide_invoices-taxclass',
    'section'     => 'self-service',
    'description' => 'Hide invoices with only this package tax class from self-service and supress sending (emailing, printing, faxing) them.  Typically set to something like "Previous balance" and used when importing legacy invoices into legacy_cust_bill.',
    'type'        => 'text',
  },

  {
    'key'         => 'selfservice-recent-did-age',
    'section'     => 'self-service',
    'description' => 'If specified, defines "recent", in number of seconds, for "Download recently allocated DIDs" in self-service.',
    'type'        => 'text',
  },

  {
    'key'         => 'selfservice_server-view-wholesale',
    'section'     => 'self-service',
    'description' => 'If enabled, use a wholesale package view in the self-service.',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'selfservice-agent_signup',
    'section'     => 'self-service',
    'description' => 'Allow agent signup via self-service.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice-agent_signup-agent_type',
    'section'     => 'self-service',
    'description' => 'Agent type when allowing agent signup via self-service.',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::agent_type;
			   map { $_->typenum => $_->atype }
                               FS::Record::qsearch('agent_type', {} ); # disabled=>'' } );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::agent_type;
			   my $agent = FS::Record::qsearchs(
			     'agent_type', { 'typenum'=>shift }
			   );
                           $agent_type ? $agent_type->atype : '';
			 },
  },

  {
    'key'         => 'selfservice-agent_login',
    'section'     => 'self-service',
    'description' => 'Allow agent login via self-service.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice-self_suspend_reason',
    'section'     => 'self-service',
    'description' => 'Suspend reason when customers suspend their own packages. Set to nothing to disallow self-suspension.',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::reason;
                           my $type = qsearchs('reason_type', 
                             { class => 'S' }) 
                              or return ();
			   map { $_->reasonnum => $_->reason }
                               FS::Record::qsearch('reason', 
                                 { reason_type => $type->typenum } 
                               );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::reason;
			   my $reason = FS::Record::qsearchs(
			     'reason', { 'reasonnum' => shift }
			   );
                           $reason ? $reason->reason : '';
			 },

    'per_agent'   => 1,
  },

  {
    'key'         => 'card_refund-days',
    'section'     => 'billing',
    'description' => 'After a payment, the number of days a refund link will be available for that payment.  Defaults to 120.',
    'type'        => 'text',
  },

  {
    'key'         => 'agent-showpasswords',
    'section'     => '',
    'description' => 'Display unencrypted user passwords in the agent (reseller) interface',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'global_unique-username',
    'section'     => 'username',
    'description' => 'Global username uniqueness control: none (usual setting - check uniqueness per exports), username (all usernames are globally unique, regardless of domain or exports), or username@domain (all username@domain pairs are globally unique, regardless of exports).  disabled turns off duplicate checking completely and is STRONGLY NOT RECOMMENDED unless you REALLY need to turn this off.',
    'type'        => 'select',
    'select_enum' => [ 'none', 'username', 'username@domain', 'disabled' ],
  },

  {
    'key'         => 'global_unique-phonenum',
    'section'     => '',
    'description' => 'Global phone number uniqueness control: none (usual setting - check countrycode+phonenumun uniqueness per exports), or countrycode+phonenum (all countrycode+phonenum pairs are globally unique, regardless of exports).  disabled turns off duplicate checking completely and is STRONGLY NOT RECOMMENDED unless you REALLY need to turn this off.',
    'type'        => 'select',
    'select_enum' => [ 'none', 'countrycode+phonenum', 'disabled' ],
  },

  {
    'key'         => 'global_unique-pbx_title',
    'section'     => '',
    'description' => 'Global phone number uniqueness control: none (check uniqueness per exports), enabled (check across all services), or disabled (no duplicate checking).',
    'type'        => 'select',
    'select_enum' => [ 'enabled', 'disabled' ],
  },

  {
    'key'         => 'global_unique-pbx_id',
    'section'     => '',
    'description' => 'Global PBX id uniqueness control: none (check uniqueness per exports), enabled (check across all services), or disabled (no duplicate checking).',
    'type'        => 'select',
    'select_enum' => [ 'enabled', 'disabled' ],
  },

  {
    'key'         => 'svc_external-skip_manual',
    'section'     => 'UI',
    'description' => 'When provisioning svc_external services, skip manual entry of id and title fields in the UI.  Usually used in conjunction with an export that populates these fields (i.e. artera_turbo).',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_external-display_type',
    'section'     => 'UI',
    'description' => 'Select a specific svc_external type to enable some UI changes specific to that type (i.e. artera_turbo).',
    'type'        => 'select',
    'select_enum' => [ 'generic', 'artera_turbo', ],
  },

  {
    'key'         => 'ticket_system',
    'section'     => 'ticketing',
    'description' => 'Ticketing system integration.  <b>RT_Internal</b> uses the built-in RT ticketing system (see the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:2.1:Documentation:RT_Installation">integrated ticketing installation instructions</a>).   <b>RT_External</b> accesses an external RT installation in a separate database (local or remote).',
    'type'        => 'select',
    #'select_enum' => [ '', qw(RT_Internal RT_Libs RT_External) ],
    'select_enum' => [ '', qw(RT_Internal RT_External) ],
  },

  {
    'key'         => 'network_monitoring_system',
    'section'     => 'network_monitoring',
    'description' => 'Networking monitoring system (NMS) integration.  <b>Torrus_Internal</b> uses the built-in Torrus ticketing system (see the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:2.1:Documentation:Torrus_Installation">integrated networking monitoring system installation instructions</a>).',
    'type'        => 'select',
    'select_enum' => [ '', qw(Torrus_Internal) ],
  },

  {
    'key'         => 'nms-auto_add-svc_ips',
    'section'     => 'network_monitoring',
    'description' => 'Automatically add (and remove) IP addresses from these service tables to the network monitoring system.',
    'type'        => 'selectmultiple',
    'select_enum' => [ 'svc_acct', 'svc_broadband', 'svc_dsl' ],
  },

  {
    'key'         => 'nms-auto_add-community',
    'section'     => 'network_monitoring',
    'description' => 'SNMP community string to use when automatically adding IP addresses from these services to the network monitoring system.',
    'type'        => 'text',
  },

  {
    'key'         => 'ticket_system-default_queueid',
    'section'     => 'ticketing',
    'description' => 'Default queue used when creating new customer tickets.',
    'type'        => 'select-sub',
    'options_sub' => sub {
                           my $conf = new FS::Conf;
                           if ( $conf->config('ticket_system') ) {
                             eval "use FS::TicketSystem;";
                             die $@ if $@;
                             FS::TicketSystem->queues();
                           } else {
                             ();
                           }
                         },
    'option_sub'  => sub { 
                           my $conf = new FS::Conf;
                           if ( $conf->config('ticket_system') ) {
                             eval "use FS::TicketSystem;";
                             die $@ if $@;
                             FS::TicketSystem->queue(shift);
                           } else {
                             '';
                           }
                         },
  },
  {
    'key'         => 'ticket_system-force_default_queueid',
    'section'     => 'ticketing',
    'description' => 'Disallow queue selection when creating new tickets from customer view.',
    'type'        => 'checkbox',
  },
  {
    'key'         => 'ticket_system-selfservice_queueid',
    'section'     => 'ticketing',
    'description' => 'Queue used when creating new customer tickets from self-service.  Defautls to ticket_system-default_queueid if not specified.',
    #false laziness w/above
    'type'        => 'select-sub',
    'options_sub' => sub {
                           my $conf = new FS::Conf;
                           if ( $conf->config('ticket_system') ) {
                             eval "use FS::TicketSystem;";
                             die $@ if $@;
                             FS::TicketSystem->queues();
                           } else {
                             ();
                           }
                         },
    'option_sub'  => sub { 
                           my $conf = new FS::Conf;
                           if ( $conf->config('ticket_system') ) {
                             eval "use FS::TicketSystem;";
                             die $@ if $@;
                             FS::TicketSystem->queue(shift);
                           } else {
                             '';
                           }
                         },
  },

  {
    'key'         => 'ticket_system-requestor',
    'section'     => 'ticketing',
    'description' => 'Email address to use as the requestor for new tickets.  If blank, the customer\'s invoicing address(es) will be used.',
    'type'        => 'text',
  },

  {
    'key'         => 'ticket_system-priority_reverse',
    'section'     => 'ticketing',
    'description' => 'Enable this to consider lower numbered priorities more important.  A bad habit we picked up somewhere.  You probably want to avoid it and use the default.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'ticket_system-custom_priority_field',
    'section'     => 'ticketing',
    'description' => 'Custom field from the ticketing system to use as a custom priority classification.',
    'type'        => 'text',
  },

  {
    'key'         => 'ticket_system-custom_priority_field-values',
    'section'     => 'ticketing',
    'description' => 'Values for the custom field from the ticketing system to break down and sort customer ticket lists.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'ticket_system-custom_priority_field_queue',
    'section'     => 'ticketing',
    'description' => 'Ticketing system queue in which the custom field specified in ticket_system-custom_priority_field is located.',
    'type'        => 'text',
  },

  {
    'key'         => 'ticket_system-selfservice_priority_field',
    'section'     => 'ticketing',
    'description' => 'Custom field from the ticket system to use as a customer-managed priority field.',
    'type'        => 'text',
  },

  {
    'key'         => 'ticket_system-selfservice_edit_subject',
    'section'     => 'ticketing',
    'description' => 'Allow customers to edit ticket subjects through selfservice.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'ticket_system-escalation',
    'section'     => 'ticketing',
    'description' => 'Enable priority escalation of tickets as part of daily batch processing.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'ticket_system-rt_external_datasrc',
    'section'     => 'ticketing',
    'description' => 'With external RT integration, the DBI data source for the external RT installation, for example, <code>DBI:Pg:user=rt_user;password=rt_word;host=rt.example.com;dbname=rt</code>',
    'type'        => 'text',

  },

  {
    'key'         => 'ticket_system-rt_external_url',
    'section'     => 'ticketing',
    'description' => 'With external RT integration, the URL for the external RT installation, for example, <code>https://rt.example.com/rt</code>',
    'type'        => 'text',
  },

  {
    'key'         => 'company_name',
    'section'     => 'required',
    'description' => 'Your company name',
    'type'        => 'text',
    'per_agent'   => 1, #XXX just FS/FS/ClientAPI/Signup.pm
  },

  {
    'key'         => 'company_address',
    'section'     => 'required',
    'description' => 'Your company address',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'company_phonenum',
    'section'     => 'notification',
    'description' => 'Your company phone number',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'echeck-void',
    'section'     => 'deprecated',
    'description' => '<B>DEPRECATED</B>, now controlled by ACLs.  Used to enable local-only voiding of echeck payments in addition to refunds against the payment gateway',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cc-void',
    'section'     => 'deprecated',
    'description' => '<B>DEPRECATED</B>, now controlled by ACLs.  Used to enable local-only voiding of credit card payments in addition to refunds against the payment gateway',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'unvoid',
    'section'     => 'deprecated',
    'description' => '<B>DEPRECATED</B>, now controlled by ACLs.  Used to enable unvoiding of voided payments',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'address1-search',
    'section'     => 'UI',
    'description' => 'Enable the ability to search the address1 field from the quick customer search.  Not recommended in most cases as it tends to bring up too many search results - use explicit address searching from the advanced customer search instead.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'address2-search',
    'section'     => 'UI',
    'description' => 'Enable a "Unit" search box which searches the second address field.  Useful for multi-tenant applications.  See also: cust_main-require_address2',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-require_address2',
    'section'     => 'UI',
    'description' => 'Second address field is required (on service address only, if billing and service addresses differ).  Also enables "Unit" labeling of address2 on customer view and edit pages.  Useful for multi-tenant applications.  See also: address2-search',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'agent-ship_address',
    'section'     => '',
    'description' => "Use the agent's master service address as the service address (only ship_address2 can be entered, if blank on the master address).  Useful for multi-tenant applications.",
    'type'        => 'checkbox',
  },

  { 'key'         => 'referral_credit',
    'section'     => 'deprecated',
    'description' => "Used to enable one-time referral credits in the amount of one month <i>referred</i> customer's recurring fee (irregardless of frequency).  Replace with a billing event on appropriate packages.",
    'type'        => 'checkbox',
  },

  { 'key'         => 'selfservice_server-cache_module',
    'section'     => 'self-service',
    'description' => 'Module used to store self-service session information.  All modules handle any number of self-service servers.  Cache::SharedMemoryCache is appropriate for a single database / single Freeside server.  Cache::FileCache is useful for multiple databases on a single server, or when IPC::ShareLite is not available (i.e. FreeBSD).', #  _Database stores session information in the database and is appropriate for multiple Freeside servers, but may be slower.',
    'type'        => 'select',
    'select_enum' => [ 'Cache::SharedMemoryCache', 'Cache::FileCache', ], # '_Database' ],
  },

  {
    'key'         => 'hylafax',
    'section'     => 'billing',
    'description' => 'Options for a HylaFAX server to enable the FAX invoice destination.  They should be in the form of a space separated list of arguments to the Fax::Hylafax::Client::sendfax subroutine.  You probably shouldn\'t override things like \'docfile\'.  *Note* Only supported when using typeset invoices (see the invoice_latex configuration option).',
    'type'        => [qw( checkbox textarea )],
  },

  {
    'key'         => 'cust_bill-ftpformat',
    'section'     => 'invoicing',
    'description' => 'Enable FTP of raw invoice data - format.',
    'type'        => 'select',
    'select_enum' => [ '', 'default', 'billco', ],
  },

  {
    'key'         => 'cust_bill-ftpserver',
    'section'     => 'invoicing',
    'description' => 'Enable FTP of raw invoice data - server.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-ftpusername',
    'section'     => 'invoicing',
    'description' => 'Enable FTP of raw invoice data - server.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-ftppassword',
    'section'     => 'invoicing',
    'description' => 'Enable FTP of raw invoice data - server.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-ftpdir',
    'section'     => 'invoicing',
    'description' => 'Enable FTP of raw invoice data - server.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-spoolformat',
    'section'     => 'invoicing',
    'description' => 'Enable spooling of raw invoice data - format.',
    'type'        => 'select',
    'select_enum' => [ '', 'default', 'billco', ],
  },

  {
    'key'         => 'cust_bill-spoolagent',
    'section'     => 'invoicing',
    'description' => 'Enable per-agent spooling of raw invoice data.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-usage_suspend',
    'section'     => 'billing',
    'description' => 'Suspends the package an account belongs to when svc_acct.seconds or a bytecount is decremented to 0 or below (accounts with an empty seconds and up|down|totalbytes value are ignored).  Typically used in conjunction with prepaid packages and freeside-sqlradius-radacctd.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-usage_unsuspend',
    'section'     => 'billing',
    'description' => 'Unuspends the package an account belongs to when svc_acct.seconds or a bytecount is incremented from 0 or below to a positive value (accounts with an empty seconds and up|down|totalbytes value are ignored).  Typically used in conjunction with prepaid packages and freeside-sqlradius-radacctd.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-usage_threshold',
    'section'     => 'billing',
    'description' => 'The threshold (expressed as percentage) of acct.seconds or acct.up|down|totalbytes at which a warning message is sent to a service holder.  Typically used in conjunction with prepaid packages and freeside-sqlradius-radacctd.',
    'type'        => 'text',
  },

  {
    'key'         => 'overlimit_groups',
    'section'     => '',
    'description' => 'RADIUS group(s) to assign to svc_acct which has exceeded its bandwidth or time limit.',
    'type'        => 'select-sub',
    'per_agent'   => 1,
    'multiple'    => 1,
    'options_sub' => sub { require FS::Record;
                           require FS::radius_group;
			   map { $_->groupnum => $_->long_description }
                               FS::Record::qsearch('radius_group', {} );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::radius_group;
			   my $radius_group = FS::Record::qsearchs(
			     'radius_group', { 'groupnum' => shift }
			   );
               $radius_group ? $radius_group->long_description : '';
			 },
  },

  {
    'key'         => 'cust-fields',
    'section'     => 'UI',
    'description' => 'Which customer fields to display on reports by default',
    'type'        => 'select',
    'select_hash' => [ FS::ConfDefaults->cust_fields_avail() ],
  },

  {
    'key'         => 'cust_pkg-display_times',
    'section'     => 'UI',
    'description' => 'Display full timestamps (not just dates) for customer packages.  Useful if you are doing real-time things like hourly prepaid.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_pkg-always_show_location',
    'section'     => 'UI',
    'description' => "Always display package locations, even when they're all the default service address.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_pkg-group_by_location',
    'section'     => 'UI',
    'description' => "Group packages by location.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_pkg-show_fcc_voice_grade_equivalent',
    'section'     => 'UI',
    'description' => "Show a field on package definitions for assigning a DS0 equivalency number suitable for use on FCC form 477.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_pkg-large_pkg_size',
    'section'     => 'UI',
    'description' => "In customer view, summarize packages with more than this many services.  Set to zero to never summarize packages.",
    'type'        => 'text',
  },

  {
    'key'         => 'svc_acct-edit_uid',
    'section'     => 'shell',
    'description' => 'Allow UID editing.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-edit_gid',
    'section'     => 'shell',
    'description' => 'Allow GID editing.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-no_edit_username',
    'section'     => 'shell',
    'description' => 'Disallow username editing.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'zone-underscore',
    'section'     => 'BIND',
    'description' => 'Allow underscores in zone names.  As underscores are illegal characters in zone names, this option is not recommended.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'echeck-nonus',
    'section'     => 'billing',
    'description' => 'Disable ABA-format account checking for Electronic Check payment info',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'voip-cust_accountcode_cdr',
    'section'     => 'telephony',
    'description' => 'Enable the per-customer option for CDR breakdown by accountcode.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'voip-cust_cdr_spools',
    'section'     => 'telephony',
    'description' => 'Enable the per-customer option for individual CDR spools.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'voip-cust_cdr_squelch',
    'section'     => 'telephony',
    'description' => 'Enable the per-customer option for not printing CDR on invoices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'voip-cdr_email',
    'section'     => 'telephony',
    'description' => 'Include the call details on emailed invoices (and HTML invoices viewed in the backend), even if the customer is configured for not printing them on the invoices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'voip-cust_email_csv_cdr',
    'section'     => 'telephony',
    'description' => 'Enable the per-customer option for including CDR information as a CSV attachment on emailed invoices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cgp_rule-domain_templates',
    'section'     => '',
    'description' => 'Communigate Pro rule templates for domains, one per line, "svcnum Name"',
    'type'        => 'textarea',
  },

  {
    'key'         => 'svc_forward-no_srcsvc',
    'section'     => '',
    'description' => "Don't allow forwards from existing accounts, only arbitrary addresses.  Useful when exporting to systems such as Communigate Pro which treat forwards in this fashion.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_forward-arbitrary_dst',
    'section'     => '',
    'description' => "Allow forwards to point to arbitrary strings that don't necessarily look like email addresses.  Only used when using forwards for weird, non-email things.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'tax-ship_address',
    'section'     => 'billing',
    'description' => 'By default, tax calculations are done based on the billing address.  Enable this switch to calculate tax based on the shipping address instead.',
    'type'        => 'checkbox',
  }
,
  {
    'key'         => 'tax-pkg_address',
    'section'     => 'billing',
    'description' => 'By default, tax calculations are done based on the billing address.  Enable this switch to calculate tax based on the package address instead (when present).',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice-ship_address',
    'section'     => 'invoicing',
    'description' => 'Include the shipping address on invoices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice-unitprice',
    'section'     => 'invoicing',
    'description' => 'Enable unit pricing on invoices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice-smallernotes',
    'section'     => 'invoicing',
    'description' => 'Display the notes section in a smaller font on invoices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice-smallerfooter',
    'section'     => 'invoicing',
    'description' => 'Display footers in a smaller font on invoices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'postal_invoice-fee_pkgpart',
    'section'     => 'billing',
    'description' => 'This allows selection of a package to insert on invoices for customers with postal invoices selected.',
    'type'        => 'select-part_pkg',
    'per_agent'   => 1,
  },

  {
    'key'         => 'postal_invoice-recurring_only',
    'section'     => 'billing',
    'description' => 'The postal invoice fee is omitted on invoices without reucrring charges when this is set.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'batch-enable',
    'section'     => 'deprecated', #make sure batch-enable_payby is set for
                                   #everyone before removing
    'description' => 'Enable credit card and/or ACH batching - leave disabled for real-time installations.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'batch-enable_payby',
    'section'     => 'billing',
    'description' => 'Enable batch processing for the specified payment types.',
    'type'        => 'selectmultiple',
    'select_enum' => [qw( CARD CHEK )],
  },

  {
    'key'         => 'realtime-disable_payby',
    'section'     => 'billing',
    'description' => 'Disable realtime processing for the specified payment types.',
    'type'        => 'selectmultiple',
    'select_enum' => [qw( CARD CHEK )],
  },

  {
    'key'         => 'batch-default_format',
    'section'     => 'billing',
    'description' => 'Default format for batches.',
    'type'        => 'select',
    'select_enum' => [ 'csv-td_canada_trust-merchant_pc_batch',
                       'csv-chase_canada-E-xactBatch', 'BoM', 'PAP',
                       'paymentech', 'ach-spiritone', 'RBC'
                    ]
  },

  #lists could be auto-generated from pay_batch info
  {
    'key'         => 'batch-fixed_format-CARD',
    'section'     => 'billing',
    'description' => 'Fixed (unchangeable) format for credit card batches.',
    'type'        => 'select',
    'select_enum' => [ 'csv-td_canada_trust-merchant_pc_batch', 'BoM', 'PAP' ,
                       'csv-chase_canada-E-xactBatch', 'paymentech' ]
  },

  {
    'key'         => 'batch-fixed_format-CHEK',
    'section'     => 'billing',
    'description' => 'Fixed (unchangeable) format for electronic check batches.',
    'type'        => 'select',
    'select_enum' => [ 'csv-td_canada_trust-merchant_pc_batch', 'BoM', 'PAP',
                       'paymentech', 'ach-spiritone', 'RBC', 'td_eft1464',
                       'eft_canada'
                     ]
  },

  {
    'key'         => 'batch-increment_expiration',
    'section'     => 'billing',
    'description' => 'Increment expiration date years in batches until cards are current.  Make sure this is acceptable to your batching provider before enabling.',
    'type'        => 'checkbox'
  },

  {
    'key'         => 'batchconfig-BoM',
    'section'     => 'billing',
    'description' => 'Configuration for Bank of Montreal batching, seven lines: 1. Origin ID, 2. Datacenter, 3. Typecode, 4. Short name, 5. Long name, 6. Bank, 7. Bank account',
    'type'        => 'textarea',
  },

  {
    'key'         => 'batchconfig-PAP',
    'section'     => 'billing',
    'description' => 'Configuration for PAP batching, seven lines: 1. Origin ID, 2. Datacenter, 3. Typecode, 4. Short name, 5. Long name, 6. Bank, 7. Bank account',
    'type'        => 'textarea',
  },

  {
    'key'         => 'batchconfig-csv-chase_canada-E-xactBatch',
    'section'     => 'billing',
    'description' => 'Gateway ID for Chase Canada E-xact batching',
    'type'        => 'text',
  },

  {
    'key'         => 'batchconfig-paymentech',
    'section'     => 'billing',
    'description' => 'Configuration for Chase Paymentech batching, five lines: 1. BIN, 2. Terminal ID, 3. Merchant ID, 4. Username, 5. Password (for batch uploads)',
    'type'        => 'textarea',
  },

  {
    'key'         => 'batchconfig-RBC',
    'section'     => 'billing',
    'description' => 'Configuration for Royal Bank of Canada PDS batching, four lines: 1. Client number, 2. Short name, 3. Long name, 4. Transaction code.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'batchconfig-td_eft1464',
    'section'     => 'billing',
    'description' => 'Configuration for TD Bank EFT1464 batching, seven lines: 1. Originator ID, 2. Datacenter Code, 3. Short name, 4. Long name, 5. Returned payment branch number, 6. Returned payment account, 7. Transaction code.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'batch-manual_approval',
    'section'     => 'billing',
    'description' => 'Allow manual batch closure, which will approve all payments that do not yet have a status.  This is not advised, but is needed for payment processors that provide a report of rejected rather than approved payments.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'batchconfig-eft_canada',
    'section'     => 'billing',
    'description' => 'Configuration for EFT Canada batching, four lines: 1. SFTP username, 2. SFTP password, 3. Transaction code, 4. Number of days to delay process date.',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'batch-spoolagent',
    'section'     => 'billing',
    'description' => 'Store payment batches per-agent.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'payment_history-years',
    'section'     => 'UI',
    'description' => 'Number of years of payment history to show by default.  Currently defaults to 2.',
    'type'        => 'text',
  },

  {
    'key'         => 'change_history-years',
    'section'     => 'UI',
    'description' => 'Number of years of change history to show by default.  Currently defaults to 0.5.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_main-packages-years',
    'section'     => 'UI',
    'description' => 'Number of years to show old (cancelled and one-time charge) packages by default.  Currently defaults to 2.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_main-use_comments',
    'section'     => 'UI',
    'description' => 'Display free form comments on the customer edit screen.  Useful as a scratch pad.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-disable_notes',
    'section'     => 'UI',
    'description' => 'Disable new style customer notes - timestamped and user identified customer notes.  Useful in tracking who did what.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main_note-display_times',
    'section'     => 'UI',
    'description' => 'Display full timestamps (not just dates) for customer notes.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-ticket_statuses',
    'section'     => 'UI',
    'description' => 'Show tickets with these statuses on the customer view page.',
    'type'        => 'selectmultiple',
    'select_enum' => [qw( new open stalled resolved rejected deleted )],
  },

  {
    'key'         => 'cust_main-max_tickets',
    'section'     => 'UI',
    'description' => 'Maximum number of tickets to show on the customer view page.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_main-skeleton_tables',
    'section'     => '',
    'description' => 'Tables which will have skeleton records inserted into them for each customer.  Syntax for specifying tables is unfortunately a tricky perl data structure for now.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cust_main-skeleton_custnum',
    'section'     => '',
    'description' => 'Customer number specifying the source data to copy into skeleton tables for new customers.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_main-enable_birthdate',
    'section'     => 'UI',
    'descritpion' => 'Enable tracking of a birth date with each customer record',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-edit_calling_list_exempt',
    'section'     => 'UI',
    'description' => 'Display the "calling_list_exempt" checkbox on customer edit.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'support-key',
    'section'     => '',
    'description' => 'A support key enables access to commercial services delivered over the network, such as the payroll module, access to the internal ticket system, priority support and optional backups.',
    'type'        => 'text',
  },

  {
    'key'         => 'card-types',
    'section'     => 'billing',
    'description' => 'Select one or more card types to enable only those card types.  If no card types are selected, all card types are available.',
    'type'        => 'selectmultiple',
    'select_enum' => \@card_types,
  },

  {
    'key'         => 'disable-fuzzy',
    'section'     => 'UI',
    'description' => 'Disable fuzzy searching.  Speeds up searching for large sites, but only shows exact matches.',
    'type'        => 'checkbox',
  },

  { 'key'         => 'pkg_referral',
    'section'     => '',
    'description' => 'Enable package-specific advertising sources.',
    'type'        => 'checkbox',
  },

  { 'key'         => 'pkg_referral-multiple',
    'section'     => '',
    'description' => 'In addition, allow multiple advertising sources to be associated with a single package.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'dashboard-install_welcome',
    'section'     => 'UI',
    'description' => 'New install welcome screen.',
    'type'        => 'select',
    'select_enum' => [ '', 'ITSP_fsinc_hosted', ],
  },

  {
    'key'         => 'dashboard-toplist',
    'section'     => 'UI',
    'description' => 'List of items to display on the top of the front page',
    'type'        => 'textarea',
  },

  {
    'key'         => 'impending_recur_msgnum',
    'section'     => 'notification',
    'description' => 'Template to use for alerts about first-time recurring billing.',
    %msg_template_options,
  },

  {
    'key'         => 'impending_recur_template',
    'section'     => 'deprecated',
    'description' => 'Template file for alerts about looming first time recurrant billing.  See the <a href="http://search.cpan.org/dist/Text-Template/lib/Text/Template.pm">Text::Template</a> documentation for details on the template substitition language.  Also see packages with a <a href="../browse/part_pkg.cgi">flat price plan</a>  The following variables are available<ul><li><code>$packages</code> allowing <code>$packages->[0]</code> thru <code>$packages->[n]</code> <li><code>$package</code> the first package, same as <code>$packages->[0]</code> <li><code>$recurdates</code> allowing <code>$recurdates->[0]</code> thru <code>$recurdates->[n]</code> <li><code>$recurdate</code> the first recurdate, same as <code>$recurdate->[0]</code> <li><code>$first</code> <li><code>$last</code></ul>',
# <li><code>$payby</code> <li><code>$expdate</code> most likely only confuse
    'type'        => 'textarea',
  },

  {
    'key'         => 'logo.png',
    'section'     => 'UI',  #'invoicing' ?
    'description' => 'Company logo for HTML invoices and the backoffice interface, in PNG format.  Suggested size somewhere near 92x62.',
    'type'        => 'image',
    'per_agent'   => 1, #XXX just view/logo.cgi, which is for the global
                        #old-style editor anyway...?
    'per_locale'  => 1,
  },

  {
    'key'         => 'logo.eps',
    'section'     => 'invoicing',
    'description' => 'Company logo for printed and PDF invoices, in EPS format.',
    'type'        => 'image',
    'per_agent'   => 1, #XXX as above, kinda
    'per_locale'  => 1,
  },

  {
    'key'         => 'selfservice-ignore_quantity',
    'section'     => 'self-service',
    'description' => 'Ignores service quantity restrictions in self-service context.  Strongly not recommended - just set your quantities correctly in the first place.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice-session_timeout',
    'section'     => 'self-service',
    'description' => 'Self-service session timeout.  Defaults to 1 hour.',
    'type'        => 'select',
    'select_enum' => [ '1 hour', '2 hours', '4 hours', '8 hours', '1 day', '1 week', ],
  },

  {
    'key'         => 'disable_setup_suspended_pkgs',
    'section'     => 'billing',
    'description' => 'Disables charging of setup fees for suspended packages.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'password-generated-allcaps',
    'section'     => 'password',
    'description' => 'Causes passwords automatically generated to consist entirely of capital letters',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'datavolume-forcemegabytes',
    'section'     => 'UI',
    'description' => 'All data volumes are expressed in megabytes',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'datavolume-significantdigits',
    'section'     => 'UI',
    'description' => 'number of significant digits to use to represent data volumes',
    'type'        => 'text',
  },

  {
    'key'         => 'disable_void_after',
    'section'     => 'billing',
    'description' => 'Number of seconds after which freeside won\'t attempt to VOID a payment first when performing a refund.',
    'type'        => 'text',
  },

  {
    'key'         => 'disable_line_item_date_ranges',
    'section'     => 'billing',
    'description' => 'Prevent freeside from automatically generating date ranges on invoice line items.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'support_packages',
    'section'     => '',
    'description' => 'A list of packages eligible for RT ticket time transfer, one pkgpart per line.', #this should really be a select multiple, or specified in the packages themselves...
    'type'        => 'select-part_pkg',
    'multiple'    => 1,
  },

  {
    'key'         => 'cust_main-require_phone',
    'section'     => '',
    'description' => 'Require daytime or night phone for all customer records.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-require_invoicing_list_email',
    'section'     => '',
    'description' => 'Email address field is required: require at least one invoicing email address for all customer records.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-display_paid_time_remaining',
    'section'     => '',
    'description' => 'Show paid time remaining in addition to time remaining.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cancel_credit_type',
    'section'     => 'billing',
    'description' => 'The group to use for new, automatically generated credit reasons resulting from cancellation.',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::reason_type;
			   map { $_->typenum => $_->type }
                               FS::Record::qsearch('reason_type', { class=>'R' } );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::reason_type;
			   my $reason_type = FS::Record::qsearchs(
			     'reason_type', { 'typenum' => shift }
			   );
                           $reason_type ? $reason_type->type : '';
			 },
  },

  {
    'key'         => 'referral_credit_type',
    'section'     => 'deprecated',
    'description' => 'Used to be the group to use for new, automatically generated credit reasons resulting from referrals.  Now set in a package billing event for the referral.',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::reason_type;
			   map { $_->typenum => $_->type }
                               FS::Record::qsearch('reason_type', { class=>'R' } );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::reason_type;
			   my $reason_type = FS::Record::qsearchs(
			     'reason_type', { 'typenum' => shift }
			   );
                           $reason_type ? $reason_type->type : '';
			 },
  },

  {
    'key'         => 'signup_credit_type',
    'section'     => 'billing', #self-service?
    'description' => 'The group to use for new, automatically generated credit reasons resulting from signup and self-service declines.',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::reason_type;
			   map { $_->typenum => $_->type }
                               FS::Record::qsearch('reason_type', { class=>'R' } );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::reason_type;
			   my $reason_type = FS::Record::qsearchs(
			     'reason_type', { 'typenum' => shift }
			   );
                           $reason_type ? $reason_type->type : '';
			 },
  },

  {
    'key'         => 'prepayment_discounts-credit_type',
    'section'     => 'billing',
    'description' => 'Enables the offering of prepayment discounts and establishes the credit reason type.',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::reason_type;
                           map { $_->typenum => $_->type }
                               FS::Record::qsearch('reason_type', { class=>'R' } );
                         },
    'option_sub'  => sub { require FS::Record;
                           require FS::reason_type;
                           my $reason_type = FS::Record::qsearchs(
                             'reason_type', { 'typenum' => shift }
                           );
                           $reason_type ? $reason_type->type : '';
                         },

  },

  {
    'key'         => 'cust_main-agent_custid-format',
    'section'     => '',
    'description' => 'Enables searching of various formatted values in cust_main.agent_custid',
    'type'        => 'select',
    'select_hash' => [
                       ''       => 'Numeric only',
                       '\d{7}'  => 'Numeric only, exactly 7 digits',
                       'ww?d+'  => 'Numeric with one or two letter prefix',
                     ],
  },

  {
    'key'         => 'card_masking_method',
    'section'     => 'UI',
    'description' => 'Digits to display when masking credit cards.  Note that the first six digits are necessary to canonically identify the credit card type (Visa/MC, Amex, Discover, Maestro, etc.) in all cases.  The first four digits can identify the most common credit card types in most cases (Visa/MC, Amex, and Discover).  The first two digits can distinguish between Visa/MC and Amex.  Note: You should manually remove stored paymasks if you change this value on an existing database, to avoid problems using stored cards.',
    'type'        => 'select',
    'select_hash' => [
                       ''            => '123456xxxxxx1234',
                       'first6last2' => '123456xxxxxxxx12',
                       'first4last4' => '1234xxxxxxxx1234',
                       'first4last2' => '1234xxxxxxxxxx12',
                       'first2last4' => '12xxxxxxxxxx1234',
                       'first2last2' => '12xxxxxxxxxxxx12',
                       'first0last4' => 'xxxxxxxxxxxx1234',
                       'first0last2' => 'xxxxxxxxxxxxxx12',
                     ],
  },

  {
    'key'         => 'disable_previous_balance',
    'section'     => 'invoicing',
    'description' => 'Disable inclusion of previous balance, payment, and credit lines on invoices',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'previous_balance-exclude_from_total',
    'section'     => 'invoicing',
    'description' => 'Do not include previous balance in the \'Total\' line.  Only meaningful when invoice_sections is false.  Optionally provide text to override the Total New Charges description',
    'type'        => [ qw(checkbox text) ],
  },

  {
    'key'         => 'previous_balance-summary_only',
    'section'     => 'invoicing',
    'description' => 'Only show a single line summarizing the total previous balance rather than one line per invoice.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'previous_balance-show_credit',
    'section'     => 'invoicing',
    'description' => 'Show the customer\'s credit balance on invoices when applicable.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'balance_due_below_line',
    'section'     => 'invoicing',
    'description' => 'Place the balance due message below a line.  Only meaningful when when invoice_sections is false.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'usps_webtools-userid',
    'section'     => 'UI',
    'description' => 'Production UserID for USPS web tools.   Enables USPS address standardization.  See the <a href="http://www.usps.com/webtools/">USPS website</a>, register and agree not to use the tools for batch purposes.',
    'type'        => 'text',
  },

  {
    'key'         => 'usps_webtools-password',
    'section'     => 'UI',
    'description' => 'Production password for USPS web tools.   Enables USPS address standardization.  See <a href="http://www.usps.com/webtools/">USPS website</a>, register and agree not to use the tools for batch purposes.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_main-auto_standardize_address',
    'section'     => 'UI',
    'description' => 'When using USPS web tools, automatically standardize the address without asking.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-require_censustract',
    'section'     => 'UI',
    'description' => 'Customer is required to have a census tract.  Useful for FCC form 477 reports. See also: cust_main-auto_standardize_address',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'census_year',
    'section'     => 'UI',
    'description' => 'The year to use in census tract lookups',
    'type'        => 'select',
    'select_enum' => [ qw( 2010 2009 2008 ) ],
  },

  {
    'key'         => 'company_latitude',
    'section'     => 'UI',
    'description' => 'Your company latitude (-90 through 90)',
    'type'        => 'text',
  },

  {
    'key'         => 'company_longitude',
    'section'     => 'UI',
    'description' => 'Your company longitude (-180 thru 180)',
    'type'        => 'text',
  },

  {
    'key'         => 'geocode_module',
    'section'     => '',
    'description' => 'Module to geocode (retrieve a latitude and longitude for) addresses',
    'type'        => 'select',
    'select_enum' => [ 'Geo::Coder::Googlev3' ],
  },

  {
    'key'         => 'geocode-require_nw_coordinates',
    'section'     => 'UI',
    'description' => 'Require latitude and longitude in the North Western quadrant, e.g. for North American co-ordinates, etc.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'disable_acl_changes',
    'section'     => '',
    'description' => 'Disable all ACL changes, for demos.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'disable_settings_changes',
    'section'     => '',
    'description' => 'Disable all settings changes, for demos, except for the usernames given in the comma-separated list.',
    'type'        => [qw( checkbox text )],
  },

  {
    'key'         => 'cust_main-edit_agent_custid',
    'section'     => 'UI',
    'description' => 'Enable editing of the agent_custid field.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-default_agent_custid',
    'section'     => 'UI',
    'description' => 'Display the agent_custid field when available instead of the custnum field.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-title-display_custnum',
    'section'     => 'UI',
    'description' => 'Add the display_custom (agent_custid or custnum) to the title on customer view pages.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_bill-default_agent_invid',
    'section'     => 'UI',
    'description' => 'Display the agent_invid field when available instead of the invnum field.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-auto_agent_custid',
    'section'     => 'UI',
    'description' => 'Automatically assign an agent_custid - select format',
    'type'        => 'select',
    'select_hash' => [ '' => 'No',
                       '1YMMXXXXXXXX' => '1YMMXXXXXXXX',
                     ],
  },

  {
    'key'         => 'cust_main-custnum-display_prefix',
    'section'     => 'UI',
    'description' => 'Prefix the customer number with this number for display purposes (and zero fill to 8 digits).',
    'type'        => 'text',
    #and then probably agent-virt this to merge these instances
  },

  {
    'key'         => 'cust_main-default_areacode',
    'section'     => 'UI',
    'description' => 'Default area code for customers.',
    'type'        => 'text',
  },

  {
    'key'         => 'order_pkg-no_start_date',
    'section'     => 'UI',
    'description' => 'Don\'t set a default start date for new packages.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'mcp_svcpart',
    'section'     => '',
    'description' => 'Master Control Program svcpart.  Leave this blank.',
    'type'        => 'text', #select-part_svc
  },

  {
    'key'         => 'cust_bill-max_same_services',
    'section'     => 'invoicing',
    'description' => 'Maximum number of the same service to list individually on invoices before condensing to a single line listing the number of services.  Defaults to 5.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-consolidate_services',
    'section'     => 'invoicing',
    'description' => 'Consolidate service display into fewer lines on invoices rather than one per service.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'suspend_email_admin',
    'section'     => '',
    'description' => 'Destination admin email address to enable suspension notices',
    'type'        => 'text',
  },

  {
    'key'         => 'email_report-subject',
    'section'     => '',
    'description' => 'Subject for reports emailed by freeside-fetch.  Defaults to "Freeside report".',
    'type'        => 'text',
  },

  {
    'key'         => 'selfservice-head',
    'section'     => 'self-service',
    'description' => 'HTML for the HEAD section of the self-service interface, typically used for LINK stylesheet tags',
    'type'        => 'textarea', #htmlarea?
    'per_agent'   => 1,
  },


  {
    'key'         => 'selfservice-body_header',
    'section'     => 'self-service',
    'description' => 'HTML header for the self-service interface',
    'type'        => 'textarea', #htmlarea?
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-body_footer',
    'section'     => 'self-service',
    'description' => 'HTML footer for the self-service interface',
    'type'        => 'textarea', #htmlarea?
    'per_agent'   => 1,
  },


  {
    'key'         => 'selfservice-body_bgcolor',
    'section'     => 'self-service',
    'description' => 'HTML background color for the self-service interface, for example, #FFFFFF',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-box_bgcolor',
    'section'     => 'self-service',
    'description' => 'HTML color for self-service interface input boxes, for example, #C0C0C0',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-text_color',
    'section'     => 'self-service',
    'description' => 'HTML text color for the self-service interface, for example, #000000',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-link_color',
    'section'     => 'self-service',
    'description' => 'HTML link color for the self-service interface, for example, #0000FF',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-vlink_color',
    'section'     => 'self-service',
    'description' => 'HTML visited link color for the self-service interface, for example, #FF00FF',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-hlink_color',
    'section'     => 'self-service',
    'description' => 'HTML hover link color for the self-service interface, for example, #808080',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-alink_color',
    'section'     => 'self-service',
    'description' => 'HTML active (clicked) link color for the self-service interface, for example, #808080',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-font',
    'section'     => 'self-service',
    'description' => 'HTML font CSS for the self-service interface, for example, 0.9em/1.5em Arial, Helvetica, Geneva, sans-serif',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-title_color',
    'section'     => 'self-service',
    'description' => 'HTML color for the self-service title, for example, #000000',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-title_align',
    'section'     => 'self-service',
    'description' => 'HTML alignment for the self-service title, for example, center',
    'type'        => 'text',
    'per_agent'   => 1,
  },
  {
    'key'         => 'selfservice-title_size',
    'section'     => 'self-service',
    'description' => 'HTML font size for the self-service title, for example, 3',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-title_left_image',
    'section'     => 'self-service',
    'description' => 'Image used for the top of the menu in the self-service interface, in PNG format.',
    'type'        => 'image',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-title_right_image',
    'section'     => 'self-service',
    'description' => 'Image used for the top of the menu in the self-service interface, in PNG format.',
    'type'        => 'image',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-menu_skipblanks',
    'section'     => 'self-service',
    'description' => 'Skip blank (spacer) entries in the self-service menu',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-menu_skipheadings',
    'section'     => 'self-service',
    'description' => 'Skip the unclickable heading entries in the self-service menu',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-menu_bgcolor',
    'section'     => 'self-service',
    'description' => 'HTML color for the self-service menu, for example, #C0C0C0',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-menu_fontsize',
    'section'     => 'self-service',
    'description' => 'HTML font size for the self-service menu, for example, -1',
    'type'        => 'text',
    'per_agent'   => 1,
  },
  {
    'key'         => 'selfservice-menu_nounderline',
    'section'     => 'self-service',
    'description' => 'Styles menu links in the self-service without underlining.',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },


  {
    'key'         => 'selfservice-menu_top_image',
    'section'     => 'self-service',
    'description' => 'Image used for the top of the menu in the self-service interface, in PNG format.',
    'type'        => 'image',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-menu_body_image',
    'section'     => 'self-service',
    'description' => 'Repeating image used for the body of the menu in the self-service interface, in PNG format.',
    'type'        => 'image',
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-menu_bottom_image',
    'section'     => 'self-service',
    'description' => 'Image used for the bottom of the menu in the self-service interface, in PNG format.',
    'type'        => 'image',
    'per_agent'   => 1,
  },
  
  {
    'key'         => 'selfservice-view_usage_nodomain',
    'section'     => 'self-service',
    'description' => 'Show usernames without their domains in "View my usage" in the self-service interface.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice-bulk_format',
    'section'     => 'deprecated',
    'description' => 'Parameter arrangement for selfservice bulk features',
    'type'        => 'select',
    'select_enum' => [ '', 'izoom-soap', 'izoom-ftp' ],
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-bulk_ftp_dir',
    'section'     => 'deprecated',
    'description' => 'Enable bulk ftp provisioning in this folder',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'signup-no_company',
    'section'     => 'self-service',
    'description' => "Don't display a field for company name on signup.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signup-recommend_email',
    'section'     => 'self-service',
    'description' => 'Encourage the entry of an invoicing email address on signup.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signup-recommend_daytime',
    'section'     => 'self-service',
    'description' => 'Encourage the entry of a daytime phone number on signup.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signup-duplicate_cc-warn_hours',
    'section'     => 'self-service',
    'description' => 'Issue a warning if the same credit card is used for multiple signups within this many hours.',
    'type'        => 'text',
  },

  {
    'key'         => 'svc_phone-radius-default_password',
    'section'     => 'telephony',
    'description' => 'Default password when exporting svc_phone records to RADIUS',
    'type'        => 'text',
  },

  {
    'key'         => 'svc_phone-allow_alpha_phonenum',
    'section'     => 'telephony',
    'description' => 'Allow letters in phone numbers.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_phone-domain',
    'section'     => 'telephony',
    'description' => 'Track an optional domain association with each phone service.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_phone-phone_name-max_length',
    'section'     => 'telephony',
    'description' => 'Maximum length of the phone service "Name" field (svc_phone.phone_name).  Sometimes useful to limit this (to 15?) when exporting as Caller ID data.',
    'type'        => 'text',
  },

  {
    'key'         => 'svc_phone-random_pin',
    'section'     => 'telephony',
    'description' => 'Number of random digits to generate in the "PIN" field, if empty.',
    'type'        => 'text',
  },

  {
    'key'         => 'svc_phone-lnp',
    'section'     => 'telephony',
    'description' => 'Enables Number Portability features for svc_phone',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'default_phone_countrycode',
    'section'     => '',
    'description' => 'Default countrcode',
    'type'        => 'text',
  },

  {
    'key'         => 'cdr-charged_party-field',
    'section'     => 'telephony',
    'description' => 'Set the charged_party field of CDRs to this field.',
    'type'        => 'select-sub',
    'options_sub' => sub { my $fields = FS::cdr->table_info->{'fields'};
                           map { $_ => $fields->{$_}||$_ }
                           grep { $_ !~ /^(acctid|charged_party)$/ }
                           FS::Schema::dbdef->table('cdr')->columns;
                         },
    'option_sub'  => sub { my $f = shift;
                           FS::cdr->table_info->{'fields'}{$f} || $f;
                         },
  },

  #probably deprecate in favor of cdr-charged_party-field above
  {
    'key'         => 'cdr-charged_party-accountcode',
    'section'     => 'telephony',
    'description' => 'Set the charged_party field of CDRs to the accountcode.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cdr-charged_party-accountcode-trim_leading_0s',
    'section'     => 'telephony',
    'description' => 'When setting the charged_party field of CDRs to the accountcode, trim any leading zeros.',
    'type'        => 'checkbox',
  },

#  {
#    'key'         => 'cdr-charged_party-truncate_prefix',
#    'section'     => '',
#    'description' => 'If the charged_party field has this prefix, truncate it to the length in cdr-charged_party-truncate_length.',
#    'type'        => 'text',
#  },
#
#  {
#    'key'         => 'cdr-charged_party-truncate_length',
#    'section'     => '',
#    'description' => 'If the charged_party field has the prefix in cdr-charged_party-truncate_prefix, truncate it to this length.',
#    'type'        => 'text',
#  },

  {
    'key'         => 'cdr-charged_party_rewrite',
    'section'     => 'telephony',
    'description' => 'Do charged party rewriting in the freeside-cdrrewrited daemon; useful if CDRs are being dropped off directly in the database and require special charged_party processing such as cdr-charged_party-accountcode or cdr-charged_party-truncate*.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cdr-taqua-da_rewrite',
    'section'     => 'telephony',
    'description' => 'For the Taqua CDR format, a comma-separated list of directory assistance 800 numbers.  Any CDRs with these numbers as "BilledNumber" will be rewritten to the "CallingPartyNumber" (and CallType "12") on import.',
    'type'        => 'text',
  },

  {
    'key'         => 'cdr-taqua-accountcode_rewrite',
    'section'     => 'telephony',
    'description' => 'For the Taqua CDR format, pull accountcodes from secondary CDRs with matching sessionNumber.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_pkg-show_autosuspend',
    'section'     => 'UI',
    'description' => 'Show package auto-suspend dates.  Use with caution for now; can slow down customer view for large insallations.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cdr-asterisk_forward_rewrite',
    'section'     => 'telephony',
    'description' => 'Enable special processing for CDRs representing forwarded calls: For CDRs that have a dcontext that starts with "Local/" but does not match dst, set charged_party to dst, parse a new dst from dstchannel, and set amaflags to "2" ("BILL"/"BILLING").',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'sg-multicustomer_hack',
    'section'     => '',
    'description' => "Don't use this.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'sg-ping_username',
    'section'     => '',
    'description' => "Don't use this.",
    'type'        => 'text',
  },

  {
    'key'         => 'sg-ping_password',
    'section'     => '',
    'description' => "Don't use this.",
    'type'        => 'text',
  },

  {
    'key'         => 'sg-login_username',
    'section'     => '',
    'description' => "Don't use this.",
    'type'        => 'text',
  },

  {
    'key'         => 'mc-outbound_packages',
    'section'     => '',
    'description' => "Don't use this.",
    'type'        => 'select-part_pkg',
    'multiple'    => 1,
  },

  {
    'key'         => 'disable-cust-pkg_class',
    'section'     => 'UI',
    'description' => 'Disable the two-step dropdown for selecting package class and package, and return to the classic single dropdown.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'queued-max_kids',
    'section'     => '',
    'description' => 'Maximum number of queued processes.  Defaults to 10.',
    'type'        => 'text',
  },

  {
    'key'         => 'queued-sleep_time',
    'section'     => '',
    'description' => 'Time to sleep between attempts to find new jobs to process in the queue.  Defaults to 10.  Installations doing real-time CDR processing for prepaid may want to set it lower.',
    'type'        => 'text',
  },

  {
    'key'         => 'cancelled_cust-noevents',
    'section'     => 'billing',
    'description' => "Don't run events for cancelled customers",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'agent-invoice_template',
    'section'     => 'invoicing',
    'description' => 'Enable display/edit of old-style per-agent invoice template selection',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_broadband-manage_link',
    'section'     => 'UI',
    'description' => 'URL for svc_broadband "Manage Device" link.  The following substitutions are available: $ip_addr.',
    'type'        => 'text',
  },

  {
    'key'         => 'svc_broadband-manage_link_text',
    'section'     => 'UI',
    'description' => 'Label for "Manage Device" link',
    'type'        => 'text',
  },

  {
    'key'         => 'svc_broadband-manage_link_loc',
    'section'     => 'UI',
    'description' => 'Location for "Manage Device" link',
    'type'        => 'select',
    'select_hash' => [
      'bottom' => 'Near Unprovision link',
      'right'  => 'With export-related links',
    ],
  },

  {
    'key'         => 'svc_broadband-manage_link-new_window',
    'section'     => 'UI',
    'description' => 'Open the "Manage Device" link in a new window',
    'type'        => 'checkbox',
  },

  #more fine-grained, service def-level control could be useful eventually?
  {
    'key'         => 'svc_broadband-allow_null_ip_addr',
    'section'     => '',
    'description' => '',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'tax-report_groups',
    'section'     => '',
    'description' => 'List of grouping possibilities for tax names on reports, one per line, "label op value" (op can be = or !=).',
    'type'        => 'textarea',
  },

  {
    'key'         => 'tax-cust_exempt-groups',
    'section'     => '',
    'description' => 'List of grouping possibilities for tax names, for per-customer exemption purposes, one tax name per line.  For example, "GST" would indicate the ability to exempt customers individually from taxes named "GST" (but not other taxes).',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cust_main-default_view',
    'section'     => 'UI',
    'description' => 'Default customer view, for users who have not selected a default view in their preferences.',
    'type'        => 'select',
    'select_hash' => [
      #false laziness w/view/cust_main.cgi and pref/pref.html
      'basics'          => 'Basics',
      'notes'           => 'Notes',
      'tickets'         => 'Tickets',
      'packages'        => 'Packages',
      'payment_history' => 'Payment History',
      'change_history'  => 'Change History',
      'jumbo'           => 'Jumbo',
    ],
  },

  {
    'key'         => 'enable_tax_adjustments',
    'section'     => 'billing',
    'description' => 'Enable the ability to add manual tax adjustments.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'rt-crontool',
    'section'     => '',
    'description' => 'Enable the RT CronTool extension.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'pkg-balances',
    'section'     => 'billing',
    'description' => 'Enable experimental package balances.  Not recommended for general use.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'pkg-addon_classnum',
    'section'     => 'billing',
    'description' => 'Enable the ability to restrict additional package orders based on package class.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-edit_signupdate',
    'section'     => 'UI',
    'descritpion' => 'Enable manual editing of the signup date.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-disable_access_number',
    'section'     => 'UI',
    'descritpion' => 'Disable access number selection.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_bill_pay_pkg-manual',
    'section'     => 'UI',
    'description' => 'Allow manual application of payments to line items.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_credit_bill_pkg-manual',
    'section'     => 'UI',
    'description' => 'Allow manual application of credits to line items.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'breakage-days',
    'section'     => 'billing',
    'description' => 'If set to a number of days, after an account goes that long without activity, recognizes any outstanding payments and credits as "breakage" by creating a breakage charge and invoice.',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'breakage-pkg_class',
    'section'     => 'billing',
    'description' => 'Package class to use for breakage reconciliation.',
    'type'        => 'select-pkg_class',
  },

  {
    'key'         => 'disable_cron_billing',
    'section'     => 'billing',
    'description' => 'Disable billing and collection from being run by freeside-daily and freeside-monthly, while still allowing other actions to run, such as notifications and backup.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_domain-edit_domain',
    'section'     => '',
    'description' => 'Enable domain renaming',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'enable_legacy_prepaid_income',
    'section'     => '',
    'description' => "Enable legacy prepaid income reporting.  Only useful when you have imported pre-Freeside packages with longer-than-monthly duration, and need to do prepaid income reporting on them before they've been invoiced the first time.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-exports',
    'section'     => '',
    'description' => 'Export(s) to call on cust_main insert, modification and deletion.',
    'type'        => 'select-sub',
    'multiple'    => 1,
    'options_sub' => sub {
      require FS::Record;
      require FS::part_export;
      my @part_export =
        map { qsearch( 'part_export', {exporttype => $_ } ) }
          keys %{FS::part_export::export_info('cust_main')};
      map { $_->exportnum => $_->exporttype.' to '.$_->machine } @part_export;
    },
    'option_sub'  => sub {
      require FS::Record;
      require FS::part_export;
      my $part_export = FS::Record::qsearchs(
        'part_export', { 'exportnum' => shift }
      );
      $part_export
        ? $part_export->exporttype.' to '.$part_export->machine
        : '';
    },
  },

  {
    'key'         => 'cust_tag-location',
    'section'     => 'UI',
    'description' => 'Location where customer tags are displayed.',
    'type'        => 'select',
    'select_enum' => [ 'misc_info', 'top' ],
  },

  {
    'key'         => 'maestro-status_test',
    'section'     => 'UI',
    'description' => 'Display a link to the maestro status test page on the customer view page',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_main-custom_link',
    'section'     => 'UI',
    'description' => 'URL to use as source for the "Custom" tab in the View Customer page.  The customer number will be appended, or you can insert "$custnum" to have it inserted elsewhere.  "$agentnum" will be replaced with the agent number, and "$usernum" will be replaced with the employee number.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cust_main-custom_title',
    'section'     => 'UI',
    'description' => 'Title for the "Custom" tab in the View Customer page.',
    'type'        => 'text',
  },

  {
    'key'         => 'part_pkg-default_suspend_bill',
    'section'     => 'billing',
    'description' => 'Default the "Continue recurring billing while suspended" flag to on for new package definitions.',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'qual-alt_address_format',
    'section'     => 'UI',
    'description' => 'Enable the alternate address format (location type, number, and kind) for qualifications.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'prospect_main-alt_address_format',
    'section'     => 'UI',
    'description' => 'Enable the alternate address format (location type, number, and kind) for prospects.  Recommended if qual-alt_address_format is set and the main use of propects is for qualifications.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'prospect_main-location_required',
    'section'     => 'UI',
    'description' => 'Require an address for prospects.  Recommended if the main use of propects is for qualifications.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'note-classes',
    'section'     => 'UI',
    'description' => 'Use customer note classes',
    'type'        => 'select',
    'select_hash' => [
                       0 => 'Disabled',
		       1 => 'Enabled',
		       2 => 'Enabled, with tabs',
		     ],
  },

  {
    'key'         => 'svc_acct-cf_privatekey-message',
    'section'     => '',
    'description' => 'For internal use: HTML displayed when cf_privatekey field is set.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'menu-prepend_links',
    'section'     => 'UI',
    'description' => 'Links to prepend to the main menu, one per line, with format "URL Link Label (optional ALT popup)".',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cust_main-external_links',
    'section'     => 'UI',
    'description' => 'External links available in customer view, one per line, with format "URL Link Label (optional ALT popup)".  The URL will have custnum appended.',
    'type'        => 'textarea',
  },
  
  {
    'key'         => 'svc_phone-did-summary',
    'section'     => 'invoicing',
    'description' => 'Enable DID activity summary on invoices, showing # DIDs activated/deactivated/ported-in/ported-out and total minutes usage, covering period since last invoice.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_acct-usage_seconds',
    'section'     => 'invoicing',
    'description' => 'Enable calculation of RADIUS usage time for invoices.  You must modify your template to display this information.',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'opensips_gwlist',
    'section'     => 'telephony',
    'description' => 'For svc_phone OpenSIPS dr_rules export, gwlist column value, per-agent',
    'type'        => 'text',
    'per_agent'   => 1,
    'agentonly'   => 1,
  },

  {
    'key'         => 'opensips_description',
    'section'     => 'telephony',
    'description' => 'For svc_phone OpenSIPS dr_rules export, description column value, per-agent',
    'type'        => 'text',
    'per_agent'   => 1,
    'agentonly'   => 1,
  },
  
  {
    'key'         => 'opensips_route',
    'section'     => 'telephony',
    'description' => 'For svc_phone OpenSIPS dr_rules export, routeid column value, per-agent',
    'type'        => 'text',
    'per_agent'   => 1,
    'agentonly'   => 1,
  },

  {
    'key'         => 'cust_bill-no_recipients-error',
    'section'     => 'invoicing',
    'description' => 'For customers with no invoice recipients, throw a job queue error rather than the default behavior of emailing the invoice to the invoice_from address.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_bill-latex_lineitem_maxlength',
    'section'     => 'invoicing',
    'description' => 'Truncate long line items to this number of characters on typeset invoices, to avoid losing things off the right margin.  Defaults to 50.  ',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_main-status_module',
    'section'     => 'UI',
    'description' => 'Which module to use for customer status display.  The "Classic" module (the default) considers accounts with cancelled recurring packages but un-cancelled one-time charges Inactive.  The "Recurring" module considers those customers Cancelled.  Similarly for customers with suspended recurring packages but one-time charges.', #other differences?
    'type'        => 'select',
    'select_enum' => [ 'Classic', 'Recurring' ],
  },

  { 
    'key'         => 'username-pound',
    'section'     => 'username',
    'description' => 'Allow the pound character (#) in usernames.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'ie-compatibility_mode',
    'section'     => 'UI',
    'description' => "Compatibility mode META tag for Internet Explorer, used on the customer view page.  Not necessary in normal operation unless custom content (notes, cust_main-custom_link) is included on customer view that is incompatibile with newer IE verisons.",
    'type'        => 'select',
    'select_enum' => [ '', '7', 'EmulateIE7', '8', 'EmulateIE8' ],
  },

  {
    'key'         => 'disable_payauto_default',
    'section'     => 'UI',
    'description' => 'Disable the "Charge future payments to this (card|check) automatically" checkbox from defaulting to checked.',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'payment-history-report',
    'section'     => 'UI',
    'description' => 'Show a link to the raw database payment history report in the Reports menu.  DO NOT ENABLE THIS for modern installations.',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'svc_broadband-require-nw-coordinates',
    'section'     => 'deprecated',
    'description' => 'Deprecated; see geocode-require_nw_coordinates instead',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'cust-email-high-visibility',
    'section'     => 'UI',
    'description' => 'Move the invoicing e-mail address field to the top of the billing address section and highlight it.',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'cust_main-require-bank-branch',
    'section'     => 'UI',
    'description' => 'An alternate DCHK/CHEK format; require entry of bank branch number.',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'cust-edit-alt-field-order',
    'section'     => 'UI',
    'description' => 'An alternate ordering of fields for the New Customer and Edit Customer screens.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cust_bill-enable_promised_date',
    'section'     => 'UI',
    'description' => 'Enable display/editing of the "promised payment date" field on invoices.',
    'type'        => 'checkbox',
  },
  
  {
    'key'         => 'available-locales',
    'section'     => '',
    'description' => 'Limit available locales (employee preferences, per-customer locale selection, etc.) to a particular set.',
    'type'        => 'select-sub',
    'multiple'    => 1,
    'options_sub' => sub { 
      map { $_ => FS::Locales->description($_) }
      grep { $_ ne 'en_US' } 
      FS::Locales->locales;
    },
    'option_sub'  => sub { FS::Locales->description(shift) },
  },
  
  {
    'key'         => 'translate-auto-insert',
    'section'     => '',
    'description' => 'Auto-insert untranslated strings for selected non-en_US locales with their default/en_US values.  Do not turn this on unless translating the interface into a new language.',
    'type'        => 'select',
    'multiple'    => 1,
    'select_enum' => [ grep { $_ ne 'en_US' } FS::Locales::locales ],
  },

  {
    'key'         => 'svc_acct-tower_sector',
    'section'     => '',
    'description' => 'Track tower and sector for svc_acct (account) services.',
    'type'        => 'checkbox',
  },

  { key => "apacheroot", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "apachemachine", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "apachemachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "bindprimary", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "bindsecondaries", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "bsdshellmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "cyrus", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "cp_app", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "erpcdmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "icradiusmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "icradius_mysqldest", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "icradius_mysqlsource", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "icradius_secrets", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "maildisablecatchall", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "mxmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "nsmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "arecords", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "cnamerecords", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "nismachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "qmailmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "radiusmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "sendmailconfigpath", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "sendmailmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "sendmailrestart", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "shellmachine", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "shellmachine-useradd", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "shellmachine-userdel", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "shellmachine-usermod", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "shellmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "radiusprepend", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "textradiusprepend", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "username_policy", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "vpopmailmachines", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "vpopmailrestart", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "safe-part_pkg", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "selfservice_server-quiet", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "signup_server-quiet", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "signup_server-email", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "vonage-username", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "vonage-password", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },
  { key => "vonage-fromnumber", section => "deprecated", description => "<b>DEPRECATED</b>", type => "text" },

);

1;

