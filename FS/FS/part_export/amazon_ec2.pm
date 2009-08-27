package FS::part_export::amazon_ec2;

use base qw( FS::part_export );

use vars qw(@ISA %info $replace_ok_kludge);
use Tie::IxHash;
use FS::Record qw( qsearchs );
use FS::svc_external;

tie my %options, 'Tie::IxHash',
  'access_key' => { label => 'AWS access key', },
  'secret_key' => { label => 'AWS secret key', },
  'ami'        => { label => 'AMI', 'default' => 'ami-ff46a796', },
  'keyname'    => { label => 'Keypair name', },
  #option to turn off (or on) ip address allocation
;

%info = (
  'svc'      => 'svc_external',
  'desc'     =>
    'Export to Amazon EC2',
  'options'  => \%options,
  'notes'    => <<'END'
Create instances in the Amazon EC2 (Elastic compute cloud).  Install
Net::Amazon::EC2 perl module.  Advisable to set svc_external-skip_manual config
option.
END
);

$replace_ok_kludge = 0;

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_external) = (shift, shift);
  $err_or_queue = $self->amazon_ec2_queue( $svc_external->svcnum, 'insert',
    $svc_external->svcnum,
    $self->option('ami'),
    $self->option('keyname'),
  );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return '' if $replace_ok_kludge;
  return "can't change instance id or IP address";
  #$err_or_queue = $self->amazon_ec2_queue( $new->svcnum,
  #  'replace', $new->username, $new->_password );
  #ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_delete {
  my( $self, $svc_external ) = (shift, shift);
  my( $instance_id, $ip ) = split(/:/, $svc_external->title );
  $err_or_queue = $self->amazon_ec2_queue( $svc_external->svcnum, 'delete',
    $instance_id,
    $ip,
  );
  ref($err_or_queue) ? '' : $err_or_queue;
}

#these three are optional
# fallback for svc_acct will change and restore password
#sub _export_suspend {
#  my( $self, $svc_something ) = (shift, shift);
#  $err_or_queue = $self->amazon_ec2_queue( $svc_something->svcnum,
#    'suspend', $svc_something->username );
#  ref($err_or_queue) ? '' : $err_or_queue;
#}
#
#sub _export_unsuspend {
#  my( $self, $svc_something ) = (shift, shift);
#  $err_or_queue = $self->amazon_ec2_queue( $svc_something->svcnum,
#    'unsuspend', $svc_something->username );
#  ref($err_or_queue) ? '' : $err_or_queue;
#}

sub export_links {
  my($self, $svc_external, $arrayref) = (shift, shift, shift);
  my( $instance_id, $ip ) = split(/:/, $svc_external->title );
   
  push @$arrayref, qq!<A HREF="http://$ip/">http://$ip/</A>!;
  '';
}

###

#a good idea to queue anything that could fail or take any time
sub amazon_ec2_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::amazon_ec2::amazon_ec2_$method",
  };
  $queue->insert( $self->option('access_key'),
                  $self->option('secret_key'),
                  @_
                )
    or $queue;
}

sub amazon_ec2_new {
  my( $access_key, $secret_key, @rest ) = @_;

  eval 'use Net::Amazon::EC2;';
  die $@ if $@;

  my $ec2 = new Net::Amazon::EC2 'AWSAccessKeyId'  => $access_key,
                                 'SecretAccessKey' => $secret_key;

  ( $ec2, @rest );
}

sub amazon_ec2_insert { #subroutine, not method
  my( $ec2, $svcnum, $ami, $keyname ) = amazon_ec2_new(@_);

  my $reservation_info = $ec2->run_instances( 'ImageId'  => $ami,
                                              'KeyName'  => $keyname,
                                              'MinCount' => 1,
                                              'MaxCount' => 1,
                                            );

  my $instance_id = $reservation_info->instances_set->[0]->instance_id;

  my $ip = $ec2->allocate_address
    or die "can't allocate address";
  $ec2->associate_address('InstanceId' => $instance_id,
                          'PublicIp'   => $ip,
                         )
    or die "can't assocate IP address $ip with instance $instance_id";

  my $svc_external = qsearchs('svc_external', { 'svcnum' => $svcnum } )
    or die "can't find svc_external.svcnum $svcnum\n";

  $svc_external->title("$instance_id:$ip");

  local($replace_ok_kludge) = 1;
  my $error = $svc_external->replace;
  die $error if $error;

}

#sub amazon_ec2_replace { #subroutine, not method
#}

sub amazon_ec2_delete { #subroutine, not method
  my( $ec2, $id, $ip ) = amazon_ec2_new(@_);

  my $instance_id = sprintf('i-%x', $id);
  $ec2->disassociate_address('PublicIp'=>$ip)
    or die "can't dissassocate $ip";

  $ec2->release_address('PublicIp'=>$ip)
    or die "can't release $ip";

  my $result = $ec2->terminate_instances('InstanceId'=>$instance_id);
  #check for instance_id match or something?

}

#sub amazon_ec2_suspend { #subroutine, not method
#}

#sub amazon_ec2_unsuspend { #subroutine, not method
#}

1;

