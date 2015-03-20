package FS::part_export::cacti;

use strict;
use base qw( FS::part_export );
use FS::Record qw( qsearchs );
use FS::UID qw( dbh );

use vars qw( %info );

my $php = 'php -q ';

tie my %options, 'Tie::IxHash',
  'user'              => { label   => 'User Name',
                           default => 'freeside' },
  'script_path'       => { label   => 'Script Path',
                           default => '/usr/share/cacti/cli/' },
  'base_url'          => { label   => 'Base Cacti URL',
                           default => '' },
  'template_id'       => { label   => 'Host Template ID',
                           default => '' },
  'tree_id'           => { label   => 'Graph Tree ID',
                           default => '' },
  'description'       => { label   => 'Description (can use $ip_addr and $description tokens)',
                           default => 'Freeside $description $ip_addr' },
#  'delete_graphs'     => { label   => 'Delete associated graphs and data sources when unprovisioning', 
#                           type    => 'checkbox',
#                         },
;

%info = (
  'svc'             => 'svc_broadband',
  'desc'            => 'Export service to cacti server, for svc_broadband services',
  'options'         => \%options,
  'notes'           => <<'END',
Add service to cacti upon provisioning, for broadband services.<BR>
See FS::part_export::cacti documentation for details.
END
);

# standard hooks for provisioning/unprovisioning service

sub _export_insert {
  my ($self, $svc_broadband) = @_;
  my ($q,$error) = _insert_queue($self, $svc_broadband);
  return $error;
}

sub _export_delete {
  my ($self, $svc_broadband) = @_;
  my ($q,$error) = _delete_queue($self, $svc_broadband);
  return $error;
}

sub _export_replace {
  my($self, $new, $old) = @_;
  return '' if $new->ip_addr eq $old->ip_addr; #important part didn't change
  #delete old then insert new, with second job dependant on the first
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  my ($dq, $iq, $error);
  ($dq,$error) = _delete_queue($self,$old);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  ($iq,$error) = _insert_queue($self,$new);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  $error = $iq->depend_insert($dq->jobnum);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  return '';
}

sub _export_suspend {
  return '';
}

sub _export_unsuspend {
  return '';
}

# create queued jobs

sub _insert_queue {
  my ($self, $svc_broadband) = @_;
  my $queue = new FS::queue {
    'svcnum' => $svc_broadband->svcnum,
    'job'    => "FS::part_export::cacti::ssh_insert",
  };
  my $error = $queue->insert(
    'host'        => $self->machine,
    'user'        => $self->option('user'),
    'hostname'    => $svc_broadband->ip_addr,
    'script_path' => $self->option('script_path'),
    'template_id' => $self->option('template_id'),
    'tree_id'     => $self->option('tree_id'),
    'description' => $self->option('description'),
	'svc_desc'    => $svc_broadband->description,
    'svcnum'      => $svc_broadband->svcnum,
  );
  return ($queue,$error);
}

sub _delete_queue {
  my ($self, $svc_broadband) = @_;
  my $queue = new FS::queue {
    'svcnum' => $svc_broadband->svcnum,
    'job'    => "FS::part_export::cacti::ssh_delete",
  };
  my $error = $queue->insert(
    'host'          => $self->machine,
    'user'          => $self->option('user'),
    'hostname'      => $svc_broadband->ip_addr,
    'script_path'   => $self->option('script_path'),
#    'delete_graphs' => $self->option('delete_graphs'),
  );
  return ($queue,$error);
}

# routines run by queued jobs

