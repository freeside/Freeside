package FS::part_svc;
use base qw(FS::Record);

use strict;
use vars qw( $DEBUG );
use Tie::IxHash;
use FS::Record qw( qsearch qsearchs fields dbh );
use FS::Schema qw( dbdef );
use FS::part_svc_column;
use FS::part_export;
use FS::export_svc;
use FS::cust_svc;
use FS::part_svc_class;

FS::UID->install_callback(sub {
    # preload the cache and make sure all modules load
    my $svc_defs = FS::part_svc->_svc_defs;
});

$DEBUG = 0;

=head1 NAME

FS::part_svc - Object methods for part_svc objects

=head1 SYNOPSIS

  use FS::part_svc;

  $record = new FS::part_svc \%hash
  $record = new FS::part_svc { 'column' => 'value' };

  $error = $record->insert;
  $error = $record->insert( [ 'pseudofield' ] );
  $error = $record->insert( [ 'pseudofield' ], \%exportnums );

  $error = $new_record->replace($old_record);
  $error = $new_record->replace($old_record, '1.3-COMPAT', [ 'pseudofield' ] );
  $error = $new_record->replace($old_record, '1.3-COMPAT', [ 'pseudofield' ], \%exportnums );

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_svc represents a service definition.  FS::part_svc inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item svcpart - primary key (assigned automatically for new service definitions)

=item svc - text name of this service definition

=item comment - text comment of this service definition

=item svcdb - table used for this service.  See L<FS::svc_acct>,
L<FS::svc_domain>, and L<FS::svc_forward>, among others.

=item classnum - Optional service class (see L<FS::svc_class>)

=item disabled - Disabled flag, empty or `Y'

=item preserve - Preserve after cancellation, empty or 'Y'

=item selfservice_access - Access allowed to the service via self-service:
empty for full access, "readonly" for read-only, "hidden" to hide it entirely

=item restrict_edit_password - Require the "Provision customer service" access
right to change the password field, rather than just "Edit password".  Only
relevant to svc_acct for now.

=item has_router - Allow the service to have an L<FS::router> connected 
through it.  Probably only relevant to svc_broadband, svc_acct, and svc_dsl
for now.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new service definition.  To add the service definition to the
database, see L<"insert">.

=cut

sub table { 'part_svc'; }

=item insert [ EXTRA_FIELDS_ARRAYREF [ , EXPORTNUMS_HASHREF [ , JOB ] ] ] 

Adds this service definition to the database.  If there is an error, returns
the error, otherwise returns false.

The following pseudo-fields may be defined, and will be maintained in
the part_svc_column table appropriately (see L<FS::part_svc_column>).

=over 4

=item I<svcdb>__I<field> - Default or fixed value for I<field> in I<svcdb>.

=item I<svcdb>__I<field>_label

=item I<svcdb>__I<field>_flag - defines I<svcdb>__I<field> action: null or empty (no default), `D' for default, `F' for fixed (unchangeable), , `S' for selectable choice, `M' for manual selection from inventory, or `A' for automatic selection from inventory.  For virtual fields, can also be 'X' for excluded.

=item I<svcdb>__I<field>_required - I<field> should always have a true value

=back

If you want to add part_svc_column records for fields that do not exist as
fields in the I<svcdb> table, make sure to list then in 
EXTRA_FIELDS_ARRAYREF also.

If EXPORTNUMS_HASHREF is specified (keys are exportnums and values are
boolean), the appopriate export_svc records will be inserted.

TODOC: JOB

=cut

