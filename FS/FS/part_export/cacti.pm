package FS::part_export::cacti;

=pod

=head1 NAME

FS::part_export::cacti

=head1 SYNOPSIS

Cacti integration for Freeside

=head1 DESCRIPTION

This module in particular handles FS::part_export object creation for Cacti integration;
consult any existing L<FS::part_export> documentation for details on how that works.

=cut

use strict;

use base qw( FS::part_export );
use FS::Record qw( qsearchs qsearch );
use FS::UID qw( dbh );
use FS::cacti_page;

use File::Rsync;
use File::Slurp qw( slurp );
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
  'description'       => { label   => 'Description (can use tokens $contact, $ip_addr and $description)',
                           default => 'Freeside $contact $description $ip_addr' },
  'graphs_path'       => { label   => 'Graph Export Directory (user@host:/path/to/graphs/)',
                           default => '' },
  'import_freq'       => { label   => 'Minimum minutes between graph imports',
                           default => '5' },
  'max_graph_size'    => { label   => 'Maximum size per graph (MB)',
                           default => '5' },
  'delete_graphs'     => { label   => 'Delete associated graphs and data sources when unprovisioning', 
                           type    => 'checkbox',
                         },
  'cacti_graph_template_id'  => { 
    'label'    => 'Graph Template',
    'type'     => 'custom',
    'multiple' => 1,
  },
  'cacti_snmp_query_id'      => { 
    'label'    => 'SNMP Query ID',
    'type'     => 'custom',
    'multiple' => 1,
  },
  'cacti_snmp_query_type_id' => { 
    'label'    => 'SNMP Query Type ID',
    'type'     => 'custom',
    'multiple' => 1,
  },
  'cacti_snmp_field'         => { 
    'label'    => 'SNMP Field',
    'type'     => 'custom',
    'multiple' => 1,
  },
  'cacti_snmp_value'         => { 
    'label'    => 'SNMP Value',
    'type'     => 'custom',
    'multiple' => 1,
  },
;

%info = (
  'svc'                  => 'svc_broadband',
  'desc'                 => 'Export service to cacti server, for svc_broadband services',
  'post_config_element'  => '/edit/elements/part_export/cacti.html',
  'options'              => \%options,
  'notes'                => <<'END',
Add service to cacti upon provisioning, for broadband services.<BR>
See <A HREF="http://www.freeside.biz/mediawiki/index.php/Freeside:4:Documentation:Cacti#Connecting_Cacti_To_Freeside">documentation</A> for details.
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
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  foreach my $page (qsearch('cacti_page',{ svcnum => $svc_broadband->svcnum })) {
    my $error = $page->delete;
    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }
  my ($q,$error) = _delete_queue($self, $svc_broadband);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  return '';
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
    'contact'     => $svc_broadband->cust_main->contact,
    'svcnum'      => $svc_broadband->svcnum,
    'self'        => $self
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
    'delete_graphs' => $self->option('delete_graphs'),
  );
  return ($queue,$error);
}

# routines run by queued jobs

