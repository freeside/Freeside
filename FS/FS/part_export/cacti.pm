package FS::part_export::cacti;

use strict;

use base qw( FS::part_export );
use FS::Record qw( qsearchs );
use FS::UID qw( dbh );

use File::Rsync;
use File::Slurp qw( append_file slurp write_file );
use File::stat;
use MIME::Base64 qw( encode_base64 );

use vars qw( %info );

my $php = 'php -q ';

tie my %options, 'Tie::IxHash',
  'user'              => { label   => 'User Name',
                           default => 'freeside' },
  'script_path'       => { label   => 'Script Path',
                           default => '/usr/share/cacti/cli/' },
  'template_id'       => { label   => 'Host Template ID',
                           default => '' },
  'tree_id'           => { label   => 'Graph Tree ID (optional)',
                           default => '' },
  'description'       => { label   => 'Description (can use $ip_addr and $description tokens)',
                           default => 'Freeside $description $ip_addr' },
  'graphs_path'       => { label   => 'Graph Export Directory (user@host:/path/to/graphs/)',
                           default => '' },
  'import_freq'       => { label   => 'Minimum minutes between graph imports',
                           default => '5' },
  'max_graph_size'    => { label   => 'Maximum size per graph (MB)',
                           default => '5' },
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
  if ($opt{'tree_id'}) {
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
  }

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