sub insert {
  my $self = shift;
  my @fields = ();
  @fields = @{shift(@_)} if @_;
  my $exportnums = shift || {};
  my $job = '';
  $job = shift if @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  # add part_svc_column records

  my $svcdb = $self->svcdb;
  foreach my $field (fields($svcdb), @fields) {
    next if $field eq 'svcnum';
    my $prefix = $svcdb.'__';
    if ( defined( $self->getfield($prefix.$field.'_flag'))
      or defined($self->getfield($prefix.$field.'_required'))
      or length($self->getfield($prefix.$field.'_label'))
    ) {
      my $part_svc_column = $self->part_svc_column($field);
      my $previous = qsearchs('part_svc_column', {
        'svcpart'    => $self->svcpart,
        'columnname' => $field,
      } );

      my $flag  = $self->getfield($prefix.$field.'_flag');
      my $label = $self->getfield($prefix.$field.'_label');
      my $required = $self->getfield($prefix.$field.'_required') ? 'Y' : '';
      if ( uc($flag) =~ /^([A-Z])$/ || $label !~ /^\s*$/ ) {

        if ( uc($flag) =~ /^([A-Z])$/ ) {
          my $parser = FS::part_svc->svc_table_fields($svcdb)->{$field}->{parse}
                       || sub { shift };
          $part_svc_column->setfield('columnflag', $1);
          $part_svc_column->setfield('columnvalue',
            &$parser($self->getfield($prefix.$field))
          );
        }

        $part_svc_column->setfield('columnlabel', $label)
          if $label !~ /^\s*$/;

        $part_svc_column->setfield('required', $required);

        if ( $previous ) {
          $error = $part_svc_column->replace($previous);
        } else {
          $error = $part_svc_column->insert;
        }

      } else {
        $error = $previous ? $previous->delete : '';
      }
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

    }
  }

  # add export_svc records
  my @exportnums = grep $exportnums->{$_}, keys %$exportnums;
  my $slice = 100/scalar(@exportnums) if @exportnums;
  my $done = 0;
  foreach my $exportnum ( @exportnums ) {
    my $export_svc = new FS::export_svc ( {
      'exportnum' => $exportnum,
      'svcpart'   => $self->svcpart,
      'role'      => $exportnums->{$exportnum},
    } );
    $error = $export_svc->insert($job, $slice*$done++, $slice);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  # XXX shouldn't this update fixed values?

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item delete

Currently unimplemented.  Set the "disabled" field instead.

=cut

sub delete {
  return "Can't (yet?) delete service definitions.";
# check & make sure the svcpart isn't in cust_svc or pkg_svc (in any packages)?
}

=item replace OLD_RECORD [ '1.3-COMPAT' [ , EXTRA_FIELDS_ARRAYREF [ , EXPORTNUMS_HASHREF [ , JOB ] ] ] ]

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

TODOC: 1.3-COMPAT

TODOC: EXTRA_FIELDS_ARRAYREF (same as insert method)

TODOC: JOB

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );
  my $compat = '';
  my @fields = ();
  my $exportnums;
  my $job = '';
  if ( @_ && $_[0] eq '1.3-COMPAT' ) {
    shift;
    $compat = '1.3';
    @fields = @{shift(@_)} if @_;
    $exportnums = @_ ? shift : '';
    $job = shift if @_;
  } else {
    return 'non-1.3-COMPAT interface not yet written';
    #not yet implemented
  }

  return "Can't change svcdb for an existing service definition!"
    unless $old->svcdb eq $new->svcdb;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $new->SUPER::replace( $old );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $compat eq '1.3' ) {

   # maintain part_svc_column records

    my $svcdb = $new->svcdb;
    foreach my $field (fields($svcdb),@fields) {
      next if $field eq 'svcnum';
      my $prefix = $svcdb.'__';
      if ( defined( $new->getfield($prefix.$field.'_flag'))
        or defined($new->getfield($prefix.$field.'_required'))
        or length($new->getfield($prefix.$field.'_label'))
      ) {
        my $part_svc_column = $new->part_svc_column($field);
        my $previous = qsearchs('part_svc_column', {
          'svcpart'    => $new->svcpart,
          'columnname' => $field,
        } );

        my $flag  = $new->getfield($svcdb.'__'.$field.'_flag');
        my $label = $new->getfield($svcdb.'__'.$field.'_label');
        my $required = $new->getfield($svcdb.'__'.$field.'_required') ? 'Y' : '';
 
        if ( uc($flag) =~ /^([A-Z])$/ || $label !~ /^\s*$/ ) {

          if ( uc($flag) =~ /^([A-Z])$/ ) {
            $part_svc_column->setfield('columnflag', $1);
            my $parser = FS::part_svc->svc_table_fields($svcdb)->{$field}->{parse}
                       || sub { shift };
            $part_svc_column->setfield('columnvalue',
              &$parser($new->getfield($svcdb.'__'.$field))
            );
          } else {
            $part_svc_column->setfield('columnflag',  '');
            $part_svc_column->setfield('columnvalue', '');
          }

          $part_svc_column->setfield('columnlabel', $label)
            if $label !~ /^\s*$/;

          $part_svc_column->setfield('required', $required);

          if ( $previous ) {
            $error = $part_svc_column->replace($previous);
          } else {
            $error = $part_svc_column->insert;
          }
        } else {
          $error = $previous ? $previous->delete : '';
        }
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
      }
    }

    # maintain export_svc records

    if ( $exportnums ) { # hash of exportnum => role

      #false laziness w/ edit/process/agent_type.cgi
      #and, more importantly, with m2m_Common
      my @new_export_svc = ();
      foreach my $part_export ( qsearch('part_export', {}) ) {
        my $exportnum = $part_export->exportnum;
        my $hashref = {
          'exportnum' => $exportnum,
          'svcpart'   => $new->svcpart,
        };
        my $export_svc = qsearchs('export_svc', $hashref);

        if ( $export_svc ) {
          my $old_role = $export_svc->role || 1; # 1 = null in the db
          if ( ! $exportnums->{$exportnum}
               or $old_role ne $exportnums->{$exportnum} ) {

            $error = $export_svc->delete;
            if ( $error ) {
              $dbh->rollback if $oldAutoCommit;
              return $error;
            }
            undef $export_svc; # on a role change, force it to be reinserted

          }
        } # if $export_svc
        if ( ! $export_svc && $exportnums->{$exportnum} ) {
          # also applies if it's been undef'd because of role change
          $hashref->{role} = $exportnums->{$exportnum};
          push @new_export_svc, new FS::export_svc ( $hashref );
        }

      }

      my $slice = 100/scalar(@new_export_svc) if @new_export_svc;
      my $done = 0;
      foreach my $export_svc (@new_export_svc) {
        $error = $export_svc->insert($job, $slice*$done++, $slice);
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
        if ( $job ) {
          $error = $job->update_statustext( int( $slice * $done ) );
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return $error;
          }
        }
      }

    }

  } else {
    $dbh->rollback if $oldAutoCommit;
    return 'non-1.3-COMPAT interface not yet written';
    #not yet implemented
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item check

Checks all fields to make sure this is a valid service definition.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error;
  $error=
    $self->ut_numbern('svcpart')
    || $self->ut_text('svc')
    || $self->ut_textn('comment')
    || $self->ut_alpha('svcdb')
    || $self->ut_flag('disabled')
    || $self->ut_flag('preserve')
    || $self->ut_enum('selfservice_access', [ '', 'hidden', 'readonly' ] )
    || $self->ut_foreign_keyn('classnum', 'part_svc_class', 'classnum' )
    || $self->ut_flag('restrict_edit_password')
    || $self->ut_flag('has_router')
;
  return $error if $error;

  my @fields = eval { fields( $self->svcdb ) }; #might die
  return "Unknown svcdb: ". $self->svcdb. " (Error: $@)"
    unless @fields;

  $self->SUPER::check;
}

