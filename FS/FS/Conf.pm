package FS::Conf;

use vars qw($default_dir @config_items $DEBUG );
use IO::File;
use FS::ConfItem;

$DEBUG = 0;

=head1 NAME

FS::Conf - Freeside configuration values

=head1 SYNOPSIS

  use FS::Conf;

  $conf = new FS::Conf "/config/directory";

  $FS::Conf::default_dir = "/config/directory";
  $conf = new FS::Conf;

  $dir = $conf->dir;

  $value = $conf->config('key');
  @list  = $conf->config('key');
  $bool  = $conf->exists('key');

  @config_items = $conf->config_items;

=head1 DESCRIPTION

Read and write Freeside configuration values.  Keys currently map to filenames,
but this may change in the future.

=head1 METHODS

=over 4

=item new [ DIRECTORY ]

Create a new configuration object.  A directory arguement is required if
$FS::Conf::default_dir has not been set.

=cut

sub new {
  my($proto,$dir) = @_;
  my($class) = ref($proto) || $proto;
  my($self) = { 'dir' => $dir || $default_dir } ;
  bless ($self, $class);
}

=item dir

Returns the directory.

=cut

sub dir {
  my($self) = @_;
  my $dir = $self->{dir};
  -e $dir or die "FATAL: $dir doesn't exist!";
  -d $dir or die "FATAL: $dir isn't a directory!";
  -r $dir or die "FATAL: Can't read $dir!";
  -x $dir or die "FATAL: $dir not searchable (executable)!";
  $dir =~ /^(.*)$/;
  $1;
}

=item config 

Returns the configuration value or values (depending on context) for key.

=cut

sub config {
  my($self,$file)=@_;
  my($dir)=$self->dir;
  my $fh = new IO::File "<$dir/$file" or return;
  if ( wantarray ) {
    map {
      /^(.*)$/
        or die "Illegal line (array context) in $dir/$file:\n$_\n";
      $1;
    } <$fh>;
  } else {
    <$fh> =~ /^(.*)$/
      or die "Illegal line (scalar context) in $dir/$file:\n$_\n";
    $1;
  }
}

=item exists

Returns true if the specified key exists, even if the corresponding value
is undefined.

=cut

sub exists {
  my($self,$file)=@_;
  my($dir) = $self->dir;
  -e "$dir/$file";
}

=item touch

=cut

sub touch {
  my($self, $file) = @_;
  my $dir = $self->dir;
  unless ( $self->exists($file) ) {
    warn "[FS::Conf] TOUCH $file\n" if $DEBUG;
    system('touch', "$dir/$file");
  }
}

=item set

=cut

sub set {
  my($self, $file, $value) = @_;
  my $dir = $self->dir;
  $value =~ /^(.*)$/s;
  $value = $1;
  unless ( $self->config($file) eq $value ) {
    warn "[FS::Conf] SET $file\n" if $DEBUG;
#    warn "$dir" if is_tainted($dir);
#    warn "$dir" if is_tainted($file);
    chmod 0644, "$dir/$file";
    my $fh = new IO::File ">$dir/$file" or return;
    chmod 0644, "$dir/$file";
    print $fh "$value\n";
  }
}
#sub is_tainted {
#             return ! eval { join('',@_), kill 0; 1; };
#         }

=item delete

=cut

sub delete {
  my($self, $file) = @_;
  my $dir = $self->dir;
  if ( $self->exists($file) ) {
    warn "[FS::Conf] DELETE $file\n";
    unlink "$dir/$file";
  }
}

=item config_items

Returns all of the possible configuration items as FS::ConfItem objects.  See
L<FS::ConfItem>.

=cut

sub config_items {
#  my $self = shift; 
  @config_items;
}

=back

=head1 BUGS

Write access (touch, set, delete) should be documented.

If this was more than just crud that will never be useful outside Freeside I'd
worry that config_items is freeside-specific and icky.

=head1 SEE ALSO

"Configuration" in the web interface (config/config.cgi).

httemplate/docs/config.html

=cut

