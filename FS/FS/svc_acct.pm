package FS::svc_acct;

use strict;
use vars qw( @ISA $nossh_hack $conf $dir_prefix @shells $usernamemin
             $usernamemax $passwordmin $username_letter $username_letterfirst
             $shellmachine $useradd $usermod $userdel $mydomain
             @saltset @pw_set);
use Carp;
use FS::Conf;
use FS::Record qw( qsearch qsearchs fields dbh );
use FS::svc_Common;
use Net::SSH qw(ssh);
use FS::part_svc;
use FS::svc_acct_pop;
use FS::svc_acct_sm;
use FS::cust_main_invoice;
use FS::svc_domain;
use FS::raddb;

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
  if ( $shellmachine ) {
    if ( $conf->exists('shellmachine-useradd') ) {
      $useradd = join("\n", $conf->config('shellmachine-useradd') )
                 || 'cp -pr /etc/skel $dir; chown -R $uid.$gid $dir';
    } else {
      $useradd = 'useradd -d $dir -m -s $shell -u $uid $username';
    }
    if ( $conf->exists('shellmachine-userdel') ) {
      $userdel = join("\n", $conf->config('shellmachine-userdel') )
                 || 'rm -rf $dir';
    } else {
      $userdel = 'userdel $username';
    }
    $usermod = join("\n", $conf->config('shellmachine-usermod') )
               || '[ -d $old_dir ] && mv $old_dir $new_dir || ( '.
                    'chmod u+t $old_dir; mkdir $new_dir; cd $old_dir; '.
                    'find . -depth -print | cpio -pdm $new_dir; '.
                    'chmod u-t $new_dir; chown -R $uid.$gid $new_dir; '.
                    'rm -rf $old_dir'.
                  ')';
  }
  $username_letter = $conf->exists('username-letter');
  $username_letterfirst = $conf->exists('username-letterfirst');
  $mydomain = $conf->config('domain');
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

  %hash = $record->radius_reply;

  %hash = $record->radius_check;

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

=item seconds - 

=item domsvc - svcnum from svc_domain

=item radius_I<Radius_Attribute> - I<Radius-Attribute>

=item domsvc - service number of svc_domain with which to associate

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
username, uid, and dir fields are defined, the command(s) specified in
the shellmachine-useradd configuration are exectued on shellmachine via ssh.
This behaviour can be surpressed by setting $FS::svc_acct::nossh_hack true.
If the shellmachine-useradd configuration file does not exist,

  useradd -d $dir -m -s $shell -u $uid $username

is the default.  If the shellmachine-useradd configuration file exists but
it empty,

  cp -pr /etc/skel $dir; chown -R $uid.$gid $dir

is the default instead.  Otherwise the contents of the file are treated as
a double-quoted perl string, with the following variables available:
$username, $uid, $gid, $dir, and $shell.

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
    if qsearchs( 'svc_acct', { 'username' => $self->username,
                               'domsvc'   => $self->domsvc,
                             } );

  my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $self->svcpart } );
  return "Unknown svcpart" unless $part_svc;
  return "uid in use"
    if $part_svc->part_svc_column('uid')->columnflag ne 'F'
      && qsearchs( 'svc_acct', { 'uid' => $self->uid } )
      && $self->username !~ /^(hyla)?fax$/
    ;

  $error = $self->SUPER::insert;
  return $error if $error;

  my( $username, $uid, $gid, $dir, $shell ) = (
    $self->username,
    $self->uid,
    $self->gid,
    $self->dir,
    $self->shell,
  );
  if ( $username && $uid && $dir && $shellmachine && ! $nossh_hack ) {
    ssh("root\@$shellmachine", eval qq("$useradd") );
  }

  ''; #no error
}

=item delete

Deletes this account from the database.  If there is an error, returns the
error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

If the configuration value (see L<FS::Conf>) shellmachine exists, the
command(s) specified in the shellmachine-userdel configuration file are
executed on shellmachine via ssh.  This behavior can be surpressed by setting
$FS::svc_acct::nossh_hack true.  If the shellmachine-userdel configuration
file does not exist,

  userdel $username

is the default.  If the shellmachine-userdel configuration file exists but
is empty,

  rm -rf $dir

is the default instead.  Otherwise the contents of the file are treated as a
double-quoted perl string, with the following variables available:
$username and $dir.

=cut

