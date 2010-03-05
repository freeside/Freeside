package FS::part_export::vpopmail;

use vars qw(@ISA %info @saltset $exportdir);
use Fcntl qw(:flock);
use Tie::IxHash;
use File::Path;
use FS::UID qw( datasrc );
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  #'machine' => { label=>'vpopmail machine', },
  'dir'     => { label=>'directory', }, # ?more info? default?
  'uid'     => { label=>'vpopmail uid' },
  'gid'     => { label=>'vpopmail gid' },
  'restart' => { label=> 'vpopmail restart command',
                 default=> 'cd /home/vpopmail/domains; for domain in *; do /home/vpopmail/bin/vmkpasswd $domain; done; /var/qmail/bin/qmail-newu; killall -HUP qmail-send',
               },
;

%info = (
  'svc'     => 'svc_acct',
  'desc'    => 'Real-time export to vpopmail text files',
  'options' => \%options,
  'notes'   => <<'END'
This export is currently unmaintained.  See shellcommands_withdomain for an
export that uses vpopmail CLI commands instead.<BR>
<BR>
Real time export to <a href="http://inter7.com/vpopmail/">vpopmail</a> text
files.  <a href="http://search.cpan.org/dist/File-Rsync">File::Rsync</a>
must be installed, and you will need to
<a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.9:Documentation:Administration:SSH_Keys">setup SSH for unattended operation</a>
to <b>vpopmail</b>@<i>export.host</i>. 
END
);

@saltset = ( 'a'..'z' , 'A'..'Z' , '0'..'9' , '.' , '/' );

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);
  $self->vpopmail_queue( $svc_acct->svcnum, 'insert',
    $svc_acct->username,
    crypt($svc_acct->_password,$saltset[int(rand(64))].$saltset[int(rand(64))]),
    $svc_acct->domain,
    $svc_acct->quota,
    $svc_acct->finger,
  );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);

  my $cpassword = crypt(
    $new->_password, $saltset[int(rand(64))].$saltset[int(rand(64))]
  );

  return "can't change username with vpopmail"
    if $old->username ne $new->username;

  #no.... if mail can't be preserved, better to disallow username changes
  #if ($old->username ne $new->username || $old->domain ne $new->domain ) {
  #  vpopmail_queue( $svc_acct->svcnum, 'delete', 
  #    $old->username, $old->domain
  #  );
  #  vpopmail_queue( $svc_acct->svcnum, 'insert', 
  #    $new->username,
  #    $cpassword,
  #    $new->domain,
  #  );

  return '' unless $old->_password ne $new->_password;

  $self->vpopmail_queue( $new->svcnum, 'replace',
    $new->username, $cpassword, $new->domain, $new->quota, $new->finger );
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $self->vpopmail_queue( $svc_acct->svcnum, 'delete',
    $svc_acct->username, $svc_acct->domain );
}

#a good idea to queue anything that could fail or take any time
sub vpopmail_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);

  my $exportdir = "%%%FREESIDE_EXPORT%%%/export." . datasrc;
  mkdir $exportdir, 0700 or die $! unless -d $exportdir;
  $exportdir .= "/vpopmail";
  mkdir $exportdir, 0700 or die $! unless -d $exportdir;
  $exportdir .= '/'. $self->machine;
  mkdir $exportdir, 0700 or die $! unless -d $exportdir;
  mkdir "$exportdir/domains", 0700 or die $! unless -d "$exportdir/domains";

  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::vpopmail::vpopmail_$method",
  };
  $queue->insert(
    $exportdir,
    $self->machine,
    $self->option('dir'),
    $self->option('uid'),
    $self->option('gid'),
    $self->option('restart'),
    @_
  );
}

sub vpopmail_insert { #subroutine, not method
  my( $exportdir, $machine, $dir, $uid, $gid, $restart ) = splice @_,0,6;
  my( $username, $password, $domain, $quota, $finger ) = @_;

  mkdir "$exportdir/domains/$domain", 0700 or die $!
    unless -d "$exportdir/domains/$domain";

  (open(VPASSWD, ">>$exportdir/domains/$domain/vpasswd")
    and flock(VPASSWD,LOCK_EX)
  ) or die "can't open vpasswd file for $username\@$domain: ".
           "$exportdir/domains/$domain/vpasswd: $!";
  print VPASSWD join(":",
    $username,
    $password,
    '1',
    '0',
    $finger,
    "$dir/domains/$domain/$username",
    $quota ? $quota.'S' : 'NOQUOTA',
  ), "\n";

  flock(VPASSWD,LOCK_UN);
  close(VPASSWD);

  for my $mkdir (
    grep { ! -d $_ } map { "$exportdir/domains/$domain/$username$_" }
        ( '', qw( /Maildir /Maildir/cur /Maildir/new /Maildir/tmp ) )
  ) {
    mkdir $mkdir, 0700 or die "can't mkdir $mkdir: $!";
  }

  vpopmail_sync( $exportdir, $machine, $dir, $uid, $gid, $restart );

}

