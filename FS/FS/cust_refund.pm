package FS::cust_refund;

use strict;
use vars qw( @ISA );
use Business::CreditCard;
use FS::Record qw( qsearchs dbh );
use FS::UID qw(getotaker);
use FS::cust_credit;
use FS::cust_credit_refund;
use FS::cust_main;

@ISA = qw( FS::Record );

=head1 NAME

FS::cust_refund - Object method for cust_refund objects

=head1 SYNOPSIS

  use FS::cust_refund;

  $record = new FS::cust_refund \%hash;
  $record = new FS::cust_refund { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_refund represents a refund: the transfer of money to a customer;
equivalent to a negative payment (see L<FS::cust_pay>).  FS::cust_refund
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item refundnum - primary key (assigned automatically for new refunds)

=item custnum - customer (see L<FS::cust_main>)

=item refund - Amount of the refund

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby - `CARD' (credit cards), `CHEK' (electronic check/ACH),
`LECB' (Phone bill billing), `BILL' (billing), or `COMP' (free)

=item payinfo - card number, P.O.#, or comp issuer (4-8 lowercase alphanumerics; think username)

=item paybatch - text field for tracking card processing

=item otaker - order taker (assigned automatically, see L<FS::UID>)

=item closed - books closed flag, empty or `Y'

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new refund.  To add the refund to the database, see L<"insert">.

=cut

sub table { 'cust_refund'; }

=item insert

Adds this refund to the database.

For backwards-compatibility and convenience, if the additional field crednum is
defined, an FS::cust_credit_refund record for the full amount of the refund
will be created.  In this case, custnum is optional.

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

  if ( $self->crednum ) {
    my $cust_credit = qsearchs('cust_credit', { 'crednum' => $self->crednum } )
      or do {
        $dbh->rollback if $oldAutoCommit;
        return "Unknown cust_credit.crednum: ". $self->crednum;
      };
    $self->custnum($cust_credit->custnum);
  }

  my $error = $self->check;
  return $error if $error;

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $self->crednum ) {
    my $cust_credit_refund = new FS::cust_credit_refund {
      'crednum'   => $self->crednum,
      'refundnum' => $self->refundnum,
      'amount'    => $self->refund,
      '_date'     => $self->_date,
    };
    $error = $cust_credit_refund->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    #$self->custnum($cust_credit_refund->cust_credit->custnum);
  }


  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

sub upgrade_replace { #1.3.x->1.4.x
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

  my $error = $self->check;
  return $error if $error;

  my %new = $self->hash;
  my $new = FS::cust_refund->new(\%new);

  if ( $self->crednum ) {
    my $cust_credit_refund = new FS::cust_credit_refund {
      'crednum'   => $self->crednum,
      'refundnum' => $self->refundnum,
      'amount'    => $self->refund,
      '_date'     => $self->_date,
    };
    $error = $cust_credit_refund->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    $new->custnum($cust_credit_refund->cust_credit->custnum);
  } else {
    die;
  }

  $error = $new->SUPER::replace($self);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Currently unimplemented (accounting reasons).

=cut

sub delete {
  my $self = shift;
  return "Can't delete closed refund" if $self->closed =~ /^Y/i;
  $self->SUPER::delete(@_);
}

=item replace OLD_RECORD

Currently unimplemented (accounting reasons).

=cut

sub replace {
   return "Can't (yet?) modify cust_refund records!";
}

=item check

Checks all fields to make sure this is a valid refund.  If there is an error,
returns the error, otherwise returns false.  Called by the insert method.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('refundnum')
    || $self->ut_numbern('custnum')
    || $self->ut_money('refund')
    || $self->ut_numbern('_date')
    || $self->ut_textn('paybatch')
    || $self->ut_enum('closed', [ '', 'Y' ])
  ;
  return $error if $error;

  return "refund must be > 0 " if $self->refund <= 0;

  $self->_date(time) unless $self->_date;

  return "unknown cust_main.custnum: ". $self->custnum
    unless $self->crednum 
           || qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->payby =~ /^(CARD|CHEK|LECB|BILL|COMP)$/ or return "Illegal payby";
  $self->payby($1);

  #false laziness with cust_pay::check
  if ( $self->payby eq 'CARD' ) {
    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $self->payinfo($payinfo);
    if ( $self->payinfo ) {
      $self->payinfo =~ /^(\d{13,16})$/
        or return "Illegal (mistyped?) credit card number (payinfo)";
      $self->payinfo($1);
      validate($self->payinfo) or return "Illegal credit card number";
      return "Unknown card type" if cardtype($self->payinfo) eq "Unknown";
    } else {
      $self->payinfo('N/A');
    }

  } else {
    $error = $self->ut_textn('payinfo');
    return $error if $error;
  }

  $self->otaker(getotaker);

  $self->SUPER::check;
}

=back

=head1 VERSION

$Id: cust_refund.pm,v 1.21 2003-08-05 00:20:42 khoff Exp $

=head1 BUGS

Delete and replace methods.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_credit>, schema.html from the base documentation.

=cut

1;

