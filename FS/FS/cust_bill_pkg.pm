package FS::cust_bill_pkg;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs dbdef dbh );
use FS::cust_main_Mixin;
use FS::cust_pkg;
use FS::cust_bill;
use FS::cust_bill_pkg_detail;
use FS::cust_bill_pay_pkg;
use FS::cust_credit_bill_pkg;

@ISA = qw( FS::cust_main_Mixin FS::Record );

=head1 NAME

FS::cust_bill_pkg - Object methods for cust_bill_pkg records

=head1 SYNOPSIS

  use FS::cust_bill_pkg;

  $record = new FS::cust_bill_pkg \%hash;
  $record = new FS::cust_bill_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg object represents an invoice line item.
FS::cust_bill_pkg inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item billpkgnum - primary key

=item invnum - invoice (see L<FS::cust_bill>)

=item pkgnum - package (see L<FS::cust_pkg>) or 0 for the special virtual sales tax package, or -1 for the virtual line item (itemdesc is used for the line)

=item setup - setup fee

=item recur - recurring fee

=item sdate - starting date of recurring fee

=item edate - ending date of recurring fee

=item itemdesc - Line item description (currentlty used only when pkgnum is 0 or -1)

=back

sdate and edate are specified as UNIX timestamps; see L<perlfunc/"time">.  Also
see L<Time::Local> and L<Date::Parse> for conversion functions.

=head1 METHODS

=over 4

=item new HASHREF

Creates a new line item.  To add the line item to the database, see
L<"insert">.  Line items are normally created by calling the bill method of a
customer object (see L<FS::cust_main>).

=cut

sub table { 'cust_bill_pkg'; }

=item insert

Adds this line item to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
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

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  unless ( defined dbdef->table('cust_bill_pkg_detail') && $self->get('details') ) {
    $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    return '';
  }

  foreach my $detail ( @{$self->get('details')} ) {
    my $cust_bill_pkg_detail = new FS::cust_bill_pkg_detail {
      'pkgnum' => $self->pkgnum,
      'invnum' => $self->invnum,
      'detail' => $detail,
    };
    $error = $cust_bill_pkg_detail->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item delete

Currently unimplemented.  I don't remove line items because there would then be
no record the items ever existed (which is bad, no?)

=cut

sub delete {
  return "Can't delete cust_bill_pkg records!";
}

=item replace OLD_RECORD

Currently unimplemented.  This would be even more of an accounting nightmare
than deleteing the items.  Just don't do it.

=cut

sub replace {
  return "Can't modify cust_bill_pkg records!";
}

=item check

Checks all fields to make sure this is a valid line item.  If there is an
error, returns the error, otherwise returns false.  Called by the insert
method.

=cut

sub check {
  my $self = shift;

  my $error =
         $self->ut_numbern('billpkgnum')
      || $self->ut_snumber('pkgnum')
      || $self->ut_number('invnum')
      || $self->ut_money('setup')
      || $self->ut_money('recur')
      || $self->ut_numbern('sdate')
      || $self->ut_numbern('edate')
      || $self->ut_textn('itemdesc')
  ;
  return $error if $error;

  #if ( $self->pkgnum != 0 ) { #allow unchecked pkgnum 0 for tax! (add to part_pkg?)
  if ( $self->pkgnum > 0 ) { #allow -1 for non-pkg line items and 0 for tax (add to part_pkg?)
    return "Unknown pkgnum ". $self->pkgnum
      unless qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
  }

  return "Unknown invnum"
    unless qsearchs( 'cust_bill' ,{ 'invnum' => $self->invnum } );

  $self->SUPER::check;
}

=item cust_pkg

Returns the package (see L<FS::cust_pkg>) for this invoice line item.

=cut

sub cust_pkg {
  my $self = shift;
  qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
}

=item cust_bill

Returns the invoice (see L<FS::cust_bill>) for this invoice line item.

=cut

sub cust_bill {
  my $self = shift;
  qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );
}

=item details

Returns an array of detail information for the invoice line item.

=cut

sub details {
  my $self = shift;
  return () unless defined dbdef->table('cust_bill_pkg_detail');
  map { $_->detail }
    qsearch ( 'cust_bill_pkg_detail', { 'pkgnum' => $self->pkgnum,
                                        'invnum' => $self->invnum, } );
    #qsearch ( 'cust_bill_pkg_detail', { 'lineitemnum' => $self->lineitemnum });
}

=item desc

Returns a description for this line item.  For typical line items, this is the
I<pkg> field of the corresponding B<FS::part_pkg> object (see L<FS::part_pkg>).
For one-shot line items and named taxes, it is the I<itemdesc> field of this
line item, and for generic taxes, simply returns "Tax".

=cut

sub desc {
  my $self = shift;

  if ( $self->pkgnum > 0 ) {
    $self->cust_pkg->part_pkg->pkg;
  } else {
    $self->itemdesc || 'Tax';
  }
}

=item owed_setup

Returns the amount owed (still outstanding) on this line item's setup fee,
which is the amount of the line item minus all payment applications (see
L<FS::cust_bill_pay_pkg> and credit applications (see
L<FS::cust_credit_bill_pkg>).

=cut

sub owed_setup {
  my $self = shift;
  $self->owed('setup', @_);
}

=item owed_recur

Returns the amount owed (still outstanding) on this line item's recurring fee,
which is the amount of the line item minus all payment applications (see
L<FS::cust_bill_pay_pkg> and credit applications (see
L<FS::cust_credit_bill_pkg>).

=cut

sub owed_recur {
  my $self = shift;
  $self->owed('recur', @_);
}

# modeled after cust_bill::owed...
sub owed {
  my( $self, $field ) = @_;
  my $balance = $self->$field();
  $balance -= $_->amount foreach ( $self->cust_bill_pay_pkg($field) );
  $balance -= $_->amount foreach ( $self->cust_credit_bill_pkg($field) );
  $balance = sprintf( '%.2f', $balance );
  $balance =~ s/^\-0\.00$/0.00/; #yay ieee fp
  $balance;
}

sub cust_bill_pay_pkg {
  my( $self, $field ) = @_;
  qsearch( 'cust_bill_pay_pkg', { 'billpkgnum' => $self->billpkgnum,
                                  'setuprecur' => $field,
                                }
         );
}

sub cust_credit_bill_pkg {
  my( $self, $field ) = @_;
  qsearch( 'cust_credit_bill_pkg', { 'billpkgnum' => $self->billpkgnum,
                                     'setuprecur' => $field,
                                   }
         );
}

=back

=head1 BUGS

setup and recur shouldn't be separate fields.  There should be one "amount"
field and a flag to tell you if it is a setup/one-time fee or a recurring fee.

A line item with both should really be two separate records (preserving
sdate and edate for setup fees for recurring packages - that information may
be valuable later).  Invoice generation (cust_main::bill), invoice printing
(cust_bill), tax reports (report_tax.cgi) and line item reports 
(cust_bill_pkg.cgi) would need to be updated.

owed_setup and owed_recur could then be repaced by just owed, and
cust_bill::open_cust_bill_pkg and
cust_bill_ApplicationCommon::apply_to_lineitems could be simplified.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_bill>, L<FS::cust_pkg>, L<FS::cust_main>, schema.html
from the base documentation.

=cut

1;

