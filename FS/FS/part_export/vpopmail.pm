package FS::part_export::myexport;

use vars qw(@ISA);
use FS::part_export;

@ISA = qw(FS::part_export);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_acct) = (shift, shift);
  $self->myexport_queue( $svc_acct->svcnum, 'insert',
    $svc_acct->username, $svc_acct->_password );
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  #return "can't change username with myexport"
  #  if $old->username ne $new->username;
  #return '' unless $old->_password ne $new->_password;
  $self->myexport_queue( $new->svcnum,
    'replace', $new->username, $new->_password );
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $self->myexport_queue( $svc_acct->svcnum,
    'delete', $svc_acct->username );
}

#a good idea to queue anything that could fail or take any time
sub myexport_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::myexport::myexport_$method",
  };
  $queue->insert( @_ );
}

sub myexport_insert { #subroutine, not method
}
sub myexport_replace { #subroutine, not method
}
sub myexport_delete { #subroutine, not method
}

