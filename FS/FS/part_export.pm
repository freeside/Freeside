package FS::part_export;
use base qw( FS::option_Common FS::m2m_Common );

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG %exports );
use Exporter;
use Tie::IxHash;
use FS::Record qw( qsearch qsearchs dbh );
use FS::part_svc;
use FS::part_export_option;
use FS::part_export_machine;
use FS::svc_export_machine;

#for export modules, though they should probably just use it themselves
use FS::queue;

@EXPORT_OK = qw(export_info);

$DEBUG = 0;

=head1 NAME

FS::part_export - Object methods for part_export records

=head1 SYNOPSIS

  use FS::part_export;

  $record = new FS::part_export \%hash;
  $record = new FS::part_export { 'column' => 'value' };

  #($new_record, $options) = $template_recored->clone( $svcpart );

  $error = $record->insert( { 'option' => 'value' } );
  $error = $record->insert( \%options );

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_export object represents an export of Freeside data to an external
provisioning system.  FS::part_export inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item exportnum - primary key

=item exportname - Descriptive name

=item machine - Machine name 

=item exporttype - Export type

=item nodomain - blank or "Y" : usernames are exported to this service with no domain

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new export.  To add the export to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_export'; }

=cut

#=item clone SVCPART
#
#An alternate constructor.  Creates a new export by duplicating an existing
#export.  The given svcpart is assigned to the new export.
#
#Returns a list consisting of the new export object and a hashref of options.
#
#=cut
#
#sub clone {
#  my $self = shift;
#  my $class = ref($self);
#  my %hash = $self->hash;
#  $hash{'exportnum'} = '';
#  $hash{'svcpart'} = shift;
#  ( $class->new( \%hash ),
#    { map { $_->optionname => $_->optionvalue }
#        qsearch('part_export_option', { 'exportnum' => $self->exportnum } )
#    }
#  );
#}

=item insert HASHREF

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If a hash reference of options is supplied, part_export_option records are
created (see L<FS::part_export_option>).

=cut

sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert(@_)
           || $self->replace;
  # use replace to do all the part_export_machine and default_machine stuff
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item delete

Delete this record from the database.

=cut

