package FS::part_export::status_shellcommands;
use base qw( FS::part_export::shellcommands );

use vars qw( %info );
use Tie::IxHash;

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

  $self->_export_command('spam_enable', $svc_acct->email);

  $self->_export_command('spam_tag2_level', $svc_acct->email, $hashref->{'spam_tag2_level'} );
  $self->_export_command('spam_kill_level', $svc_acct->email, $hashref->{'spam_kill_level'} );

}

1;