sub delete {
  my $self = shift;

  return "Can't delete an account which has (svc_acct_sm) mail aliases!"
    if $self->uid && qsearch( 'svc_acct_sm', { 'domuid' => $self->uid } );

  return "Can't delete an account which is a (svc_forward) source!"
    if qsearch( 'svc_forward', { 'srcsvc' => $self->svcnum } );

  return "Can't delete an account which is a (svc_forward) destination!"
    if qsearch( 'svc_forward', { 'dstsvc' => $self->svcnum } );

  return "Can't delete an account with (svc_www) web service!"
    if qsearch( 'svc_www', { 'usersvc' => $self->usersvc } );

  # what about records in session ?

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  foreach my $cust_main_invoice (
    qsearch( 'cust_main_invoice', { 'dest' => $self->svcnum } )
  ) {
    my %hash = $cust_main_invoice->hash;
    $hash{'dest'} = $self->email;
    my $new = new FS::cust_main_invoice \%hash;
    my $error = $new->replace($cust_main_invoice);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $svc_domain (
    qsearch( 'svc_domain', { 'catchall' => $self->svcnum } )
  ) {
    my %hash = new FS::svc_domain->hash;
    $hash{'catchall'} = '';
    my $new = new FS::svc_domain \%hash;
    my $error = $new->replace($svc_domain);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  my( $username, $dir ) = (
    $self->username,
    $self->dir,
  );
  if ( $username && $shellmachine && ! $nossh_hack ) {
    ssh("root\@$shellmachine", eval qq("$userdel") );
  }

  '';
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If the configuration value (see L<FS::Conf>) shellmachine exists, and the 
dir field has changed, the command(s) specified in the shellmachine-usermod
configuraiton file are executed on shellmachine via ssh.  This behavior can
be surpressed by setting $FS::svc-acct::nossh_hack true.  If the
shellmachine-userdel configuration file does not exist or is empty, :

  [ -d $old_dir ] && mv $old_dir $new_dir || (
    chmod u+t $old_dir;
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

  my ( $old_dir, $new_dir, $uid, $gid ) = (
    $old->getfield('dir'),
    $new->getfield('dir'),
    $new->getfield('uid'),
    $new->getfield('gid'),
  );
  if ( $old_dir && $new_dir && $old_dir ne $new_dir && ! $nossh_hack ) {
    ssh("root\@$shellmachine", eval qq("$usermod") );
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

  my $error = $self->ut_numbern('svcnum')
              || $self->ut_number('domsvc')
  ;
  return $error if $error;

  my $ulen = $usernamemax || $self->dbdef_table->column('username')->length;
  $recref->{username} =~ /^([a-z0-9_\-\.]{$usernamemin,$ulen})$/
    or return "Illegal username";
  $recref->{username} = $1;
  if ( $username_letterfirst ) {
    $recref->{username} =~ /^[a-z]/ or return "Illegal username";
  } elsif ( $username_letter ) {
    $recref->{username} =~ /[a-z]/ or return "Illegal username";
  }

  $recref->{popnum} =~ /^(\d*)$/ or return "Illegal popnum: ".$recref->{popnum};
  $recref->{popnum} = $1;
  return "Unknown popnum" unless
    ! $recref->{popnum} ||
    qsearchs('svc_acct_pop',{'popnum'=> $recref->{popnum} } );

  unless ( $part_svc->part_svc_column('uid')->columnflag eq 'F' ) {

    $recref->{uid} =~ /^(\d*)$/ or return "Illegal uid";
    $recref->{uid} = $1 eq '' ? $self->unique('uid') : $1;

    $recref->{gid} =~ /^(\d*)$/ or return "Illegal gid";
    $recref->{gid} = $1 eq '' ? $recref->{uid} : $1;
    #not all systems use gid=uid
    #you can set a fixed gid in part_svc

    return "Only root can have uid 0"
      if $recref->{uid} == 0 && $recref->{username} ne 'root';

    $error = $self->ut_textn('finger');
    return $error if $error;

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

  unless ( $part_svc->part_svc_column('slipip')->columnflag eq 'F' ) {
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
  } elsif ( $recref->{_password} eq '!!' ) {
    $recref->{_password} = '!!';
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
    #$attrib =~ s/_/\-/g;
    ( $FS::raddb::attrib{lc($attrib)}, $self->getfield($column) );
  } grep { /^radius_/ && $self->getfield($_) } fields( $self->table );
}

=item radius_check

Returns key/value pairs, suitable for assigning to a hash, for any RADIUS
check attributes of this record.

Accessing RADIUS attributes directly is not supported and will break in the
future.

=cut

sub radius_check {
  my $self = shift;
  map {
    /^(rc_(.*))$/;
    my($column, $attrib) = ($1, $2);
    #$attrib =~ s/_/\-/g;
    ( $FS::raddb::attrib{lc($attrib)}, $self->getfield($column) );
  } grep { /^rc_/ && $self->getfield($_) } fields( $self->table );
}

=item domain

Returns the domain associated with this account.

=cut

sub domain {
  my $self = shift;
  if ( $self->domsvc ) {
    my $svc_domain = qsearchs( 'svc_domain', { 'svcnum' => $self->domsvc } )
      or die "no svc_domain.svcnum for svc_acct.domsvc ". $self->domsvc;
    $svc_domain->domain;
  } else {
    $mydomain or die "svc_acct.domsvc is null and no legacy domain config file";
  }
}

=item email

Returns an email address associated with the account.

=cut

sub email {
  my $self = shift;
  $self->username. '@'. $self->domain;
}

=back

=head1 VERSION

$Id: svc_acct.pm,v 1.33 2001-09-07 20:26:33 ivan Exp $

=head1 BUGS

The bits which ssh should fork before doing so (or maybe queue jobs for a
daemon).

The $recref stuff in sub check should be cleaned up.

The suspend, unsuspend and cancel methods update the database, but not the
current object.  This is probably a bug as it's unexpected and
counterintuitive.

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>,
L<FS::part_svc>, L<FS::cust_pkg>, L<Net::SSH>, L<ssh>, L<FS::svc_acct_pop>,
schema.html from the base documentation.

=cut

1;

