package FS::svc_Common;

use strict;
use vars qw( @ISA $noexport_hack );
use FS::Record qw( qsearchs fields dbh );
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

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->check;
  return $error if $error;

  my $svcnum = $self->svcnum;
  my $cust_svc;
  unless ( $svcnum ) {
    $cust_svc = new FS::cust_svc ( {
      #hua?# 'svcnum'  => $svcnum,
      'pkgnum'  => $self->pkgnum,
      'svcpart' => $self->svcpart,
    } );
    $error = $cust_svc->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    $svcnum = $self->svcnum($cust_svc->svcnum);
  } else {
    $cust_svc = qsearchs('cust_svc',{'svcnum'=>$self->svcnum});
    unless ( $cust_svc ) {
      $dbh->rollback if $oldAutoCommit;
      return "no cust_svc record found for svcnum ". $self->svcnum;
    }
    $self->pkgnum($cust_svc->pkgnum);
    $self->svcpart($cust_svc->svcpart);
  }

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  #new-style exports!
  unless ( $noexport_hack ) {
    foreach my $part_export ( $self->cust_svc->part_svc->part_export ) {
      my $error = $part_export->export_insert($self);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "exporting to ". $part_export->exporttype.
               " (transaction rolled back): $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

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

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->SUPER::delete;
  return $error if $error;

  #new-style exports!
  unless ( $noexport_hack ) {
    foreach my $part_export ( $self->cust_svc->part_svc->part_export ) {
      my $error = $part_export->export_delete($self);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "exporting to ". $part_export->exporttype.
               " (transaction rolled back): $error";
      }
    }
  }

  return $error if $error;

  my $cust_svc = $self->cust_svc;
  $error = $cust_svc->delete;
  return $error if $error;

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item replace OLD_RECORD

Replaces OLD_RECORD with this one.  If there is an error, returns the error,
otherwise returns false.

=cut

sub replace {
  my ($new, $old) = (shift, shift);
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $new->SUPER::replace($old);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  #new-style exports!
  unless ( $noexport_hack ) {
    foreach my $part_export ( $new->cust_svc->part_svc->part_export ) {
      my $error = $part_export->export_replace($new,$old);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "exporting to ". $part_export->exporttype.
               " (transaction rolled back): $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';
}


=item setfixed

Sets any fixed fields for this service (see L<FS::part_svc>).  If there is an
error, returns the error, otherwise returns the FS::part_svc object (use ref()
to test the return).  Usually called by the check method.

=cut

sub setfixed {
  my $self = shift;
  $self->setx('F');
}

=item setdefault

Sets all fields to their defaults (see L<FS::part_svc>), overriding their
current values.  If there is an error, returns the error, otherwise returns
the FS::part_svc object (use ref() to test the return).

=cut

sub setdefault {
  my $self = shift;
  $self->setx('D');
}

sub setx {
  my $self = shift;
  my $x = shift;

  my $error;

  $error =
    $self->ut_numbern('svcnum')
  ;
  return $error if $error;

  #get part_svc
  my $svcpart;
  if ( $self->svcnum ) {
    my $cust_svc = $self->cust_svc;
    return "Unknown svcnum" unless $cust_svc; 
    $svcpart = $cust_svc->svcpart;
  } else {
    $svcpart = $self->getfield('svcpart');
  }
  my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $svcpart } );
  return "Unkonwn svcpart" unless $part_svc;

  #set default/fixed/whatever fields from part_svc
  my $table = $self->table;
  foreach my $field ( grep { $_ ne 'svcnum' } fields($table) ) {
    my $part_svc_column = $part_svc->part_svc_column($field);
    if ( $part_svc_column->columnflag eq $x ) {
      $self->setfield( $field, $part_svc_column->columnvalue );
    }
  }

 $part_svc;

}

=item cust_svc

Returns the cust_svc record associated with this svc_ record, as a FS::cust_svc
object (see L<FS::cust_svc>).

=cut

sub cust_svc {
  my $self = shift;
  qsearchs('cust_svc', { 'svcnum' => $self->svcnum } );
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

$Id: svc_Common.pm,v 1.9 2002-05-31 00:18:56 khoff Exp $

=head1 BUGS

The setfixed method return value.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>, schema.html
from the base documentation.

=cut

1;

