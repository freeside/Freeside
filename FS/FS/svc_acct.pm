package FS::svc_acct;

use strict;
use vars qw( @ISA $nossh_hack $conf $dir_prefix @shells $usernamemin
             $usernamemax $passwordmin
             $shellmachine @saltset @pw_set);
use Carp;
use FS::Conf;
use FS::Record qw( qsearchs fields );
use FS::svc_Common;
use FS::SSH qw(ssh);
use FS::part_svc;
use FS::svc_acct_pop;

@ISA = qw( FS::svc_Common );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::svc_acct'} = sub { 
  $conf = new FS::Conf;
  $dir_prefix = $conf->config('home');
  @shells = $conf->config('shells');
  $shellmachine = $conf->config('shellmachine');
  $usernamemin = $conf->config('usernamemin') || 2;
  $usernamemax = $conf->config('usernamemax');
  $passwordmin = $conf->config('passwordmin') || 6;
};

@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );
@pw_set = ( 'a'..'z', 'A'..'Z', '0'..'9', '(', ')', '#', '!', '.', ',' );

#not needed in 5.004 #srand($$|time);

=head1 NAME

FS::svc_acct - Object methods for svc_acct records

=head1 SYNOPSIS

  use FS::svc_acct;

  $record = new FS::svc_acct \%hash;
  $record = new FS::svc_acct { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

  %hash = $record->radius;

=head1 DESCRIPTION

An FS::svc_acct object represents an account.  FS::svc_acct inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatcially for new accounts)

=item username

=item _password - generated if blank

=item popnum - Point of presence (see L<FS::svc_acct_pop>)

=item uid

=item gid

=item finger - GECOS

=item dir - set automatically if blank (and uid is not)

=item shell

=item quota - (unimplementd)

=item slipip - IP address

=item radius_I<Radius_Attribute> - I<Radius-Attribute>

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new account.  To add the account to the database, see L<"insert">.

=cut

sub table { 'svc_acct'; }

=item insert

Adds this account to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

If the configuration value (see L<FS::Conf>) shellmachine exists, and the 
username, uid, and dir fields are defined, the command

  useradd -d $dir -m -s $shell -u $uid $username

is executed on shellmachine via ssh.  This behaviour can be surpressed by
setting $FS::svc_acct::nossh_hack true.

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

  return "Username ". $self->username. " in use"
    if qsearchs( 'svc_acct', { 'username' => $self->username } );

  my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );
  return "Unkonwn svcpart" unless $part_svc;
  return "uid in use"
    if $part_svc->svc_acct__uid_flag ne 'F'
      && qsearchs( 'svc_acct', { 'uid' => $self->uid } )
      && $self->username !~ /^(hyla)?fax$/
    ;

  $error = $self->SUPER::insert;
  return $error if $error;

  my ( $username, $uid, $dir, $shell ) = (
    $self->username,
    $self->uid,
    $self->dir,
    $self->shell,
  );
  if ( $username 
       && $uid
       && $dir
       && $shellmachine
       && ! $nossh_hack ) {
    #one way
    ssh("root\@$shellmachine",
        "useradd -d $dir -m -s $shell -u $uid $username"
    );
    #another way
    #ssh("root\@$shellmachine","/bin/mkdir $dir; /bin/chmod 711 $dir; ".
    #  "/bin/cp -p /etc/skel/.* $dir 2>/dev/null; ".
    #  "/bin/cp -pR /etc/skel/Maildir $dir 2>/dev/null; ".
    #  "/bin/chown -R $uid $dir") unless $nossh_hack;
  }

  ''; #no error
}

=item delete

Deletes this account from the database.  If there is an error, returns the
error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

If the configuration value (see L<FS::Conf>) shellmachine exists, the command:

  userdel $username

is executed on shellmachine via ssh.  This behaviour can be surpressed by
setting $FS::svc_acct::nossh_hack true.

=cut

