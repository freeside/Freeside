package FS::svc_forward;

use strict;
use vars qw( @ISA $nossh_hack $conf $shellmachine @qmailmachines
             @vpopmailmachines );
use Net::SSH qw(ssh);
use FS::Conf;
use FS::Record qw( fields qsearch qsearchs );
use FS::svc_Common;
use FS::cust_svc;
use FS::svc_acct;
use FS::svc_domain;

@ISA = qw( FS::svc_Common );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::svc_forward'} = sub { 
  $conf = new FS::Conf;
  if ( $conf->exists('qmailmachines') ) {
    $shellmachine = $conf->config('shellmachine')
  } else {
    $shellmachine = '';
  }
  if ( $conf->exists('vpopmailmachines') ) {
    @vpopmailmachines = $conf->config('vpopmailmachines');
  } else {
    @vpopmailmachines = ();
  }
};

=head1 NAME

FS::svc_forward - Object methods for svc_forward records

=head1 SYNOPSIS

  use FS::svc_forward;

  $record = new FS::svc_forward \%hash;
  $record = new FS::svc_forward { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_forward object represents a mail forwarding alias.  FS::svc_forward
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatcially for new accounts)

=item srcsvc - svcnum of the source of the forward (see L<FS::svc_acct>)

=item dstsvc - svcnum of the destination of the forward (see L<FS::svc_acct>)

=item dst - foreign destination (email address) - forward not local to freeside

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new mail forwarding alias.  To add the mail forwarding alias to the
database, see L<"insert">.

=cut

sub table { 'svc_forward'; }

=item insert

Adds this mail forwarding alias to the database.  If there is an error, returns
the error, otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

If the configuration values (see L<FS::Conf>) vpopmailmachines exist, then
the command:

  [ -d /home/vpopmail/$vdomain/$source ] || {
    echo "$destination" >> /home/vpopmail/$vdomain/$source/.$qmail
    chown $vpopuid:$vpopgid /home/vpopmail/$vdomain/$source/.$qmail
  }

is executed on each vpopmailmachine via ssh (see L<dot-qmail/"EXTENSION ADDRESSES">).
This behaviour can be surpressed by setting $FS::svc_forward::nossh_hack true.

=cut

sub insert {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  $error=$self->check;
  return $error if $error;

  $error = $self->SUPER::insert;
  return $error if $error;

  my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $self->srcsvc } );
  my $svc_domain = qsearchs( 'svc_domain', { 'svcnum' => $svc_acct->domsvc } );
  my $source = $svc_acct->username . $svc_domain->domain;
  my $destination;
  if ($self->dstdvc) {
    my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $self->dstsvc } );
    my $svc_domain = qsearchs( 'svc_domain', { 'svcnum' => $svc_acct->domsvc } );
    $destination = $svc_acct->username . $svc_domain->domain;
  } else {
    $destination = $self->dst;
  }
    
  my $vdomain = $svc_acct->domain;

  foreach my $vpopmailmachine ( @vpopmailmachines ) {
    my ($machine, $vpopdir, $vpopuid, $vpopgid) = split (/\s+/, $vpopmailmachine);

    ssh("root\@$machine","[ -d $vpopdir/$vdomain/$source ] || { echo $destination >> $vpopdir/$vdomain/$source/.qmail; chown $vpopuid:$vpopgid $vpopdir/$vdomain/$source/.qmail; }")  
      if ( ! $nossh_hack && $machine);
  }

  ''; #no error

}

=item delete

Deletes this mail forwarding alias from the database.  If there is an error,
returns the error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );
  my $error;

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

Checks all fields to make sure this is a valid mail forwarding alias.  If there
is an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

Sets any fixed values; see L<FS::part_svc>.

=cut

sub check {
  my $self = shift;
  my $error;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my($recref) = $self->hashref;

  $recref->{srcsvc} =~ /^(\d+)$/ or return "Illegal srcsvc";
  $recref->{srcsvc} = $1;
  my($svc_acct);
  return "Unknown srcsvc" unless
    $svc_acct=qsearchs('svc_acct',{'svcnum'=> $recref->{srcsvc} } );

  return "Illegal use of dstsvc and dst" if
    ($recref->{dstsvc} && $recref->{dst});

  return "Illegal use of dstsvc and dst" if
    (! $recref->{dstsvc} && ! $recref->{dst});

  $recref->{dstsvc} =~ /^(\d+)$/ or return "Illegal dstsvc";
  $recref->{dstsvc} = $1;

  if ($recref->{dstsvc}) {
    my($svc_acct);
    return "Unknown dstsvc" unless
      my $svc_domain=qsearchs('svc_acct',{'svcnum'=> $recref->{dstsvc} } );
  }

  if ($recref->{dst}) {
    $recref->{dst} =~ /^([\w\.\-]+)\@(([\w\.\-]+\.)+\w+)$/
       or return "Illegal dst";
  }

  ''; #no error
}

=back

=head1 VERSION

$Id: svc_forward.pm,v 1.4 2001-08-20 09:41:52 ivan Exp $

=head1 BUGS

The remote commands should be configurable.

The $recref stuff in sub check should be cleaned up.

=head1 SEE ALSO

L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>,
L<FS::svc_acct>, L<FS::svc_domain>, L<Net::SSH>, L<ssh>, L<dot-qmail>,
schema.html from the base documentation.

=cut

1;

