package FS::svc_Common;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs fields );
use FS::cust_svc;
use FS::part_svc;

@ISA = qw( FS::Record );

=head1 NAME

FS::svc_Common - Object method for all svc_ records

=head1 SYNOPSIS

use FS::svc_Common;

@ISA = qw( FS::svc_Common );

=head1 DESCRIPTION

FS::svc_Common is intended as a base class for table-specific classes to
inherit from, i.e. FS::svc_acct.  FS::svc_Common inherits from FS::Record.

=head1 METHODS

=over 4

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=cut

sub insert {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  $error = $self->check;
  return $error if $error;

  my $svcnum = $self->svcnum;
  my $cust_svc;
  unless ( $svcnum ) {
    $cust_svc = new FS::cust_svc ( {
      'svcnum'  => $svcnum,
      'pkgnum'  => $self->pkgnum,
      'svcpart' => $self->svcpart,
    } );
    $error = $cust_svc->insert;
    return $error if $error;
    $svcnum = $self->svcnum($cust_svc->svcnum);
  }

  $error = $self->SUPER::insert;
  if ( $error ) {
    $cust_svc->delete if $cust_svc;
    return $error;
  }

  '';
}

=item delete

Deletes this account from the database.  If there is an error, returns the
error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

=cut

sub delete {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $svcnum = $self->svcnum;

  $error = $self->SUPER::delete;
  return $error if $error;

  my $cust_svc = qsearchs( 'cust_svc' , { 'svcnum' => $svcnum } );  
  $error = $cust_svc->delete;
  return $error if $error;

  '';
}

=item setfixed;

Sets any fixed fields for this service (see L<FS::part_svc>).  If there is an
error, returns the error, otherwise returns the FS::part_svc object (use ref()
to test the return).  Usually called by the check method.

=cut

sub setfixed {
  my $self = shift;

  my $error;

  $error =
    $self->ut_numbern('svcnum')
  ;
  return $error if $error;

  #get part_svc
  my $svcpart;
  if ( $self->svcnum ) {
    my $cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $self->svcnum } );
    return "Unknown svcnum" unless $cust_svc; 
    $svcpart = $cust_svc->svcpart;
  } else {
    $svcpart = $self->getfield('svcpart');
  }
  my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $svcpart } );
  return "Unkonwn svcpart" unless $part_svc;

  #set fixed fields from part_svc
  foreach my $field ( fields('svc_acct') ) {
    if ( $part_svc->getfield('svc_acct__'. $field. '_flag') eq 'F' ) {
      $self->setfield( $field, $part_svc->getfield('svc_acct__'. $field) );
    }
  }

 $part_svc;

}

=item suspend

=item unsuspend

=item cancel

Stubs - return false (no error) so derived classes don't need to define these
methods.  Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub suspend { ''; }
sub unsuspend { ''; }
sub cancel { ''; }

=back

=head1 VERSION

$Id: svc_Common.pm,v 1.2 1999-01-25 12:26:14 ivan Exp $

=head1 BUGS

The setfixed method return value.

The new method should set defaults from part_svc (like the check method
sets fixed values).

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>, schema.html
from the base documentation.

=head1 HISTORY

$Log: svc_Common.pm,v $
Revision 1.2  1999-01-25 12:26:14  ivan
yet more mod_perl stuff

Revision 1.1  1998/12/30 00:30:45  ivan
svc_ stuff is more properly OO - has a common superclass FS::svc_Common


=cut

1;

