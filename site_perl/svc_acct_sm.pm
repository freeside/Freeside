package FS::svc_acct_sm;

use strict;
use vars qw( @ISA $nossh_hack $conf $shellmachine @qmailmachines );
use FS::Record qw( fields qsearch qsearchs );
use FS::svc_Common;
use FS::cust_svc;
use FS::SSH qw(ssh);
use FS::Conf;

@ISA = qw( FS::svc_Common );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::svc_acct_sm'} = sub { 
  $conf = new FS::Conf;
  $shellmachine = $conf->exists('qmailmachines')
                  ? $conf->config('shellmachine')
                  : '';
};

=head1 NAME

FS::svc_acct_sm - Object methods for svc_acct_sm records

=head1 SYNOPSIS

  use FS::svc_acct_sm;

  $record = new FS::svc_acct_sm \%hash;
  $record = new FS::svc_acct_sm { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_acct object represents a virtual mail alias.  FS::svc_acct inherits
from FS::Record.  The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatcially for new accounts)

=item domsvc - svcnum of the virtual domain (see L<FS::svc_domain>)

=item domuid - uid of the target account (see L<FS::svc_acct>)

=item domuser - virtual username

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new virtual mail alias.  To add the virtual mail alias to the
database, see L<"insert">.

=cut

sub table { 'svc_acct_sm'; }

=item insert

Adds this virtual mail alias to the database.  If there is an error, returns
the error, otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

If the configuration values (see L<FS::Conf>) shellmachine and qmailmachines
exist, and domuser is `*' (meaning a catch-all mailbox), the command:

  [ -e $dir/.qmail-$qdomain-default ] || {
    touch $dir/.qmail-$qdomain-default;
    chown $uid:$gid $dir/.qmail-$qdomain-default;
  }

is executed on shellmachine via ssh (see L<dot-qmail/"EXTENSION ADDRESSES">).
This behaviour can be surpressed by setting $FS::svc_acct_sm::nossh_hack true.

=cut

sub insert {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  $error=$self->check;
  return $error if $error;

  return "Domain username (domuser) in use for this domain (domsvc)"
    if qsearchs('svc_acct_sm',{ 'domuser'=> $self->domuser,
                                'domsvc' => $self->domsvc,
                              } );

  return "First domain username (domuser) for domain (domsvc) must be " .
         qq='*' (catch-all)!=
    if $self->domuser ne '*' &&
       ! qsearch('svc_acct_sm',{ 'domsvc' => $self->domsvc } );

  $error = $self->SUPER::insert;
  return $error if $error;

  my $svc_domain = qsearchs( 'svc_domain', { 'svcnum' => $self->domsvc } );
  my $svc_acct = qsearchs( 'svc_acct', { 'uid' => $self->domuid } );
  my ( $uid, $gid, $dir, $domain ) = (
    $svc_acct->uid,
    $svc_acct->gid,
    $svc_acct->dir,
    $svc_domain->domain,
  );
  my $qdomain = $domain;
  $qdomain =~ s/\./:/g; #see manpage for 'dot-qmail': EXTENSION ADDRESSES
  ssh("root\@$shellmachine","[ -e $dir/.qmail-$qdomain-default ] || { touch $dir/.qmail-$qdomain-default; chown $uid:$gid $dir/.qmail-$qdomain-default; }")  
    if ( ! $nossh_hack && $shellmachine && $dir && $self->domuser eq '*' );

  ''; #no error

}

=item delete

Deletes this virtual mail alias from the database.  If there is an error,
returns the error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );
  my $error;

  return "Domain username (domuser) in use for this domain (domsvc)"
    if ( $old->domuser ne $new->domuser
         || $old->domsvc  ne $new->domsvc
       )  && qsearchs('svc_acct_sm',{
         'domuser'=> $new->domuser,
         'domsvc' => $new->domsvc,
       } )
     ;

 $new->SUPER::replace($old);

}

=item suspend

Just returns false (no error) for now.

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Just returns false (no error) for now.

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Just returns false (no error) for now.

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid virtual mail alias.  If there is
an error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

Sets any fixed values; see L<FS::part_svc>.

=cut

sub check {
  my $self = shift;
  my $error;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my($recref) = $self->hashref;

  $recref->{domuser} =~ /^(\*|[a-z0-9_\-]{2,32})$/
    or return "Illegal domain username (domuser)";
  $recref->{domuser} = $1;

  $recref->{domsvc} =~ /^(\d+)$/ or return "Illegal domsvc";
  $recref->{domsvc} = $1;
  my($svc_domain);
  return "Unknown domsvc" unless
    $svc_domain=qsearchs('svc_domain',{'svcnum'=> $recref->{domsvc} } );

  $recref->{domuid} =~ /^(\d+)$/ or return "Illegal uid";
  $recref->{domuid} = $1;
  my($svc_acct);
  return "Unknown uid" unless
    $svc_acct=qsearchs('svc_acct',{'uid'=> $recref->{domuid} } );

  ''; #no error
}

=back

=head1 VERSION

$Id: svc_acct_sm.pm,v 1.4 1998-12-30 00:30:46 ivan Exp $

=head1 BUGS

The remote commands should be configurable.

The $recref stuff in sub check should be cleaned up.

=head1 SEE ALSO

L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>,
L<FS::svc_acct>, L<FS::svc_domain>, L<FS::SSH>, L<ssh>, L<dot-qmail>,
schema.html from the base documentation.

=head1 HISTORY

ivan@voicenet.com 97-jul-16 - 21

rewrite ivan@sisd.com 98-mar-10

s/qsearchs/qsearch/ to eliminate warning ivan@sisd.com 98-apr-19

uses conf/shellmachine and has an nossh_hack ivan@sisd.com 98-jul-14

s/\./:/g in .qmail-domain:com ivan@sisd.com 98-aug-13 

pod, FS::Conf, moved .qmail file from check to insert 98-sep-23

=cut

1;

