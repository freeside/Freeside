package FS::part_svc;

use strict;
use vars qw( @ISA );
use FS::Record qw( fields );

@ISA = qw(FS::Record);

=head1 NAME

FS::part_svc - Object methods for part_svc objects

=head1 SYNOPSIS

  use FS::part_svc;

  $record = new FS::part_referral \%hash
  $record = new FS::part_referral { 'column' => 'value' };

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
L<FS::svc_domain>, and L<FS::svc_acct_sm>, among others.

=item I<svcdb>__I<field> - Default or fixed value for I<field> in I<svcdb>.

=item I<svcdb>__I<field>_flag - defines I<svcdb>__I<field> action: null, `D' for default, or `F' for fixed

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

  return "Can't change svcdb!"
    unless $old->svcdb eq $new->svcdb;

  $new->SUPER::replace( $old );
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
  ;
  return $error if $error;

  my @fields = eval { fields( $recref->{svcdb} ) }; #might die
  return "Unknown svcdb!" unless @fields;

  my $svcdb;
  foreach $svcdb ( qw(
    svc_acct svc_acct_sm svc_domain
  ) ) {
    my @rows = map { /^${svcdb}__(.*)$/; $1 }
      grep ! /_flag$/,
        grep /^${svcdb}__/,
          fields('part_svc');
    foreach my $row (@rows) {
      unless ( $svcdb eq $recref->{svcdb} ) {
        $recref->{$svcdb.'__'.$row}='';
        $recref->{$svcdb.'__'.$row.'_flag'}='';
        next;
      }
      $recref->{$svcdb.'__'.$row.'_flag'} =~ /^([DF]?)$/
        or return "Illegal flag for $svcdb $row";
      $recref->{$svcdb.'__'.$row.'_flag'} = $1;

      my $error = $self->ut_anything($svcdb.'__'.$row);
      return $error if $error;

    }
  }

  ''; #no error
}

=back

=head1 VERSION

$Id: part_svc.pm,v 1.1 1999-08-04 09:03:53 ivan Exp $

=head1 BUGS

Delete is unimplemented.

The list of svc_* tables is hardcoded.  When svc_acct_pop is renamed, this
should be fixed.

=head1 SEE ALSO

L<FS::Record>, L<FS::part_pkg>, L<FS::pkg_svc>, L<FS::cust_svc>,
L<FS::svc_acct>, L<FS::svc_acct_sm>, L<FS::svc_domain>, schema.html from the
base documentation.

=cut

1;