#foreign keys would make this much less tedious... grr dumb mysql
sub delete {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  # clean up export_nas records
  my $error = $self->process_m2m(
    'link_table'    => 'export_nas',
    'target_table'  => 'nas',
    'params'        => [],
  ) || $self->process_m2m(
    'link_table'    => 'export_svc',
    'target_table'  => 'part_svc',
    'params'        => [],
  ) || $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $export_svc ( $self->export_svc ) {
    my $error = $export_svc->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  foreach my $part_export_machine ( $self->part_export_machine ) {
    my $error = $part_export_machine->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item replace [ OLD_RECORD ] [ HASHREF | OPTION => VALUE ... ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

If a list or hash reference of options is supplied, option records are created
or modified.

=cut

sub replace {
  my $self = shift;
  my $old = $self->replace_old;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  my $error;

  if ( $self->part_export_machine_textarea ) {

    my %part_export_machine = map { $_->machine => $_ }
                                $self->part_export_machine;

    my @machines = map { $_ =~ s/^\s+//; $_ =~ s/\s+$//; $_ }
                     grep /\S/,
                       split /[\n\r]{1,2}/,
                         $self->part_export_machine_textarea;

    foreach my $machine ( @machines ) {

      if ( $part_export_machine{$machine} ) {

        if ( $part_export_machine{$machine}->disabled eq 'Y' ) {
          $part_export_machine{$machine}->disabled('');
          $error = $part_export_machine{$machine}->replace;
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return $error;
          }
        }

        if ( $self->default_machine_name eq $machine ) {
          $self->default_machine( $part_export_machine{$machine}->machinenum );
        }

        delete $part_export_machine{$machine}; #so we don't disable it below

      } else {

        my $part_export_machine = new FS::part_export_machine {
                                        'exportnum' => $self->exportnum,
                                        'machine'   => $machine
                                      };
        $error = $part_export_machine->insert;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
  
        if ( $self->default_machine_name eq $machine ) {
          $self->default_machine( $part_export_machine->machinenum );
        }
      }

    }

    foreach my $part_export_machine ( values %part_export_machine ) {
      $part_export_machine->disabled('Y');
      $error = $part_export_machine->replace;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }

    if ( $old->machine ne '_SVC_MACHINE' ) {
      # then set up the default for any already-attached export_svcs
      foreach my $export_svc ( $self->export_svc ) {
        my @svcs = qsearch('cust_svc', { 'svcpart' => $export_svc->svcpart });
        foreach my $cust_svc ( @svcs ) {
          my $svc_export_machine = FS::svc_export_machine->new({
              'exportnum'   => $self->exportnum,
              'svcnum'      => $cust_svc->svcnum,
              'machinenum'  => $self->default_machine,
          });
          $error ||= $svc_export_machine->insert;
        }
      }
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    } # if switching to selectable hosts

  } elsif ( $old->machine eq '_SVC_MACHINE' ) {
    # then we're switching from selectable to non-selectable
    foreach my $svc_export_machine (
      qsearch('svc_export_machine', { 'exportnum' => $self->exportnum })
    ) {
      $error ||= $svc_export_machine->delete;
    }
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

  }

  $error = $self->SUPER::replace(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $self->machine eq '_SVC_MACHINE' and ! $self->default_machine ) {
    $dbh->rollback if $oldAutoCommit;
    return "no default export host selected";
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}

=item check

Checks all fields to make sure this is a valid export.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;
  my $error = 
    $self->ut_numbern('exportnum')
    || $self->ut_textn('exportname')
    || $self->ut_domainn('machine')
    || $self->ut_alpha('exporttype')
  ;

  if ( $self->machine eq '_SVC_MACHINE' ) {
    $error ||= $self->ut_numbern('default_machine')
  } else {
    $self->set('default_machine', '');
  }

  return $error if $error;

  $self->nodomain =~ /^(Y?)$/ or return "Illegal nodomain: ". $self->nodomain;
  $self->nodomain($1);

  $self->deprecated(1); #BLAH

  #check exporttype?

  $self->SUPER::check;
}

=item label

Returns a label for this export, "exportname||exportype (machine)".  

=cut

sub label {
  my $self = shift;
  ($self->exportname || $self->exporttype ). ' ('. $self->machine. ')';
}

=item label_html

Returns a label for this export, "exportname: exporttype to machine".

=cut

sub label_html {
  my $self = shift;

  my $label = $self->exportname
                ? '<B>'. $self->exportname. '</B>: ' #<BR>'.
                : '';

  $label .= $self->exporttype;

  $label .= ' to '. ( $self->machine eq '_SVC_MACHINE'
                        ? 'per-service hostname'
                        : $self->machine
                    )
    if $self->machine;

  $label;

}

#=item part_svc
#
#Returns the service definition (see L<FS::part_svc>) for this export.
#
#=cut
#
#sub part_svc {
#  my $self = shift;
#  qsearchs('part_svc', { svcpart => $self->svcpart } );
#}

sub part_svc {
  use Carp;
  croak "FS::part_export::part_svc deprecated";
  #confess "FS::part_export::part_svc deprecated";
}

=item svc_x

Returns a list of associated FS::svc_* records.

=cut

sub svc_x {
  my $self = shift;
  map { $_->svc_x } $self->cust_svc;
}

=item cust_svc

Returns a list of associated FS::cust_svc records.

=cut

sub cust_svc {
  my $self = shift;
  map { qsearch('cust_svc', { 'svcpart' => $_->svcpart } ) }
    grep { qsearch('cust_svc', { 'svcpart' => $_->svcpart } ) }
      $self->export_svc;
}

=item part_export_machine

Returns all machines as FS::part_export_machine objects (see
L<FS::part_export_machine>).

=cut

sub part_export_machine {
  my $self = shift;
  map { $_ } #behavior of sort undefined in scalar context
    sort { $a->machine cmp $b->machine }
      qsearch('part_export_machine', { 'exportnum' => $self->exportnum } );
}

=item export_svc

Returns a list of associated FS::export_svc records.

=item export_device

Returns a list of associated FS::export_device records.

=item part_export_option

Returns all options as FS::part_export_option objects (see
L<FS::part_export_option>).

=cut

sub part_export_option {
  my $self = shift;
  $self->option_objects;
}

=item options 

Returns a list of option names and values suitable for assigning to a hash.

=item option OPTIONNAME

Returns the option value for the given name, or the empty string.

=item _rebless

Reblesses the object into the FS::part_export::EXPORTTYPE class, where
EXPORTTYPE is the object's I<exporttype> field.  There should be better docs
on how to create new exports, but until then, see L</NEW EXPORT CLASSES>.

=cut

sub _rebless {
  my $self = shift;
  my $exporttype = $self->exporttype;
  my $class = ref($self). "::$exporttype";
  eval "use $class;";
  #die $@ if $@;
  bless($self, $class) unless $@;
  $self;
}

=item svc_machine SVC_X

Return the export hostname for SVC_X.

=cut

sub svc_machine {
  my( $self, $svc_x ) = @_;

  return $self->machine unless $self->machine eq '_SVC_MACHINE';

  my $svc_export_machine = qsearchs('svc_export_machine', {
    'svcnum'    => $svc_x->svcnum,
    'exportnum' => $self->exportnum,
  });

  if (!$svc_export_machine) {
    warn "No hostname selected for ".($self->exportname || $self->exporttype);
    return $self->default_export_machine->machine;
  }

  return $svc_export_machine->part_export_machine->machine;
}

=item default_export_machine

Return the default export hostname for this export.

=cut

sub default_export_machine {
  my $self = shift;
  my $machinenum = $self->default_machine;
  if ( $machinenum ) {
    my $default_machine = FS::part_export_machine->by_key($machinenum);
    return $default_machine->machine if $default_machine;
  }
  # this should not happen
  die "no default export hostname for export ".$self->exportnum;
}

#these should probably all go away, just let the subclasses define em

=item export_insert SVC_OBJECT

=cut

sub export_insert {
  my $self = shift;
  #$self->rebless;
  $self->_export_insert(@_);
}

#sub AUTOLOAD {
#  my $self = shift;
#  $self->rebless;
#  my $method = $AUTOLOAD;
#  #$method =~ s/::(\w+)$/::_$1/; #infinite loop prevention
#  $method =~ s/::(\w+)$/_$1/; #infinite loop prevention
#  $self->$method(@_);
#}

=item export_replace NEW OLD

=cut

sub export_replace {
  my $self = shift;
  #$self->rebless;
  $self->_export_replace(@_);
}

=item export_delete

=cut

sub export_delete {
  my $self = shift;
  #$self->rebless;
  $self->_export_delete(@_);
}

=item export_suspend

=cut

sub export_suspend {
  my $self = shift;
  #$self->rebless;
  $self->_export_suspend(@_);
}

=item export_unsuspend

=cut

sub export_unsuspend {
  my $self = shift;
  #$self->rebless;
  $self->_export_unsuspend(@_);
}

#fallbacks providing useful error messages intead of infinite loops
sub _export_insert {
  my $self = shift;
  return "_export_insert: unknown export type ". $self->exporttype;
}

sub _export_replace {
  my $self = shift;
  return "_export_replace: unknown export type ". $self->exporttype;
}

sub _export_delete {
  my $self = shift;
  return "_export_delete: unknown export type ". $self->exporttype;
}

#call svcdb-specific fallbacks

sub _export_suspend {
  my $self = shift;
  #warn "warning: _export_suspened unimplemented for". ref($self);
  my $svc_x = shift;
  my $new = $svc_x->clone_suspended;
  $self->_export_replace( $new, $svc_x );
}

sub _export_unsuspend {
  my $self = shift;
  #warn "warning: _export_unsuspend unimplemented for ". ref($self);
  my $svc_x = shift;
  my $old = $svc_x->clone_kludge_unsuspend;
  $self->_export_replace( $svc_x, $old );
}

=item export_links SVC_OBJECT ARRAYREF

Adds a list of web elements to ARRAYREF specific to this export and SVC_OBJECT.
The elements are displayed in the UI to lead the the operator to external
configuration, monitoring, and similar tools.

=item export_getsettings SVC_OBJECT SETTINGS_HASHREF DEFAUTS_HASHREF

Adds a hashref of settings to SETTINGSREF specific to this export and
SVC_OBJECT.  The elements can be displayed in the UI on the service view.

DEFAULTSREF is a hashref with the same keys where true values indicate the
setting is a default (and thus can be displayed in the UI with less emphasis,
or hidden by default).

=item actions

Adds one or more "action" links to the export's display in 
browse/part_export.cgi.  Should return pairs of values.  The first is 
the link label; the second is the Mason path to a document to load.
The document will show in a popup.

=cut

sub actions { }

=cut

=item weight

Returns the 'weight' element from the export's %info hash, or 0 if there is 
no weight defined.

=cut

sub weight {
  my $self = shift;
  export_info()->{$self->exporttype}->{'weight'} || 0;
}

=item info

Returns a reference to (a copy of) the export's %info hash.

=cut

sub info {
  my $self = shift;
  $self->{_info} ||= { 
    %{ export_info()->{$self->exporttype} }
  };
}

#default fallbacks... FS::part_export::DID_Common ?
sub can_get_dids { 0; }
sub get_dids_can_tollfree { 0; }
sub get_dids_can_manual   { 0; }
sub get_dids_can_edit     { 0; } #don't use without can_manual, otherwise the
                                 # DID selector provisions a new number from
                                 # inventory each edit
sub get_dids_npa_select   { 1; }

=back

=head1 SUBROUTINES

=over 4

=item export_info [ SVCDB ]

Returns a hash reference of the exports for the given I<svcdb>, or if no
I<svcdb> is specified, for all exports.  The keys of the hash are
I<exporttype>s and the values are again hash references containing information
on the export:

  'desc'     => 'Description',
  'options'  => {
                  'option'  => { label=>'Option Label' },
                  'option2' => { label=>'Another label' },
                },
  'nodomain' => 'Y', #or ''
  'notes'    => 'Additional notes',

=cut

sub export_info {
  #warn $_[0];
  return $exports{$_[0]} || {} if @_;
  #{ map { %{$exports{$_}} } keys %exports };
  my $r = { map { %{$exports{$_}} } keys %exports };
}


sub _upgrade_data {  #class method
  my ($class, %opts) = @_;

  my @part_export_option = qsearch('part_export_option', { 'optionname' => 'overlimit_groups' });
  foreach my $opt ( @part_export_option ) {
    next if $opt->optionvalue =~ /^[\d\s]+$/ || !$opt->optionvalue;
    my @groupnames = split(' ',$opt->optionvalue);
    my @groupnums;
    my $error = '';
    foreach my $groupname ( @groupnames ) {
        my $g = qsearchs('radius_group', { 'groupname' => $groupname } );
        unless ( $g ) {
            $g = new FS::radius_group {
                            'groupname' => $groupname,
                            'description' => $groupname,
                            };
            $error = $g->insert;
            die $error if $error;
        }
        push @groupnums, $g->groupnum;
    }
    $opt->optionvalue(join(' ',@groupnums));
    $error = $opt->replace;
    die $error if $error;
  }
  # for exports that have selectable hostnames, make sure all services
  # have a hostname selected
  foreach my $part_export (
    qsearch('part_export', { 'machine' => '_SVC_MACHINE' })
  ) {

    my $exportnum = $part_export->exportnum;
    my $machinenum = $part_export->default_machine;
    if (!$machinenum) {
      my ($first) = $part_export->part_export_machine;
      if (!$first) {
        # user intervention really is required.
        die "Export $exportnum has no hostname options defined.\n".
            "You must correct this before upgrading.\n";
      }
      # warn about this, because we might not choose the right one
      warn "Export $exportnum (". $part_export->exporttype.
           ") has no default hostname.  Setting to ".$first->machine."\n";
      $machinenum = $first->machinenum;
      $part_export->set('default_machine', $machinenum);
      my $error = $part_export->replace;
      die $error if $error;
    }

    # the service belongs to a service def that uses this export
    # and there is not a hostname selected for this export for that service
    my $join = ' JOIN export_svc USING ( svcpart )'.
               ' LEFT JOIN svc_export_machine'.
               ' ON ( cust_svc.svcnum = svc_export_machine.svcnum'.
               ' AND export_svc.exportnum = svc_export_machine.exportnum )';

    my @svcs = qsearch( {
          'select'    => 'cust_svc.*',
          'table'     => 'cust_svc',
          'addl_from' => $join,
          'extra_sql' => ' WHERE svcexportmachinenum IS NULL'.
                         ' AND export_svc.exportnum = '.$part_export->exportnum,
      } );
    foreach my $cust_svc (@svcs) {
      my $svc_export_machine = FS::svc_export_machine->new({
          'exportnum'   => $exportnum,
          'machinenum'  => $machinenum,
          'svcnum'      => $cust_svc->svcnum,
      });
      my $error = $svc_export_machine->insert;
      die $error if $error;
    }
  }

  # pass downstream
  my %exports_in_use;
  $exports_in_use{ref $_} = 1 foreach qsearch('part_export', {});
  foreach (keys(%exports_in_use)) {
    $_->_upgrade_exporttype(%opts) if $_->can('_upgrade_exporttype');
  }
}

#=item exporttype2svcdb EXPORTTYPE
#
#Returns the applicable I<svcdb> for an I<exporttype>.
#
#=cut
#
#sub exporttype2svcdb {
#  my $exporttype = $_[0];
#  foreach my $svcdb ( keys %exports ) {
#    return $svcdb if grep { $exporttype eq $_ } keys %{$exports{$svcdb}};
#  }
#  '';
#}

#false laziness w/part_pkg & cdr
foreach my $INC ( @INC ) {
  foreach my $file ( glob("$INC/FS/part_export/*.pm") ) {
    warn "attempting to load export info from $file\n" if $DEBUG;
    $file =~ /\/(\w+)\.pm$/ or do {
      warn "unrecognized file in $INC/FS/part_export/: $file\n";
      next;
    };
    my $mod = $1;
    my $info = eval "use FS::part_export::$mod; ".
                    "\\%FS::part_export::$mod\::info;";
    if ( $@ ) {
      die "error using FS::part_export::$mod (skipping): $@\n" if $@;
      next;
    }
    unless ( keys %$info ) {
      warn "no %info hash found in FS::part_export::$mod, skipping\n"
        unless $mod =~ /^(passwdfile|null|.+_Common)$/; #hack but what the heck
      next;
    }
    warn "got export info from FS::part_export::$mod: $info\n" if $DEBUG;
    no strict 'refs';
    foreach my $svc (
      ref($info->{'svc'}) ? @{$info->{'svc'}} : $info->{'svc'}
    ) {
      unless ( $svc ) {
        warn "blank svc for FS::part_export::$mod (skipping)\n";
        next;
      }
      $exports{$svc}->{$mod} = $info;
    }
  }
}

=back

=head1 NEW EXPORT CLASSES

A module should be added in FS/FS/part_export/ (an example may be found in
eg/export_template.pm)

=head1 BUGS

Hmm... cust_export class (not necessarily a database table...) ... ?

deprecated column...

=head1 SEE ALSO

L<FS::part_export_option>, L<FS::export_svc>, L<FS::svc_acct>,
L<FS::svc_domain>,
L<FS::svc_forward>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

