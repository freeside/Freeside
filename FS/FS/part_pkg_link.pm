package FS::part_pkg_link;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearchs qsearch dbh );
use FS::part_pkg;
use FS::cust_pkg;
use FS::reason;
use FS::reason_type;

@ISA = qw(FS::Record);

=head1 NAME

FS::part_pkg_link - Object methods for part_pkg_link records

=head1 SYNOPSIS

  use FS::part_pkg_link;

  $record = new FS::part_pkg_link \%hash;
  $record = new FS::part_pkg_link { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_pkg_link object represents an link from one package definition to
another.  FS::part_pkg_link inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item pkglinknum

primary key

=item src_pkgpart

Source package (see L<FS::part_pkg>)

=item dst_pkgpart

Destination package (see L<FS::part_pkg>)

=item link_type

Link type - currently, "bill" (source package bills a line item from target
package), or "svc" (source package includes services from target package), 
or "supp" (ordering source package creates a target package).

=item hidden

Flag indicating that this subpackage should be felt, but not seen as an invoice
line item when set to 'Y'.  Not allowed for "supp" links.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new link.  To add the link to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'part_pkg_link'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

If this is a supplemental package link, inserting it will order the 
supplemental packages for any main packages that already exist.

=cut

sub insert {
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $self = shift;
  my $error = $self->SUPER::insert(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error if $error;
  }

  if ( $self->link_type eq 'supp' ) {
    # queue this?
    my @main_pkgs = qsearch('cust_pkg', {
        pkgpart => $self->src_pkgpart,
        cancel  => '',
    });
    foreach my $main_pkg (@main_pkgs) {
      # duplicates code in FS::cust_pkg::uncancel, sort of
      my $supp_pkg = FS::cust_pkg->new({
          'pkgpart'     => $self->dst_pkgpart,
          'pkglinknum'  => $self->pkglinknum,
          'main_pkgnum' => $main_pkg->pkgnum,
          'order_date'  => time,
          map { $_ => $main_pkg->get($_) }
          qw( custnum locationnum pkgbatch 
              start_date setup expire adjourn contract_end bill susp 
              refnum discountnum waive_setup quantity 
              recur_show_zero setup_show_zero )
      });
      $error = $supp_pkg->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "$error (ordering new supplemental package to pkg#".$main_pkg->pkgnum.")" if $error;
      }
    }

    return $error if $error;
  }

  return;
}

=item delete

Delete this record from the database.

If this is a supplemental package link, deleting it will set pkglinknum = null
for any related packages, and set those packages to expire on their next bill
date.

=cut

my $cancel_reason_text = 'Supplemental package removed';
my $cancel_reason_type = 'Cancel Reason';

sub delete {
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $self = shift;

  if ( $self->link_type eq 'supp' ) {
    my $error = $self->remove_linked;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $error = $self->SUPER::delete(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }
  $dbh->commit;
  return;
}

=item remove_linked

Removes any supplemental packages that were created by this link, by canceling
them and setting their pkglinknum to null. This should be done in preparation
for removing the link itself.

=cut

sub remove_linked {
  my $self = shift;
  my $pkglinknum = $self->pkglinknum;
  my $error;

  # find linked packages
  my @pkgs = qsearch('cust_pkg', { pkglinknum => $pkglinknum });
  warn "expiring ".scalar(@pkgs).
       " linked packages from part_pkg_link #$pkglinknum\n";

  my $reason = FS::reason->new_or_existing(
    class => 'C',
    type => $cancel_reason_type,
    reason => $cancel_reason_text
  );

  foreach my $pkg (@pkgs) {
    $pkg->set('pkglinknum' => '');
    if ( $pkg->get('cancel') ) {
      # then just replace it to unlink the package from this object
      $error = $pkg->replace;
    } else {
      $error = $pkg->cancel(
        'date'    => $pkg->get('bill'), # cancel on next bill, or else now
        'reason'  => $reason->reasonnum,
      );
    }
    if ( $error ) {
      return "$error (scheduling package #".$pkg->pkgnum." for expiration)";
    }
  }
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid link.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('pkglinknum')
    || $self->ut_foreign_key('src_pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_foreign_key('dst_pkgpart', 'part_pkg', 'pkgpart')
    || $self->ut_enum('link_type', [ 'bill', 'svc', 'supp' ] )
    || $self->ut_enum('hidden', [ '', 'Y' ] )
  ;
  return $error if $error;

  if ( $self->link_type eq 'supp' ) {
    # some sanity checking
    my $src_pkg = $self->src_pkg;
    my $dst_pkg = $self->dst_pkg;
    if ( $src_pkg->freq eq '0' and $dst_pkg->freq ne '0' ) {
      return "One-time charges can't have supplemental packages."
    } elsif ( $dst_pkg->freq ne '0' ) {
      my $ratio = $dst_pkg->freq / $src_pkg->freq;
      if ($ratio != int($ratio)) {
        return "Supplemental package period (pkgpart ".$dst_pkg->pkgpart.
               ") must be an integer multiple of main package period.";
      }
    }
  }

  $self->SUPER::check;
}

=item src_pkg

Returns the source part_pkg object (see L<FS::part_pkg>).

=cut

sub src_pkg {
  my $self = shift;
  qsearchs('part_pkg', { 'pkgpart' => $self->src_pkgpart } );
}

=item dst_pkg

Returns the source part_pkg object (see L<FS::part_pkg>).

=cut

sub dst_pkg {
  my $self = shift;
  qsearchs('part_pkg', { 'pkgpart' => $self->dst_pkgpart } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

