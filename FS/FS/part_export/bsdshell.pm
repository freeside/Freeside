package FS::part_export::bsdshell;

use vars qw(@ISA);
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);
  $err_or_queue = $self->bsdshell_queue( $svc_acct->svcnum, 'insert',
    $svc_acct->username, $svc_acct->_password );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  #return "can't change username with bsdshell"
  #  if $old->username ne $new->username;
  #return '' unless $old->_password ne $new->_password;
  $err_or_queue = $self->bsdshell_queue( $new->svcnum,
    'replace', $new->username, $new->_password );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $err_or_queue = $self->bsdshell_queue( $svc_acct->svcnum,
    'delete', $svc_acct->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

#a good idea to queue anything that could fail or take any time
sub bsdshell_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::bsdshell::bsdshell_$method",
  };
  $queue->insert( @_ ) or $queue;
}

sub bsdshell_insert { #subroutine, not method
}
sub bsdshell_replace { #subroutine, not method
}
sub bsdshell_delete { #subroutine, not method
}

