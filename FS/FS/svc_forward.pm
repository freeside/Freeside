package FS::svc_forward;

use strict;
use vars qw( @ISA $nossh_hack $conf $shellmachine @qmailmachines
             @vpopmailmachines );
use Net::SSH qw(ssh);
use FS::Conf;
use FS::Record qw( fields qsearch qsearchs dbh );
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

  [ -d $vpopdir/domains/$domain/$source ] && {
    echo "$destination" >> $vpopdir/domains/$domain/$username/.$qmail
    chown $vpopuid:$vpopgid $vpopdir/domains/$domain/$username/.$qmail
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

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->check;
  return $error if $error;

  $error = $self->SUPER::insert;
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $self->srcsvc } );
  my $username = $svc_acct->username;
  my $domain = $svc_acct->domain;
  my $destination;
  if ($self->dstsvc) {
    $destination = $self->dstsvc_acct->email;
  } else {
    $destination = $self->dst;
  }
    
  foreach my $vpopmailmachine ( @vpopmailmachines ) {
    my($machine, $vpopdir, $vpopuid, $vpopgid) = split(/\s+/, $vpopmailmachine);
    my $queue = new FS::queue { 'job' => 'Net::SSH::ssh_cmd' };  # should be neater
    my $error = $queue->insert("root\@$machine","[ -d $vpopdir/domains/$domain/$username ] && { echo \"$destination\" >> $vpopdir/domains/$domain/$username/.qmail; chown $vpopuid:$vpopgid $vpopdir/domains/$domain/$username/.qmail; }") 
      unless $nossh_hack;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "queueing job (transaction rolled back): $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  ''; #no error

}

=item delete

Deletes this mail forwarding alias from the database.  If there is an error,
returns the error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

If the configuration value vpopmailmachines exists, then the command:

  { sed -e '/^$destination/d' < 
      $vpopdir/domains/$srcdomain/$srcusername/.qmail >
      $vpopdir/domains/$srcdomain/$srcusername/.qmail.temp;
    mv $vpopdir/domains/$srcdomain/$srcusername/.qmail.temp
      $vpopdir/domains/$srcdomain/$srcusername/.qmail;
    chown $vpopuid.$vpopgid $vpopdir/domains/$srcdomain/$srcusername/.qmail; }
    

is executed on each vpopmailmachine via ssh.  This behaviour can be supressed
by setting $FS::svc_forward_nossh_hack true.

=cut

