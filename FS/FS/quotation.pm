package FS::quotation;
use base qw( FS::Template_Mixin FS::cust_main_Mixin FS::otaker_Mixin FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs );
use FS::CurrentUser;
use FS::cust_main;
use FS::prospect_main;
use FS::quotation_pkg;

=head1 NAME

FS::quotation - Object methods for quotation records

=head1 SYNOPSIS

  use FS::quotation;

  $record = new FS::quotation \%hash;
  $record = new FS::quotation { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::quotation object represents a quotation.  FS::quotation inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item quotationnum

primary key

=item prospectnum

prospectnum

=item custnum

custnum

=item _date

_date

=item disabled

disabled

=item usernum

usernum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new quotation.  To add the quotation to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'quotation'; }
sub notice_name { 'Quotation'; }
sub template_conf { 'quotation_'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid quotation.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('quotationnum')
    || $self->ut_foreign_keyn('prospectnum', 'prospect_main', 'prospectnum' )
    || $self->ut_foreign_keyn('custnum', 'cust_main', 'custnum' )
    || $self->ut_numbern('_date')
    || $self->ut_enum('disabled', [ '', 'Y' ])
    || $self->ut_numbern('usernum')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  $self->SUPER::check;
}

=item prospect_main

=cut

sub prospect_main {
  my $self = shift;
  qsearchs('prospect_main', { 'prospectnum' => $self->prospectnum } );
}

=item cust_main

=cut

sub cust_main {
  my $self = shift;
  qsearchs('cust_main', { 'custnum' => $self->custnum } );
}

=item cust_bill_pkg

=cut

sub cust_bill_pkg {
  my $self = shift;
  #actually quotation_pkg objects
  qsearch('quotation_pkg', { quotationnum=>$self->quotationnum });
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

