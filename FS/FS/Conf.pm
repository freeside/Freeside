package FS::Conf;

use vars qw($default_dir @config_items $DEBUG );
use IO::File;
use File::Basename;
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

  $conf->touch('key');
  $conf->set('key' => 'value');
  $conf->delete('key');

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

=item config KEY

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

=item exists KEY

Returns true if the specified key exists, even if the corresponding value
is undefined.

=cut

sub exists {
  my($self,$file)=@_;
  my($dir) = $self->dir;
  -e "$dir/$file";
}

=item touch KEY

Creates the specified configuration key if it does not exist.

=cut

sub touch {
  my($self, $file) = @_;
  my $dir = $self->dir;
  unless ( $self->exists($file) ) {
    warn "[FS::Conf] TOUCH $file\n" if $DEBUG;
    system('touch', "$dir/$file");
  }
}

=item set KEY VALUE

Sets the specified configuration key to the given value.

=cut

sub set {
  my($self, $file, $value) = @_;
  my $dir = $self->dir;
  $value =~ /^(.*)$/s;
  $value = $1;
  unless ( join("\n", @{[ $self->config($file) ]}) eq $value ) {
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

=item delete KEY

Deletes the specified configuration key.

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
  my $self = shift; 
  #quelle kludge
  @config_items,
  map { 
        my $basename = basename($_);
        $basename =~ /^(.*)$/;
        $basename = $1;
        new FS::ConfItem {
                           'key'         => $basename,
                           'section'     => 'billing',
                           'description' => 'Alternate template file for invoices.  See the <a href="../docs/billing.html">billing documentation</a> for details.',
                           'type'        => 'textarea',
                         }
      } glob($self->dir. '/invoice_template_*')
  ;
}

=back

=head1 BUGS

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
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>www_shellcommands</i> <a href="../browse/part_export.cgi">export</a> instead.  The directory containing Apache virtual hosts',
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
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>www_shellcommands</i> <a href="../browse/part_export.cgi">export</a> instead.  A machine with the apacheroot directory and user home directories.  The existance of this file enables setup of virtual host directories, and, in conjunction with the `home\' configuration file, symlinks into user home directories.',
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
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>bind</i> <a href="../browse/part_export.cgi">export</a> instead.  Your BIND primary nameserver.  This enables export of /var/named/named.conf and zone files into /var/named',
    'type'        => 'text',
  },

  {
    'key'         => 'bindsecondaries',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>bind_slave</i> <a href="../browse/part_export.cgi">export</a> instead.  Your BIND secondary nameservers, one per line.  This enables export of /var/named/named.conf',
    'type'        => 'textarea',
  },

  {
    'key'         => 'business-onlinepayment',
    'section'     => 'billing',
    'description' => '<a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> support, at least three lines: processor, login, and password.  An optional fourth line specifies the action or actions (multiple actions are separated with `,\': for example: `Authorization Only, Post Authorization\').    Optional additional lines are passed to Business::OnlinePayment as %processor_options.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'business-onlinepayment-description',
    'section'     => 'billing',
    'description' => 'String passed as the description field to <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a>.  Evaluated as a double-quoted perl string, with the following variables available: <code>$agent</code> (the agent name), and <code>$pkgs</code> (a comma-separated list of packages to which the invoiced being charged applies)',
    'type'        => 'text',
  },

  {
    'key'         => 'bsdshellmachines',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>bsdshell</i> <a href="../browse/part_export.cgi">export</a> instead.  Your BSD flavored shell (and mail) machines, one per line.  This enables export of `/etc/passwd\' and `/etc/master.passwd\'.',
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
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>cyrus</i> <a href="../browse/part_export.cgi">export</a> instead.  This option used to integrate with <a href="http://asg.web.cmu.edu/cyrus/imapd/">Cyrus IMAP Server</a>, three lines: IMAP server, admin username, and admin password.  Cyrus::IMAP::Admin should be installed locally and the connection to the server secured.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cp_app',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>cp</i> <a href="../browse/part_export.cgi">export</a> instead.  This option used to integrate with <a href="http://www.cp.net/">Critial Path Account Provisioning Protocol</a>, four lines: "host:port", username, password, and workgroup (for new users).',
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
    'description' => 'Enable deletion of unclosed payments.  Be very careful!  Only delete payments that were data-entry errors, not adjustments. Optionally specify one or more comma-separated email addresses to be notified when a payment is deleted.',
    'type'        => [qw( checkbox text )],
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
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add an <i>sqlradius</i> <a href="../browse/part_export.cgi">export</a> instead.  This option used to enable radcheck and radreply table population - by default in the Freeside database, or in the database specified by the <a href="http://rootwood.haze.st/aspside/config/config-view.cgi#icradius_secrets">icradius_secrets</a> config option (the radcheck and radreply tables needs to be created manually).  You do not need to use MySQL for your Freeside database to export to an ICRADIUS/FreeRADIUS MySQL database with this option.  <blockquote><b>ADDITIONAL DEPRECATED FUNCTIONALITY</b> (instead use <a href="http://www.mysql.com/documentation/mysql/bychapter/manual_MySQL_Database_Administration.html#Replication">MySQL replication</a> or point icradius_secrets to the external database) - your <a href="ftp://ftp.cheapnet.net/pub/icradius">ICRADIUS</a> machines or <a href="http://www.freeradius.org/">FreeRADIUS</a> (with MySQL authentication) machines, one per line.  Machines listed in this file will have the radcheck table exported to them.  Each line should contain four items, separted by whitespace: machine name, MySQL database name, MySQL username, and MySQL password.  For example: <CODE>"radius.isp.tld&nbsp;radius_db&nbsp;radius_user&nbsp;passw0rd"</CODE></blockquote>',
    'type'        => [qw( checkbox textarea )],
  },

  {
    'key'         => 'icradius_mysqldest',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add an <i>sqlradius</i> https://billing.crosswind.net/freeside/browse/part_export.cgi">export</a> instead.  Used to be the destination directory for the MySQL databases, on the ICRADIUS/FreeRADIUS machines.  Defaults to "/usr/local/var/".',
    'type'        => 'text',
  },

  {
    'key'         => 'icradius_mysqlsource',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add an <i>sqlradius</i> https://billing.crosswind.net/freeside/browse/part_export.cgi">export</a> instead.  Used to be the source directory for for the MySQL radcheck table files, on the Freeside machine.  Defaults to "/usr/local/var/freeside".',
    'type'        => 'text',
  },

  {
    'key'         => 'icradius_secrets',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add an <i>sqlradius</i> https://billing.crosswind.net/freeside/browse/part_export.cgi">export</a> instead.  This option used to specify a database for ICRADIUS/FreeRADIUS export.  Three lines: DBI data source, username and password.',
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
    'section'     => 'deprecated',
    'description' => 'MX entries for new domains, weight and machine, one per line, with trailing `.\'',
    'type'        => 'textarea',
  },

  {
    'key'         => 'nsmachines',
    'section'     => 'deprecated',
    'description' => 'NS nameservers for new domains, one per line, with trailing `.\'',
    'type'        => 'textarea',
  },

  {
    'key'         => 'defaultrecords',
    'section'     => 'BIND',
    'description' => 'DNS entries to add automatically when creating a domain',
    'type'        => 'editlist',
    'editlist_parts' => [ { type=>'text' },
                          { type=>'immutable', value=>'IN' },
                          { type=>'select',
                            select_enum=>{ map { $_=>$_ } qw(A CNAME MX NS)} },
                          { type=> 'text' }, ],
  },

  {
    'key'         => 'arecords',
    'section'     => 'deprecated',
    'description' => 'A list of tab seperated CNAME records to add automatically when creating a domain',
    'type'        => 'textarea',
  },

  {
    'key'         => 'cnamerecords',
    'section'     => 'deprecated',
    'description' => 'A list of tab seperated CNAME records to add automatically when creating a domain',
    'type'        => 'textarea',
  },

  {
    'key'         => 'nismachines',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>.  Your NIS master (not slave master) machines, one per line.  This enables export of `/etc/global/passwd\' and `/etc/global/shadow\'.',
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
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add an <i>sqlradius</i> <a href="../browse/part_export.cgi">export</a> instead.  This option used to export to be: your RADIUS authentication machines, one per line.  This enables export of `/etc/raddb/users\'.',
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
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>shellcommands</i> <a href="../browse/part_export.cgi">export</a> instead.  This option used to contain a single machine with user home directories mounted.  This enables home directory creation, renaming and archiving/deletion.  In conjunction with `qmailmachines\', it also enables `.qmail-extension\' file maintenance.',
    'type'        => 'text',
  },

  {
    'key'         => 'shellmachine-useradd',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>shellcommands</i> <a href="../browse/part_export.cgi">export</a> instead.  This option used to contain command(s) to run on shellmachine when an account is created.  If the <b>shellmachine</b> option is set but this option is not, <code>useradd -d $dir -m -s $shell -u $uid $username</code> is the default.  If this option is set but empty, <code>cp -pr /etc/skel $dir; chown -R $uid.$gid $dir</code> is the default instead.  Otherwise the value is evaluated as a double-quoted perl string, with the following variables available: <code>$username</code>, <code>$uid</code>, <code>$gid</code>, <code>$dir</code>, and <code>$shell</code>.',
    'type'        => [qw( checkbox text )],
  },

  {
    'key'         => 'shellmachine-userdel',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>shellcommands</i> <a href="../browse/part_export.cgi">export</a> instead.  This option used to contain command(s) to run on shellmachine when an account is deleted.  If the <b>shellmachine</b> option is set but this option is not, <code>userdel $username</code> is the default.  If this option is set but empty, <code>rm -rf $dir</code> is the default instead.  Otherwise the value is evaluated as a double-quoted perl string, with the following variables available: <code>$username</code> and <code>$dir</code>.',
    'type'        => [qw( checkbox text )],
  },

  {
    'key'         => 'shellmachine-usermod',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>shellcommands</i> <a href="../browse/part_export.cgi">export</a> instead.  This option used to contain command(s) to run on shellmachine when an account is modified.  If the <b>shellmachine</b> option is set but this option is empty, <code>[ -d $old_dir ] &amp;&amp; mv $old_dir $new_dir || ( chmod u+t $old_dir; mkdir $new_dir; cd $old_dir; find . -depth -print | cpio -pdm $new_dir; chmod u-t $new_dir; chown -R $uid.$gid $new_dir; rm -rf $old_dir )</code> is the default.  Otherwise the contents of the file are treated as a double-quoted perl string, with the following variables available: <code>$old_dir</code>, <code>$new_dir</code>, <code>$uid</code> and <code>$gid</code>.',
    #'type'        => [qw( checkbox text )],
    'type'        => 'text',
  },

  {
    'key'         => 'shellmachines',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>sysvshell</i> <a href="../browse/part_export.cgi">export</a> instead.  Your Linux and System V flavored shell (and mail) machines, one per line.  This enables export of `/etc/passwd\' and `/etc/shadow\' files.',
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
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, real-time text radius now edits an existing file in place - just (turn off freeside-queued and) edit your RADIUS users file directly.  The contents used to be be prepended to the top of the RADIUS users file (text exports only).',
    'type'        => 'textarea',
  },

  {
    'key'         => 'textradiusprepend',
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, use RADIUS check attributes instead.  The contents used to be prepended to the first line of a user\'s RADIUS entry in text exports.',
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
    'section'     => 'deprecated',
    'description' => '<b>DEPRECATED</b>, add a <i>cp</i> <a href="../browse/part_export.cgi">export</a> instead.  This option used to contain your vpopmail pop toasters, one per line.  Each line is of the form "machinename vpopdir vpopuid vpopgid".  For example: <code>poptoaster.domain.tld /home/vpopmail 508 508</code>  Note: vpopuid and vpopgid are values taken from the vpopmail machine\'s /etc/passwd',
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
    'select_enum' => [ qw(CARD PREPAY BILL COMP) ],
  },

  {
    'key'         => 'signup_server-email',
    'section'     => '',
    'description' => 'Comma-separated list of email addresses to receive notification of signups via the signup server.',
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
    'description' => 'Run billing for signup server signups immediately, and suspend accounts which subsequently have a balance.',
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
    'key'         => 'welcome_email',
    'section'     => '',
    'description' => 'Template file for welcome email.  Welcome emails are sent to the customer email invoice destination(s) each time a svc_acct record is created.  See the <a href="http://search.cpan.org/doc/MJD/Text-Template-1.42/Template.pm">Text::Template</a> documentation for details on the template substitution language.  The following variables are available: <code>$username</code>, <code>$password</code>, <code>$first</code>, <code>$last</code> and <code>$pkg</code>.',
    'type'        => 'textarea',
  },

  {
    'key'         => 'welcome_email-from',
    'section'     => '',
    'description' => 'From: address header for welcome email',
    'type'        => 'text',
  },

  {
    'key'         => 'welcome_email-subject',
    'section'     => '',
    'description' => 'Subject: header for welcome email',
    'type'        => 'text',
  },
  
  {
    'key'         => 'welcome_email-mimetype',
    'section'     => '',
    'description' => 'MIME type for welcome email',
    'type'        => 'select',
    'select_enum' => [ 'text/plain', 'text/html' ],
  },

);

1;

