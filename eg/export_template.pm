package FS::part_export::myexport;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'regular_option'  => { label => 'Option description', default => 'value' },
  'select_option'   => { label   => 'Select option description',
                         type    => 'select', options=>[qw(chocolate vanilla)],
                         default => 'vanilla',
                       },
  'textarea_option' => { label   => 'Textarea option description',
                         type    => 'textarea',
                         default => 'Default text.',
                      },
  'checkbox_option' => { label => 'Checkbox label', type => 'checkbox' },
;

%info = (
  'svc'      => 'svc_acct',
  #'svc'      => [qw( svc_acct svc_forward )],
  'desc'     =>
    'Export short description',
  'options'  => \%options,
  'nodomain' => 'Y',
  'notes'    => <<'END'
HTML notes about this export.
END

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_something) = (shift, shift);
  $err_or_queue = $self->myexport_queue( $svc_something->svcnum, 'insert',
    $svc_something->username, $svc_something->_password );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  #return "can't change username with myexport"
  #  if $old->username ne $new->username;
  #return '' unless $old->_password ne $new->_password;
  $err_or_queue = $self->myexport_queue( $new->svcnum,
    'replace', $new->username, $new->_password );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_delete {
  my( $self, $svc_something ) = (shift, shift);
  $err_or_queue = $self->myexport_queue( $svc_something->svcnum,
    'delete', $svc_something->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

#these three are optional
# fallback for svc_acct will change and restore password
sub _export_suspend {
  my( $self, $svc_something ) = (shift, shift);
  $err_or_queue = $self->myexport_queue( $svc_something->svcnum,
    'suspend', $svc_something->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_unsuspend {
  my( $self, $svc_something ) = (shift, shift);
  $err_or_queue = $self->myexport_queue( $svc_something->svcnum,
    'unsuspend', $svc_something->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub export_links {
  my($self, $svc_something, $arrayref) = (shift, shift, shift);
  #push @$arrayref, qq!<A HREF="http://example.com/~!. $svc_something->username.
  #                 qq!">!. $svc_something->username. qq!</A>!;
  '';
}

###

#a good idea to queue anything that could fail or take any time
sub myexport_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::myexport::myexport_$method",
  };
  $queue->insert( @_ ) or $queue;
}

sub myexport_insert { #subroutine, not method
  my( $username, $password ) = @_;
  #do things with $username and $password
}

sub myexport_replace { #subroutine, not method
}

sub myexport_delete { #subroutine, not method
  my( $username ) = @_;
  #do things with $username
}

sub myexport_suspend { #subroutine, not method
}

sub myexport_unsuspend { #subroutine, not method
}


