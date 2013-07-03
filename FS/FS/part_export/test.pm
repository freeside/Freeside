package FS::part_export::test;

use strict;
use vars qw(%options %info);
use Tie::IxHash;
use base qw(FS::part_export);

tie %options, 'Tie::IxHash',
  'result'  => { label    => 'Result',
                 type     => 'select',
                 options  => [ 'success', 'failure', 'exception' ],
                 default  => 'success',
               },
  'errormsg'=> { label    => 'Error message',
                 default  => 'Test export' },
  'insert'  => { label    => 'Insert', type => 'checkbox', default => 1, },
  'delete'  => { label    => 'Delete', type => 'checkbox', default => 1, },
  'replace' => { label    => 'Replace',type => 'checkbox', default => 1, },
  'suspend' => { label    => 'Suspend',type => 'checkbox', default => 1, },
  'unsuspend'=>{ label => 'Unsuspend', type => 'checkbox', default => 1, },
;

%info = (
  'svc'     => [ qw(svc_acct svc_broadband svc_phone svc_domain) ],
  'desc'    => 'Test export for development',
  'options' => \%options,
  'notes'   => <<END,
<P>Test export.  Do not use this in production systems.</P>
<P>This export either always succeeds, always fails (returning an error),
or always dies, according to the "Result" option.  It does nothing else; the
purpose is purely to simulate success or failure within an export module.</P>
<P>The checkbox options can be used to turn the export off for certain
actions, if this is needed.</P>
END
);

sub export_insert {
  my $self = shift;
  $self->run(@_) if $self->option('insert');
}

sub export_delete {
  my $self = shift;
  $self->run(@_) if $self->option('delete');
}

sub export_replace {
  my $self = shift;
  $self->run(@_) if $self->option('replace');
}

sub export_suspend {
  my $self = shift;
  $self->run(@_) if $self->option('suspend');
}

sub export_unsuspend {
  my $self = shift;
  $self->run(@_) if $self->option('unsuspend');
}

sub run {
  my $self = shift;
  my $svc_x = shift;
  my $result = $self->option('result');
  if ( $result eq 'failure' ) {
    return $self->option('errormsg');
  } elsif ( $result eq 'exception' ) {
    die $self->option('errormsg');
  } else {
    return '';
  }
}

1;
