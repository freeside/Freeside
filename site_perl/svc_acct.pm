package FS::svc_acct;

use strict;
use vars qw(@ISA @EXPORT_OK $nossh_hack $conf $dir_prefix @shells
            $shellmachine @saltset @pw_set);
use Exporter;
use FS::Conf;
use FS::Record qw(fields qsearchs);
use FS::SSH qw(ssh);
use FS::cust_svc;

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(fields);

$conf = new FS::Conf;
$dir_prefix = $conf->config('home');
@shells = $conf->config('shells');
$shellmachine = $conf->config('shellmachine');

@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );
@pw_set = ( 'a'..'z', 'A'..'Z', '0'..'9', '(', ')', '#', '!', '.', ',' );

#not needed in 5.004 #srand($$|time);

=head1 NAME

FS::svc_acct - Object methods for svc_acct records

=head1 SYNOPSIS

  use FS::svc_acct;

  $record = create FS::svc_acct \%hash;
  $record = create FS::svc_acct { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_acct object represents an account.  FS::svc_acct inherits from
FS::Record.  The following fields are currently supported:

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

=item create HASHREF

Creates a new account.  To add the account to the database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('svc_acct')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('svc_acct',$hashref);

}

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
  my($self)=@_;
  my($error);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  $error=$self->check;
  return $error if $error;

  return "Username ". $self->username. " in use"
    if qsearchs('svc_acct',{'username'=> $self->username } );

  my($part_svc) = qsearchs('part_svc',{ 'svcpart' => $self->svcpart });
  return "Unkonwn svcpart" unless $part_svc;
  return "uid in use"
    if $part_svc->svc_acct__uid_flag ne 'F'
      && qsearchs('svc_acct',{'uid'=> $self->uid } )
      && $self->username !~ /^(hyla)?fax$/
    ;

  my($svcnum)=$self->svcnum;
  my($cust_svc);
  unless ( $svcnum ) {
    $cust_svc=create FS::cust_svc ( {
      'svcnum'  => $svcnum,
      'pkgnum'  => $self->pkgnum,
      'svcpart' => $self->svcpart,
    } );
    my($error) = $cust_svc->insert;
    return $error if $error;
    $svcnum = $self->svcnum($cust_svc->svcnum);
  }

  $error = $self->add;
  if ($error) {
    #$cust_svc->del if $cust_svc;
    $cust_svc->delete if $cust_svc;
    return $error;
  }

  my($username,$uid,$dir,$shell) = (
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
  my($self)=@_;
  my($error);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  my($svcnum)=$self->getfield('svcnum');

  $error = $self->del;
  return $error if $error;

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum});  
  $error = $cust_svc->del;
  return $error if $error;

  my($username) = $self->getfield('username');
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
  my($new,$old)=@_;
  my($error);

  return "(Old) Not a svc_acct record!" unless $old->table eq "svc_acct";
  return "Can't change svcnum!"
    unless $old->getfield('svcnum') eq $new->getfield('svcnum');

  return "Username in use"
    if $old->getfield('username') ne $new->getfield('username') &&
      qsearchs('svc_acct',{'username'=> $new->getfield('username') } );

  return "Can't change uid!"
    if $old->getfield('uid') ne $new->getfield('uid');

  #change homdir when we change username
  if ( $old->getfield('username') ne $new->getfield('username') ) {
    $new->setfield('dir','');
  }

  $error=$new->check;
  return $error if $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  $error = $new->rep($old);
  return $error if $error;

  my($old_dir,$new_dir)=( $old->getfield('dir'),$new->getfield('dir') );
  my($uid,$gid)=( $new->getfield('uid'), $new->getfield('gid') );
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
  my($old) = @_;
  my(%hash) = $old->hash;
  unless ( $hash{_password} =~ /^\*SUSPENDED\* / ) {
    $hash{_password} = '*SUSPENDED* '.$hash{_password};
    my($new) = create FS::svc_acct ( \%hash );
#    $new->replace($old);
    $new->rep($old); #to avoid password checking :)
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
  my($old) = @_;
  my(%hash) = $old->hash;
  if ( $hash{_password} =~ /^\*SUSPENDED\* (.*)$/ ) {
    $hash{_password} = $1;
    my($new) = create FS::svc_acct ( \%hash );
#    $new->replace($old);
    $new->rep($old); #to avoid password checking :)
  } else {
    ''; #no error (already unsuspended)
  }
}