=item part_svc_column COLUMNNAME

Returns the part_svc_column object (see L<FS::part_svc_column>) for the given
COLUMNNAME, or a new part_svc_column object if none exists.

=cut

sub part_svc_column {
  my( $self, $columnname) = @_;
  $self->svcpart &&
    qsearchs('part_svc_column',  {
                                   'svcpart'    => $self->svcpart,
                                   'columnname' => $columnname,
                                 }
  ) or new FS::part_svc_column {
                                 'svcpart'    => $self->svcpart,
                                 'columnname' => $columnname,
                               };
}

=item all_part_svc_column

=cut

sub all_part_svc_column {
  my $self = shift;
  qsearch('part_svc_column', { 'svcpart' => $self->svcpart } );
}

=item part_export [ EXPORTTYPE ]

Returns a list of all exports (see L<FS::part_export>) for this service, or,
if an export type is specified, only returns exports of the given type.

=cut

sub part_export {
  my $self = shift;
  my %search;
  $search{'exporttype'} = shift if @_;
  map { $_ } #behavior of sort undefined in scalar context
    sort { $a->weight <=> $b->weight }
      map { qsearchs('part_export', { 'exportnum'=>$_->exportnum, %search } ) }
        qsearch('export_svc', { 'svcpart'=>$self->svcpart } );
}

