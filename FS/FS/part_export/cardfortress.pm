package FS::part_export::cardfortress;

use strict;
use base 'FS::part_export';
use vars qw( %info );
use String::ShellQuote;
use Net::OpenSSH;

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


  open my $def_in, '<', '/dev/null' or die "unable to open /dev/null";
  my $ssh = Net::OpenSSH->new( $self->machine,
                               default_stdin_fh => $def_in );

  #capture2 and return STDERR, its probably useful if there's a problem
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

#well, we're just going to disable them for now, but there you go
sub _export_delete    { shift->merchant_disable(@_) }

sub _export_suspend   { shift->merchant_disable(@_) }

sub _export_unsuspend { shift->merchant_enable(@_) }

sub merchant_disable {
  my( $self, $svc_acct ) = (shift, shift);

  open my $def_in, '<', '/dev/null' or die "unable to open /dev/null";
  my $ssh = Net::OpenSSH->new( $self->machine,
                               default_stdin_fh => $def_in );

  #capture2 and return STDERR, its probably useful if there's a problem
  my $unused_output = $ssh->capture(
    '/usr/local/bin/merchant_disable', map $svc_acct->$_, qw( username )
  );
  return $ssh->error if $ssh->error;

  '';

}

sub merchant_enable {
  my( $self, $svc_acct ) = (shift, shift);

  open my $def_in, '<', '/dev/null' or die "unable to open /dev/null";
  my $ssh = Net::OpenSSH->new( $self->machine,
                               default_stdin_fh => $def_in );

  #capture2 and return STDERR, its probably useful if there's a problem
  my $unused_output = $ssh->capture(
    '/usr/local/bin/merchant_enable', map $svc_acct->$_, qw( username )
  );
  return $ssh->error if $ssh->error;

  '';

}

1;
