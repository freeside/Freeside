package FS::cust_payby;

use strict;
use base qw( FS::payinfo_Mixin FS::Record );
use FS::UID;
use FS::Record qw( qsearchs ); #qsearch;
use FS::payby;
use FS::cust_main;
use Business::CreditCard qw( validate cardtype );
use FS::Msgcat qw( gettext );

use vars qw( $conf @encrypted_fields
             $ignore_expired_card $ignore_banned_card
             $ignore_invalid_card
           );

@encrypted_fields = ('payinfo', 'paycvv');
sub nohistory_fields { ('payinfo', 'paycvv'); }

$ignore_expired_card = 0;
$ignore_banned_card = 0;
$ignore_invalid_card = 0;

install_callback FS::UID sub { 
  $conf = new FS::Conf;
  #yes, need it for stuff below (prolly should be cached)
  $ignore_invalid_card = $conf->exists('allow_invalid_cards');
};

=head1 NAME

FS::cust_payby - Object methods for cust_payby records

=head1 SYNOPSIS

  use FS::cust_payby;

  $record = new FS::cust_payby \%hash;
  $record = new FS::cust_payby { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_payby object represents customer stored payment information.
FS::cust_payby inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item custpaybynum

primary key

=item custnum

custnum

=item weight

weight

=item payby

payby

=item payinfo

payinfo

=item paycvv

paycvv

=item paymask

paymask

=item paydate

paydate

=item paystart_month

paystart_month

=item paystart_year

paystart_year

=item payissue

payissue

=item payname

payname

=item paystate

paystate

=item paytype

paytype

=item payip

payip


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cust_payby'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('custpaybynum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum')
    || $self->ut_number('weight')
    #encrypted #|| $self->ut_textn('payinfo')
    #encrypted #|| $self->ut_textn('paycvv')
#    || $self->ut_textn('paymask') #XXX something
    #later #|| $self->ut_textn('paydate')
    || $self->ut_numbern('paystart_month')
    || $self->ut_numbern('paystart_year')
    || $self->ut_numbern('payissue')
#    || $self->ut_textn('payname') #XXX something
    || $self->ut_alphan('paystate')
    || $self->ut_textn('paytype')
    || $self->ut_ipn('payip')
  ;
  return $error if $error;

  ### from cust_main

  FS::payby->can_payby($self->table, $self->payby)
    or return "Illegal payby: ". $self->payby;

  # If it is encrypted and the private key is not availaible then we can't
  # check the credit card.
  my $check_payinfo = ! $self->is_encrypted($self->payinfo);

  # Need some kind of global flag to accept invalid cards, for testing
  # on scrubbed data.
  #XXX if ( !$import && $check_payinfo && $self->payby =~ /^(CARD|DCRD)$/ ) {
  if ( !$ignore_invalid_card && 
    $check_payinfo && $self->payby =~ /^(CARD|DCRD)$/ ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $payinfo =~ /^(\d{13,16}|\d{8,9})$/
      or return gettext('invalid_card'); # . ": ". $self->payinfo;
    $payinfo = $1;
    $self->payinfo($payinfo);
    validate($payinfo)
      or return gettext('invalid_card'); # . ": ". $self->payinfo;

    return gettext('unknown_card_type')
      if $self->payinfo !~ /^99\d{14}$/ #token
      && cardtype($self->payinfo) eq "Unknown";

    unless ( $ignore_banned_card ) {
      my $ban = FS::banned_pay->ban_search( %{ $self->_banned_pay_hashref } );
      if ( $ban ) {
        if ( $ban->bantype eq 'warn' ) {
          #or others depending on value of $ban->reason ?
          return '_duplicate_card'.
                 ': disabled from'. time2str('%a %h %o at %r', $ban->_date).
                 ' until '.         time2str('%a %h %o at %r', $ban->_end_date).
                 ' (ban# '. $ban->bannum. ')'
            unless $self->override_ban_warn;
        } else {
          return 'Banned credit card: banned on '.
                 time2str('%a %h %o at %r', $ban->_date).
                 ' by '. $ban->otaker.
                 ' (ban# '. $ban->bannum. ')';
        }
      }
    }

    if (length($self->paycvv) && !$self->is_encrypted($self->paycvv)) {
      if ( cardtype($self->payinfo) eq 'American Express card' ) {
        $self->paycvv =~ /^(\d{4})$/
          or return "CVV2 (CID) for American Express cards is four digits.";
        $self->paycvv($1);
      } else {
        $self->paycvv =~ /^(\d{3})$/
          or return "CVV2 (CVC2/CID) is three digits.";
        $self->paycvv($1);
      }
    } else {
      $self->paycvv('');
    }

    my $cardtype = cardtype($payinfo);
    if ( $cardtype =~ /^(Switch|Solo)$/i ) {

      return "Start date or issue number is required for $cardtype cards"
        unless $self->paystart_month && $self->paystart_year or $self->payissue;

      return "Start month must be between 1 and 12"
        if $self->paystart_month
           and $self->paystart_month < 1 || $self->paystart_month > 12;

      return "Start year must be 1990 or later"
        if $self->paystart_year
           and $self->paystart_year < 1990;

      return "Issue number must be beween 1 and 99"
        if $self->payissue
          and $self->payissue < 1 || $self->payissue > 99;

    } else {
      $self->paystart_month('');
      $self->paystart_year('');
      $self->payissue('');
    }

  } elsif ( !$ignore_invalid_card && 
    $check_payinfo && $self->payby =~ /^(CHEK|DCHK)$/ ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/[^\d\@\.]//g;
    if ( $conf->config('echeck-country') eq 'CA' ) {
      $payinfo =~ /^(\d+)\@(\d{5})\.(\d{3})$/
        or return 'invalid echeck account@branch.bank';
      $payinfo = "$1\@$2.$3";
    } elsif ( $conf->config('echeck-country') eq 'US' ) {
      $payinfo =~ /^(\d+)\@(\d{9})$/ or return 'invalid echeck account@aba';
      $payinfo = "$1\@$2";
    } else {
      $payinfo =~ /^(\d+)\@(\d+)$/ or return 'invalid echeck account@routing';
      $payinfo = "$1\@$2";
    }
    $self->payinfo($payinfo);
    $self->paycvv('');

    unless ( $ignore_banned_card ) {
      my $ban = FS::banned_pay->ban_search( %{ $self->_banned_pay_hashref } );
      if ( $ban ) {
        if ( $ban->bantype eq 'warn' ) {
          #or others depending on value of $ban->reason ?
          return '_duplicate_ach' unless $self->override_ban_warn;
        } else {
          return 'Banned ACH account: banned on '.
                 time2str('%a %h %o at %r', $ban->_date).
                 ' by '. $ban->otaker.
                 ' (ban# '. $ban->bannum. ')';
        }
      }
    }

  } elsif ( $self->payby eq 'LECB' ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $payinfo =~ /^1?(\d{10})$/ or return 'invalid btn billing telephone number';
    $payinfo = $1;
    $self->payinfo($payinfo);
    $self->paycvv('');

  } elsif ( $self->payby eq 'BILL' ) {

    $error = $self->ut_textn('payinfo');
    return "Illegal P.O. number: ". $self->payinfo if $error;
    $self->paycvv('');

  } elsif ( $self->payby eq 'COMP' ) {

    my $curuser = $FS::CurrentUser::CurrentUser;
    if (    ! $self->custnum
         && ! $curuser->access_right('Complimentary customer')
       )
    {
      return "You are not permitted to create complimentary accounts."
    }

    $error = $self->ut_textn('payinfo');
    return "Illegal comp account issuer: ". $self->payinfo if $error;
    $self->paycvv('');

  } elsif ( $self->payby eq 'PREPAY' ) {

    my $payinfo = $self->payinfo;
    $payinfo =~ s/\W//g; #anything else would just confuse things
    $self->payinfo($payinfo);
    $error = $self->ut_alpha('payinfo');
    return "Illegal prepayment identifier: ". $self->payinfo if $error;
    return "Unknown prepayment identifier"
      unless qsearchs('prepay_credit', { 'identifier' => $self->payinfo } );
    $self->paycvv('');

  }

  if ( $self->paydate eq '' || $self->paydate eq '-' ) {
    return "Expiration date required"
      # shouldn't payinfo_check do this?
      unless $self->payby =~ /^(BILL|PREPAY|CHEK|DCHK|LECB|CASH|WEST|MCRD|PPAL)$/;
    $self->paydate('');
  } else {
    my( $m, $y );
    if ( $self->paydate =~ /^(\d{1,2})[\/\-](\d{2}(\d{2})?)$/ ) {
      ( $m, $y ) = ( $1, length($2) == 4 ? $2 : "20$2" );
    } elsif ( $self->paydate =~ /^19(\d{2})[\/\-](\d{1,2})[\/\-]\d+$/ ) {
      ( $m, $y ) = ( $2, "19$1" );
    } elsif ( $self->paydate =~ /^(20)?(\d{2})[\/\-](\d{1,2})[\/\-]\d+$/ ) {
      ( $m, $y ) = ( $3, "20$2" );
    } else {
      return "Illegal expiration date: ". $self->paydate;
    }
    $m = sprintf('%02d',$m);
    $self->paydate("$y-$m-01");
    my($nowm,$nowy)=(localtime(time))[4,5]; $nowm++; $nowy+=1900;
    return gettext('expired_card')
      if #XXX !$import
      #&&
         !$ignore_expired_card 
      && ( $y<$nowy || ( $y==$nowy && $1<$nowm ) );
  }

  if ( $self->payname eq '' && $self->payby !~ /^(CHEK|DCHK)$/ &&
       ( ! $conf->exists('require_cardname')
         || $self->payby !~ /^(CARD|DCRD)$/  ) 
  ) {
    $self->payname( $self->first. " ". $self->getfield('last') );
  } else {
    $self->payname =~ /^([\w \,\.\-\'\&]+)$/
      or return gettext('illegal_name'). " payname: ". $self->payname;
    $self->payname($1);
  }

  ###

  $self->SUPER::check;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