sub vpopmail_replace { #subroutine, not method
  my( $exportdir, $machine, $dir, $uid, $gid, $restart ) = splice @_,0,6;
  my( $username, $password, $domain, $quota, $finger ) = @_;
  
  (open(VPASSWD, "$exportdir/domains/$domain/vpasswd")
    and flock(VPASSWD,LOCK_EX)
  ) or die "can't open $exportdir/domains/$domain/vpasswd: $!";

  open(VPASSWDTMP, ">$exportdir/domains/$domain/vpasswd.tmp")
    or die "Can't open $exportdir/domains/$domain/vpasswd.tmp: $!";

  while (<VPASSWD>) {
    my ($mailbox, $pw, $vuid, $vgid, $vfinger, $vdir, $vquota, @rest) =
      split(':', $_);
    if ( $username ne $mailbox ) {
      print VPASSWDTMP $_;
      next
    }
    print VPASSWDTMP join (':',
      $mailbox,
      $password,
      '1',
      '0',
      $finger,
      "$dir/domains/$domain/$username", #$vdir
      $quota ? $quota.'S' : 'NOQUOTA',
    ), "\n";
  }

  close(VPASSWDTMP);

  rename "$exportdir/domains/$domain/vpasswd.tmp", "$exportdir/domains/$domain/vpasswd"
    or die "Can't rename $exportdir/domains/$domain/vpasswd.tmp: $!";

  flock(VPASSWD,LOCK_UN);
  close(VPASSWD);

  vpopmail_sync( $exportdir, $machine, $dir, $uid, $gid, $restart );

}

sub vpopmail_delete { #subroutine, not method
  my( $exportdir, $machine, $dir, $uid, $gid, $restart ) = splice @_,0,6;
  my( $username, $domain ) = @_;
  
  (open(VPASSWD, "$exportdir/domains/$domain/vpasswd")
    and flock(VPASSWD,LOCK_EX)
  ) or die "can't open $exportdir/domains/$domain/vpasswd: $!";

  open(VPASSWDTMP, ">$exportdir/domains/$domain/vpasswd.tmp")
    or die "Can't open $exportdir/domains/$domain/vpasswd.tmp: $!";

  while (<VPASSWD>) {
    my ($mailbox, $rest) = split(':', $_);
    print VPASSWDTMP $_ unless $username eq $mailbox;
  }

  close(VPASSWDTMP);

  rename "$exportdir/domains/$domain/vpasswd.tmp",
         "$exportdir/domains/$domain/vpasswd"
    or die "Can't rename $exportdir/domains/$domain/vpasswd.tmp: $!";

  flock(VPASSWD,LOCK_UN);
  close(VPASSWD);

  rmtree "$exportdir/domains/$domain/$username"
    or die "can't rmtree $exportdir/domains/$domain/$username: $!";

  vpopmail_sync( $exportdir, $machine, $dir, $uid, $gid, $restart );
}

sub vpopmail_sync {
  my( $exportdir, $machine, $dir, $uid, $gid, $restart ) = splice @_,0,6;
  
  chdir $exportdir;
#  my @args = ( $rsync, "-rlpt", "-e", $ssh, "domains/",
#               "vpopmail\@$machine:$dir/domains/"  );
#  system {$args[0]} @args;

  eval "use File::Rsync;";
  die $@ if $@;

  my $rsync = File::Rsync->new({ rsh => 'ssh' });

  $rsync->exec( {
    recursive => 1,
    perms     => 1,
    times     => 1,
    src       => "$exportdir/domains/",
    dest      => "vpopmail\@$machine:$dir/domains/",
  } ); # true/false return value from exec is not working, alas
  if ( $rsync->err ) {
    die "error uploading to vpopmail\@$machine:$dir/domains/ : ".
        'exit status: '. $rsync->status. ', '.
        'STDERR: '. join(" / ", $rsync->err). ', '.
        'STDOUT: '. join(" / ", $rsync->out);
  }

  eval "use Net::SSH qw(ssh);";
  die $@ if $@;

  ssh("vpopmail\@$machine", $restart) if $restart;
}

1;