=item part_export_usage

Returns a list of any exports (see L<FS::part_export>) for this service that
are capable of reporting usage information.

=cut

sub part_export_usage {
  my $self = shift;
  grep $_->can('usage_sessions'), $self->part_export;
}

=item part_export_did

Returns a list of any exports (see L<FS::part_export>) for this service that
are capable of returing available DID (phone number) information.

=cut

sub part_export_did {
  my $self = shift;
  grep $_->can_get_dids, $self->part_export;
}

=item part_export_dsl_pull

Returns a list of any exports (see L<FS::part_export>) for this service that
are capable of pulling/pushing DSL orders.

=cut

sub part_export_dsl_pull {
    my $self = shift;
    grep $_->can('dsl_pull'), $self->part_export;
}

=item cust_svc [ PKGPART ] 

Returns a list of associated customer services (FS::cust_svc records).

If a PKGPART is specified, returns the customer services which are contained
within packages of that type (see L<FS::part_pkg>).  If PKGPARTis specified as
B<0>, returns unlinked customer services.

=cut

sub cust_svc {
  my $self = shift;

  my $hashref = { 'svcpart' => $self->svcpart };

  my( $addl_from, $extra_sql ) = ( '', '' );
  if ( @_ ) {
    my $pkgpart = shift;
    if ( $pkgpart =~ /^(\d+)$/ ) {
      $addl_from = 'LEFT JOIN cust_pkg USING ( pkgnum )';
      $extra_sql = "AND pkgpart = $1";
    } elsif ( $pkgpart eq '0' ) {
      $hashref->{'pkgnum'} = '';
    }
  }

  qsearch({
    'table'     => 'cust_svc',
    'addl_from' => $addl_from,
    'hashref'   => $hashref,
    'extra_sql' => $extra_sql,
  });
}

=item num_cust_svc [ PKGPART ] 

Returns the number of associated customer services (FS::cust_svc records).

If a PKGPART is specified, returns the number of customer services which are
contained within packages of that type (see L<FS::part_pkg>).  If PKGPART
is specified as B<0>, returns the number of unlinked customer services.

=cut

sub num_cust_svc {
  my $self = shift;

  return $self->{Hash}{num_cust_svc}
    if !@_ && exists($self->{Hash}{num_cust_svc});

  my @param = ( $self->svcpart );

  my( $join, $and ) = ( '', '' );
  if ( @_ ) {
    my $pkgpart = shift;
    if ( $pkgpart ) {
      $join = 'LEFT JOIN cust_pkg USING ( pkgnum )';
      $and = 'AND pkgpart = ?';
      push @param, $pkgpart;
    } elsif ( $pkgpart eq '0' ) {
      $and = 'AND pkgnum IS NULL';
    }
  }

  my $sth = dbh->prepare(
    "SELECT COUNT(*) FROM cust_svc $join WHERE svcpart = ? $and"
  ) or die dbh->errstr;
  $sth->execute(@param)
    or die $sth->errstr;
  $sth->fetchrow_arrayref->[0];
}

