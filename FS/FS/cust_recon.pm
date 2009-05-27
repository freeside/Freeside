package FS::cust_recon;

use strict;
use base qw( FS::Record );
use FS::Record qw( qsearch qsearchs );

=head1 NAME

FS::cust_recon - Object methods for cust_recon records

=head1 SYNOPSIS

  use FS::cust_recon;

  $record = new FS::cust_recon \%hash;
  $record = new FS::cust_recon { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_recon object represents a customer reconcilation.  FS::cust_recon
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item reconid

primary key

=item recondate

recondate

=item custnum

custnum

=item agentnum

agentnum

=item last

last

=item first

first

=item address1

address1

=item address2

address2

=item city

city

=item state

state

=item zip

zip

=item pkg

pkg

=item adjourn

adjourn

=item status

status

=item agent_custid

agent_custid

=item agent_pkg

agent_pkg

=item agent_adjourn

agent_adjourn

=item comments

comments


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new customer reconcilation.  To add the reconcilation to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_recon'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item delete

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid reconcilation.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('reconid')
    || $self->ut_numbern('recondate')
    || $self->ut_number('custnum')
    || $self->ut_number('agentnum')
    || $self->ut_text('last')
    || $self->ut_text('first')
    || $self->ut_text('address1')
    || $self->ut_textn('address2')
    || $self->ut_text('city')
    || $self->ut_textn('state')
    || $self->ut_textn('zip')
    || $self->ut_textn('pkg')
    || $self->ut_numbern('adjourn')
    || $self->ut_textn('status')
    || $self->ut_text('agent_custid')
    || $self->ut_textn('agent_pkg')
    || $self->ut_numbern('agent_adjourn')
    || $self->ut_textn('comments')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=back

=head1 BUGS

Possibly the existance of this module.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

