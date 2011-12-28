package FS::part_export::broadband_nas;

use strict;
use vars qw(%info $DEBUG);
use base 'FS::part_export';
use FS::Record qw(qsearch qsearchs);
use FS::nas;
use FS::export_nas;
use FS::svc_broadband;
use FS::part_export::sqlradius;
use Tie::IxHash;

$DEBUG = 0;

my $me = '['.__PACKAGE__.']';

tie my %options, 'Tie::IxHash',
  '1' => { type => 'title', label => 'Defaults' },
  default_shortname => { label => 'Short name' },
  default_secret    => { label => 'Shared secret' },
  default_type      => { label => 'Type' },
  default_ports     => { label => 'Ports' },
  default_server    => { label => 'Virtual server' },
  default_community => { label => 'Community' },
  '2' => { type => 'title', label => 'Export to' },
  # default export_nas entries will be inserted at runtime
;

FS::UID->install_callback(
  sub {
    #creating new options based on records in a table,
    #has to be done after initialization
    foreach ( FS::part_export::sqlradius->all_sqlradius ) {
      my $name = 'exportnum' . $_->exportnum;
      $options{$name} = 
        { type => 'checkbox', label => $_->exportnum . ': ' . $_->label };

    }
  }
);

%info = (
  'svc'     => 'svc_broadband',
  'desc'    => 'Create a NAS entry in Freeside',
  'options' => \%options,
  'weight'  => 10,
  'notes'   => <<'END'
<p>Create an entry in the NAS (RADIUS client) table, inheriting the IP 
address and description of the broadband service.  This can be used 
with 'sqlradius' or 'broadband_sqlradius' exports to maintain entries
in the client table on a RADIUS server.</p>
<p>Most broadband configurations should not use this, even if they use 
RADIUS for access control.</p>
END
);

=item export_insert NEWSVC

=item export_replace NEWSVC OLDSVC

NEWSVC can contain pseudo-field entries for fields in nas.  Those changes 
will be applied to the attached NAS record.

=cut

sub export_insert {
  my $self = shift;
  my $svc_broadband = shift;
  my %hash = map { $_ => $svc_broadband->get($_) } FS::nas->fields;
  my $nas = $self->default_nas(
    %hash,
    'nasname'     => $svc_broadband->ip_addr,
    'description' => $svc_broadband->description,
    'svcnum'      => $svc_broadband->svcnum,
  );

  my $error = 
      $nas->insert()
   || $nas->process_m2m('link_table' => 'export_nas',
                        'target_table' => 'part_export',
                        'params' => { $self->options });
  die $error if $error;
  return;
}

sub export_delete {
  my $self = shift;
  my $svc_broadband = shift;
  my $svcnum = $svc_broadband->svcnum;
  my $nas = qsearchs('nas', { 'svcnum' => $svcnum });
  if ( !$nas ) {
    # we were going to delete it anyway...
    warn "linked NAS with svcnum $svcnum not found for deletion\n";
    return;
  }
  my $error = $nas->delete; # will clean up export_nas records
  die $error if $error;
  return;
}

sub export_replace {
  my $self = shift;
  my ($new_svc, $old_svc) = (shift, shift);

  my $svcnum = $new_svc->svcnum;
  my $nas = qsearchs('nas', { 'svcnum' => $svcnum });
  if ( !$nas ) {
    warn "linked nas with svcnum $svcnum not found for update, creating new\n";
    # then we should insert it
    # (this happens if the nas table is wiped out, or if the broadband_nas 
    # export is newly applied to an existing svcpart)
    return $self->export_insert($new_svc);
  }

  my %hash = $new_svc->hash;
  foreach (FS::nas->fields) {
    $nas->set($_, $hash{$_}) if exists($hash{$_});
  }
  
  $nas->nasname($new_svc->ip_addr); # this must always be true

  my $error = $nas->replace;
  die $error if $error;
  return;
}

=item default_nas HASH

Returns a new L<FS::nas> object containing the default values, plus anything
in HASH.

=cut

sub default_nas {
  my $self = shift;
  FS::nas->new({
    map( { $_ => $self->option("default_$_") }
      qw(shortname type ports secret server community)
    ),
    @_
  });
}


1;