=item num_cust_svc_cancelled

Returns the number of associated customer services that are
attached to cancelled packages.

=cut

sub num_cust_svc_cancelled {
  my $self = shift;
  my $sth = dbh->prepare(
    "SELECT COUNT(*) FROM cust_svc
     LEFT JOIN cust_pkg USING ( pkgnum )
     WHERE svcpart = ?
     AND cust_pkg.cancel IS NOT NULL"
  ) or die dbh->errstr;
  $sth->execute($self->svcpart)
    or die $sth->errstr;
  $sth->fetchrow_arrayref->[0];
}

=item svc_x

Returns a list of associated FS::svc_* records.

=cut

sub svc_x {
  my $self = shift;
  map { $_->svc_x } $self->cust_svc;
}

=back

=head1 CLASS METHODS

=over 4

=cut

my $svc_defs;
my $svc_info;
sub _svc_defs {

  return $svc_defs if $svc_defs; #cache

  my $conf = new FS::Conf;

  #false laziness w/part_pkg.pm::plan_info

  my %info;
  foreach my $INC ( @INC ) {
    warn "globbing $INC/FS/svc_*.pm\n" if $DEBUG;
    foreach my $file ( glob("$INC/FS/svc_*.pm") ) {

      warn "attempting to load service table info from $file\n" if $DEBUG;
      $file =~ /\/(\w+)\.pm$/ or do {
        warn "unrecognized file in $INC/FS/: $file\n";
        next;
      };
      my $mod = $1;

      if ( $mod =~ /^svc_[A-Z]/ or $mod =~ /^(svc_acct_pop|svc_export_machine)$/ ) {
        warn "skipping FS::$mod" if $DEBUG;
	next;
      }

      eval "use FS::$mod;";
      if ( $@ ) {
        die "error using FS::$mod (skipping): $@\n" if $@;
        next;
      }
      unless ( UNIVERSAL::can("FS::$mod", 'table_info') ) {
        warn "FS::$mod has no table_info method; skipping";
	next;
      }

      my $info = "FS::$mod"->table_info;
      unless ( keys %$info ) {
        warn "FS::$mod->table_info doesn't return info, skipping\n";
        next;
      }
      warn "got info from FS::$mod: $info\n" if $DEBUG;
      if ( exists($info->{'disabled'}) && $info->{'disabled'} ) {
        warn "skipping disabled service FS::$mod" if $DEBUG;
        next;
      }
      $info{$mod} = $info;

      # all svc_* modules are required to have h_svc_* modules for invoice
      # display. check for them as early as possible.
      eval "use FS::h_$mod;";
      if ( $@ ) {
        die "couldn't load history record module h_$mod: $@\n";
      }
    }
  }


  tie my %svc_defs, 'Tie::IxHash', 
    map  { $_ => $info{$_}->{'fields'} }
    sort { $info{$a}->{'display_weight'} <=> $info{$b}->{'display_weight'} }
    keys %info,
  ;

  tie my %svc_info, 'Tie::IxHash',
    map  { $_ => $info{$_} }
    sort { $info{$a}->{'display_weight'} <=> $info{$b}->{'display_weight'} }
    keys %info,
  ;
    
  $svc_info = \%svc_info; #access via svc_table_info  
  $svc_defs = \%svc_defs; #cache
  
}

=item svc_tables

Returns a list of all svc_ tables.

=cut

sub svc_tables {
  my $class = shift;
  my $svc_defs = $class->_svc_defs;
  grep { defined( dbdef->table($_) ) } keys %$svc_defs;
}

=item svc_table_fields TABLE

