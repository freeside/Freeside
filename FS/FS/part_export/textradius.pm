package FS::part_export::textradius;

use vars qw(@ISA $prefix);
use Fcntl qw(:flock);
use FS::UID qw(datasrc);
use FS::part_export;

@ISA = qw(FS::part_export);

$prefix = "/usr/local/etc/freeside/export.";

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);
  $err_or_queue = $self->textradius_queue( $svc_acct->svcnum, 'insert',
    $svc_acct->username, $svc_acct->radius_check, '-', $svc_acct->radius_reply);
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't (yet?) change username with textradius"
    if $old->username ne $new->username;
  #return '' unless $old->_password ne $new->_password;
  $err_or_queue = $self->textradius_queue( $new->svcnum, 'insert',
    $new->username, $new->radius_check, '-', $new->radius_reply);
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $err_or_queue = $self->textradius_queue( $svc_acct->svcnum, 'delete',
    $svc_acct->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

#a good idea to queue anything that could fail or take any time
sub textradius_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::textradius::textradius_$method",
  };
  $queue->insert(
    $self->option('user')||'root',
    $self->machine,
    $self->option('users'),
    @_,
  ) or $queue;
}

sub textradius_insert { #subroutine, not method
  my( $user, $host, $users, $username, @attributes ) = @_;

  #silly arg processing
  my($att, @check);
  push @check, $att while @attributes && ($att=shift @attributes) ne '-';
  my %check = @check;
  my %reply = @attributes;

  my $file = textradius_download($user, $host, $users);

  eval "use RADIUS::UserFile;";
  die $@ if $@;

  my $userfile = new RADIUS::UserFile(
    File        => $file,
    Who         => [ $username ],
    Check_Items => [ keys %check ],
  ) or die "error parsing $file";

  $userfile->remove($username);
  $userfile->add(
    Who        => $username,
    Attributes => { %check, %reply },
    Comment    => 'user added by Freeside',
  ) or die "error adding to $file";

  $userfile->update( Who => [ $username ] )
    or die "error updating $file";

  textradius_upload($user, $host, $users);

}

sub textradius_delete { #subroutine, not method
  my( $user, $host, $users, $username ) = @_;

  my $file = textradius_download($user, $host, $users);

  eval "use RADIUS::UserFile;";
  die $@ if $@;

  my $userfile = new RADIUS::UserFile(
    File        => $file,
    Who         => [ $username ],
  ) or die "error parsing $file";

  $userfile->remove($username);

  $userfile->update( Who => [ $username ] )
    or die "error updating $file";

  textradius_upload($user, $host, $users);
}

sub textradius_download {
  my( $user, $host, $users ) = @_;

  my $dir = $prefix. datasrc;
  mkdir $dir, 0700 or die $! unless -d $dir;
  $dir .= "/$host";
  mkdir $dir, 0700 or die $! unless -d $dir;

  my $dest = "$dir/users";

  eval "use File::Rsync;";
  die $@ if $@;
  my $rsync = File::Rsync->new({ rsh => 'ssh' });

  open(LOCK, "+>>$dest.lock")
    and flock(LOCK,LOCK_EX)
      or die "can't open $dest.lock: $!";

  $rsync->exec( {
    src  => "$user\@$host:$users",
    dest => $dest,
  } ); # true/false return value from exec is not working, alas
  if ( $rsync->err ) {
    die "error downloading $user\@$host:$users : ".
        'exit status: '. $rsync->status. ', '.
        'STDERR: '. join(" / ", $rsync->err). ', '.
        'STDOUT: '. join(" / ", $rsync->out);
  }

  $dest;
}

sub textradius_upload {
  my( $user, $host, $users ) = @_;

  my $dir = $prefix. datasrc. "/$host";

  eval "use File::Rsync;";
  die $@ if $@;
  my $rsync = File::Rsync->new({
    rsh => 'ssh',
    #dry_run => 1,
  });
  $rsync->exec( {
    src  => "$dir/users",
    dest => "$user\@$host:$users",
  } ); # true/false return value from exec is not working, alas
  if ( $rsync->err ) {
    die "error uploading to $user\@$host:$users : ".
        'exit status: '. $rsync->status. ', '.
        'STDERR: '. join(" / ", $rsync->err). ', '.
        'STDOUT: '. join(" / ", $rsync->out);
  }

  flock(LOCK,LOCK_UN);
  close LOCK;

}