# NOT A METHOD, run as an FS::queue job
# copies graphs for a single service from Cacti export directory to FS cache
# generates basic html pages for this service's graphs, and stores them in FS cache
sub process_graphs {
  my ($job,$param) = @_; #

  $job->update_statustext(10);
  my $cachedir = $FS::UID::cache_dir . '/cacti-graphs/';

  # load the service
  my $svcnum = $param->{'svcnum'} || die "No svcnum specified";
  my $svc = qsearchs({
   'table'   => 'svc_broadband',
   'hashref' => { 'svcnum' => $svcnum },
  }) || die "Could not load svcnum $svcnum";

  # load relevant FS::part_export::cacti object
  my ($self) = $svc->cust_svc->part_svc->part_export('cacti');

  $job->update_statustext(20);

  # check for recent uploads, avoid doing this too often
  my $svchtml = $cachedir.'svc_'.$svcnum.'.html';
  if (-e $svchtml) {
    open(my $fh, "<$svchtml");
    my $firstline = <$fh>;
    close($fh);
    if ($firstline =~ /UPDATED (\d+)/) {
      if ($1 > time - 60 * ($self->option('import_freq') || 5)) {
        $job->update_statustext(100);
        return '';
      }
    }
  }

  $job->update_statustext(30);

  # get list of graphs for this svc
  my $cmd = $php
          . $self->option('script_path')
          . q(freeside_cacti.php --get-graphs --ip=')
          . $svc->ip_addr
          . q(');
  my @graphs = map { [ split(/\t/,$_) ] } 
                 split(/\n/, ssh_cmd(
                   'host'          => $self->machine,
                   'user'          => $self->option('user'),
                   'command'       => $cmd
                 ));

  $job->update_statustext(40);

  # copy graphs to cache
  # requires version 2.6.4 of rsync, released March 2005
  my $rsync = File::Rsync->new({
    'rsh'       => 'ssh',
    'verbose'   => 1,
    'recursive' => 1,
    'source'    => $self->option('graphs_path'),
    'dest'      => $cachedir,
    'include'   => [
      (map { q('**graph_).${$_}[0].q(*.png') } @graphs),
      (map { q('**thumb_).${$_}[0].q(.png') } @graphs),
      q('*/'),
      q('- *'),
    ],
  });
  #don't know why a regular $rsync->exec isn't doing includes right, but this does
  my $error = system(join(' ',@{$rsync->getcmd()}));
  die "rsync failed with exit status $error" if $error;

  $job->update_statustext(50);

  # create html files in cache
  my $now = time;
  my $svchead = q(<!-- UPDATED ) . $now . qq( -->\n)
              . '<H2 STYLE="margin-top: 0;">Service #' . $svcnum . '</H2>' . "\n"
              . q(<P>Last updated ) . scalar(localtime($now)) . q(</P>) . "\n";
  write_file($svchtml,$svchead);
  my $maxgraph = 1024 * 1024 * ($self->options('max_graph_size') || 5);
  my $nographs = 1;
  for (my $i = 0; $i <= $#graphs; $i++) {
    my $graph = $graphs[$i];
    my $thumbfile = $cachedir . 'graphs/thumb_' . $$graph[0] . '.png';
    if (
      (-e $thumbfile) && 
      ( stat($thumbfile)->size() < $maxgraph )
    ) {
      $nographs = 0;
      # add graph to main file
      my $graphhead = q(<H3>) . $$graph[1] . q(</H3>) . "\n";
      append_file( $svchtml, $graphhead,
        anchor_tag( 
          $svcnum, $$graph[0], img_tag($thumbfile)
        )
      );
      # create graph details file
      my $graphhtml = $cachedir . 'svc_' . $svcnum . '_graph_' . $$graph[0] . '.html';
      write_file($graphhtml,$svchead,$graphhead);
      my $nodetail = 1;
      my $j = 1;
      while (-e (my $graphfile = $cachedir.'graphs/graph_'.$$graph[0].'_'.$j.'.png')) {
        if ( stat($graphfile)->size() < $maxgraph ) {
          $nodetail = 0;
          append_file( $graphhtml, img_tag($graphfile) );
        }
        $j++;
      }
      append_file($graphhtml, '<P>No detail graphs to display for this graph</P>')
        if $nodetail;
    }
    $job->update_statustext(50 + ($i / $#graphs) * 50);
  }
  append_file($svchtml,'<P>No graphs to display for this service</P>')
    if $nographs;

  $job->update_statustext(100);
  return '';
}

sub img_tag {
  my $somefile = shift;
  return q(<IMG SRC="data:image/png;base64,)
       . encode_base64(slurp($somefile,binmode=>':raw'))
       . qq(" STYLE="margin-bottom: 1em;"><BR>\n);
}

sub anchor_tag {
  my ($svcnum, $graphnum, $contents) = @_;
  return q(<A HREF="?svcnum=)
       . $svcnum
       . q(&graphnum=)
       . $graphnum
       . q(">)
       . $contents
       . q(</A>);
}

#this gets used by everything else
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
devices exported by Freeside, and note the template's id number.  Optionally,
create a Graph Tree for these devices to be automatically added to, and note
the tree's id number.  Configure a Graph Export (under Settings) and note 
the Export Directory.

In Freeside, go to Configuration->Services->Provisioning exports to
add a new export.  From the Add Export page, select cacti for Export then enter...

* the Hostname or IP address of your Cacti server

* the User Name with permission to run scripts in the cli directory

* the full Script Path to that directory (eg /usr/share/cacti/cli/)

* the Host Template ID for adding new devices

* the Graph Tree ID for adding new devices (optional)

* the Description for new devices;  you can use the tokens
  $ip_addr and $description to include the equivalent fields
  from the broadband service definition

* the Graph Export Directory, including connection information
  if necessary (user@host:/path/to/graphs/)

* the minimum minutes between graph imports to Freeside (graphs will
  otherwise be imported into Freeside as needed.)  This should be at least
  as long as the minumum time between graph exports configured in Cacti.
  Defaults to 5 if unspecified.

* the maximum size per graph, in MB;  individual graphs that exceed this size
  will be quietly ignored by Freeside.  Defaults to 5 if unspecified.

After adding the export, go to Configuration->Services->Service definitions.
The export you just created will be available for selection when adding or
editing broadband service definitions; check the box to activate it for 
a given service.  Note that you should only have one cacti export per
broadband service definition.

When properly configured broadband services are provisioned, they will now
be added to Cacti using the Host Template you specified.  If you also specified
a Graph Tree, the created device will also be added to that.

Once added, a link to the graphs for this host will be available when viewing 
the details of the provisioned service in Freeside.

Devices will be deleted from Cacti when the service is unprovisioned in Freeside, 
and they will be deleted and re-added if the ip address changes.

Currently, graphs themselves must still be added in Cacti by hand or some
other form of automation tailored to your specific graph inputs and data sources.

=head1 AUTHOR

Jonathan Prykop 
jonathan@freeside.biz

=head1 LICENSE AND COPYRIGHT

Copyright 2015 Freeside Internet Services      

This program is free software; you can redistribute it and/or 
modify it under the terms of the GNU General Public License 
as published by the Free Software Foundation.

=cut

1;