Given a table name, returns a hashref of field names.  The field names
returned are those with additional (service-definition related) information,
not necessarily all database fields of the table.  Pseudo-fields may also
be returned (i.e. svc_acct.usergroup).

Each value of the hashref is another hashref, which can have one or more of
the following keys:

=over 4

=item label - Description of the field

=item def_label - Optional description of the field in the context of service definitions

=item type - Currently "text", "select", "checkbox", "textarea", "disabled", 
some components specified by "select-.*.html", and a bunch more...

=item disable_default - This field should not allow a default value in service definitions

=item disable_fixed - This field should not allow a fixed value in service definitions

=item disable_inventory - This field should not allow inventory values in service definitions

=item select_list - If type is "text", this can be a listref of possible values.

=item select_table - An alternative to select_list, this defines a database table with the possible choices.

=item select_key - Used with select_table, this is the field name of keys

=item select_label - Used with select_table, this is the field name of labels

=item select_allow_empty - Used with select_table, adds an empty option

=item required - This field should always have a true value (do not use with type checkbox or disabled)

=back

=cut

#maybe this should move and be a class method in svc_Common.pm
sub svc_table_fields {
  my($class, $table) = @_;
  my $svc_defs = $class->_svc_defs;
  my $def = $svc_defs->{$table};

  foreach ( grep !ref($def->{$_}), keys %$def ) {

    #normalize the shortcut in %info hash
    $def->{$_} = { 'label' => $def->{$_} };

    $def->{$_}{'type'} ||= 'text';

  }

  $def;
}

=item svc_table_info TABLE

Returns table_info for TABLE from cache, or empty
hashref if none is found.

Caution:  caches table_info for ALL services when run;
access a service's table_info directly unless you know
you're loading them all.

Caution:  does not standardize fields into hashrefs;
use L</svc_table_fields> to access fields.

=cut

sub svc_table_info {
  my $class = shift;
  my $table = shift;
  $class->_svc_defs; #creates cache if needed
  return $svc_info->{$table} || {};
}

=back

=head1 SUBROUTINES

=over 4

=item process

Job-queue processor for web interface adds/edits

=cut

use Data::Dumper;
sub process {
  my $job = shift;
  my $param = shift;
  warn Dumper($param) if $DEBUG;

  my $old = qsearchs('part_svc', { 'svcpart' => $param->{'svcpart'} }) 
    if $param->{'svcpart'};

  #unmunge cgp_accessmodes (falze laziness-ish w/edit/process/svc_acct.cgi)
  $param->{'svc_acct__cgp_accessmodes'} ||=
    join(' ', sort
      grep { $_ !~ /^(flag|label)$/ }
           map { /^svc_acct__cgp_accessmodes_([\w\/]+)$/ or die "no way"; $1; }
               grep $param->{$_},
                    grep /^svc_acct__cgp_accessmodes_([\w\/]+)$/,
                         keys %$param
        );
  

  my $new = new FS::part_svc ( {
    map {
      $_ => $param->{$_};
  #  } qw(svcpart svc svcdb)
    } ( fields('part_svc'),
        map { my $svcdb = $_;
              my @fields = fields($svcdb);
              push @fields, 'usergroup' if $svcdb eq 'svc_acct'
                                        or $svcdb eq 'svc_broadband'; #kludge

              map {
                    my $f = $svcdb.'__'.$_;
                    my $flag = $param->{ $f.'_flag' } || ''; #silence warnings
                    if ( $flag =~ /^[MAH]$/ ) {
                      $param->{ $f } = delete( $param->{ $f.'_classnum' } );
                    }
		    if ( ( $flag =~ /^[MAHS]$/ or $_ eq 'usergroup' )
                         and ref($param->{ $f }) ) {
                      $param->{ $f } = join(',', @{ $param->{ $f } });
		    }
                    ( $f, $f.'_flag', $f.'_label', $f.'_required' );
                  }
                  @fields;

            } FS::part_svc->svc_tables()
      )
  } );
  
  my %exportnums =
    map { $_->exportnum => ( $param->{'exportnum'.$_->exportnum} || '') }
        qsearch('part_export', {} );
  foreach my $exportnum (%exportnums) {
    my $role = $param->{'exportnum'.$exportnum.'_role'};
    # role is undef if the export has no role selector
    if ( $exportnums{$exportnum} && $role ) {
      $exportnums{$exportnum} = $role;
    }
  }
  my $error;
  if ( $param->{'svcpart'} ) {
    $error = $new->replace( $old,
                            '1.3-COMPAT',    #totally bunk, as jeff noted
                            [ 'usergroup' ],
                            \%exportnums,
                            $job
                          );
  } else {
    $error = $new->insert( [ 'usergroup' ],
                           \%exportnums,
                           $job,
                         );
    $param->{'svcpart'} = $new->getfield('svcpart');
  }

  die "$error\n" if $error;
}

