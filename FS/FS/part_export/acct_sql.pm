package FS::part_export::acct_sql;
use base qw( FS::part_export::sql_Common );

use strict;
use vars qw( %info );
use Tie::IxHash;
use FS::Record; #qw(qsearchs);

tie my %options, 'Tie::IxHash', %{__PACKAGE__->sql_options};
$options{'crypt'} = { label => 'Password encryption',
                      type=>'select', options=>[qw(crypt md5 sha1_base64 sha512)],
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

tie my %libnss_pgsql_passwd_map, 'Tie::IxHash',
  'username' => 'username',
  #'passwd'   => literal string 'x'
  'uid'      => 'uid',
  'gid'      => 'gid',
  'gecos'    => 'finger',
  'homedir'  => 'dir',
  'shell'    => 'shell',
;
my $libnss_pgsql_passwd_map =
  join('\n', map "$_ $libnss_pgsql_passwd_map{$_}",
                 keys %libnss_pgsql_passwd_map      );

tie my %libnss_pgsql_passwd_static, 'Tie::IxHash',
  'passwd' => 'x',
;
my $libnss_pgsql_passwd_static =
  join('\n', map "$_ $libnss_pgsql_passwd_static{$_}",
                 keys %libnss_pgsql_passwd_static      );

tie my %libnss_pgsql_shadow_map, 'Tie::IxHash',
  'username' => 'username',
  'passwd'   => 'crypt_password',
;
my $libnss_pgsql_shadow_map =
  join('\n', map "$_ $libnss_pgsql_shadow_map{$_}",
                 keys %libnss_pgsql_shadow_map      );

tie my %libnss_pgsql_shadow_static, 'Tie::IxHash',
  'lastchange' => '18550', #not actually implemented..
  'min'        => '0',
  'max'        => '99999',
  'warn'       => '7',
  'inact'      => '0',
  'expire'     => '-1',
  'flag'       => '0',
;
my $libnss_pgsql_shadow_static =
  join('\n', map "$_ $libnss_pgsql_shadow_static{$_}",
                 keys %libnss_pgsql_shadow_static      );

%info = (
  'svc'        => 'svc_acct',
  'desc'       => 'Real-time export of accounts to SQL databases '.
                  '(vpopmail, Postfix+Courier IMAP, others?)',
  'options'    => \%options,
  'nodomain'   => '',
  'no_machine' => 1,
  'default_svc_class' => 'Email',
  'notes'    => <<END
Export accounts (svc_acct records) to SQL databases.  Currently has default
configurations for vpopmail, Postfix+Courier IMAP, Postfix native and ,
but can be configured for other schemas.

<BR><BR>In contrast to sqlmail, this is intended to export just svc_acct
records only, rather than a single export for svc_acct, svc_forward and
svc_domain records, to export in "default" database schemas rather than
configure servers for a Freeside-specific schema, and to be configured for
different mail (and authentication) server setups.

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
  <LI><INPUT TYPE="button" VALUE="libnss-pgsql passwd" onClick='
    this.form.table.value = "passwd_table";
    this.form.schema.value = "$libnss_pgsql_passwd_map";
    this.form.static.value = "$libnss_pgsql_passwd_static";
    this.form.primary_key.value = "uid";
  '>
  <LI><INPUT TYPE="button" VALUE="libnss-pgsql shadow" onClick='
    this.form.table.value = "shadow_table";
    this.form.schema.value = "$libnss_pgsql_shadow_map";
    this.form.static.value = "$libnss_pgsql_shadow_static";
    this.form.primary_key.value = "username";
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