sub delete {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  $error = $self->SUPER::delete;
  return $error if $error;

  my $username = $self->username;
  if ( $username && $shellmachine && ! $nossh_hack ) {
    ssh("root\@$shellmachine","userdel $username");
  }

  '';
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If the configuration value (see L<FS::Conf>) shellmachine exists, and the 
dir field has changed, the command:

  [ -d $old_dir ] && (
    chmod u+t $old_dir;
    umask 022;
    mkdir $new_dir;
    cd $old_dir;
    find . -depth -print | cpio -pdm $new_dir;
    chmod u-t $new_dir;
    chown -R $uid.$gid $new_dir;
    rm -rf $old_dir
  )

is executed on shellmachine via ssh.  This behaviour can be surpressed by
setting $FS::svc_acct::nossh_hack true.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );
  my $error;

  return "Username in use"
    if $old->username ne $new->username &&
      qsearchs( 'svc_acct', { 'username' => $new->username } );

  return "Can't change uid!" if $old->uid != $new->uid;

  #change homdir when we change username
  $new->setfield('dir', '') if $old->username ne $new->username;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  $error = $new->SUPER::replace($old);
  return $error if $error;

  my ( $old_dir, $new_dir ) = ( $old->getfield('dir'), $new->getfield('dir') );
  my ( $uid, $gid) = ( $new->getfield('uid'), $new->getfield('gid') );
  if ( $old_dir
       && $new_dir
       && $old_dir ne $new_dir
       && ! $nossh_hack
  ) {
    ssh("root\@$shellmachine","[ -d $old_dir ] && ".
                 "( chmod u+t $old_dir; ". #turn off qmail delivery
                 "umask 022; mkdir $new_dir; cd $old_dir; ".
                 "find . -depth -print | cpio -pdm $new_dir; ".
                 "chmod u-t $new_dir; chown -R $uid.$gid $new_dir; ".
                 "rm -rf $old_dir". 
                 ")"
    );
  }

  ''; #no error
}

=item suspend

Suspends this account by prefixing *SUSPENDED* to the password.  If there is an
error, returns the error, otherwise returns false.

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub suspend {
  my $self = shift;
  my %hash = $self->hash;
  unless ( $hash{_password} =~ /^\*SUSPENDED\* / ) {
    $hash{_password} = '*SUSPENDED* '.$hash{_password};
    my $new = new FS::svc_acct ( \%hash );
    $new->replace($self);
  } else {
    ''; #no error (already suspended)
  }
}

=item unsuspend

Unsuspends this account by removing *SUSPENDED* from the password.  If there is
an error, returns the error, otherwise returns false.

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub unsuspend {
  my $self = shift;
  my %hash = $self->hash;
  if ( $hash{_password} =~ /^\*SUSPENDED\* (.*)$/ ) {
    $hash{_password} = $1;
    my $new = new FS::svc_acct ( \%hash );
    $new->replace($self);
  } else {
    ''; #no error (already unsuspended)
  }
}

=item cancel

Just returns false (no error) for now.

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid service.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

Sets any fixed values; see L<FS::part_svc>.

=cut