=item process_bulk_cust_svc

Job-queue processor for web interface bulk customer service changes

=cut

use Data::Dumper;
sub process_bulk_cust_svc {
  my $job = shift;
  my $param = shift;
  warn Dumper($param) if $DEBUG;

  local($FS::svc_Common::noexport_hack) = 1
    if $param->{'noexport'};

  my $old_part_svc =
    qsearchs('part_svc', { 'svcpart' => $param->{'old_svcpart'} } );

  die "Must select a new service definition\n" unless $param->{'new_svcpart'};

  #the rest should be abstracted out to to its own subroutine?

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  local( $FS::cust_svc::ignore_quantity ) = 1;

  my $total = $old_part_svc->num_cust_svc( $param->{'pkgpart'} );

  my $n = 0;
  foreach my $old_cust_svc ( $old_part_svc->cust_svc( $param->{'pkgpart'} ) ) {

    my $new_cust_svc = new FS::cust_svc { $old_cust_svc->hash };

    $new_cust_svc->svcpart( $param->{'new_svcpart'} );
    my $error = $new_cust_svc->replace($old_cust_svc);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      die "$error\n" if $error;
    }

    $error = $job->update_statustext( int( 100 * ++$n / $total ) );
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      die $error if $error;
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

sub _upgrade_data {  #class method
  my ($class, %opts) = @_;

  my @part_svc_column = qsearch('part_svc_column', { 'columnname' => 'usergroup' });
  foreach my $col ( @part_svc_column ) {
    next if $col->columnvalue =~ /^[\d,]+$/ || !$col->columnvalue;
    my @groupnames = split(',',$col->columnvalue);
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
            die "Error inserting new radius_group for service definition group \"$groupname\": $error"
              if $error;
        }
        push @groupnums, $g->groupnum;
    }
    $col->columnvalue(join(',',@groupnums));
    $error = $col->replace;
    die $error if $error;
  }

  my @badlabels = qsearch({
    'table' => 'part_svc_column',
    'hashref' => {},
    'extra_sql' => 'WHERE columnlabel IN ('.
      "'Descriptive label for this particular device.',".
      "'IP address.  Leave blank for automatic assignment.',".
      "'Maximum upload speed for this service in Kbps.  0 denotes unlimited.',".
      "'Maximum download speed for this service in Kbps.  0 denotes unlimited.')"
  });
  foreach my $col ( @badlabels ) {
    $col->columnlabel('');
    my $error = $col->replace;
    die $error if $error;
  }

}

=head1 BUGS

Delete is unimplemented.

The list of svc_* tables is no longer hardcoded, but svc_acct_pop is skipped
as a special case until it is renamed.

all_part_svc_column methods should be documented

=head1 SEE ALSO

L<FS::Record>, L<FS::part_svc_column>, L<FS::part_pkg>, L<FS::pkg_svc>,
L<FS::cust_svc>, L<FS::svc_acct>, L<FS::svc_forward>, L<FS::svc_domain>,
schema.html from the base documentation.

=cut

1;

