package FS::qual;

use strict;
use base qw( FS::option_Common );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::qual - Object methods for qual records

=head1 SYNOPSIS

  use FS::qual;

  $record = new FS::qual \%hash;
  $record = new FS::qual { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::qual object represents a qualification for service.  FS::qual inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item qualnum - primary key

=item prospectnum

=item custnum 

=item locationnum

=item phonenum - Service Telephone Number

=item exportnum - export instance providing service-qualification capabilities,
see L<FS::part_export>

=item vendor_qual_id - qualification id from vendor/telco

=item status - qualification status (e.g. (N)ew, (P)ending, (Q)ualifies)


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new qualification.  To add the qualification to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'qual'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid qualification.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('qualnum')
    || $self->ut_foreign_keyn('custnum', 'cust_main', 'qualnum')
    || $self->ut_foreign_keyn('prospectnum', 'prospect_main', 'prospectnum')
    || $self->ut_foreign_keyn('locationnum', 'cust_location', 'locationnum')
    || $self->ut_numbern('phonenum')
    || $self->ut_foreign_keyn('exportnum', 'part_export', 'exportnum')
    || $self->ut_textn('vendor_qual_id')
    || $self->ut_alpha('status')
  ;
  return $error if $error;

  return "Invalid prospect/customer/location combination" if (
   ( $self->locationnum && $self->prospectnum && $self->custnum ) ||
   ( !$self->locationnum && !$self->prospectnum && !$self->custnum )
  );

  $self->SUPER::check;
}

sub part_export {
    my $self = shift;
    if ( $self->exportnum ) {
	return qsearchs('part_export', { exportnum => $self->exportnum } )
		or die 'invalid exportnum';
    }
    '';
}

sub location {
    my $self = shift;
    if ( $self->locationnum ) {
	my $l = qsearchs( 'cust_location', 
		    { 'locationnum' => $self->locationnum });
	return $l->location_hash if $l;
    }
    if ( $self->custnum ) {
	my $c = qsearchs( 'cust_main', { 'custnum' => $self->custnum });
	return $c->location_hash if $c;
    }
  # prospectnum does not imply any particular address! must specify locationnum

    '';
}

sub cust_or_prospect {
    my $self = shift;
    if ( $self->locationnum ) {
	my $l = qsearchs( 'cust_location', 
		    { 'locationnum' => $self->locationnum });
	return qsearchs('cust_main',{ 'custnum' => $l->custnum })
	    if $l->custnum;
	return qsearchs('prospect_main',{ 'prospectnum' => $l->prospectnum })
	    if $l->prospectnum;
    }
    return qsearchs('cust_main', { 'custnum' => $self->custnum }) 
	if $self->custnum;
    return qsearchs('prospect_main', { 'prospectnum' => $self->prospectnum })
	if $self->prospectnum;
}

sub status_long {
    my $self = shift;
    my $s = {
	'Q' => 'Qualified',
	'D' => 'Does not Qualify',
	'N' => 'New',
    };
    return $s->{$self->status} if defined $s->{$self->status};
    return 'Unknown';
}

=back

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

