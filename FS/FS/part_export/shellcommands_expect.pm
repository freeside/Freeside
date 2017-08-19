package FS::part_export::shellcommands_expect;
use base qw( FS::part_export::shellcommands );

use strict;
use Tie::IxHash;
use Net::OpenSSH;
use Expect;
#use FS::Record qw( qsearch qsearchs );

tie my %options, 'Tie::IxHash',
  'user'      => { label =>'Remote username', default=>'root' },
  'useradd'   => { label => 'Insert commands',    type => 'textarea', },
  'userdel'   => { label => 'Delete commands',    type => 'textarea', },
  'usermod'   => { label => 'Modify commands',    type => 'textarea', },
  'suspend'   => { label => 'Suspend commands',   type => 'textarea', },
  'unsuspend' => { label => 'Unsuspend commands', type => 'textarea', },
  'debug'     => { label => 'Enable debugging',
                   type  => 'checkbox',
                   value => 1,
                 },
;

our %info = (
  'svc'     => 'svc_acct',
  'desc'    => 'Real time export via remote SSH, with interactive ("Expect"-like) scripting, for svc_acct services',
  'options' => \%options,
  'notes'   => q[
Interactively run commands via SSH in a remote terminal, like "Expect".  In
most cases, you probably want a regular shellcommands (or broadband_shellcommands, etc.) export instead, unless
you have a specific need to interact with a terminal-based interface in an
"Expect"-like fashion.
<BR><BR>

Each line specifies a string to match and a command to
run after that string is found, separated by the first space.  For example, to
run "exit" after a prompt ending in "#" is sent, "# exit".  You will need to
<a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.9:Documentation:Administration:SSH_Keys">setup SSH for unattended operation</a>.
<BR><BR>

In commands, all variable substitutions of the regular shellcommands (or
broadband_shellcommands, etc.) export are available (use a backslash to escape
a literal $).
]
);

sub _export_command {
  my ( $self, $action, $svc_acct) = (shift, shift, shift);
  my @lines = split("\n", $self->option($action) );

  return '' unless @lines;

  my @commands = ();
  foreach my $line (@lines) {
    my($match, $command) = split(' ', $line, 2);
    my( $command_string ) = $self->_export_subvars( $svc_acct, $command, '' );
    push @commands, [ $match, $command_string ];
  }

  $self->shellcommands_expect_queue( $svc_acct->svcnum, @commands );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  my @lines = split("\n", $self->option('replace') );

  return '' unless @lines;

  my @commands = ();
  foreach my $line (@lines) {
    my($match, $command) = split(' ', $line, 2);
    my( $command_string ) = $self->_export_subvars_replace( $new, $old, $command, '' );
    push @commands, [ $match, $command_string ];
  }

  $self->shellcommands_expect_queue( $new->svcnum, @commands );
}

sub shellcommands_expect_queue {
  my( $self, $svcnum, @commands ) = @_;

  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::shellcommands_expect::ssh_expect",
  };
  $queue->insert(
    user          => $self->option('user') || 'root',
    host          => $self->machine,
    debug         => $self->option('debug'),
    commands      => \@commands,
  );
}

sub ssh_expect { #subroutine, not method
  my $opt = { @_ };

  my $dest = $opt->{'user'}.'@'.$opt->{'host'};

  open my $def_in, '<', '/dev/null' or die "unable to open /dev/null\n";
  my $ssh = Net::OpenSSH->new( $dest, 'default_stdin_fh' => $def_in );
  # ignore_all_errors doesn't override SSH connection/auth errors--
  # probably correct
  die "Couldn't establish SSH connection to $dest: ". $ssh->error
    if $ssh->error;

  my ($pty, $pid) = $ssh->open2pty
    or die "Couldn't start a remote terminal session";
  my $expect = Expect->init($pty);
  #not useful #$expect->debug($opt->{debug} ? 3 : 0);

  foreach my $line ( @{ $opt->{commands} } ) {
    my( $match, $command ) = @$line;

    warn "Waiting for '$match'\n" if $opt->{debug};

    my $matched = $expect->expect(30, $match);
    unless ( $matched ) {
      my $err = "Never saw '$match'\n";
      warn $err;
      die $err;
    }
    warn "Running '$command'\n" if $opt->{debug};
    $expect->send("$command\n");
  }

  '';
}

1;
