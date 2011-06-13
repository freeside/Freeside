package FS::part_export::acct_sql;
use base qw( FS::part_export::sql_Common );

use strict;
use vars qw( %info );
use FS::Record; #qw(qsearchs);

my %options = __PACKAGE__->sql_options;
$options{'crypt'} = { label => 'Password encryption',
                      type=>'select', options=>[qw(crypt md5 sha1_base64)],
                      default=>'crypt',
                    };

tie my %vpopmail_map, 'Tie::IxHash',
  'pw_name'   => 'username',
  'pw_domain' => 'domain',
  'pw_passwd' => 'crypt_password',
  'pw_uid'    => 'uid',
  'pw_gid'    => 'gid',
  'pw_gecos'  => 'finger',
  'pw_dir'    => 'dir',
  #'pw_shell'  => 'shell',
  'pw_shell'  => 'quota',
;
my $vpopmail_map = join('\n', map "$_ $vpopmail_map{$_}", keys %vpopmail_map );

tie my %postfix_courierimap_mailbox_map, 'Tie::IxHash',
  'username' => 'email',
  'password' => '_password',
  'crypt'    => 'crypt_password',
  'name'     => 'finger',
  'maildir'  => 'virtual_maildir',
  'domain'   => 'domain',
  'svcnum'   => 'svcnum',
;
my $postfix_courierimap_mailbox_map =
  join('\n', map "$_ $postfix_courierimap_mailbox_map{$_}",
                 keys %postfix_courierimap_mailbox_map      );

tie my %postfix_courierimap_alias_map, 'Tie::IxHash',
  'address' => 'email',
  'goto'    => 'email',
  'domain'  => 'domain',
  'svcnum'  => 'svcnum',
;
my $postfix_courierimap_alias_map =
  join('\n', map "$_ $postfix_courierimap_alias_map{$_}",
                 keys %postfix_courierimap_alias_map      );

tie my %postfix_native_mailbox_map, 'Tie::IxHash',
  'userid'   => 'email',
  'uid'      => 'uid',
  'gid'      => 'gid',
  'password' => 'ldap_password',
  'mail'     => 'domain_slash_username',
;
my $postfix_native_mailbox_map =
  join('\n', map "$_ $postfix_native_mailbox_map{$_}",
                 keys %postfix_native_mailbox_map      );

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export of accounts to SQL databases '.
                '(vpopmail, Postfix+Courier IMAP, others?)',
  'options'  => \%options,
  'nodomain' => '',
  'notes'    => <<END
Export accounts (svc_acct records) to SQL databases.  Currently has default
configurations for vpopmail and Postfix+Courier IMAP but intended to be
configurable for other schemas as well.

<BR><BR>In contrast to sqlmail, this is intended to export just svc_acct
records only, rather than a single export for svc_acct, svc_forward and
svc_domain records, to export in "default" database schemas rather than
configure the MTA or POP/IMAP server for a Freeside-specific schema, and
to be configured for different mail server setups.

<BR><BR>Use these buttons for some useful presets:
<UL>
  <li><INPUT TYPE="button" VALUE="vpopmail" onClick='
    this.form.table.value = "vpopmail";
    this.form.schema.value = "$vpopmail_map";
    this.form.primary_key.value = "pw_name, pw_domain";
  '>
  <LI><INPUT TYPE="button" VALUE="postfix_courierimap_mailbox" onClick='
    this.form.table.value = "mailbox";
    this.form.schema.value = "$postfix_courierimap_mailbox_map";
    this.form.primary_key.value = "username";
  '>
  <LI><INPUT TYPE="button" VALUE="postfix_courierimap_alias" onClick='
    this.form.table.value = "alias";
    this.form.schema.value = "$postfix_courierimap_alias_map";
    this.form.primary_key.value = "address";
  '>
  <LI><INPUT TYPE="button" VALUE="postfix_native_mailbox" onClick='
    this.form.table.value = "users";
    this.form.schema.value = "$postfix_native_mailbox_map";
    this.form.primary_key.value = "userid";
  '>
</UL>
END
);

sub _map_arg_callback {
  my($self, $field) = @_;
  my $crypt = $self->option('crypt');
  return () unless $field eq 'crypt_password' && $crypt;
  ($crypt);
}

1;

