package FS::part_svc;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs fields dbh );
use FS::part_svc_column;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_svc - Object methods for part_svc objects

=head1 SYNOPSIS

  use FS::part_svc;

  $record = new FS::part_svc \%hash
  $record = new FS::part_svc { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

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

=item insert

Adds this service definition to the database.  If there is an error, returns
the error, otherwise returns false.

=item I<svcdb>__I<field> - Default or fixed value for I<field> in I<svcdb>.

=item I<svcdb>__I<field>_flag - defines I<svcdb>__I<field> action: null, `D' for default, or `F' for fixed

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

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $svcdb = $self->svcdb;
#  my @rows = map { /^${svcdb}__(.*)$/; $1 }
#    grep ! /_flag$/,
#      grep /^${svcdb}__/,
#        fields('part_svc');
  foreach my $field (
    grep { $_ ne 'svcnum'
           && defined( $self->getfield($svcdb.'__'.$_.'_flag') )
         } fields($svcdb)
  ) {
    my $part_svc_column = $self->part_svc_column($field);
    my $previous = qsearchs('part_svc_column', {
      'svcpart'    => $self->svcpart,
      'columnname' => $field,
    } );

    my $flag = $self->getfield($svcdb.'__'.$field.'_flag');
    if ( uc($flag) =~ /^([DF])$/ ) {
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

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't (yet?) delete service definitions.";
# check & make sure the svcpart isn't in cust_svc or pkg_svc (in any packages)?
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

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
    my $svcdb = $new->svcdb;
    foreach my $field (
      grep { $_ ne 'svcnum'
             && defined( $new->getfield($svcdb.'__'.$_.'_flag') )
           } fields($svcdb)
    ) {
      my $part_svc_column = $new->part_svc_column($field);
      my $previous = qsearchs('part_svc_column', {
        'svcpart'    => $new->svcpart,
        'columnname' => $field,
      } );

      my $flag = $new->getfield($svcdb.'__'.$field.'_flag');
      if ( uc($flag) =~ /^([DF])$/ ) {
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

##REPLACED BY part_svc_column
#  my $svcdb;
#  foreach $svcdb ( qw(
#    svc_acct svc_acct_sm svc_domain
#  ) ) {
#    my @rows = map { /^${svcdb}__(.*)$/; $1 }
#      grep ! /_flag$/,
#        grep /^${svcdb}__/,
#          fields('part_svc');
#    foreach my $row (@rows) {
#      unless ( $svcdb eq $recref->{svcdb} ) {
#        $recref->{$svcdb.'__'.$row}='';
#        $recref->{$svcdb.'__'.$row.'_flag'}='';
#        next;
#      }
#      $recref->{$svcdb.'__'.$row.'_flag'} =~ /^([DF]?)$/
#        or return "Illegal flag for $svcdb $row";
#      $recref->{$svcdb.'__'.$row.'_flag'} = $1;
#
#      my $error = $self->ut_anything($svcdb.'__'.$row);
#      return $error if $error;
#
#    }
#  }

  ''; #no error
}

=item part_svc_column COLUMNNAME

Returns the part_svc_column object (see L<FS::part_svc_column>) for the given
COLUMNNAME, or a new part_svc_column object if none exists.

=cut

sub part_svc_column {
  my $self = shift;
  my $columnname = shift;
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

=item part_export

=cut

sub part_export {
  my $self = shift;
  my %search = ( 'svcpart' => $self->svcpart );
  qsearch('part_export', \%search);
}

=back

=head1 VERSION

$Id: part_svc.pm,v 1.10 2002-03-20 21:31:49 ivan Exp $

=head1 BUGS

Delete is unimplemented.

The list of svc_* tables is hardcoded.  When svc_acct_pop is renamed, this
should be fixed.

=head1 SEE ALSO

L<FS::Record>, L<FS::part_svc_column>, L<FS::part_pkg>, L<FS::pkg_svc>,
L<FS::cust_svc>, L<FS::svc_acct>, L<FS::svc_forward>, L<FS::svc_domain>,
schema.html from the base documentation.

=cut

1;

