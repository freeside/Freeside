package FS::part_svc;

use strict;
use vars qw(@ISA @EXPORT_OK);
use Exporter;
use FS::Record qw(fields hfields);

@ISA = qw(FS::Record Exporter);
@EXPORT_OK = qw(hfields fields);

=head1 NAME

FS::part_svc - Object methods for part_svc objects

=head1 SYNOPSIS

  use FS::part_svc;

  $record = create FS::part_referral \%hash
  $record = create FS::part_referral { 'column' => 'value' };

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

=item create HASHREF

Creates a new service definition.  To add the service definition to the
database, see L<"insert">.

=cut

sub create {
  my($proto,$hashref)=@_;

  #now in FS::Record::new
  #my($field);
  #foreach $field (fields('part_svc')) {
  #  $hashref->{$field}='' unless defined $hashref->{$field};
  #}

  $proto->new('part_svc',$hashref);
}

=item insert

Adds this service definition to the database.  If there is an error, returns
the error, otherwise returns false.

=cut

sub insert {
  my($self)=@_;

  $self->check or
  $self->add;
}

=item delete

Currently unimplemented.

=cut

sub delete {
  return "Can't (yet?) delete service definitions.";
# maybe check & make sure the svcpart isn't in cust_svc or (in any packages)?
#  my($self)=@_;
#
#  $self->del;
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  return "(Old) Not a part_svc record!" unless $old->table eq "part_svc";
  return "Can't change svcpart!"
    unless $old->getfield('svcpart') eq $new->getfield('svcpart');
  return "Can't change svcdb!"
    unless $old->getfield('svcdb') eq $new->getfield('svcdb');
  $new->check or
  $new->rep($old);
}

=item check

Checks all fields to make sure this is a valid service definition.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my($self)=@_;
  return "Not a part_svc record!" unless $self->table eq "part_svc";
  my($recref) = $self->hashref;

  my($error);
  return $error if $error=
    $self->ut_numbern('svcpart')
    || $self->ut_text('svc')
    || $self->ut_alpha('svcdb')
  ;

  my(@fields) = eval { fields($recref->{svcdb}) }; #might die
  return "Unknown svcdb!" unless @fields;

  my($svcdb);
  foreach $svcdb ( qw(
    svc_acct svc_acct_sm svc_charge svc_domain svc_wo
  ) ) {
    my(@rows)=map { /^${svcdb}__(.*)$/; $1 }
      grep ! /_flag$/,
        grep /^${svcdb}__/,
          fields('part_svc');
    my($row);
    foreach $row (@rows) {
      unless ( $svcdb eq $recref->{svcdb} ) {
        $recref->{$svcdb.'__'.$row}='';
        $recref->{$svcdb.'__'.$row.'_flag'}='';
        next;
      }
      $recref->{$svcdb.'__'.$row.'_flag'} =~ /^([DF]?)$/
        or return "Illegal flag for $svcdb $row";
      $recref->{$svcdb.'__'.$row.'_flag'} = $1;

#      $recref->{$svcdb.'__'.$row} =~ /^(.*)$/ #not restrictive enough?
#        or return "Illegal value for $svcdb $row";
#      $recref->{$svcdb.'__'.$row} = $1;
      my($error);
      return $error if $error=$self->ut_anything($svcdb.'__'.$row);

    }
  }

  ''; #no error
}

=back

=head1 BUGS

It doesn't properly override FS::Record yet.

Delete is unimplemented.

=head1 SEE ALSO

L<FS::Record>, L<FS::part_pkg>, L<FS::pkg_svc>, L<FS::cust_svc>,
L<FS::svc_acct>, L<FS::svc_acct_sm>, L<FS::svc_domain>, schema.html from the
base documentation.

=head1 HISTORY

ivan@sisd.com 97-nov-14

data checking/untainting calls into FS::Record added
ivan@sisd.com 97-dec-6

pod ivan@sisd.com 98-sep-21

=cut

1;