sub delete {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::Autocommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $svc_acct = $self->srcsvc_acct;
  my $username = $svc_acct->username;
  my $domain = $svc_acct->domain;
  my $destination;
  if ($self->dstsvc) {
    $destination = $self->dstsvc_acct->email;
  } else {
    $destination = $self->dst;
  }
  foreach my $vpopmailmachine ( @vpopmailmachines ) {
    my($machine, $vpopdir, $vpopuid, $vpopgid) =
      split(/\s+/, $vpopmailmachine);
    my $queue = new FS::queue { 'job' => 'Net::SSH::ssh_cmd' };  # should be neater
    my $error = $queue->insert("root\@$machine",
      "sed -e '/^$destination/d' " .
        "< $vpopdir/domains/$domain/$username/.qmail" .
        "> $vpopdir/domains/$domain/$username/.qmail.temp; " .
      "mv $vpopdir/domains/$domain/$username/.qmail.temp " .
        "$vpopdir/domains/$domain/$username/.qmail; " .
      "chown $vpopuid.$vpopgid $vpopdir/domains/$domain/$username/.qmail;"
    )
      unless $nossh_hack;

    if ($error ) {
      $dbh->rollback if $oldAutoCommit;
      return "queueing job (transaction rolled back): $error";
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}


=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If the configuration value vpopmailmachines exists, then the command:

  { sed -e '/^$destination/d' < 
      $vpopdir/domains/$srcdomain/$srcusername/.qmail >
      $vpopdir/domains/$srcdomain/$srcusername/.qmail.temp;
    mv $vpopdir/domains/$srcdomain/$srcusername/.qmail.temp
      $vpopdir/domains/$srcdomain/$srcusername/.qmail; 
    chown $vpopuid.$vpopgid $vpopdir/domains/$srcdomain/$srcusername/.qmail; }
    

is executed on each vpopmailmachine via ssh.  This behaviour can be supressed
by setting $FS::svc_forward_nossh_hack true.

Also, if the configuration value vpopmailmachines exists, then the command:

  [ -d $vpopdir/domains/$domain/$source ] && {
    echo "$destination" >> $vpopdir/domains/$domain/$username/.$qmail
    chown $vpopuid:$vpopgid $vpopdir/domains/$domain/$username/.$qmail
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

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $new->SUPER::replace($old);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $old_svc_acct = $old->srcsvc_acct;
  my $old_username = $old_svc_acct->username;
  my $old_domain = $old_svc_acct->domain;
  my $destination;
  if ($old->dstsvc) {
    $destination = $old->dstsvc_acct->email;
  } else {
    $destination = $old->dst;
  }
  foreach my $vpopmailmachine ( @vpopmailmachines ) {
    my($machine, $vpopdir, $vpopuid, $vpopgid) =
      split(/\s+/, $vpopmailmachine);
    my $queue = new FS::queue { 'job' => 'Net::SSH::ssh_cmd' };  # should be neater
    my $error = $queue->insert("root\@$machine",
      "sed -e '/^$destination/d' " .
        "< $vpopdir/domains/$old_domain/$old_username/.qmail" .
        "> $vpopdir/domains/$old_domain/$old_username/.qmail.temp; " .
      "mv $vpopdir/domains/$old_domain/$old_username/.qmail.temp " .
        "$vpopdir/domains/$old_domain/$old_username/.qmail; " .
      "chown $vpopuid.$vpopgid " .
        "$vpopdir/domains/$old_domain/$old_username/.qmail;"
    )
      unless $nossh_hack;

    if ( $error ) {
       $dbh->rollback if $oldAutoCommit;
       return "queueing job (transaction rolled back): $error";
    }
  }

  #false laziness with stuff in insert, should subroutine
  my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $new->srcsvc } );
  my $username = $svc_acct->username;
  my $domain = $svc_acct->domain;
  if ($new->dstsvc) {
    $destination = $new->dstsvc_acct->email;
  } else {
    $destination = $new->dst;
  }
  
  foreach my $vpopmailmachine ( @vpopmailmachines ) {
    my($machine, $vpopdir, $vpopuid, $vpopgid) = split(/\s+/, $vpopmailmachine);
    my $queue = new FS::queue { 'job' => 'Net::SSH::ssh_cmd' };  # should be neater
    my $error = $queue->insert("root\@$machine","[ -d $vpopdir/domains/$domain/$username ] && { echo \"$destination\" >> $vpopdir/domains/$domain/$username/.qmail; chown $vpopuid:$vpopgid $vpopdir/domains/$domain/$username/.qmail; }") 
      unless $nossh_hack;
    if ( $error ) {
       $dbh->rollback if $oldAutoCommit;
       return "queueing job (transaction rolled back): $error";
    }
  }
  #end subroutinable bits

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
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

  #return "Unknown dstsvc: $dstsvc" unless $self->dstsvc_acct || ! $self->dstsvc;
  return "Unknown dstsvc"
    unless qsearchs('svc_acct', { 'svcnum' => $self->dstsvc } )
           || ! $self->dstsvc;


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

$Id: svc_forward.pm,v 1.10 2002-02-17 19:07:32 jeff Exp $

=head1 BUGS

The remote commands should be configurable.

=head1 SEE ALSO

L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>,
L<FS::svc_acct>, L<FS::svc_domain>, L<Net::SSH>, L<ssh>, L<dot-qmail>,
schema.html from the base documentation.

=cut

1;

