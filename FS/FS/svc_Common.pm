package FS::svc_Common;

use strict;
use vars qw( @ISA $noexport_hack );
use FS::Record qw( qsearch qsearchs fields dbh );
use FS::cust_svc;
use FS::part_svc;
use FS::queue;

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

=cut

sub virtual_fields {

  # This restricts the fields based on part_svc_column and the svcpart of 
  # the service.  There are four possible cases:
  # 1.  svcpart passed as part of the svc_x hash.
  # 2.  svcpart fetched via cust_svc based on svcnum.
  # 3.  No svcnum or svcpart.  In this case, return ALL the fields with 
  #     dbtable eq $self->table.
  # 4.  Called via "fields('svc_acct')" or something similar.  In this case
  #     there is no $self object.

  my $self = shift;
  my $svcpart;
  my @vfields = $self->SUPER::virtual_fields;

  return @vfields unless (ref $self); # Case 4

  if ($self->svcpart) { # Case 1
    $svcpart = $self->svcpart;
  } elsif ( $self->svcnum
            && qsearchs('cust_svc',{'svcnum'=>$self->svcnum} )
          ) { #Case 2
    $svcpart = $self->cust_svc->svcpart;
  } else { # Case 3
    $svcpart = '';
  }

  if ($svcpart) { #Cases 1 and 2
    my %flags = map { $_->columnname, $_->columnflag } (
        qsearch ('part_svc_column', { svcpart => $svcpart } )
      );
    return grep { not ($flags{$_} eq 'X') } @vfields;
  } else { # Case 3
    return @vfields;
  } 
  return ();
}

=item check

Checks the validity of fields in this record.

At present, this does nothing but call FS::Record::check (which, in turn, 
does nothing but run virtual field checks).

=cut

sub check {
  my $self = shift;
  $self->SUPER::check;
}

=item insert [ JOBNUM_ARRAYREF [ OBJECTS_ARRAYREF ] ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields pkgnum and svcpart (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

If an arrayref is passed as parameter, the B<jobnum>s of any export jobs will
be added to the array.

If an arrayref of FS::tablename objects (for example, FS::acct_snarf objects)
is passed as the optional second parameter, they will have their svcnum fields
set and will be inserted after this record, but before any exports are run.

=cut

sub insert {
  my $self = shift;
  local $FS::queue::jobnums = shift if @_;
  my $objects = scalar(@_) ? shift : [];
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
  my $cust_svc = $svcnum ? qsearchs('cust_svc',{'svcnum'=>$self->svcnum}) : '';
  #unless ( $svcnum ) {
  if ( !$svcnum or !$cust_svc ) {
    $cust_svc = new FS::cust_svc ( {
      #hua?# 'svcnum'  => $svcnum,
      'svcnum'  => $self->svcnum,
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
    #$cust_svc = qsearchs('cust_svc',{'svcnum'=>$self->svcnum});
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

  foreach my $object ( @$objects ) {
    $object->svcnum($self->svcnum);
    $error = $object->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
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
        return "error exporting to ". $part_export->exporttype.
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
  if ( $self->svcnum && qsearchs('cust_svc', {'svcnum'=>$self->svcnum}) ) {
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
  foreach my $field ( grep { $_ ne 'svcnum' } $self->fields ) {
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

Runs export_suspend callbacks.

=cut

sub suspend {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  #new-style exports!
  unless ( $noexport_hack ) {
    foreach my $part_export ( $self->cust_svc->part_svc->part_export ) {
      my $error = $part_export->export_suspend($self);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error exporting to ". $part_export->exporttype.
               " (transaction rolled back): $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item unsuspend

Runs export_unsuspend callbacks.

=cut

sub unsuspend {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  #new-style exports!
  unless ( $noexport_hack ) {
    foreach my $part_export ( $self->cust_svc->part_svc->part_export ) {
      my $error = $part_export->export_unsuspend($self);
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error exporting to ". $part_export->exporttype.
               " (transaction rolled back): $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item cancel

Stub - returns false (no error) so derived classes don't need to define these
methods.  Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=cut

sub cancel { ''; }

=item clone_suspended

Constructor used by FS::part_export::_export_suspend fallback.  Stub returning
same object for svc_ classes which don't implement a suspension fallback
(everything except svc_acct at the moment).  Document better.

=cut

sub clone_suspended {
  shift;
}

=item clone_kludge_unsuspend 

Constructor used by FS::part_export::_export_unsuspend fallback.  Stub returning
same object for svc_ classes which don't implement a suspension fallback
(everything except svc_acct at the moment).  Document better.

=cut

sub clone_kludge_unsuspend {
  shift;
}

=back

=head1 BUGS

The setfixed method return value.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_svc>, L<FS::part_svc>, L<FS::cust_pkg>, schema.html
from the base documentation.

=cut

1;

