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

If the configuration value (see L<FS::Conf>) vpopmailmachines exists, then
the command:

  [ -d $vpopdir/$domain/$source ] || {
    echo "$destination" >> $vpopdir/$domain/$username/.$qmail
    chown $vpopuid:$vpopgid $vpopdir/$domain/$username/.$qmail
  }

is executed on each vpopmailmachine via ssh (see the vpopmail documentation).
This behaviour can be supressed by setting $FS::svc_forward::nossh_hack true.

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

  $error = $self->check;
  return $error if $error;

  $error = $self->SUPER::insert;
  return $error if $error;

  my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $self->srcsvc } );
  my $username = $svc_acct->username;
  my $domain = $svc_acct->domain;
  my $destination;
  if ($self->dstsvc) {
    my $dst_svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $self->dstsvc } );
    $destination = $dst_svc_acct->email;
  } else {
    $destination = $self->dst;
  }
    
  foreach my $vpopmailmachine ( @vpopmailmachines ) {
    my($machine, $vpopdir, $vpopuid, $vpopgid) = split(/\s+/, $vpopmailmachine);
    ssh("root\@$machine","[ -d $vpopdir/$domain/$username ] || { echo \"$destination\" >> $vpopdir/$domain/$username/.qmail; chown $vpopuid:$vpopgid $vpopdir/$domain/$username/.qmail; }") 
      unless $nossh_hack;
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

If srcsvc changes, and the configuration value vpopmailmachines exists, then
the command:

  rm $vpopdir/$domain/$username/.qmail

is executed on each vpopmailmachine via ssh.  This behaviour can be supressed
by setting $FS::svc_forward_nossh_hack true.

If dstsvc changes (or dstsvc is 0 and dst changes), and the configuration value
vpopmailmachines exists, then the command:

  [ -d $vpopdir/$domain/$source ] || {
    echo "$destination" >> $vpopdir/$domain/$username/.$qmail
    chown $vpopuid:$vpopgid $vpopdir/$domain/$username/.$qmail
  }

is executed on each vpopmailmachine via ssh.  This behaviour can be supressed
by setting $FS::svc_forward_nossh_hack true.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );

  if ( $new->srcsvc != $old->srcsvc
       && ( $new->dstsvc != $old->dstsvc
            || ! $new->dstsvc && $new->dst ne $old->dst 
          )
      ) {
    return "Can't change both source and destination of a mail forward!"
  }

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $error = $new->SUPER::replace($old);
  return $error if $error;

  if ( $new->srcsvc != $old->srcsvc ) {
    my $old_svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $old->srcsvc } );
    my $old_username = $old_svc_acct->username;
    my $old_domain = $old_svc_acct->domain;
    foreach my $vpopmailmachine ( @vpopmailmachines ) {
      my($machine, $vpopdir, $vpopuid, $vpopgid) =
        split(/\s+/, $vpopmailmachine);
      ssh("root\@$machine","rm $vpopdir/$old_domain/$old_username/.qmail")
        unless $nossh_hack;
    }
  }

  #false laziness with stuff in insert, should subroutine
  my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $new->srcsvc } );
  my $username = $svc_acct->username;
  my $domain = $svc_acct->domain;
  my $destination;
  if ($new->dstsvc) {
    my $dst_svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $new->dstsvc } );
    $destination = $dst_svc_acct->email;
  } else {
    $destination = $new->dst;
  }
  
  foreach my $vpopmailmachine ( @vpopmailmachines ) {
    my($machine, $vpopdir, $vpopuid, $vpopgid) = split(/\s+/, $vpopmailmachine);
    ssh("root\@$machine","[ -d $vpopdir/$domain/$username ] || { echo \"$destination\" >> $vpopdir/$domain/$username/.qmail; chown $vpopuid:$vpopgid $vpopdir/$domain/$username/.qmail; }") 
      unless $nossh_hack;
  }
  #end subroutinable bits

  '';
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

  my $x = $self->setfixed;
  return $x unless ref($x);
  #my $part_svc = $x;

  my $error = $self->ut_numbern('svcnum')
              || $self->ut_number('srcsvc')
              || $self->ut_numbern('dstsvc')
  ;
  return $error if $error;

  return "Unknown srcsvc" unless $self->srcsvc_acct;

  return "Both dstsvc and dst were defined; one one can be specified"
    if $self->dstsvc && $self->dst;

  return "one of dstsvc or dst is required"
    unless $self->dstsvc || $self->dst;

  return "Unknown dstsvc" unless $self->dstsvc_acct || ! $self->dstsvc;

  if ( $self->dst ) {
    $self->dst =~ /^([\w\.\-]+)\@(([\w\-]+\.)+\w+)$/
       or return "Illegal dst: ". $self->dst;
    $self->dst("$1\@$2");
  } else {
    $self->dst('');
  }

  ''; #no error
}

=item srcsvc_acct

Returns the FS::svc_acct object referenced by the srcsvc column.

=cut

sub srcsvc_acct {
  my $self = shift;
  qsearchs('svc_acct', { 'svcnum' => $self->srcsvc } );
}

=item dstsvc_acct

Returns the FS::svc_acct object referenced by the srcsvc column, or false for
forwards not local to freeside.

=cut

sub dstsvc_acct {
  my $self = shift;
  qsearchs('svc_acct', { 'svcnum' => $self->dstsvc } );
}

=back

=head1 VERSION

$Id: svc_forward.pm,v 1.9 2002-02-11 23:01:01 ivan Exp $

=head1 BUGS

The remote commands should be configurable.

=head1 SEE ALSO

L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>,
L<FS::svc_acct>, L<FS::svc_domain>, L<Net::SSH>, L<ssh>, L<dot-qmail>,
schema.html from the base documentation.

=cut

1;

