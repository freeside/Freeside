package FS::part_export::textradius;

use vars qw(@ISA);
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);
  $err_or_queue = $self->textradius_queue( $svc_acct->svcnum, 'insert',
    $svc_acct->username, $svc_acct->_password );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  #return "can't change username with textradius"
  #  if $old->username ne $new->username;
  #return '' unless $old->_password ne $new->_password;
  $err_or_queue = $self->textradius_queue( $new->svcnum,
    'replace', $new->username, $new->_password );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $err_or_queue = $self->textradius_queue( $svc_acct->svcnum,
    'delete', $svc_acct->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

#a good idea to queue anything that could fail or take any time
sub textradius_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::textradius::textradius_$method",
  };
  $queue->insert( @_ ) or $queue;
}

sub textradius_insert { #subroutine, not method
}
sub textradius_replace { #subroutine, not method
}
sub textradius_delete { #subroutine, not method
}

