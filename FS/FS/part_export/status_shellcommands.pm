package FS::part_export::status_shellcommands;
use base qw( FS::part_export::shellcommands );

use vars qw( %info );
use Tie::IxHash;
use String::ShellQuote;

tie my %options, 'Tie::IxHash',
  'user' => { label=>'Remote username', default=>'root' },

  'spam_enable'     => { label=>'Spam filtering enable command', },
  'spam_disable'    => { label=>'Spam filtering disable command', },
  'spam_tag2_level'  => { label=>'Spam set tag2 level command', },
  'spam_kill_level' => { label=>'Spam set kill level command', },

  'ignore_all_output' => {
    label => 'Ignore all output and errors from the command',
    type  => 'checkbox',
  },
;

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Set mailbox status via shell commands',
  'options'  => \%options,
  'nodomain' => '',
  'notes'    => <<END
Set mailbox status information (vacation and spam settings) with shell commands.
END
);

#don't want to inherit these from shellcommands
sub _export_insert    {}
sub _export_replace   {}
sub _export_delete    {}
sub _export_suspend   {}
sub _export_unsuspend {}

sub export_setstatus {
  my($self, $svc_acct, $hashref) = @_;

  my @shellargs = (
    $svc_acct->svcnum,
    user          => $self->option('user') || 'root',
    host          => $self->machine,
    #stdin_string  => $stdin_string,
    ignore_all_output => $self->option('ignore_all_output'),
    #ignored_errors    => $self->option('ignored_errors') || '',
  );

  $self->shellcommands_queue( @shallargs, 'command' =>
    $self->option('spam_enable'). ' '.
    shell_quote($svc_acct->email)
  )
    || $self->shellcommands_queue( @shallargs, 'command' =>
         $self->option('spam_tag2_level'). ' '.
         shell_quote($svc_acct->email). ' '.
         $hashref->{'spam_tag2_level'}
       )
    || $self->shellcommands_queue( @shallargs, 'command' =>
         $self->option('spam_kill_level'). ' '.
         shell_quote($svc_acct->email). ' '.
         $hashref->{'spam_kill_level'}
       )
  ;

}

1;
