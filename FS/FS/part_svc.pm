package FS::part_svc;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs fields dbh );
use FS::part_svc_column;
use FS::part_export;
use FS::export_svc;
use FS::cust_svc;

@ISA = qw(FS::Record);

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

=item svcdb - table used for this service.  See L<FS::svc_acct>,
L<FS::svc_domain>, and L<FS::svc_forward>, among others.

=item disabled - Disabled flag, empty or `Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new service definition.  To add the service definition to the
database, see L<"insert">.

=cut

sub table { 'part_svc'; }

=item insert [ EXTRA_FIELDS_ARRAYREF [ , EXPORTNUMS_HASHREF ] ] 

Adds this service definition to the database.  If there is an error, returns
the error, otherwise returns false.

The following pseudo-fields may be defined, and will be maintained in
the part_svc_column table appropriately (see L<FS::part_svc_column>).

=over 4

=item I<svcdb>__I<field> - Default or fixed value for I<field> in I<svcdb>.

=item I<svcdb>__I<field>_flag - defines I<svcdb>__I<field> action: null, `D' for default, or `F' for fixed.  For virtual fields, can also be 'X' for excluded.

=back

If you want to add part_svc_column records for fields that do not exist as
(real or virtual) fields in the I<svcdb> table, make sure to list then in 
EXTRA_FIELDS_ARRAYREF also.

If EXPORTNUMS_HASHREF is specified (keys are exportnums and values are
boolean), the appopriate export_svc records will be inserted.

=cut

sub insert {
  my $self = shift;
  my @fields = ();
  my @exportnums = ();
  @fields = @{shift(@_)} if @_;
  if ( @_ ) {
    my $exportnums = shift;
    @exportnums = grep $exportnums->{$_}, keys %$exportnums;
  }

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
#  my @rows = map { /^${svcdb}__(.*)$/; $1 }
#    grep ! /_flag$/,
#      grep /^${svcdb}__/,
#        fields('part_svc');
  foreach my $field (
    grep { $_ ne 'svcnum'
           && defined( $self->getfield($svcdb.'__'.$_.'_flag') )
         } (fields($svcdb), @fields)
  ) {
    my $part_svc_column = $self->part_svc_column($field);
    my $previous = qsearchs('part_svc_column', {
      'svcpart'    => $self->svcpart,
      'columnname' => $field,
    } );

    my $flag = $self->getfield($svcdb.'__'.$field.'_flag');
    if ( uc($flag) =~ /^([DFX])$/ ) {
      $part_svc_column->setfield('columnflag', $1);
      $part_svc_column->setfield('columnvalue',
        $self->getfield($svcdb.'__'.$field)
      );
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

  # add export_svc records

  foreach my $exportnum ( @exportnums ) {
    my $export_svc = new FS::export_svc ( {
      'exportnum' => $exportnum,
      'svcpart'   => $self->svcpart,
    } );
    $error = $export_svc->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

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

=item replace OLD_RECORD [ '1.3-COMPAT' [ , EXTRA_FIELDS_ARRAYREF [ , EXPORTNUMS_HASHREF ] ] ]

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

TODOC: 1.3-COMPAT

TODOC: EXTRA_FIELDS_ARRAYREF (same as insert method)

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );

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

  if ( @_ && $_[0] eq '1.3-COMPAT' ) {
    shift;
    my @fields = ();
    @fields = @{shift(@_)} if @_;
    my $exportnums = @_ ? shift : '';

   # maintain part_svc_column records

    my $svcdb = $new->svcdb;
    foreach my $field (
      grep { $_ ne 'svcnum'
             && defined( $new->getfield($svcdb.'__'.$_.'_flag') )
           } (fields($svcdb),@fields)
    ) {
      my $part_svc_column = $new->part_svc_column($field);
      my $previous = qsearchs('part_svc_column', {
        'svcpart'    => $new->svcpart,
        'columnname' => $field,
      } );

      my $flag = $new->getfield($svcdb.'__'.$field.'_flag');
      if ( uc($flag) =~ /^([DFX])$/ ) {
        $part_svc_column->setfield('columnflag', $1);
        $part_svc_column->setfield('columnvalue',
          $new->getfield($svcdb.'__'.$field)
        );
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

    # maintain export_svc records

    if ( $exportnums ) {

      #false laziness w/ edit/process/agent_type.cgi
      foreach my $part_export ( qsearch('part_export', {}) ) {
        my $exportnum = $part_export->exportnum;
        my $hashref = {
          'exportnum' => $exportnum,
          'svcpart'   => $new->svcpart,
        };
        my $export_svc = qsearchs('export_svc', $hashref);

        if ( $export_svc && ! $exportnums->{$exportnum} ) {
          $error = $export_svc->delete;
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return $error;
          }
        } elsif ( ! $export_svc && $exportnums->{$exportnum} ) {
          $export_svc = new FS::export_svc ( $hashref );
          $error = $export_svc->insert;
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
  my $recref = $self->hashref;

  my $error;
  $error=
    $self->ut_numbern('svcpart')
    || $self->ut_text('svc')
    || $self->ut_alpha('svcdb')
    || $self->ut_enum('disabled', [ '', 'Y' ] )
  ;
  return $error if $error;

  my @fields = eval { fields( $recref->{svcdb} ) }; #might die
  return "Unknown svcdb!" unless @fields;

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

Returns all exports (see L<FS::part_export>) for this service, or, if an
export type is specified, only returns exports of the given type.

=cut

sub part_export {
  my $self = shift;
  my %search;
  $search{'exporttype'} = shift if @_;
  map { qsearchs('part_export', { 'exportnum' => $_->exportnum, %search } ) }
    qsearch('export_svc', { 'svcpart' => $self->svcpart } );
}

=item cust_svc

Returns a list of associated FS::cust_svc records.

=cut

sub cust_svc {
  my $self = shift;
  qsearch('cust_svc', { 'svcpart' => $self->svcpart } );
}

=item svc_x

Returns a list of associated FS::svc_* records.

=cut

sub svc_x {
  my $self = shift;
  map { $_->svc_x } $self->cust_svc;
}

=back

=head1 BUGS

Delete is unimplemented.

The list of svc_* tables is hardcoded.  When svc_acct_pop is renamed, this
should be fixed.

all_part_svc_column method should be documented

=head1 SEE ALSO

L<FS::Record>, L<FS::part_svc_column>, L<FS::part_pkg>, L<FS::pkg_svc>,
L<FS::cust_svc>, L<FS::svc_acct>, L<FS::svc_forward>, L<FS::svc_domain>,
schema.html from the base documentation.

=cut

1;

