package FS::SSH;

use strict;
use vars qw(@ISA @EXPORT_OK $ssh $scp);
use Exporter;
use IPC::Open2;
use IPC::Open3;

@ISA = qw(Exporter);
@EXPORT_OK = qw(ssh scp issh iscp sshopen2 sshopen3);

$ssh="ssh";
$scp="scp";

=head1 NAME

FS::SSH - Subroutines to call ssh and scp

=head1 SYNOPSIS

  use FS::SSH qw(ssh scp issh iscp sshopen2 sshopen3);

  ssh($host, $command);

  issh($host, $command);

  scp($source, $destination);

  iscp($source, $destination);

  sshopen2($host, $reader, $writer, $command);

  sshopen3($host, $reader, $writer, $error, $command);

=head1 DESCRIPTION

  Simple wrappers around ssh and scp commands.

=head1 SUBROUTINES

=over 4

=item ssh HOST, COMMAND 

Calls ssh in batch mode.

=cut

sub ssh {
  my($host,$command)=@_;
  my(@cmd)=($ssh, "-o", "BatchMode yes", $host, $command);
#  	print join(' ',@cmd),"\n";
#0;
  system(@cmd);
}

=item issh HOST, COMMAND

Prints the ssh command to be executed, waits for the user to confirm, and
(optionally) executes the command.

=cut

sub issh {
  my($host,$command)=@_;
  my(@cmd)=($ssh, $host, $command);
  print join(' ',@cmd),"\n";
  if ( &_yesno ) {
    	###print join(' ',@cmd),"\n";
    system(@cmd);
  }
}

=item scp SOURCE, DESTINATION

Calls scp in batch mode.

=cut

sub scp {
  my($src,$dest)=@_;
  my(@cmd)=($scp,"-Bprq",$src,$dest);
#  	print join(' ',@cmd),"\n";
#0;
  system(@cmd);
}

=item iscp SOURCE, DESTINATION

Prints the scp command to be executed, waits for the user to confirm, and
(optionally) executes the command.

=cut

sub iscp {
  my($src,$dest)=@_;
  my(@cmd)=($scp,"-pr",$src,$dest);
  print join(' ',@cmd),"\n";
  if ( &_yesno ) {
    	###print join(' ',@cmd),"\n";
    system(@cmd);
  }
}

=item sshopen2 HOST, READER, WRITER, COMMAND

Connects the supplied filehandles to the ssh process (in batch mode).

=cut

sub sshopen2 {
  my($host,$reader,$writer,$command)=@_;
  open2($reader,$writer,$ssh,'-o','Batchmode yes',$host,$command);
}

=item sshopen3 HOST, WRITER, READER, ERROR, COMMAND

Connects the supplied filehandles to the ssh process (in batch mode).

=cut

sub sshopen3 {
  my($host,$writer,$reader,$error,$command)=@_;
  open3($writer,$reader,$error,$ssh,'-o','Batchmode yes',$host,$command);
}

sub _yesno {
  print "Proceed [y/N]:";
  my($x)=scalar(<STDIN>);
  $x =~ /^y/i;
}

=head1 BUGS

Not OO.

scp stuff should transparantly use rsync-over-ssh instead.

=head1 SEE ALSO

L<ssh>, L<scp>, L<IPC::Open2>, L<IPC::Open3>

=cut

1;

