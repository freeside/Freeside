package FS::part_export::cardfortress;

use strict;
use base 'FS::part_export';
use vars qw( %info );
use String::ShellQuote;

#tie my %options, 'Tie::IxHash';
#;

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'CardFortress',
  'options'  => {}, #\%options,
  'nodomain' => 'Y',
  'notes'    => '',
);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);

  eval "use Net::OpenSSH;";
  return $@ if $@;

  open my $def_in, '<', '/dev/null' or die "unable to open /dev/null";
  my $ssh = Net::OpenSSH->new( $self->machine,
                               default_stdin_fh => $def_in );

  my $private_key = $ssh->capture(
    { 'stdin_data' => $svc_acct->_password. "\n" },
    '/usr/local/bin/merchant_create', map $svc_acct->$_, qw( username finger )
  );
  return $ssh->error if $ssh->error;

  $svc_acct->cf_privatekey($private_key);

  $svc_acct->replace;

}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  return 'username changes not yet supported'
    if $old->username ne $new->username;

  return 'password changes not yet supported'
    if $old->_password ne $new->_password;

  return 'Real name changes not yet supported'
    if $old->finger ne $new->finger;

  '';
}

sub _export_delete {
  #my( $self, $svc_x ) = (shift, shift);

  return 'deletion not yet supproted';
}

1;
