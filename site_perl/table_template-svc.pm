package FS::svc_table;

use strict;
use vars qw(@ISA);
use FS::Record qw(fields qsearch qsearchs);
use FS::cust_svc;

@ISA = qw(FS::Record);

=head1 NAME

FS::table_name - Object methods for table_name records

=head1 SYNOPSIS

  use FS::table_name;

  $record = new FS::table_name \%hash;
  $record = new FS::table_name { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::table_name object represents an example.  FS::table_name inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item field - description

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'table_name'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

=cut

sub insert {
  my($self)=@_;
  my($error);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  $error=$self->check;
  return $error if $error;

  my($svcnum)=$self->svcnum;
  my($cust_svc);
  unless ( $svcnum ) {
    $cust_svc=create FS::cust_svc ( {
      'svcnum'  => $svcnum,
      'pkgnum'  => $self->pkgnum,
      'svcpart' => $self->svcpart,
    } );
    my($error) = $cust_svc->insert;
    return $error if $error;
    $svcnum = $self->svcnum($cust_svc->svcnum);
  }

  $error = $self->add;
  if ($error) {
    #$cust_svc->del if $cust_svc;
    $cust_svc->delete if $cust_svc;
    return $error;

  ''; #no error
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my($self)=@_;
  my($error);

  $error = $self->del;
  return $error if $error;

}


=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my($new,$old)=@_;
  my($error);

  return "(Old) Not a svc_table record!" unless $old->table eq "svc_table";
  return "Can't change svcnum!"
    unless $old->getfield('svcnum') eq $new->getfield('svcnum');

  $error=$new->check;
  return $error if $error;

  $error = $new->rep($old);
  return $error if $error;

  ''; #no error
}

=item suspend

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub suspend {
  ''; #no error (stub)
}

=item unsuspend

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub unsuspend {
  ''; #no error (stub)
}


=item cancel

Just returns false (no error) for now.

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub cancel {
  ''; #no error (stub)
}

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my($self)=@_;
  return "Not a svc_table record!" unless $self->table eq "svc_table";
  my($recref) = $self->hashref;

  $recref->{svcnum} =~ /^(\d+)$/ or return "Illegal svcnum";
  $recref->{svcnum} = $1;

  #get part_svc
  my($svcpart);
  my($svcnum)=$self->getfield('svcnum');
  if ($svcnum) {
    my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum});
    return "Unknown svcnum" unless $cust_svc; 
    $svcpart=$cust_svc->svcpart;
  } else {
    $svcpart=$self->getfield('svcpart');
  }
  my($part_svc)=qsearchs('part_svc',{'svcpart'=>$svcpart});
  return "Unkonwn svcpart" unless $part_svc;

  #set fixed fields from part_svc
  my($field);
  foreach $field ( fields('svc_acct') ) {
    if ( $part_svc->getfield('svc_acct__'. $field. '_flag') eq 'F' ) {
      $self->setfield($field,$part_svc->getfield('svc_acct__'. $field) );
    }
  }

  ''; #no error
}

=back

=head1 VERSION

$Id: table_template-svc.pm,v 1.3 1998-12-29 11:59:56 ivan Exp $

=head1 BUGS

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>, schema.html
froom the base documentation.

=head1 HISTORY

ivan@voicenet.com 97-jul-21

$Log: table_template-svc.pm,v $
Revision 1.3  1998-12-29 11:59:56  ivan
mostly properly OO, some work still to be done with svc_ stuff

Revision 1.2  1998/11/15 04:33:01  ivan
updates for newest versoin


=cut

1;