sub check {
  my $self = shift;

  my($recref) = $self->hashref;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my $ulen = $usernamemax || $self->dbdef_table->column('username')->length;
  $recref->{username} =~ /^([a-z0-9_\-\.]{$usernamemin,$ulen})$/
    or return "Illegal username";
  $recref->{username} = $1;
  $recref->{username} =~ /[a-z]/ or return "Illegal username";

  $recref->{popnum} =~ /^(\d*)$/ or return "Illegal popnum: ".$recref->{popnum};
  $recref->{popnum} = $1;
  return "Unkonwn popnum" unless
    ! $recref->{popnum} ||
    qsearchs('svc_acct_pop',{'popnum'=> $recref->{popnum} } );

  unless ( $part_svc->getfield('svc_acct__uid_flag') eq 'F' ) {

    $recref->{uid} =~ /^(\d*)$/ or return "Illegal uid";
    $recref->{uid} = $1 eq '' ? $self->unique('uid') : $1;

    $recref->{gid} =~ /^(\d*)$/ or return "Illegal gid";
    $recref->{gid} = $1 eq '' ? $recref->{uid} : $1;
    #not all systems use gid=uid
    #you can set a fixed gid in part_svc

    return "Only root can have uid 0"
      if $recref->{uid} == 0 && $recref->{username} ne 'root';

    my($error);
    return $error if $error=$self->ut_textn('finger');

    $recref->{dir} =~ /^([\/\w\-]*)$/
      or return "Illegal directory";
    $recref->{dir} = $1 || 
      $dir_prefix . '/' . $recref->{username}
      #$dir_prefix . '/' . substr($recref->{username},0,1). '/' . $recref->{username}
    ;

    unless ( $recref->{username} eq 'sync' ) {
      if ( grep $_ eq $recref->{shell}, @shells ) {
        $recref->{shell} = (grep $_ eq $recref->{shell}, @shells)[0];
      } else {
        return "Illegal shell \`". $self->shell. "\'; ".
               $conf->dir. "/shells contains: @shells";
      }
    } else {
      $recref->{shell} = '/bin/sync';
    }

    $recref->{quota} =~ /^(\d*)$/ or return "Illegal quota (unimplemented)";
    $recref->{quota} = $1;

  } else {
    $recref->{gid} ne '' ? 
      return "Can't have gid without uid" : ( $recref->{gid}='' );
    $recref->{finger} ne '' ? 
      return "Can't have finger-name without uid" : ( $recref->{finger}='' );
    $recref->{dir} ne '' ? 
      return "Can't have directory without uid" : ( $recref->{dir}='' );
    $recref->{shell} ne '' ? 
      return "Can't have shell without uid" : ( $recref->{shell}='' );
    $recref->{quota} ne '' ? 
      return "Can't have quota without uid" : ( $recref->{quota}='' );
  }

  unless ( $part_svc->getfield('svc_acct__slipip_flag') eq 'F' ) {
    unless ( $recref->{slipip} eq '0e0' ) {
      $recref->{slipip} =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/
        or return "Illegal slipip". $self->slipip;
      $recref->{slipip} = $1;
    } else {
      $recref->{slipip} = '0e0';
    }

  }

  #arbitrary RADIUS stuff; allow ut_textn for now
  foreach ( grep /^radius_/, fields('svc_acct') ) {
    $self->ut_textn($_);
  }

  #generate a password if it is blank
  $recref->{_password} = join('',map($pw_set[ int(rand $#pw_set) ], (0..7) ) )
    unless ( $recref->{_password} );

  #if ( $recref->{_password} =~ /^((\*SUSPENDED\* )?)([^\t\n]{4,16})$/ ) {
  if ( $recref->{_password} =~ /^((\*SUSPENDED\* )?)([^\t\n]{$passwordmin,8})$/ ) {
    $recref->{_password} = $1.$3;
    #uncomment this to encrypt password immediately upon entry, or run
    #bin/crypt_pw in cron to give new users a window during which their
    #password is available to techs, for faxing, etc.  (also be aware of 
    #radius issues!)
    #$recref->{password} = $1.
    #  crypt($3,$saltset[int(rand(64))].$saltset[int(rand(64))]
    #;
  } elsif ( $recref->{_password} =~ /^((\*SUSPENDED\* )?)([\w\.\/\$]{13,34})$/ ) {
    $recref->{_password} = $1.$3;
  } elsif ( $recref->{_password} eq '*' ) {
    $recref->{_password} = '*';
  } else {
    return "Illegal password";
  }

  ''; #no error
}

=item radius

Depriciated, use radius_reply instead.

=cut

sub radius {
  carp "FS::svc_acct::radius depriciated, use radius_reply";
  $_[0]->radius_reply;
}

=item radius_reply

Returns key/value pairs, suitable for assigning to a hash, for any RADIUS
reply attributes of this record.

Note that this is now the preferred method for reading RADIUS attributes - 
accessing the columns directly is discouraged, as the column names are
expected to change in the future.

=cut

sub radius_reply { 
  my $self = shift;
  map {
    /^(radius_(.*))$/;
    my($column, $attrib) = ($1, $2);
    $attrib =~ s/_/\-/g;
    ( $attrib, $self->getfield($column) );
  } grep { /^radius_/ && $self->getfield($_) } fields( $self->table );
}

=item radius_check

Returns key/value pairs, suitable for assigning to a hash, for any RADIUS
check attributes of this record.

Accessing RADIUS attributes directly is not supported and will break in the
future.

=back

sub radius_check {
  my $self = shift;
  map {
    /^(rc_(.*))$/;
    my($column, $attrib) = ($1, $2);
    $attrib =~ s/_/\-/g;
    ( $attrib, $self->getfield($column) );
  } grep { /^rc_/ && $self->getfield($_) } fields( $self->table );
}

=head1 VERSION

$Id: svc_acct.pm,v 1.9 2000-07-06 08:57:27 ivan Exp $

=head1 BUGS

The remote commands should be configurable.

The bits which ssh should fork before doing so.

The $recref stuff in sub check should be cleaned up.

The suspend, unsuspend and cancel methods update the database, but not the
current object.  This is probably a bug as it's unexpected and
counterintuitive.

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>,
L<FS::part_svc>, L<FS::cust_pkg>, L<FS::SSH>, L<ssh>, L<FS::svc_acct_pop>,
schema.html from the base documentation.

=cut

1;

