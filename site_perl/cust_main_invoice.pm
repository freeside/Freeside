package FS::cust_main_invoice;

use strict;
use vars qw(@ISA $conf $mydomain);
use Exporter;
use FS::Record qw( qsearchs );
use FS::Conf;
use FS::cust_main;
use FS::svc_acct;

@ISA = qw( FS::Record );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::cust_main_invoice'} = sub { 
  $conf = new FS::Conf;
  $mydomain = $conf->config('domain');
};

=head1 NAME

FS::cust_main_invoice - Object methods for cust_main_invoice records

=head1 SYNOPSIS

  use FS::cust_main_invoice;

  $record = new FS::cust_main_invoice \%hash;
  $record = new FS::cust_main_invoice { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $email_address = $record->address;

=head1 DESCRIPTION

An FS::cust_main_invoice object represents an invoice destination.  FS::cust_main_invoice inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item destnum - primary key

=item custnum - customer (see L<FS::cust_main>)

=item dest - Invoice destination: If numeric, a <a href="#svc_acct">svcnum</a>, if string, a literal email address, or `POST' to enable mailing (the default if no cust_main_invoice records exist)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new invoice destination.  To add the invoice destination to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_main_invoice'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );

  return "Can't change custnum!" unless $old->custnum eq $new->custnum;

  $new->SUPER::replace;
}


=item check

Checks all fields to make sure this is a valid invoice destination.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $error = $self->ut_number('destnum')
        or $self->ut_number('custnum')
        or $self->ut_text('dest')
  ;
  return $error if $error;

  return "Unknown customer"
    unless qsearchs('cust_main',{ 'custnum' => $self->custnum });

  if ( $self->dest eq 'POST' ) {
    #contemplate our navel
  } elsif ( $self->dest =~ /^(\d+)$/ ) {
    return "Unknown local account (specified by svcnum)"
      unless qsearchs( 'svc_acct', { 'svcnum' => $self->dest } );
  } elsif ( $self->dest =~ /^([\w\.\-]+)\@(([\w\.\-]\.)+\w+)$/ ) {
    my($user, $domain) = ($1, $2);
    if ( $domain eq $mydomain ) {
      my $svc_acct = qsearchs( 'svc_acct', { 'username' => $user } );
      return "Unknown local account (specified literally)" unless $svc_acct;
      $svc_acct->svcnum =~ /^(\d+)$/ or die "Non-numeric svcnum?!";
      $self->dest($1);
    }
  } else {
    return "Illegal destination!";
  }

  ''; #no error
}

=item address

Returns the literal email address for this record (or `POST').

=cut

sub address {
  my $self = shift;
  if ( $self->dest =~ /(\d+)$/ ) {
    my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $1 } );
    $svc_acct->username . '@' . $mydomain;
  } else {
    $self->dest;
  }
}

=back

=head1 VERSION

$Id: cust_main_invoice.pm,v 1.3 1998-12-29 11:59:42 ivan Exp $

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>

=head1 HISTORY

ivan@voicenet.com 97-jul-1

added hfields
ivan@sisd.com 97-nov-13

$Log: cust_main_invoice.pm,v $
Revision 1.3  1998-12-29 11:59:42  ivan
mostly properly OO, some work still to be done with svc_ stuff

Revision 1.2  1998/12/16 09:58:53  ivan
library support for editing email invoice destinations (not in sub collect yet)

Revision 1.1  1998/12/16 07:40:02  ivan
new table

Revision 1.3  1998/11/15 04:33:00  ivan
updates for newest versoin

Revision 1.2  1998/11/15 03:48:49  ivan
update for current version


=cut

1;

