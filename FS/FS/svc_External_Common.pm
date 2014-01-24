package FS::svc_External_Common;

use strict;
use vars qw(@ISA);
use FS::svc_Common;

@ISA = qw( FS::svc_Common );

=head1 NAME

FS::svc_External_Common - Base class for svc_X classes which track external databases

=head1 SYNOPSIS

  package FS::svc_newservice;
  use base qw( FS::svc_External_Common );

=head1 DESCRIPTION

FS::svc_External_Common is intended as a base class for table-specific classes
to inherit from.  FS::svc_External_Common is used for services which connect
to externally tracked services via "id" and "table" fields.

FS::svc_External_Common inherits from FS::svc_Common.

The following fields are currently supported:

=over 4

=item svcnum - primary key

=item id - unique number of external record

=item title - for invoice line items

=back

=head1 METHODS

=over 4

=item search_sql

Provides a default search_sql method which returns an SQL fragment to search
the B<title> field.

=cut

sub search_sql {
  my($class, $string) = @_;
  $class->search_sql_field('title', $string);
}

=item new HASHREF

Creates a new external service.  To add the external service to the database,
see L<"insert">.  

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

=item label

Returns a string identifying this external service in the form "id:title"

=cut

sub label {
  my $self = shift;
  $self->id. ':'. $self->title;
}

=item insert [ , OPTION => VALUE ... ]

Adds this external service to the database.  If there is an error, returns the
error, otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

Currently available options are: I<depend_jobnum>

If I<depend_jobnum> is set (to a scalar jobnum or an array reference of
jobnums), all provisioning jobs will have a dependancy on the supplied
jobnum(s) (they will not run until the specific job(s) complete(s)).

=cut

#sub insert {
#  my $self = shift;
#  my $error;
#
#  $error = $self->SUPER::insert(@_);
#  return $error if $error;
#
#  '';
#}

=item delete

Delete this record from the database.

=cut

#sub delete {
#  my $self = shift;
#  my $error;
#
#  $error = $self->SUPER::delete;
#  return $error if $error;
#
#  '';
#}


=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

#sub replace {
#  my ( $new, $old ) = ( shift, shift );
#  my $error;
#
#  $error = $new->SUPER::replace($old);
#  return $error if $error;
#
#  '';
#}

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid external service.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  my $error = 
    $self->ut_numbern('svcnum')
    || $self->ut_numbern('id')
    || $self->ut_textn('title')
  ;

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>,
L<FS::cust_pkg>, schema.html from the base documentation.

=cut

1;