sub ssh_insert {
  my %opt = @_;

  # Option validation
  die "Non-numerical Host Template ID, check export configuration\n"
    unless $opt{'template_id'} =~ /^\d+$/;
  die "Non-numerical Graph Tree ID, check export configuration\n"
    unless $opt{'tree_id'} =~ /^\d+$/;

  # Add host to cacti
  my $desc = $opt{'description'};
  $desc =~ s/\$ip_addr/$opt{'hostname'}/g;
  $desc =~ s/\$description/$opt{'svc_desc'}/g;
  $desc =~ s/'/'\\''/g;
  my $cmd = $php
          . $opt{'script_path'} 
          . q(add_device.php --description=')
          . $desc
          . q(' --ip=')
          . $opt{'hostname'}
          . q(' --template=)
          . $opt{'template_id'};
  my $response = ssh_cmd(%opt, 'command' => $cmd);
  unless ( $response =~ /Success - new device-id: \((\d+)\)/ ) {
    die "Error adding device: $response";
  }
  my $id = $1;

  # Add host to tree
  $cmd = $php
       . $opt{'script_path'}
       . q(add_tree.php --type=node --node-type=host --tree-id=)
       . $opt{'tree_id'}
       . q( --host-id=)
       . $id;
  $response = ssh_cmd(%opt, 'command' => $cmd);
  unless ( $response =~ /Added Node node-id: \((\d+)\)/ ) {
      die "Error adding host to tree: $response";
  }
  my $leaf_id = $1;

  # Store id for generating graph urls
  my $svc_broadband = qsearchs({
    'table'   => 'svc_broadband',
    'hashref' => { 'svcnum' => $opt{'svcnum'} },
  });
  die "Could not reload broadband service" unless $svc_broadband;
  $svc_broadband->set('cacti_leaf_id',$leaf_id);
  my $error = $svc_broadband->replace;
  return $error if $error;

#  # Get list of graph templates for new id
#  $cmd = $php
#       . $opt{'script_path'} 
#       . q(freeside_cacti.php --get-graph-templates --host-template=)
#       . $opt{'template_id'};
#  my @gtids = split(/\n/,ssh_cmd(%opt, 'command' => $cmd));
#  die "No graphs configured for host template"
#    unless @gtids;
#
#  # Create graphs
#  foreach my $gtid (@gtids) {
#
#    # sanity checks, should never happen
#    next unless $gtid;
#    die "Bad graph template: $gtid"
#      unless $gtid =~ /^\d+$/;
#
#    # create the graph
#    $cmd = $php
#         . $opt{'script_path'}
#         . q(add_graphs.php --graph-type=cg --graph-template-id=)
#         . $gtid
#         . q( --host-id=)
#         . $id;
#    $response = ssh_cmd(%opt, 'command' => $cmd);
#    die "Error creating graph $gtid: $response"
#      unless $response =~ /Graph Added - graph-id: \((\d+)\)/;
#    my $gid = $1;
#
#    # add the graph to the tree
#    $cmd = $php
#         . $opt{'script_path'}
#         . q(add_tree.php --type=node --node-type=graph --tree-id=)
#         . $opt{'tree_id'}
#         . q( --graph-id=)
#         . $gid;
#    $response = ssh_cmd(%opt, 'command' => $cmd);
#    die "Error adding graph $gid to tree: $response"
#      unless $response =~ /Added Node/;
#
#  } #foreach $gtid

  return '';
}

sub ssh_delete {
  my %opt = @_;
  my $cmd = $php
          . $opt{'script_path'} 
          . q(freeside_cacti.php --drop-device --ip=')
          . $opt{'hostname'}
          . q(');
#  $cmd .= q( --delete-graphs)
#    if $opt{'delete_graphs'};
  my $response = ssh_cmd(%opt, 'command' => $cmd);
  die "Error removing from cacti: " . $response
    if $response;
  return '';
}

#fake false laziness, other ssh_cmds handle error/output differently
sub ssh_cmd {
  use Net::OpenSSH;
  my $opt = { @_ };
  my $ssh = Net::OpenSSH->new($opt->{'user'}.'@'.$opt->{'host'});
  die "Couldn't establish SSH connection: ". $ssh->error if $ssh->error;
  my ($output, $errput) = $ssh->capture2($opt->{'command'});
  die "Error running SSH command: ". $ssh->error if $ssh->error;
  die $errput if $errput;
  return $output;
}

=pod

=head1 NAME

FS::part_export::cacti

=head1 SYNOPSIS

Cacti integration for Freeside

=head1 DESCRIPTION

This module in particular handles FS::part_export object creation for Cacti integration;
consult any existing L<FS::part_export> documentation for details on how that works.
What follows is more general instructions for connecting your Cacti installation
to your Freeside installation.

=head2 Connecting Cacti To Freeside

Copy the freeside_cacti.php script from the bin directory of your Freeside
installation to the cli directory of your Cacti installation.  Give this file 
the same permissions as the other files in that directory, and create 
(or choose an existing) user with sufficient permission to read these scripts.

In the regular Cacti interface, create a Host Template to be used by 
devices exported by Freeside, and note the template's id number.

In Freeside, go to Configuration->Services->Provisioning exports to
add a new export.  From the Add Export page, select cacti for Export then enter...

* the User Name with permission to run scripts in the cli directory

* enter the full Script Path to that directory (eg /usr/share/cacti/cli/)

* enter the Base Cacti URL for your cacti server (eg https://example.com/cacti/)

* the Host Template ID for adding new devices

* the Graph Tree ID for adding new devices

* the Description for new devices;  you can use the tokens
  $ip_addr and $description to include the equivalent fields
  from the broadband service definition

After adding the export, go to Configuration->Services->Service definitions.
The export you just created will be available for selection when adding or
editing broadband service definitions.

When properly configured broadband services are provisioned, they should now
be added to Cacti using the Host Template you specified, and the created device
will also be added to the specified Graph Tree.

Once added, a link to the graphs for this host will be available when viewing 
the details of the provisioned service in Freeside (you will need to authenticate 
into Cacti to view them.)

Devices will be deleted from Cacti when the service is unprovisioned in Freeside, 
and they will be deleted and re-added if the ip address changes.

Currently, graphs themselves must still be added in cacti by hand or some
other form of automation tailored to your specific graph inputs and data sources.

=head1 AUTHOR

Jonathan Prykop 
jonathan@freeside.biz

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Freeside Internet Services      

This program is free software; you can redistribute it and/or           |
modify it under the terms of the GNU General Public License             |
as published by the Free Software Foundation.

=cut

1;


