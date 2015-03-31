package FS::reason;

use strict;
use vars qw( @ISA $DEBUG $me );
use DBIx::DBSchema;
use DBIx::DBSchema::Table;
use DBIx::DBSchema::Column;
use FS::Record qw( qsearch qsearchs dbh dbdef );
use FS::reason_type;

@ISA = qw(FS::Record);
$DEBUG = 0;
$me = '[FS::reason]';

=head1 NAME

FS::reason - Object methods for reason records

=head1 SYNOPSIS

  use FS::reason;

  $record = new FS::reason \%hash;
  $record = new FS::reason { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::reason object represents a reason message.  FS::reason inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item reasonnum - primary key

=item reason_type - index into FS::reason_type

=item reason - text of the reason

=item disabled - 'Y' or ''

=item unsuspend_pkgpart - for suspension reasons only, the pkgpart (see
L<FS::part_pkg>) of a package to be ordered when the package is unsuspended.
Typically this will be some kind of reactivation fee.  Attaching it to 
a suspension reason allows the reactivation fee to be charged for some
suspensions but not others. DEPRECATED.

=item unsuspend_hold - 'Y' or ''.  If unsuspend_pkgpart is set, this tells
whether to bill the unsuspend package immediately ('') or to wait until 
the customer's next invoice ('Y').

=item unused_credit - 'Y' or ''. For suspension reasons only (for now).
If enabled, the customer will be credited for their remaining time on 
suspension.

=item feepart - for suspension reasons, the feepart of a fee to be
charged when a package is suspended for this reason.

=item fee_hold - 'Y' or ''. If feepart is set, tells whether to bill the fee
immediately ('') or wait until the customer's next invoice ('Y').

=item fee_on_unsuspend - If feepart is set, tells whether to charge the fee
on suspension ('') or unsuspension ('Y').

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new reason.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'reason'; }

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

Checks all fields to make sure this is a valid reason.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('reasonnum')
    || $self->ut_number('reason_type')
    || $self->ut_foreign_key('reason_type', 'reason_type', 'typenum')
    || $self->ut_text('reason')
  ;
  return $error if $error;

  if ( $self->reasontype->class eq 'S' ) {
    $error = $self->ut_numbern('unsuspend_pkgpart')
          || $self->ut_foreign_keyn('unsuspend_pkgpart', 'part_pkg', 'pkgpart')
          || $self->ut_flag('unsuspend_hold')
          || $self->ut_flag('unused_credit')
          || $self->ut_foreign_keyn('feepart', 'part_fee', 'feepart')
          || $self->ut_flag('fee_on_unsuspend')
          || $self->ut_flag('fee_hold')
    ;
    return $error if $error;
  } else {
    foreach (qw(unsuspend_pkgpart unsuspend_hold unused_credit feepart
                fee_on_unsuspend fee_hold)) {
      $self->set($_ => '');
    }
  }

  $self->SUPER::check;
}

=item reasontype

Returns the reason_type (see L<FS::reason_type>) associated with this reason.

=cut

sub reasontype {
  qsearchs( 'reason_type', { 'typenum' => shift->reason_type } );
}

=back

=head1 CLASS METHODS

=over 4

=item new_or_existing reason => REASON, type => TYPE, class => CLASS

Fetches the reason matching these parameters if there is one.  If not,
inserts one.  Will also insert the reason type if necessary.  CLASS must
be one of 'C' (cancel reasons), 'R' (credit reasons), 'S' (suspend reasons),
or 'F' (refund reasons).

This will die if anything fails.

=cut

sub new_or_existing {
  my $class = shift;
  my %opt = @_;

  my $error = '';
  my $reason_type;
  if ( ref $opt{type} eq 'FS::reason_type' ) {
    $reason_type = $opt{type};
  } elsif ( $opt{type} =~ /^\d+$/ ) {
    $reason_type = FS::reason_type->by_key($opt{type});
    if (!$reason_type) {
      die "reason_type #$opt{type} not found\n";
    }
  } else {
    my %hash = ('class' => $opt{'class'}, 'type' => $opt{'type'});
    $reason_type = qsearchs('reason_type', \%hash)
                      || FS::reason_type->new(\%hash);

    $error = $reason_type->insert unless $reason_type->typenum;
    die "error inserting reason type: $error\n" if $error;
  }

  my %hash = ('reason_type' => $reason_type->typenum,
              'reason' => $opt{'reason'});
  my $reason = qsearchs('reason', \%hash)
               || FS::reason->new(\%hash);

  $error = $reason->insert unless $reason->reasonnum;
  die "error inserting reason: $error\n" if $error;

  $reason;
}

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