@config_items = map { new FS::ConfItem $_ } (

  {
    'key'         => 'address',
    'section'     => 'deprecated',
    'description' => 'This configuration option is no longer used.  See <a href="#invoice_template">invoice_template</a> instead.',
    'type'        => 'text',
  },

  {
    'key'         => 'alerter_template',
    'section'     => 'billing',
    'description' => 'Template file for billing method expiration alerts.  See the <a href="../docs/billing.html#invoice_template">billing documentation</a> for details.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'apacheroot',
    'section'     => 'apache',
    'description' => 'The directory containing Apache virtual hosts',
    'type'        => 'text',
  },

  {
    'key'         => 'apacheip',
    'section'     => 'apache',
    'description' => 'The current IP address to assign to new virtual hosts',
    'type'        => 'text',
  },

  {
    'key'         => 'apachemachine',
    'section'     => 'apache',
    'description' => 'A machine with the apacheroot directory and user home directories.  The existance of this file enables setup of virtual host directories, and, in conjunction with the `home\' configuration file, symlinks into user home directories.',
    'type'        => 'text',
  },

  {
    'key'         => 'apachemachines',
    'section'     => 'apache',
    'description' => 'Your Apache machines, one per line.  This enables export of `/etc/apache/vhosts.conf\', which can be included in your Apache configuration via the <a href="http://www.apache.org/docs/mod/core.html#include">Include</a> directive.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'bindprimary',
    'section'     => 'BIND',
    'description' => 'Your BIND primary nameserver.  This enables export of /var/named/named.conf and zone files into /var/named',
    'type'        => 'text',
  },

  {
    'key'         => 'bindsecondaries',
    'section'     => 'BIND',
    'description' => 'Your BIND secondary nameservers, one per line.  This enables export of /var/named/named.conf',
    'type'        => 'textarea',
  },

  {
    'key'         => 'business-onlinepayment',
    'section'     => 'billing',
    'description' => '<a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> support, at least three lines: processor, login, and password.  An optional fourth line specifies the action or actions (multiple actions are separated with `,\': for example: `Authorization Only, Post Authorization\').    Optional additional lines are passed to Business::OnlinePayment as %processor_options.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'bsdshellmachines',
    'section'     => 'shell',
    'description' => 'Your BSD flavored shell (and mail) machines, one per line.  This enables export of `/etc/passwd\' and `/etc/master.passwd\'.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'countrydefault',
    'section'     => 'UI',
    'description' => 'Default two-letter country code (if not supplied, the default is `US\')',
    'type'        => 'text',
  },

  {
    'key'         => 'cybercash3.2',
    'section'     => 'billing',
    'description' => '<a href="http://www.cybercash.com/cashregister/">CyberCash Cashregister v3.2</a> support.  Two lines: the full path and name of your merchant_conf file, and the transaction type (`mauthonly\' or `mauthcapture\').',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cyrus',
    'section'     => 'mail',
    'description' => 'Integration with <a href="http://asg.web.cmu.edu/cyrus/imapd/">Cyrus IMAP Server</a>, three lines: IMAP server, admin username, and admin password.  Cyrus::IMAP::Admin should be installed locally and the connection to the server secured.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cp_app',
    'section'     => 'mail',
    'description' => 'Integration with <a href="http://www.cp.net/">Critial Path Account Provisioning Protocol</a>, four lines: "host:port", username, password, and workgroup (for new users).',
    'type'        => 'textarea',
  },

  {
    'key'         => 'deletecustomers',
    'section'     => 'UI',
    'description' => 'Enable customer deletions.  Be very careful!  Deleting a customer will remove all traces that this customer ever existed!  It should probably only be used when auditing a legacy database.  Normally, you cancel all of a customers\' packages if they cancel service.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'deletepayments',
    'section'     => 'UI',
    'description' => 'Enable deletion of unclosed payments.  Be very careful!  Only delete payments that were data-entry errors, not adjustments.',
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
    'key'         => 'domain',
    'section'     => 'deprecated',
    'description' => 'Your domain name.',
    'type'        => 'text',
  },

  {
    'key'         => 'editreferrals',
    'section'     => 'UI',
    'description' => 'Enable referral modification for existing customers',
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
    'description' => 'Automatically adds new accounts to the email invoice list upon customer creation',
    'type'       => 'checkbox',
  },

  {
    'key'         => 'erpcdmachines',
    'section'     => '',
    'description' => 'Your ERPCD authenticaion machines, one per line.  This enables export of `/usr/annex/acp_passwd\' and `/usr/annex/acp_dialup\'',
    'type'        => 'textarea',
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
    'section'     => 'required',
    'description' => 'For new users, prefixed to username to create a directory name.  Should have a leading but not a trailing slash.',
    'type'        => 'text',
  },

  {
    'key'         => 'icradiusmachines',
    'section'     => 'radius',
    'description' => 'Turn this option on to enable radcheck and radreply table population - by default in the Freeside database, or in the database specified by the <a href="http://rootwood.haze.st/aspside/config/config-view.cgi#icradius_secrets">icradius_secrets</a> config option (the radcheck and radreply tables needs to be created manually).  You do not need to use MySQL for your Freeside database to export to an ICRADIUS/FreeRADIUS MySQL database with this option.  <blockquote><b>ADDITIONAL DEPRECATED FUNCTIONALITY</b> (instead use <a href="http://www.mysql.com/documentation/mysql/bychapter/manual_MySQL_Database_Administration.html#Replication">MySQL replication</a> or point icradius_secrets to the external database) - your <a href="ftp://ftp.cheapnet.net/pub/icradius">ICRADIUS</a> machines or <a href="http://www.freeradius.org/">FreeRADIUS</a> (with MySQL authentication) machines, one per line.  Machines listed in this file will have the radcheck table exported to them.  Each line should contain four items, separted by whitespace: machine name, MySQL database name, MySQL username, and MySQL password.  For example: <CODE>"radius.isp.tld&nbsp;radius_db&nbsp;radius_user&nbsp;passw0rd"</CODE></blockquote>',
    'type'        => [qw( checkbox textarea )],
  },

  {
    'key'         => 'icradius_mysqldest',
    'section'     => 'radius',
    'description' => '<b>DEPRECATED</b> (instead use <a href="http://www.mysql.com/documentation/mysql/bychapter/manual_MySQL_Database_Administration.html#Replication">MySQL replication</a> or point icradius_secrets to the external database) - Destination directory for the MySQL databases, on the ICRADIUS/FreeRADIUS machines.  Defaults to "/usr/local/var/".',
    'type'        => 'text',
  },

  {
    'key'         => 'icradius_mysqlsource',
    'section'     => 'radius',
    'description' => '<b>DEPRECATED</b> (instead use <a href="http://www.mysql.com/documentation/mysql/bychapter/manual_MySQL_Database_Administration.html#Replication">MySQL replication</a> or point icradius_secrets to the external database) - Source directory for for the MySQL radcheck table files, on the Freeside machine.  Defaults to "/usr/local/var/freeside".',
    'type'        => 'text',
  },

  {
    'key'         => 'icradius_secrets',
    'section'     => 'radius',
    'description' => 'Optionally specifies a database for ICRADIUS/FreeRADIUS export.  Three lines: DBI data source, username and password.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'invoice_from',
    'section'     => 'required',
    'description' => 'Return address on email invoices',
    'type'        => 'text',
  },

  {
    'key'         => 'invoice_template',
    'section'     => 'required',
    'description' => 'Required template file for invoices.  See the <a href="../docs/billing.html">billing documentation</a> for details.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'lpr',
    'section'     => 'required',
    'description' => 'Print command for paper invoices, for example `lpr -h\'',
    'type'        => 'text',
  },

  {
    'key'         => 'maildisablecatchall',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, now the default.  Turning this option on used to disable the requirement that each virtual domain have a catch-all mailbox.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'money_char',
    'section'     => '',
    'description' => 'Currency symbol - defaults to `$\'',
    'type'        => 'text',
  },

  {
    'key'         => 'mxmachines',
    'section'     => 'BIND',
    'description' => 'MX entries for new domains, weight and machine, one per line, with trailing `.\'',
    'type'        => 'textarea',
  },

  {
    'key'         => 'nsmachines',
    'section'     => 'BIND',
    'description' => 'NS nameservers for new domains, one per line, with trailing `.\'',
    'type'        => 'textarea',
  },

  {
    'key'         => 'arecords',
    'section'     => 'BIND',
    'description' => 'A list of tab seperated A records to add automatically when creating a domain',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cnamerecords',
    'section'     => 'BIND',
    'description' => 'A list of tab seperated CNAME records to add automatically when creating a domain',
    'type'        => 'textarea',
  },

  {
    'key'         => 'nismachines',
    'section'     => 'shell',
    'description' => 'Your NIS master (not slave master) machines, one per line.  This enables export of `/etc/global/passwd\' and `/etc/global/shadow\'.',
    'type'        => 'textarea',
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
    'key'         => 'qmailmachines',
    'section'     => 'mail',
    'description' => 'Your qmail machines, one per line.  This enables export of `/var/qmail/control/virtualdomains\', `/var/qmail/control/recipientmap\', and `/var/qmail/control/rcpthosts\'.  Setting this option (even if empty) also turns on user `.qmail-extension\' file maintenance in conjunction with the <b>shellmachine</b> option.',
    'type'        => [qw( checkbox textarea )],
  },

  {
    'key'         => 'radiusmachines',
    'section'     => 'radius',
    'description' => 'Your RADIUS authentication machines, one per line.  This enables export of `/etc/raddb/users\'.',
    'type'        => 'textarea',
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
    'key'         => 'report_template',
    'section'     => 'required',
    'description' => 'Required template file for reports.  See the <a href="../docs/billing.html">billing documentation</a> for details.',
    'type'        => 'textarea',
  },


  {
    'key'         => 'maxsearchrecordsperpage',
    'section'     => 'UI',
    'description' => 'If set, number of search records to return per page.',
    'type'        => 'text',
  },

  {
    'key'         => 'sendmailconfigpath',
    'section'     => 'mail',
    'description' => 'Sendmail configuration file path.  Defaults to `/etc\'.  Many newer distributions use `/etc/mail\'.',
    'type'        => 'text',
  },

  {
    'key'         => 'sendmailmachines',
    'section'     => 'mail',
    'description' => 'Your sendmail machines, one per line.  This enables export of `/etc/virtusertable\' and `/etc/sendmail.cw\'.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'sendmailrestart',
    'section'     => 'mail',
    'description' => 'If defined, the command which is run on sendmail machines after files are copied.',
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
    'key'         => 'shellmachine',
    'section'     => 'shell',
    'description' => 'A single machine with user home directories mounted.  This enables home directory creation, renaming and archiving/deletion.  In conjunction with `qmailmachines\', it also enables `.qmail-extension\' file maintenance.',
    'type'        => 'text',
  },

  {
    'key'         => 'shellmachine-useradd',
    'section'     => 'shell',
    'description' => 'The command(s) to run on shellmachine when an account is created.  If the <b>shellmachine</b> option is set but this option is not, <code>useradd -d $dir -m -s $shell -u $uid $username</code> is the default.  If this option is set but empty, <code>cp -pr /etc/skel $dir; chown -R $uid.$gid $dir</code> is the default instead.  Otherwise the value is evaluated as a double-quoted perl string, with the following variables available: <code>$username</code>, <code>$uid</code>, <code>$gid</code>, <code>$dir</code>, and <code>$shell</code>.',
    'type'        => [qw( checkbox text )],
  },

  {
    'key'         => 'shellmachine-userdel',
    'section'     => 'shell',
    'description' => 'The command(s) to run on shellmachine when an account is deleted.  If the <b>shellmachine</b> option is set but this option is not, <code>userdel $username</code> is the default.  If this option is set but empty, <code>rm -rf $dir</code> is the default instead.  Otherwise the value is evaluated as a double-quoted perl string, with the following variables available: <code>$username</code> and <code>$dir</code>.',
    'type'        => [qw( checkbox text )],
  },

  {
    'key'         => 'shellmachine-usermod',
    'section'     => 'shell',
    'description' => 'The command(s) to run on shellmachine when an account is modified.  If the <b>shellmachine</b> option is set but this option is empty, <code>[ -d $old_dir ] &amp;&amp; mv $old_dir $new_dir || ( chmod u+t $old_dir; mkdir $new_dir; cd $old_dir; find . -depth -print | cpio -pdm $new_dir; chmod u-t $new_dir; chown -R $uid.$gid $new_dir; rm -rf $old_dir )</code> is the default.  Otherwise the contents of the file are treated as a double-quoted perl string, with the following variables available: <code>$old_dir</code>, <code>$new_dir</code>, <code>$uid</code> and <code>$gid</code>.',
    #'type'        => [qw( checkbox text )],
    'type'        => 'text',
  },

  {
    'key'         => 'shellmachines',
    'section'     => 'shell',
    'description' => 'Your Linux and System V flavored shell (and mail) machines, one per line.  This enables export of `/etc/passwd\' and `/etc/shadow\' files.',
     'type'        => 'textarea',
 },

  {
    'key'         => 'shells',
    'section'     => 'required',
    'description' => 'Legal shells (think /etc/shells).  You probably want to `cut -d: -f7 /etc/passwd | sort | uniq\' initially so that importing doesn\'t fail with `Illegal shell\' errors, then remove any special entries afterwords.  A blank line specifies that an empty shell is permitted.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'showpasswords',
    'section'     => 'UI',
    'description' => 'Display unencrypted user passwords in the web interface',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'signupurl',
    'section'     => 'UI',
    'description' => 'if you are using customer-to-customer referrals, and you enter the URL of your <a href="../docs/signup.html">signup server CGI</a>, the customer view screen will display a customized link to the signup server with the appropriate customer as referral',
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
    'key'         => 'radiusprepend',
    'section'     => 'radius',
    'description' => 'The contents will be prepended to the top of the RADIUS users file (text exports only).',
    'type'        => 'textarea',
  },

  {
    'key'         => 'textradiusprepend',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, use RADIUS check attributes instead.  This option will be removed soon.  The contents will be prepended to the first line of a user\'s RADIUS entry in text exports.',
    'type'        => 'text',
  },

  {
    'key'         => 'unsuspendauto',
    'section'     => 'billing',
    'description' => 'Enables the automatic unsuspension of suspended packages when a customer\'s balance due changes from positive to zero or negative as the result of a payment or credit',
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
    'description' => 'Allow the ampersand character (&amp;) in usernames.  Be careful when using this option in conjunction with <a href="#shellmachine-useradd">shellmachine-useradd</a> and other configuration options which execute shell commands, as the ampersand will be interpreted by the shell if not quoted.',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'username-letter',
    'section'     => 'username',
    'description' => 'Usernames must contain at least one letter',
    'type'        => 'checkbox',
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
    'key'         => 'username-uppercase',
    'section'     => 'username',
    'description' => 'Allow uppercase characters in usernames',
    'type'        => 'checkbox',
  },

  {
    'key'         => 'username_policy',
    'section'     => '',
    'description' => 'This file controls the mechanism for preventing duplicate usernames in passwd/radius files exported from svc_accts.  This should be one of \'prepend domsvc\' \'append domsvc\' \'append domain\' or \'append @domain\'',
    'type'        => 'select',
    'select_enum' => [ 'prepend domsvc', 'append domsvc', 'append domain', 'append @domain' ],
    #'type'        => 'text',
  },

  {
    'key'         => 'vpopmailmachines',
    'section'     => 'mail',
    'description' => 'Your vpopmail pop toasters, one per line.  Each line is of the form "machinename vpopdir vpopuid vpopgid".  For example: <code>poptoaster.domain.tld /home/vpopmail 508 508</code>  Note: vpopuid and vpopgid are values taken from the vpopmail machine\'s /etc/passwd',
    'type'        => 'textarea',
  },

  {
    'key'         => 'vpopmailrestart',
    'section'     => 'mail',
    'description' => 'If defined, the shell commands to run on vpopmail machines after files are copied.  An example can be found in eg/vpopmailrestart of the source distribution.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'safe-part_pkg',
    'section'     => 'UI',
    'description' => 'Validates package definition setup and recur expressions against a preset list.  Useful for webdemos, annoying to powerusers.',
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
    'description' => 'Turns on display/collection of SS# in the web interface.',
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

);

1;

