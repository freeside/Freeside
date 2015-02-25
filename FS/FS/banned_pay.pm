package FS::banned_pay;
use base qw( FS::otaker_Mixin FS::Record );

use strict;
use Digest::MD5 qw(md5_base64);
use Digest::SHA qw( sha512_base64 );
use FS::Record qw( qsearchs dbh );
use FS::CurrentUser;

=head1 NAME

FS::banned_pay - Object methods for banned_pay records

=head1 SYNOPSIS

  use FS::banned_pay;

  $record = new FS::banned_pay \%hash;
  $record = new FS::banned_pay { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::banned_pay object represents an banned credit card or ACH account.
FS::banned_pay inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item bannum

primary key

=item payby

I<CARD> or I<CHEK>

=item payinfo

fingerprint of banned card (base64-encoded MD5 or SHA512 digest)

=item payinfo_hash

Digest hash algorythm, currently either MD5 or SHA512.  Empty implies a legacy
MD5 hash.

=item _date

specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item end_date

optional end date, also specified as a UNIX timestamp.

=item usernum

order taker (assigned automatically, see L<FS::access_user>)

=item bantype

Ban type: "" or null (regular ban), "warn" (warning)

=item reason

reason (text)

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new ban.  To add the ban to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'banned_pay'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid ban.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('bannum')
    || $self->ut_enum('payby', [ 'CARD', 'CHEK' ] )
    || $self->ut_text('payinfo')
    || $self->ut_enum('payinfo_hash', [ '', 'MD5', 'SHA512' ] )
    || $self->ut_numbern('_date')
    || $self->ut_numbern('end_date')
    || $self->ut_enum('bantype', [ '', 'warn' ] )
    || $self->ut_textn('reason')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  $self->SUPER::check;
}

=back

=head1 CLASS METHODS

=item ban_search OPTION => VALUE ...

Takes two parameters: payby and payinfo, and searches for an (un-expired) ban
matching those items.

Returns the ban, or false if no ban was found.

=cut

sub ban_search {
  my( $class, %opt ) = @_;
  qsearchs({
    'table'     => 'banned_pay',
    'hashref'   => { 'payby' => $opt{payby}, },
    'extra_sql' => "
      AND (((payinfo_hash IS NULL OR payinfo_hash = '' OR payinfo_hash = 'MD5')
              AND payinfo = ". dbh->quote( md5_base64($opt{payinfo}) ). "
           )
           OR 
           (payinfo_hash = 'SHA256'
              AND payinfo = ". dbh->quote( sha512_base64($opt{payinfo}) ). "
           )
          )
      AND ( end_date IS NULL OR end_date >= ". time. " ) ",
  });
}

# Used by FS::Upgrade to migrate to a new database.
sub _upgrade_data {  # class method
  my ($class, %opts) = @_;
  $class->_upgrade_otaker(%opts);
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

