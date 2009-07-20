package FS::Conf;

use vars qw($base_dir @config_items @base_items @card_types $DEBUG);
use Carp;
use IO::File;
use File::Basename;
use MIME::Base64;
use FS::ConfItem;
use FS::ConfDefaults;
use FS::Conf_compat17;
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

=item new

Create a new configuration object.

=cut

sub new {
  my($proto) = @_;
  my($class) = ref($proto) || $proto;
  my($self) = { 'base_dir' => $base_dir };
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

=item config KEY [ AGENTNUM ]

Returns the configuration value or values (depending on context) for key.
The optional agent number selects an agent specific value instead of the
global default if one is present.

=cut

sub _usecompat {
  my ($self, $method) = (shift, shift);
  carp "NO CONFIGURATION RECORDS FOUND -- USING COMPATIBILITY MODE"
    if use_confcompat;
  my $compat = new FS::Conf_compat17 ("$base_dir/conf." . datasrc);
  $compat->$method(@_);
}

# needs a non _ name, called externally by config-view now (and elsewhere?)
sub _config {
  my($self,$name,$agentnum)=@_;
  my $hashref = { 'name' => $name };
  $hashref->{agentnum} = $agentnum;
  local $FS::Record::conf = undef;  # XXX evil hack prevents recursion
  my $cv = FS::Record::qsearchs('conf', $hashref);
  if (!$cv && defined($agentnum) && $agentnum) {
    $hashref->{agentnum} = '';
    $cv = FS::Record::qsearchs('conf', $hashref);
  }
  return $cv;
}

sub config {
  my $self = shift;
  return $self->_usecompat('config', @_) if use_confcompat;

  my($name, $agentnum)=@_;

  carp "FS::Conf->config($name, $agentnum) called"
    if $DEBUG > 1;

  my $cv = $self->_config($name, $agentnum) or return;

  if ( wantarray ) {
    my $v = $cv->value;
    chomp $v;
    (split "\n", $v, -1);
  } else {
    (split("\n", $cv->value))[0];
  }
}

=item config_binary KEY [ AGENTNUM ]

Returns the exact scalar value for key.

=cut

sub config_binary {
  my $self = shift;
  return $self->_usecompat('config_binary', @_) if use_confcompat;

  my($name,$agentnum)=@_;
  my $cv = $self->_config($name, $agentnum) or return;
  decode_base64($cv->value);
}

=item exists KEY [ AGENTNUM ]

Returns true if the specified key exists, even if the corresponding value
is undefined.

=cut

sub exists {
  my $self = shift;
  return $self->_usecompat('exists', @_) if use_confcompat;

  my($name, $agentnum)=@_;

  carp "FS::Conf->exists($name, $agentnum) called"
    if $DEBUG > 1;

  defined($self->_config($name, $agentnum));
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

  my $old = FS::Record::qsearchs('conf', {name => $name, agentnum => $agentnum});
  my $new = new FS::conf { $old ? $old->hash 
                                : ('name' => $name, 'agentnum' => $agentnum)
                         };
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
  if ( my $cv = FS::Record::qsearchs('conf', {name => $name, agentnum => $agentnum}) ) {
    warn "[FS::Conf] DELETE $name\n";

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
                  'description' => 'Alternate ' . $proto->description . '  See the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.7:Documentation:Administration#Invoice_templates">billing documentation</a> for details.',
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

@base_items = qw (
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

@config_items = map { new FS::ConfItem $_ } (

  {
    'key'         => 'address',
    'section'     => 'deprecated',
    'description' => 'This configuration option is no longer used.  See <a href="#invoice_template">invoice_template</a> instead.',
    'type'        => 'text',
  },

  {
    'key'         => 'alert_expiration',
    'section'     => 'billing',
    'description' => 'Enable alerts about billing method expiration.',
    'type'        => 'checkbox',
    'per_agent'   => 1,
  },

  {
    'key'         => 'alerter_template',
    'section'     => 'billing',
    'description' => 'Template file for billing method expiration alerts.  See the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.7:Documentation:Administration#Credit_cards_and_Electronic_checks">billing documentation</a> for details.',
    'type'        => 'textarea',
    'per_agent'   => 1,
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
    'key'         => 'encryption',
    'section'     => 'billing',
    'description' => 'Enable encryption of credit cards.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'encryptionmodule',
    'section'     => 'billing',
    'description' => 'Use which module for encryption?',
    'type'        => 'text',
  },

  {
    'key'         => 'encryptionpublickey',
    'section'     => 'billing',
    'description' => 'Your RSA Public Key - Required if Encryption is turned on.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'encryptionprivatekey',
    'section'     => 'billing',
    'description' => 'Your RSA Private Key - Including this will enable the "Bill Now" feature.  However if the system is compromised, a hacker can use this key to decode the stored credit card information.  This is generally not a good idea.',
    'type'        => 'textarea',
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
    'description' => 'String passed as the description field to <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a>.  Evaluated as a double-quoted perl string, with the following variables available: <code>$agent</code> (the agent name), and <code>$pkgs</code> (a comma-separated list of packages for which these charges apply)',
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
		       '%Y/%m/%d' => 'YYYY/MM/DD',
                     ],
  },

  {
    'key'         => 'deletecustomers',
    'section'     => 'UI',
    'description' => 'Enable customer deletions.  Be very careful!  Deleting a customer will remove all traces that this customer ever existed!  It should probably only be used when auditing a legacy database.  Normally, you cancel all of a customers\' packages if they cancel service.',
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
    'key'         => 'dirhash',
    'section'     => 'shell',
    'description' => 'Optional numeric value to control directory hashing.  If positive, hashes directories for the specified number of levels from the front of the username.  If negative, hashes directories for the specified number of levels from the end of the username.  Some examples: <ul><li>1: user -> <a href="#home">/home</a>/u/user<li>2: user -> <a href="#home">/home</a>/u/s/user<li>-1: user -> <a href="#home">/home</a>/r/user<li>-2: user -> <a href="#home">home</a>/r/e/user</ul>',
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
    'type'       => 'checkbox',
  },

  {
    'key'         => 'emailinvoiceonly',
    'section'     => 'billing',
    'description' => 'Disables postal mail invoices',
    'type'       => 'checkbox',
  },

  {
    'key'         => 'disablepostalinvoicedefault',
    'section'     => 'billing',
    'description' => 'Disables postal mail invoices as the default option in the UI.  Be careful not to setup customers which are not sent invoices.  See <a href ="#emailinvoiceauto">emailinvoiceauto</a>.',
    'type'       => 'checkbox',
  },

  {
    'key'         => 'emailinvoiceauto',
    'section'     => 'billing',
    'description' => 'Automatically adds new accounts to the email invoice list',
    'type'       => 'checkbox',
  },

  {
    'key'         => 'emailinvoiceautoalways',
    'section'     => 'billing',
    'description' => 'Automatically adds new accounts to the email invoice list even when the list contains email addresses',
    'type'       => 'checkbox',
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
    'section'     => 'billing',
    'description' => 'Subject: header on email invoices.  Defaults to "Invoice".  The following substitutions are available: $name, $name_short, $invoice_number, and $invoice_date.',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_template',
    'section'     => 'billing',
    'description' => 'Text template file for invoices.  Used if no invoice_html template is defined, and also seen by users using non-HTML capable mail clients.  See the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.7:Documentation:Administration#Plaintext_invoice_templates">billing documentation</a> for details.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_html',
    'section'     => 'billing',
    'description' => 'Optional HTML template for invoices.  See the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.7:Documentation:Administration#HTML_invoice_templates">billing documentation</a> for details.',

    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_htmlnotes',
    'section'     => 'billing',
    'description' => 'Notes section for HTML invoices.  Defaults to the same data in invoice_latexnotes if not specified.',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_htmlfooter',
    'section'     => 'billing',
    'description' => 'Footer for HTML invoices.  Defaults to the same data in invoice_latexfooter if not specified.',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_htmlreturnaddress',
    'section'     => 'billing',
    'description' => 'Return address for HTML invoices.  Defaults to the same data in invoice_latexreturnaddress if not specified.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_latex',
    'section'     => 'billing',
    'description' => 'Optional LaTeX template for typeset PostScript invoices.  See the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.7:Documentation:Administration#Typeset_.28LaTeX.29_invoice_templates">billing documentation</a> for details.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_latexnotes',
    'section'     => 'billing',
    'description' => 'Notes section for LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_latexfooter',
    'section'     => 'billing',
    'description' => 'Footer for LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_latexcoupon',
    'section'     => 'billing',
    'description' => 'Remittance coupon for LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_latexreturnaddress',
    'section'     => 'billing',
    'description' => 'Return address for LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_latexsmallfooter',
    'section'     => 'billing',
    'description' => 'Optional small footer for multi-page LaTeX typeset PostScript invoices.',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'invoice_email_pdf',
    'section'     => 'billing',
    'description' => 'Send PDF invoice as an attachment to emailed invoices.  By default, includes the plain text invoice as the email body, unless invoice_email_pdf_note is set.',
    'type'        => 'checkbox'
  },

  {
    'key'         => 'invoice_email_pdf_note',
    'section'     => 'billing',
    'description' => 'If defined, this text will replace the default plain text invoice as the body of emailed PDF invoices.',
    'type'        => 'textarea'
  },


  { 
    'key'         => 'invoice_default_terms',
    'section'     => 'billing',
    'description' => 'Optional default invoice term, used to calculate a due date printed on invoices.',
    'type'        => 'select',
    'select_enum' => [ '', 'Payable upon receipt', 'Net 0', 'Net 10', 'Net 15', 'Net 20', 'Net 30', 'Net 45', 'Net 60' ],
  },

  { 
    'key'         => 'invoice_sections',
    'section'     => 'billing',
    'description' => 'Split invoice into sections and label according to package category when enabled.',
    'type'        => 'checkbox',
  },

  { 
    'key'         => 'separate_usage',
    'section'     => 'billing',
    'description' => 'Split the rated call usage into a separate line from the recurring charges.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'payment_receipt_email',
    'section'     => 'billing',
    'description' => 'Template file for payment receipts.  Payment receipts are sent to the customer email invoice destination(s) when a payment is received.  See the <a href="http://search.cpan.org/dist/Text-Template/lib/Text/Template.pm">Text::Template</a> documentation for details on the template substitution language.  The following variables are available: <ul><li><code>$date</code> <li><code>$name</code> <li><code>$paynum</code> - Freeside payment number <li><code>$paid</code> - Amount of payment <li><code>$payby</code> - Payment type (Card, Check, Electronic check, etc.) <li><code>$payinfo</code> - Masked credit card number or check number <li><code>$balance</code> - New balance</ul>',
    'type'        => [qw( checkbox textarea )],
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
                            select_enum=>{ map { $_=>$_ } qw(A CNAME MX NS TXT)} },
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
    'key' => 'password-noampersand',
    'section' => 'password',
    'description' => 'Disallow ampersands in passwords',
    'type' => 'checkbox',
  },

  {
    'key' => 'password-noexclamation',
    'section' => 'password',
    'description' => 'Disallow exclamations in passwords (Not setting this could break old text Livingston or Cistron Radius servers)',
    'type' => 'checkbox',
  },

  {
    'key'         => 'referraldefault',
    'section'     => 'UI',
    'description' => 'Default referral, specified by refnum',
    'type'        => 'text',
  },

#  {
#    'key'         => 'registries',
#    'section'     => 'required',
#    'description' => 'Directory which contains domain registry information.  Each registry is a directory.',
#  },

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
    'key'         => 'signupurl',
    'section'     => 'UI',
    'description' => 'if you are using customer-to-customer referrals, and you enter the URL of your <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.7:Documentation:Self-Service_Installation">signup server CGI</a>, the customer view screen will display a customized link to the signup server with the appropriate customer as referral',
    'type'        => 'text',
  },

  {
    'key'         => 'smtpmachine',
    'section'     => 'required',
    'description' => 'SMTP relay for Freeside\'s outgoing mail',
    'type'        => 'text',
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
    'description' => 'Message locale',
    'type'        => 'select',
    'select_enum' => [ qw(en_US) ],
  },

  {
    'key'         => 'signup_server-payby',
    'section'     => '',
    'description' => 'Acceptable payment types for the signup server',
    'type'        => 'selectmultiple',
    'select_enum' => [ qw(CARD DCRD CHEK DCHK LECB PREPAY BILL COMP) ],
  },

  {
    'key'         => 'signup_server-default_agentnum',
    'section'     => '',
    'description' => 'Default agent for the signup server',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::agent;
			   map { $_->agentnum => $_->agent }
                               FS::Record::qsearch('agent', { disabled=>'' } );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::agent;
			   my $agent = FS::Record::qsearchs(
			     'agent', { 'agentnum'=>shift }
			   );
                           $agent ? $agent->agent : '';
			 },
  },

  {
    'key'         => 'signup_server-default_refnum',
    'section'     => '',
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
    'section'     => '',
    'description' => 'Default package for the signup server',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::part_pkg;
                           map { $_->pkgpart => $_->pkg.' - '.$_->comment }
                               FS::Record::qsearch( 'part_pkg',
			                            { 'disabled' => ''}
						  );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::part_pkg;
                           my $part_pkg = FS::Record::qsearchs(
			     'part_pkg', { 'pkgpart'=>shift }
			   );
                           $part_pkg
			     ? $part_pkg->pkg.' - '.$part_pkg->comment
			     : '';
			 },
  },

  {
    'key'         => 'signup_server-default_svcpart',
    'section'     => '',
    'description' => 'Default svcpart for the signup server - only necessary for services that trigger special provisioning widgets (such as DID provisioning).',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::part_svc;
                           map { $_->svcpart => $_->svc }
                               FS::Record::qsearch( 'part_svc',
			                            { 'disabled' => ''}
						  );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::part_svc;
                           my $part_svc = FS::Record::qsearchs(
			     'part_svc', { 'svcpart'=>shift }
			   );
                           $part_svc ? $part_svc->svc : '';
			 },
  },

  {
    'key'         => 'signup_server-service',
    'section'     => '',
    'description' => 'Service for the signup server - "Account (svc_acct)" is the default setting, or "Phone number (svc_phone)" for ITSP signup',
    'type'        => 'select',
    'select_hash' => [
                       'svc_acct'  => 'Account (svc_acct)',
                       'svc_phone' => 'Phone number (svc_phone)',
                     ],
  },

  {
    'key'         => 'selfservice_server-base_url',
    'section'     => '',
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
    'section'     => '',
    'description' => 'Run billing for signup server signups immediately, and do not provision accounts which subsequently have a balance.',
    'type'        => 'checkbox',
  },
  {
    'key'         => 'signup_server-classnum2',
    'section'     => '',
    'description' => 'Package Class for first optional purchase',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::pkg_class;
                           map { $_->classnum => $_->classname }
                               FS::Record::qsearch('pkg_class', {} );
		         },
    'option_sub'  => sub { require FS::Record;
                           require FS::pkg_class;
                           my $pkg_class = FS::Record::qsearchs(
			     'pkg_class', { 'classnum'=>shift }
			   );
                           $pkg_class ? $pkg_class->classname : '';
			 },
  },

  {
    'key'         => 'signup_server-classnum3',
    'section'     => '',
    'description' => 'Package Class for second optional purchase',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::pkg_class;
                           map { $_->classnum => $_->classname }
                               FS::Record::qsearch('pkg_class', {} );
		         },
    'option_sub'  => sub { require FS::Record;
                           require FS::pkg_class;
                           my $pkg_class = FS::Record::qsearchs(
			     'pkg_class', { 'classnum'=>shift }
			   );
                           $pkg_class ? $pkg_class->classname : '';
			 },
  },

  {
    'key'         => 'backend-realtime',
    'section'     => '',
    'description' => 'Run billing for backend signups immediately.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'declinetemplate',
    'section'     => 'billing',
    'description' => 'Template file for credit card decline emails.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'emaildecline',
    'section'     => 'billing',
    'description' => 'Enable emailing of credit card decline notices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'emaildecline-exclude',
    'section'     => 'billing',
    'description' => 'List of error messages that should not trigger email decline notices, one per line.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cancelmessage',
    'section'     => 'billing',
    'description' => 'Template file for cancellation emails.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cancelsubject',
    'section'     => 'billing',
    'description' => 'Subject line for cancellation emails.',
    'type'        => 'text',
  },

  {
    'key'         => 'emailcancel',
    'section'     => 'billing',
    'description' => 'Enable emailing of cancellation notices.  Make sure to fill in the cancelmessage and cancelsubject configuration values as well.',
    'type'        => 'checkbox',
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
    'description' => 'Enable downloading tax data directly from the vendor site',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'ignore_incalculable_taxes',
    'section'     => 'billing',
    'description' => 'Prefer to invoice without tax over not billing at all',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'welcome_email',
    'section'     => '',
    'description' => 'Template file for welcome email.  Welcome emails are sent to the customer email invoice destination(s) each time a svc_acct record is created.  See the <a href="http://search.cpan.org/dist/Text-Template/lib/Text/Template.pm">Text::Template</a> documentation for details on the template substitution language.  The following variables are available<ul><li><code>$username</code> <li><code>$password</code> <li><code>$first</code> <li><code>$last</code> <li><code>$pkg</code></ul>',
    'type'        => 'textarea',
    'per_agent'   => 1,
  },

  {
    'key'         => 'welcome_email-from',
    'section'     => '',
    'description' => 'From: address header for welcome email',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'welcome_email-subject',
    'section'     => '',
    'description' => 'Subject: header for welcome email',
    'type'        => 'text',
    'per_agent'   => 1,
  },
  
  {
    'key'         => 'welcome_email-mimetype',
    'section'     => '',
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

  {
    'key'         => 'warning_email',
    'section'     => '',
    'description' => 'Template file for warning email.  Warning emails are sent to the customer email invoice destination(s) each time a svc_acct record has its usage drop below a threshold or 0.  See the <a href="http://search.cpan.org/dist/Text-Template/lib/Text/Template.pm">Text::Template</a> documentation for details on the template substitution language.  The following variables are available<ul><li><code>$username</code> <li><code>$password</code> <li><code>$first</code> <li><code>$last</code> <li><code>$pkg</code> <li><code>$column</code> <li><code>$amount</code> <li><code>$threshold</code></ul>',
    'type'        => 'textarea',
  },

  {
    'key'         => 'warning_email-from',
    'section'     => '',
    'description' => 'From: address header for warning email',
    'type'        => 'text',
  },

  {
    'key'         => 'warning_email-cc',
    'section'     => '',
    'description' => 'Additional recipient(s) (comma separated) for warning email when remaining usage reaches zero.',
    'type'        => 'text',
  },

  {
    'key'         => 'warning_email-subject',
    'section'     => '',
    'description' => 'Subject: header for warning email',
    'type'        => 'text',
  },
  
  {
    'key'         => 'warning_email-mimetype',
    'section'     => '',
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
    'section'     => 'UI',
    'description' => 'Extra HTML to be displayed on the Account View screen.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'radius-password',
    'section'     => '',
    'description' => 'RADIUS attribute for plain-text passwords.',
    'type'        => 'select',
    'select_enum' => [ 'Password', 'User-Password' ],
  },

  {
    'key'         => 'radius-ip',
    'section'     => '',
    'description' => 'RADIUS attribute for IP addresses.',
    'type'        => 'select',
    'select_enum' => [ 'Framed-IP-Address', 'Framed-Address' ],
  },

  {
    'key'         => 'svc_acct-alldomains',
    'section'     => '',
    'description' => 'Allow accounts to select any domain in the database.  Normally accounts can only select from the domain set in the service definition and those purchased by the customer.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'dump-scpdest',
    'section'     => '',
    'description' => 'destination for scp database dumps: user@host:/path',
    'type'        => 'text',
  },

  {
    'key'         => 'dump-pgpid',
    'section'     => '',
    'description' => "Optional PGP public key user or key id for database dumps.  The public key should exist on the freeside user's public keyring, and the gpg binary and GnuPG perl module should be installed.",
    'type'        => 'text',
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
    'type'        => 'textarea',
  },

  {
    'key'         => 'selfservice_server-primary_only',
    'section'     => '',
    'description' => 'Only allow primary accounts to access self-service functionality.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice_server-phone_login',
    'section'     => '',
    'description' => 'Allow login to self-service with phone number and PIN.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice_server-single_domain',
    'section'     => '',
    'description' => 'If specified, only use this one domain for self-service access.',
    'type'        => 'text',
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
    'section'     => '',
    'description' => 'Ticketing system integration.  <b>RT_Internal</b> uses the built-in RT ticketing system (see the <a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.7:Documentation:RT_Installation">integrated ticketing installation instructions</a>).   <b>RT_External</b> accesses an external RT installation in a separate database (local or remote).',
    'type'        => 'select',
    #'select_enum' => [ '', qw(RT_Internal RT_Libs RT_External) ],
    'select_enum' => [ '', qw(RT_Internal RT_External) ],
  },

  {
    'key'         => 'ticket_system-default_queueid',
    'section'     => '',
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
    'key'         => 'ticket_system-priority_reverse',
    'section'     => '',
    'description' => 'Enable this to consider lower numbered priorities more important.  A bad habit we picked up somewhere.  You probably want to avoid it and use the default.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'ticket_system-custom_priority_field',
    'section'     => '',
    'description' => 'Custom field from the ticketing system to use as a custom priority classification.',
    'type'        => 'text',
  },

  {
    'key'         => 'ticket_system-custom_priority_field-values',
    'section'     => '',
    'description' => 'Values for the custom field from the ticketing system to break down and sort customer ticket lists.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'ticket_system-custom_priority_field_queue',
    'section'     => '',
    'description' => 'Ticketing system queue in which the custom field specified in ticket_system-custom_priority_field is located.',
    'type'        => 'text',
  },

  {
    'key'         => 'ticket_system-rt_external_datasrc',
    'section'     => '',
    'description' => 'With external RT integration, the DBI data source for the external RT installation, for example, <code>DBI:Pg:user=rt_user;password=rt_word;host=rt.example.com;dbname=rt</code>',
    'type'        => 'text',

  },

  {
    'key'         => 'ticket_system-rt_external_url',
    'section'     => '',
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
    'section'     => '',
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
    'section'     => 'billing',
    'description' => 'Enable FTP of raw invoice data - format.',
    'type'        => 'select',
    'select_enum' => [ '', 'default', 'billco', ],
  },

  {
    'key'         => 'cust_bill-ftpserver',
    'section'     => 'billing',
    'description' => 'Enable FTP of raw invoice data - server.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-ftpusername',
    'section'     => 'billing',
    'description' => 'Enable FTP of raw invoice data - server.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-ftppassword',
    'section'     => 'billing',
    'description' => 'Enable FTP of raw invoice data - server.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-ftpdir',
    'section'     => 'billing',
    'description' => 'Enable FTP of raw invoice data - server.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-spoolformat',
    'section'     => 'billing',
    'description' => 'Enable spooling of raw invoice data - format.',
    'type'        => 'select',
    'select_enum' => [ '', 'default', 'billco', ],
  },

  {
    'key'         => 'cust_bill-spoolagent',
    'section'     => 'billing',
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
    'key'         => 'voip-cust_cdr_spools',
    'section'     => '',
    'description' => 'Enable the per-customer option for individual CDR spools.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'voip-cust_cdr_squelch',
    'section'     => '',
    'description' => 'Enable the per-customer option for not printing CDR on invoices.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'voip-cdr_email',
    'section'     => '',
    'description' => 'Include the call details on emailed invoices even if the customer is configured for not printing them on the invoices.',
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
    'description' => 'By default, tax calculations are done based on the billing address.  Enable this switch to calculate tax based on the package address instead (when present).  Note that this option is currently incompatible with vendor data taxation enabled by enable_taxproducts.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice-ship_address',
    'section'     => 'billing',
    'description' => 'Enable this switch to include the ship address on the invoice.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'invoice-unitprice',
    'section'     => 'billing',
    'description' => 'This switch enables unit pricing on the invoice.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'postal_invoice-fee_pkgpart',
    'section'     => 'billing',
    'description' => 'This allows selection of a package to insert on invoices for customers with postal invoices selected.',
    'type'        => 'select-sub',
    'options_sub' => sub { require FS::Record;
                           require FS::part_pkg;
			   map { $_->pkgpart => $_->pkg }
                               FS::Record::qsearch('part_pkg', { disabled=>'' } );
			 },
    'option_sub'  => sub { require FS::Record;
                           require FS::part_pkg;
			   my $part_pkg = FS::Record::qsearchs(
			     'part_pkg', { 'pkgpart'=>shift }
			   );
                           $part_pkg ? $part_pkg->pkg : '';
			 },
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
                       'ach-spiritone',
                    ]
  },

  {
    'key'         => 'batch-fixed_format-CARD',
    'section'     => 'billing',
    'description' => 'Fixed (unchangeable) format for credit card batches.',
    'type'        => 'select',
    'select_enum' => [ 'csv-td_canada_trust-merchant_pc_batch', 'BoM', 'PAP' ,
                       'csv-chase_canada-E-xactBatch', 'BoM', 'PAP' ]
  },

  {
    'key'         => 'batch-fixed_format-CHEK',
    'section'     => 'billing',
    'description' => 'Fixed (unchangeable) format for electronic check batches.',
    'type'        => 'select',
    'select_enum' => [ 'csv-td_canada_trust-merchant_pc_batch', 'BoM', 'PAP',
                       'ach-spiritone',
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
    'key'         => 'payment_history-years',
    'section'     => 'UI',
    'description' => 'Number of years of payment history to show by default.  Currently defaults to 2.',
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
    'key'         => 'dashboard-toplist',
    'section'     => 'UI',
    'description' => 'List of items to display on the top of the front page',
    'type'        => 'textarea',
  },

  {
    'key'         => 'impending_recur_template',
    'section'     => 'billing',
    'description' => 'Template file for alerts about looming first time recurrant billing.  See the <a href="http://search.cpan.org/dist/Text-Template/lib/Text/Template.pm">Text::Template</a> documentation for details on the template substitition language.  Also see packages with a <a href="../browse/part_pkg.cgi">flat price plan</a>  The following variables are available<ul><li><code>$packages</code> allowing <code>$packages->[0]</code> thru <code>$packages->[n]</code> <li><code>$package</code> the first package, same as <code>$packages->[0]</code> <li><code>$recurdates</code> allowing <code>$recurdates->[0]</code> thru <code>$recurdates->[n]</code> <li><code>$recurdate</code> the first recurdate, same as <code>$recurdate->[0]</code> <li><code>$first</code> <li><code>$last</code></ul>',
# <li><code>$payby</code> <li><code>$expdate</code> most likely only confuse
    'type'        => 'textarea',
  },

  {
    'key'         => 'logo.png',
    'section'     => 'billing',  #? 
    'description' => 'Company logo for HTML invoices and the backoffice interface, in PNG format.  Suggested size somewhere near 92x62.',
    'type'        => 'image',
    'per_agent'   => 1, #XXX just view/logo.cgi, which is for the global
                        #old-style editor anyway...?
  },

  {
    'key'         => 'logo.eps',
    'section'     => 'billing',  #? 
    'description' => 'Company logo for printed and PDF invoices, in EPS format.',
    'type'        => 'image',
    'per_agent'   => 1, #XXX as above, kinda
  },

  {
    'key'         => 'selfservice-ignore_quantity',
    'section'     => '',
    'description' => 'Ignores service quantity restrictions in self-service context.  Strongly not recommended - just set your quantities correctly in the first place.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'selfservice-session_timeout',
    'section'     => '',
    'description' => 'Self-service session timeout.  Defaults to 1 hour.',
    'type'        => 'select',
    'select_enum' => [ '1 hour', '2 hours', '4 hours', '8 hours', '1 day', '1 week', ],
  },

  {
    'key'         => 'disable_setup_suspended_pkgs',
    'section'     => 'billing',
    'description' => 'Disables charging of setup fees for suspended packages.',
    'type'       => 'checkbox',
  },

  {
    'key' => 'password-generated-allcaps',
    'section' => 'password',
    'description' => 'Causes passwords automatically generated to consist entirely of capital letters',
    'type' => 'checkbox',
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
    'type'        => 'textarea',
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
    'section'     => 'billing',
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
    'key'         => 'cust_main-agent_custid-format',
    'section'     => '',
    'description' => 'Enables searching of various formatted values in cust_main.agent_custid',
    'type'        => 'select',
    'select_hash' => [
                       ''      => 'Numeric only',
                       'ww?d+' => 'Numeric with one or two letter prefix',
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
    'section'     => 'billing',
    'description' => 'Disable inclusion of previous balancem payment, and credit lines on invoices',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'previous_balance-summary_only',
    'section'     => 'billing',
    'description' => 'Only show a single line summarizing the total previous balance rather than one line per invoice.',
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
    'key'         => 'disable_acl_changes',
    'section'     => '',
    'description' => 'Disable all ACL changes, for demos.',
    'type'        => 'checkbox',
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
    'description' => 'Display the agent_custid field instead of the custnum field.',
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
    'key'         => 'cust_main-default_areacode',
    'section'     => 'UI',
    'description' => 'Default area code for customers.',
    'type'        => 'text',
  },

  {
    'key'         => 'mcp_svcpart',
    'section'     => '',
    'description' => 'Master Control Program svcpart.  Leave this blank.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_bill-max_same_services',
    'section'     => 'billing',
    'description' => 'Maximum number of the same service to list individually on invoices before condensing to a single line listing the number of services.  Defaults to 5.',
    'type'        => 'text',
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
    'section'     => '',
    'description' => 'HTML for the HEAD section of the self-service interface, typically used for LINK stylesheet tags',
    'type'        => 'textarea', #htmlarea?
  },


  {
    'key'         => 'selfservice-body_header',
    'section'     => '',
    'description' => 'HTML header for the self-service interface',
    'type'        => 'textarea', #htmlarea?
  },

  {
    'key'         => 'selfservice-body_footer',
    'section'     => '',
    'description' => 'HTML header for the self-service interface',
    'type'        => 'textarea', #htmlarea?
  },


  {
    'key'         => 'selfservice-body_bgcolor',
    'section'     => '',
    'description' => 'HTML background color for the self-service interface, for example, #FFFFFF',
    'type'        => 'text',
  },

  {
    'key'         => 'selfservice-box_bgcolor',
    'section'     => '',
    'description' => 'HTML color for self-service interface input boxes, for example, #C0C0C0"',
    'type'        => 'text',
  },

  {
    'key'         => 'selfservice-bulk_format',
    'section'     => '',
    'description' => 'Parameter arrangement for selfservice bulk features',
    'type'        => 'select',
    'select_enum' => [ '', 'izoom-soap', 'izoom-ftp' ],
    'per_agent'   => 1,
  },

  {
    'key'         => 'selfservice-bulk_ftp_dir',
    'section'     => '',
    'description' => 'Enable bulk ftp provisioning in this folder',
    'type'        => 'text',
    'per_agent'   => 1,
  },

  {
    'key'         => 'signup-no_company',
    'section'     => '',
    'description' => "Don't display a field for company name on signup.",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signup-recommend_email',
    'section'     => '',
    'description' => 'Encourage the entry of an invoicing email address on signup.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signup-recommend_daytime',
    'section'     => '',
    'description' => 'Encourage the entry of a daytime phone number  invoicing email address on signup.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_phone-radius-default_password',
    'section'     => '',
    'description' => 'Default password when exporting svc_phone records to RADIUS',
    'type'        => 'text',
  },

  {
    'key'         => 'svc_phone-allow_alpha_phonenum',
    'section'     => '',
    'description' => 'Allow letters in phone numbers.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'default_phone_countrycode',
    'section'     => '',
    'description' => 'Default countrcode',
    'type'        => 'text',
  },

  {
    'key'         => 'cdr-charged_party-accountcode',
    'section'     => '',
    'description' => 'Set the charged_party field of CDRs to the accountcode.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cdr-charged_party-accountcode-trim_leading_0s',
    'section'     => '',
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
    'section'     => '',
    'description' => 'Do charged party rewriting in the freeside-cdrrewrited daemon; useful if CDRs are being dropped off directly in the database and require special charged_party processing such as cdr-charged_party-accountcode or cdr-charged_party-truncate*.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'cdr-taqua-da_rewrite',
    'section'     => '',
    'description' => 'For the Taqua CDR format, a comma-separated list of directory assistance 800 numbers.  Any CDRs with these numbers as "BilledNumber" will be rewritten to the "CallingPartyNumber" (and CallType "12") on import.',
    'type'        => 'text',
  },

  {
    'key'         => 'cust_pkg-show_autosuspend',
    'section'     => 'UI',
    'description' => 'Show package auto-suspend dates.  Use with caution for now; can slow down customer view for large insallations.',
    'type'       => 'checkbox',
  },

  {
    'key'         => 'cdr-asterisk_forward_rewrite',
    'section'     => '',
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
    'key'         => 'cancelled_cust-noevents',
    'section'     => 'billing',
    'description' => "Don't run events for cancelled customers",
    'type'        => 'checkbox',
  },

  {
    'key'         => 'agent-invoice_template',
    'section'     => 'billing',
    'description' => 'Enable display/edit of old-style per-agent invoice template selection',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'svc_broadband-manage_link',
    'section'     => 'UI',
    'description' => 'URL for svc_broadband "Manage Device" link.  The following substitutions are available: $ip_addr.',
    'type'        => 'text',
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
      #''                => 'Change History',
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

);

1;

