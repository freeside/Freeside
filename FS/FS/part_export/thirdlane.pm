package FS::part_export::thirdlane;

use base qw( FS::part_export );

use vars qw(%info $me);
use Tie::IxHash;
use Frontier::Client;

$me = '['.__PACKAGE__.']';

tie my %options, 'Tie::IxHash',
  #'server'           => { label => 'Thirdlane server name or IP address', },
  'username'         => { label => 'Thirdlane username', },
  'password'         => { label => 'Thirdlane password', },
  'prototype_tenant' => { label => 'Prototype tenant name', },
  'debug'            => { label => 'Checkbox label', type => 'checkbox' },
#  'select_option'   => { label   => 'Select option description',
#                         type    => 'select', options=>[qw(chocolate vanilla)],
#                         default => 'vanilla',
#                       },
#  'textarea_option' => { label   => 'Textarea option description',
#                         type    => 'textarea',
#                         default => 'Default text.',
#                      },
;

%info = (
  'svc'      => [qw( svc_pbx svc_phone )],
  'desc'     =>
    'Export tenants and DIDs to Thirdlane PBX manager',
  'options'  => \%options,
  'notes'    => <<'END'
Exports tenants and DIDs to Thirdlane PBX manager using the XML-RPC API.
END
);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_x) = (shift, shift);

  if ( $svc_x->isa('FS::svc_pbx') ) {

    my $tenant = {
      'tenant'   => $svc_x->title,
      'maxusers' => $svc_x->max_extensions,
      #others?  will they not clone?
    };

    @what_to_clone = qw(routes schedules menus queues voiceprompts moh);

    my $result = $self->_thirdlane_command( 'asterisk::rpc_tenant_create',
                                            $tenant,
                                            $self->option('prototype_tenant'),
                                            \@what_to_clone,
                                          );

    use Data::Dumper;
    warn Dumper(\$result);

    #$result == 0 means okay??

    #$error;

    '';

  } elsif ( $svc_x->isa('FS::svc_phone') ) {

  } else {
    die "guru meditation #10: $svc_x is not FS::svc_pbx or FS::svc_phone";
  }

}

sub _export_insert {
  my($self, $svc_x) = (shift, shift);

  if ( $svc_x->isa('FS::svc_pbx') ) {

    my $result = $self->_thirdlane_command( 'asterisk::rpc_tenant_delete',
                                            $svc_x->title,
                                          );

    use Data::Dumper;
    warn Dumper(\$result);

    #$result == 0 means okay??

    #$error;

    '';

  } elsif ( $svc_x->isa('FS::svc_phone') ) {

  } else {
    die "guru meditation #11: $svc_x is not FS::svc_pbx or FS::svc_phone";
  }

}

sub _export_replace {
  my($self, $svc_x) = (shift, shift);

  if ( $svc_x->isa('FS::svc_pbx') ) {

    my $tenant = {
      'tenant'   => $svc_x->title,
      'maxusers' => $svc_x->max_extensions,
      #others?  will they not clone?
    };

    my $result = $self->_thirdlane_command( 'asterisk::rpc_tenant_update',
                                            $tenant
                                          );

    use Data::Dumper;
    warn Dumper(\$result);

    #$result == 0 means okay??

    #$error;

    '';

  } elsif ( $svc_x->isa('FS::svc_phone') ) {

  } else {
    die "guru meditation #11: $svc_x is not FS::svc_pbx or FS::svc_phone";
  }

}


sub _thirdlane_command {
  my($self, @param) = @_;

  my $url = 'http://'.
              $self->option('username'). ':'. $self->option('password'). '@'.
              $self->machine. '/xmlrpc.cgi';

  warn "$me connecting to $url\n"
    if $self->option('debug');
  my $conn = Frontier::Client->new( 'url'   => $url,
                                    'debug' => $self->option('debug'),
                                  );

  warn "$me sending command: ". join(' ', @param). "\n"
    if $self->option('debug');
  $conn->call(@param);
  
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  #return "can't change username with thirdlane"
  #  if $old->username ne $new->username;
  #return '' unless $old->_password ne $new->_password;
  $err_or_queue = $self->thirdlane_queue( $new->svcnum,
    'replace', $new->username, $new->_password );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_delete {
  '';
  #my( $self, $svc_something ) = (shift, shift);
  #$err_or_queue = $self->thirdlane_queue( $svc_something->svcnum,
  #  'delete', $svc_something->username );
  #ref($err_or_queue) ? '' : $err_or_queue;
}

#these three are optional
# fallback for svc_acct will change and restore password
sub _export_suspend {
  my( $self, $svc_something ) = (shift, shift);
  $err_or_queue = $self->thirdlane_queue( $svc_something->svcnum,
    'suspend', $svc_something->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_unsuspend {
  my( $self, $svc_something ) = (shift, shift);
  $err_or_queue = $self->thirdlane_queue( $svc_something->svcnum,
    'unsuspend', $svc_something->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub export_links {
  my($self, $svc_something, $arrayref) = (shift, shift, shift);
  #push @$arrayref, qq!<A HREF="http://example.com/~!. $svc_something->username.
  #                 qq!">!. $svc_something->username. qq!</A>!;
  '';
}

####
#
##a good idea to queue anything that could fail or take any time
#sub thirdlane_queue {
#  my( $self, $svcnum, $method ) = (shift, shift, shift);
#  my $queue = new FS::queue {
#    'svcnum' => $svcnum,
#    'job'    => "FS::part_export::thirdlane::thirdlane_$method",
#  };
#  $queue->insert( @_ ) or $queue;
#}
#
#sub thirdlane_insert { #subroutine, not method
#  my( $username, $password ) = @_;
#  #do things with $username and $password
#}
#
#sub thirdlane_replace { #subroutine, not method
#}
#
#sub thirdlane_delete { #subroutine, not method
#  my( $username ) = @_;
#  #do things with $username
#}
#
#sub thirdlane_suspend { #subroutine, not method
#}
#
#sub thirdlane_unsuspend { #subroutine, not method
#}

1;