sub ssh_insert {
  my %opt = @_;
  my $self = $opt{'self'};

  # Option validation
  die "Non-numerical Host Template ID, check export configuration\n"
    unless $opt{'template_id'} =~ /^\d+$/;
  die "Non-numerical Graph Tree ID, check export configuration\n"
    unless $opt{'tree_id'} =~ /^\d*$/;

  # Add host to cacti
  my $desc = $opt{'description'};
  $desc =~ s/\$ip_addr/$opt{'hostname'}/g;
  $desc =~ s/\$description/$opt{'svc_desc'}/g;
  $desc =~ s/\$contact/$opt{'contact'}/g;
#for some reason, device names with apostrophes fail to export graphs in Cacti
#just removing them for now, someday maybe dig to figure out why
#  $desc =~ s/'/'\\''/g;
  $desc =~ s/'//g;
  my $cmd = $php
          . trailslash($opt{'script_path'})
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
         . trailslash($opt{'script_path'})
         . q(add_tree.php --type=node --node-type=host --tree-id=)
         . $opt{'tree_id'}
         . q( --host-id=)
         . $id;
    $response = ssh_cmd(%opt, 'command' => $cmd);
    unless ( $response =~ /Added Node node-id: \((\d+)\)/ ) {
      die "Host added, but error adding host to tree: $response";
    }
  }

  # Get list of graph templates for new id
  $cmd = $php
       . trailslash($opt{'script_path'}) 
       . q(freeside_cacti.php --get-graph-templates --host-template=)
       . $opt{'template_id'};
  my $ginfo = { map { $_ ? ($_ => undef) : () } split(/\n/,ssh_cmd(%opt, 'command' => $cmd)) };

  # Add extra config info
  my @xtragid = split("\n", $self->option('cacti_graph_template_id'));
  my @query_id = split("\n", $self->option('cacti_snmp_query_id'));
  my @query_type_id = split("\n", $self->option('cacti_snmp_query_type_id'));
  my @snmp_field = split("\n", $self->option('cacti_snmp_field'));
  my @snmp_value = split("\n", $self->option('cacti_snmp_value'));
  for (my $i = 0; $i < @xtragid; $i++) {
    my $gtid = $xtragid[$i];
    $ginfo->{$gtid} ||= [];
    push(@{$ginfo->{$gtid}},{
      'gtid'          => $gtid,
      'query_id'      => $query_id[$i],
      'query_type_id' => $query_type_id[$i],
      'snmp_field'    => $snmp_field[$i],
      'snmp_value'    => $snmp_value[$i],
    });
  }

  my @gdefs = map {
    ref($ginfo->{$_}) ? @{$ginfo->{$_}} : {'gtid' => $_}
  } keys %$ginfo;
  warn "Host ".$opt{'hostname'}." exported to cacti, but no graphs configured"
    unless @gdefs;

  # Create graphs
  my $gerror = '';
  foreach my $gdef (@gdefs) {
    # validate graph info
    my $gtid = $gdef->{'gtid'};
    next unless $gtid;
    $gerror .= " Bad graph template: $gtid"
      unless $gtid =~ /^\d+$/;
    my $isds = $gdef->{'query_id'} 
            || $gdef->{'query_type_id'} 
            || $gdef->{'snmp_field'} 
            || $gdef->{'snmp_value'};
    if ($isds) {
      $gerror .= " Bad SNMP Query Id: " . $gdef->{'query_id'}
        unless $gdef->{'query_id'} =~ /^\d+$/;
      $gerror .= " Bad SNMP Query Type Id: " . $gdef->{'query_type_id'}
        unless $gdef->{'query_type_id'} =~ /^\d+$/;
      $gerror .= " SNMP Field cannot contain apostrophe"
        if $gdef->{'snmp_field'} =~ /'/;
      $gerror .= " SNMP Value cannot contain apostrophe"
        if $gdef->{'snmp_value'} =~ /'/;
    }
    next if $gerror;

    # create the graph
    $cmd = $php
         . trailslash($opt{'script_path'})
         . q(add_graphs.php --graph-type=)
         . ($isds ? 'ds' : 'cg')
         . q( --graph-template-id=)
         . $gtid
         . q( --host-id=)
         . $id;
    if ($isds) {
      $cmd .= q( --snmp-query-id=)
           .  $gdef->{'query_id'}
           .  q( --snmp-query-type-id=)
           .  $gdef->{'query_type_id'}
           .  q( --snmp-field=')
           .  $gdef->{'snmp_field'}
           .  q(' --snmp-value=')
           .  $gdef->{'snmp_value'}
           .  q(');
    }
    $response = ssh_cmd(%opt, 'command' => $cmd);
    #might be more than one graph added, just testing success
    $gerror .= "Error creating graph $gtid: $response"
      unless $response =~ /Graph Added - graph-id: \((\d+)\)/;

  } #foreach $gtid

  # job fails, but partial export may have occurred
  die $gerror . " Partial export occurred\n" if $gerror;

  return '';
}

sub ssh_delete {
  my %opt = @_;
  my $cmd = $php
          . trailslash($opt{'script_path'}) 
          . q(freeside_cacti.php --drop-device --ip=')
          . $opt{'hostname'}
          . q(');
  $cmd .= q( --delete-graphs)
    if $opt{'delete_graphs'};
  my $response = ssh_cmd(%opt, 'command' => $cmd);
  die "Error removing from cacti: " . $response
    if $response;
  return '';
}

=head1 SUBROUTINES

=over 4

=item process_graphs JOB PARAM

Intended to be run as an FS::queue job.

Copies graphs for a single service from Cacti export directory to FS cache,
generates basic html pages for this service with base64-encoded graphs embedded, 
and stores the generated pages in the database.

=back

=cut

sub process_graphs {
  my ($job,$param) = @_;

  $job->update_statustext(10);
  my $cachedir = trailslash($FS::UID::cache_dir,'cache.'.$FS::UID::datasrc,'cacti-graphs');

  # load the service
  my $svcnum = $param->{'svcnum'} || die "No svcnum specified";
  my $svc = qsearchs({
   'table'   => 'svc_broadband',
   'hashref' => { 'svcnum' => $svcnum },
  }) || die "Could not load svcnum $svcnum";

  # load relevant FS::part_export::cacti object
  my ($self) = $svc->cust_svc->part_svc->part_export('cacti');

  $job->update_statustext(20);

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  # check for existing pages
  my $now = time;
  my @oldpages = qsearch({
    'table'    => 'cacti_page',
    'hashref'  => { 'svcnum' => $svcnum, 'exportnum' => $self->exportnum },
    'select'   => 'cacti_pagenum, exportnum, svcnum, graphnum, imported', #no need to load old content
    'order_by' => 'ORDER BY graphnum',
  });
  if (@oldpages) {
    #if pages are recent enough, do nothing and return
    if ($oldpages[0]->imported > $self->exptime($now)) {
      $job->update_statustext(100);
      return '';
    }
    #delete old pages
    foreach my $oldpage (@oldpages) {
      my $error = $oldpage->delete;
      if ($error) {
        $dbh->rollback if $oldAutoCommit;
        die $error;
      }
    }
  }

  $job->update_statustext(30);

  # get list of graphs for this svc from cacti server
  my $cmd = $php
          . trailslash($self->option('script_path'))
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

  # copy graphs from cacti server to cache
  # requires version 2.6.4 of rsync, released March 2005
  my $rsync = File::Rsync->new({
    'rsh'       => 'ssh',
    'verbose'   => 1,
    'recursive' => 1,
    'quote-src' => 1,
    'quote-dst' => 1,
    'source'    => trailslash($self->option('graphs_path')),
    'dest'      => $cachedir,
    'include'   => [
      (map { q('**graph_).${$_}[0].q(*.png') } @graphs),
      (map { q('**thumb_).${$_}[0].q(.png') } @graphs),
      q('*/'),
      q('- *'),
    ],
  });
  #don't know why a regular $rsync->exec isn't doing includes right, but this does
  my $rscmd = join(' ',@{$rsync->getcmd()});
  my $error = system($rscmd);
  die "rsync ($rscmd) failed with exit status $error" if $error;

  $job->update_statustext(50);

  # create html file contents
  my $svchead = q(<!-- UPDATED ) . $now . qq( -->)
              . '<H2 STYLE="margin-top: 0;">Service #' . $svcnum . '</H2>'
              . q(<P>Last updated ) . scalar(localtime($now)) . q(</P>);
  my $svchtml = $svchead;
  my $maxgraph = 1024 * 1024 * ($self->options('max_graph_size') || 5);
  my $nographs = 1;
  for (my $i = 0; $i <= $#graphs; $i++) {
    my $graph = $graphs[$i];
    my $thumbfile = $cachedir . 'graphs/thumb_' . $$graph[0] . '.png';
    if (-e $thumbfile) {
      if ( stat($thumbfile)->size() < $maxgraph ) {
        $nographs = 0;
        # add graph to main file
        my $graphhead = q(<H3>) . $$graph[1] . q(</H3>);
        $svchtml .= $graphhead;
        $svchtml .= anchor_tag( $svcnum, $$graph[0], img_tag($thumbfile) );
        # create graph details file
        my $graphhtml = $svchead . $graphhead;
        my $nodetail = 1;
        my $j = 1;
        while (-e (my $graphfile = $cachedir.'graphs/graph_'.$$graph[0].'_'.$j.'.png')) {
          if ( stat($graphfile)->size() < $maxgraph ) {
            $nodetail = 0;
            $graphhtml .= img_tag($graphfile);
          }
          unlink($graphfile);
          $j++;
        }
        $graphhtml .= '<P>No detail graphs to display for this graph</P>'
          if $nodetail;
        my $newobj = new FS::cacti_page {
          'exportnum' => $self->exportnum,
          'svcnum'    => $svcnum,
          'graphnum'  => $$graph[0],
          'imported'  => $now,
          'content'   => $graphhtml,
        };
        $error = $newobj->insert;
        if ($error) {
          $dbh->rollback if $oldAutoCommit;
          die $error;
        }
      } else {
        $svchtml .= qq(<P STYLE="color: #FF0000">File $thumbfile is too large, skipping</P>);
      }
      unlink($thumbfile);
    } else {
      $svchtml .= qq(<P STYLE="color: #FF0000">File $thumbfile does not exist, skipping</P>);
    }
    $job->update_statustext(49 + int($i / @graphs) * 50);
  }
  $svchtml .= '<P>No graphs to display for this service</P>'
    if $nographs;
  my $newobj = new FS::cacti_page {
    'exportnum' => $self->exportnum,
    'svcnum'    => $svcnum,
    'graphnum'  => '',
    'imported'  => $now,
    'content'   => $svchtml,
  };
  $error  = $newobj->insert;
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    die $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  $job->update_statustext(100);
  return '';
}

sub img_tag {
  my $somefile = shift;
  return q(<IMG SRC="data:image/png;base64,)
       . encode_base64(slurp($somefile,binmode=>':raw'),'')
       . qq(" STYLE="margin-bottom: 1em;"><BR>);
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
  die "Error running SSH command: ". $opt->{'command'}. ' ERROR: ' . $ssh->error if $ssh->error;
  die $errput if $errput;
  return $output;
}

#there's probably a better place to put this?
#makes sure there's a trailing slash between/after input
#doesn't add leading slashes
sub trailslash {
  my @paths = @_;
  my $out = '';
  foreach my $path (@paths) {
    $out .= $path;
    $out .= '/' unless $out =~ /\/$/;
  }
  return $out;
}

=head1 METHODS

=over 4

=item cleanup

Removes all expired graphs for this export from the database.

=cut

sub cleanup {
  my $self = shift;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  my $sth = $dbh->prepare('DELETE FROM cacti_page WHERE exportnum = ? and imported <= ?') 
    or do {
      $dbh->rollback if $oldAutoCommit;
      return $dbh->errstr;
    };
  $sth->execute($self->exportnum,$self->exptime)
    or do {
      $dbh->rollback if $oldAutoCommit;
      return $dbh->errstr;
    };
  $dbh->commit or return $dbh->errstr if $oldAutoCommit;
  return '';
}

=item exptime [ TIME ]

Accepts optional current time, defaults to actual current time.

Returns timestamp for the oldest possible non-expired graph import,
based on the import_freq option.

=cut

sub exptime {
  my $self = shift;
  my $now = shift || time;
  return $now - 60 * ($self->option('import_freq') || 5);
}

=back

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