=item cancel

Just returns false (no error) for now.

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

# Usage: $error = $record -> cancel;
sub cancel {
  ''; #stub (no error) - taken care of in delete
}

=item check

Checks all fields to make sure this is a valid service.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

Sets any fixed values; see L<FS::part_svc>.

=cut

sub check {
  my($self)=@_;
  return "Not a svc_acct record!" unless $self->table eq "svc_acct";
  my($recref) = $self->hashref;

  $recref->{svcnum} =~ /^(\d*)$/ or return "Illegal svcnum";
  $recref->{svcnum} = $1;

  #get part_svc
  my($svcpart);
  my($svcnum)=$self->getfield('svcnum');
  if ($svcnum) {
    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum});
    return "Unknown svcnum" unless $cust_svc; 
    $svcpart=$cust_svc->svcpart;
  } else {
    $svcpart=$self->getfield('svcpart');
  }
  my($part_svc)=qsearchs('part_svc',{'svcpart'=>$svcpart});
  return "Unkonwn svcpart" unless $part_svc;

  #set fixed fields from part_svc
  my($field);
  foreach $field ( fields('svc_acct') ) {
    if ( $part_svc->getfield('svc_acct__'. $field. '_flag') eq 'F' ) {
      $self->setfield($field,$part_svc->getfield('svc_acct__'. $field) );
    }
  }

  my($ulen)=$self->dbdef_table->column('username')->length;
  $recref->{username} =~ /^([a-z0-9_\-]{2,$ulen})$/
    or return "Illegal username";
  $recref->{username} = $1;
  $recref->{username} =~ /[a-z]/ or return "Illegal username";

  $recref->{popnum} =~ /^(\d*)$/ or return "Illegal popnum";
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
      my($shell);
      if ( $shell = (grep $_ eq $recref->{shell}, @shells)[0] ) {
        $recref->{shell} = $shell;
      } else {
        return "Illegal shell ". $self->shell;
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
  if ( $recref->{_password} =~ /^((\*SUSPENDED\* )?)([^\t\n]{4,8})$/ ) {
    $recref->{_password} = $1.$3;
    #uncomment this to encrypt password immediately upon entry, or run
    #bin/crypt_pw in cron to give new users a window during which their
    #password is available to techs, for faxing, etc.  (also be aware of 
    #radius issues!)
    #$recref->{password} = $1.
    #  crypt($3,$saltset[int(rand(64))].$saltset[int(rand(64))]
    #;
  } elsif ( $recref->{_password} =~ /^((\*SUSPENDED\* )?)([\w\.\/]{13,24})$/ ) {
    $recref->{_password} = $1.$3;
  } elsif ( $recref->{_password} eq '*' ) {
    $recref->{_password} = '*';
  } else {
    return "Illegal password";
  }

  ''; #no error
}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

The remote commands should be configurable.

The create method should set defaults from part_svc (like the check method
sets fixed values).

=head1 SEE ALSO

L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>,
L<FS::SSH>, L<ssh>, L<FS::svc_acct_pop>, schema.html from the base
documentation.

=head1 HISTORY

ivan@voicenet.com 97-jul-16 - 21

rewrite (among other things, now know about part_svc) ivan@sisd.com 98-mar-8

Changed 'password' to '_password' because Pg6.3 reserves the password word
	bmccane@maxbaud.net	98-apr-3

username length and shell no longer hardcoded ivan@sisd.com 98-jun-28

eww but needed: ignore uid duplicates for 'fax' and 'hylafax'
ivan@sisd.com 98-jun-29

$nossh_hack ivan@sisd.com 98-jul-13

protections against UID/GID of 0 for incorrectly-setup RDBMSs (also
in bin/svc_acct.export) ivan@sisd.com 98-jul-13

arbitrary radius attributes ivan@sisd.com 98-aug-13

/var/spool/freeside/conf/shellmachine ivan@sisd.com 98-aug-13

pod and FS::conf ivan@sisd.com 98-sep-22

=cut

1;

