package FS::cust_pay_void; 

use strict;
use base qw( FS::otaker_Mixin FS::payinfo_Mixin FS::cust_main_Mixin
             FS::Record );
use vars qw( @encrypted_fields $otaker_upgrade_kludge );
use Business::CreditCard;
use FS::UID qw(getotaker);
use FS::Record qw(qsearch qsearchs dbh fields);
use FS::CurrentUser;
use FS::access_user;
use FS::cust_pay;
#use FS::cust_bill;
#use FS::cust_bill_pay;
#use FS::cust_pay_refund;
#use FS::cust_main;
use FS::cust_pkg;

@encrypted_fields = ('payinfo');
$otaker_upgrade_kludge = 0;

=head1 NAME

FS::cust_pay_void - Object methods for cust_pay_void objects

=head1 SYNOPSIS

  use FS::cust_pay_void;

  $record = new FS::cust_pay_void \%hash;
  $record = new FS::cust_pay_void { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pay_void object represents a voided payment.  The following fields
are currently supported:

=over 4

=item paynum

primary key (assigned automatically for new payments)

=item custnum

customer (see L<FS::cust_main>)

=item paid

Amount of this payment

=item _date

specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item otaker

order taker (see L<FS::access_user>)

=item payby

Payment Type (See L<FS::payinfo_Mixin> for valid values)

=item payinfo

card number, check #, or comp issuer (4-8 lowercase alphanumerics; think username), respectively

=item paybatch

text field for tracking card processing

=item closed

books closed flag, empty or `Y'

=item pkgnum

Desired pkgnum when using experimental package balances.

=item void_date

=item reason

=back

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new payment.  To add the payment to the databse, see L<"insert">.

=cut

sub table { 'cust_pay_void'; }

=item insert

Adds this voided payment to the database.

=item unvoid 

"Un-void"s this payment: Deletes the voided payment from the database and adds
back a normal payment.

=cut

sub unvoid {
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

  my $cust_pay = new FS::cust_pay ( {
    map { $_ => $self->get($_) } fields('cust_pay')
  } );
  my $error = $cust_pay->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $error = $self->delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Deletes this voided payment.  You probably don't want to use this directly; see
the B<unvoid> method to add the original payment back.

=item replace [ OLD_RECORD ]

You can, but probably shouldn't modify voided payments...

Replaces the OLD_RECORD with this one in the database, or, if OLD_RECORD is not
supplied, replaces this record.  If there is an error, returns the error,
otherwise returns false.

=item check

Checks all fields to make sure this is a valid voided payment.  If there is an
error, returns the error, otherwise returns false.  Called by the insert
method.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('paynum')
    || $self->ut_numbern('custnum')
    || $self->ut_money('paid')
    || $self->ut_number('_date')
    || $self->ut_textn('paybatch')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_foreign_keyn('pkgnum', 'cust_pkg', 'pkgnum')
    || $self->ut_numbern('void_date')
    || $self->ut_textn('reason')
    || $self->payinfo_check
  ;
  return $error if $error;

  return "paid must be > 0 " if $self->paid <= 0;

  return "unknown cust_main.custnum: ". $self->custnum
    unless $self->invnum
           || qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->void_date(time) unless $self->void_date;

  $self->void_usernum($FS::CurrentUser::CurrentUser->usernum)
    unless $self->void_usernum;

  $self->SUPER::check;
}

=item cust_main

Returns the parent customer object (see L<FS::cust_main>).

=cut

sub cust_main {
  my $self = shift;
  qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
}

=item void_access_user

Returns the voiding employee object (see L<FS::access_user>).

=cut

sub void_access_user {
  my $self = shift;
  qsearchs('access_user', { 'usernum' => $self->void_usernum } );
}

# Used by FS::Upgrade to migrate to a new database.
sub _upgrade_data {  # class method
  my ($class, %opts) = @_;

  my $sql = "SELECT usernum FROM access_user WHERE username = ( SELECT history_user FROM h_cust_pay_void WHERE paynum = ? AND history_action = 'insert' ORDER BY history_date LIMIT 1 ) ";
  my $sth = dbh->prepare($sql) or die dbh->errstr;

  foreach my $cust_pay_void (qsearch('cust_pay_void', {'void_usernum' => ''})) {
    $sth->execute($cust_pay_void->paynum) or die $sth->errstr;
    my $row = $sth->fetchrow_arrayref;
    my $usernum = $row ? $row->[0] : '';
    if ( $usernum ) {
      $cust_pay_void->void_usernum($usernum);
      my $error = $cust_pay_void->replace;
      die $error if $error;
    } else {
      warn "cust_pay_void upgrade: can't find access_user record for ". $cust_pay_void->paynum. "\n";
    }
  }

  local($otaker_upgrade_kludge) = 1;
  $class->_upgrade_otaker(%opts);

  #XXX look for the h_cust_pay delete records and when that's a different
  # usernum, set usernum
}

=back

=head1 BUGS

Delete and replace methods.

=head1 SEE ALSO

L<FS::cust_pay>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

