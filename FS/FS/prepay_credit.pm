package FS::prepay_credit;

use strict;
use vars qw( @ISA $DEBUG $me );
use FS::Record qw(qsearchs dbh);
use FS::agent;

@ISA = qw(FS::Record);

$DEBUG = 0;
$me = '[FS::prepay_credit]';

=head1 NAME

FS::prepay_credit - Object methods for prepay_credit records

=head1 SYNOPSIS

  use FS::prepay_credit;

  $record = new FS::prepay_credit \%hash;
  $record = new FS::prepay_credit {
    'identifier' => '4198123455512121'
    'amount'     => '19.95',
  };

  $record = new FS::prepay_credit {
    'identifier' => '4198123455512121'
    'seconds'    => '7200',
  };


  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::prepay_credit object represents a pre-paid card.  FS::prepay_credit
inherits from FS::Record.  The following
fields are currently supported:

=over 4

=item field - description

=item identifier - identifier entered by the user to receive the credit

=item amount - amount of the credit

=item seconds - time amount of credit (see L<FS::svc_acct/seconds>)

=item agentnum - optional agent (see L<FS::agent>) for this prepaid card

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new pre-paid credit.  To add the pre-paid credit to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'prepay_credit'; }

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

Checks all fields to make sure this is a valid pre-paid credit.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $identifier = $self->identifier;
  $identifier =~ s/\W//g; #anything else would just confuse things
  $self->identifier($identifier);

  $self->ut_numbern('prepaynum')
  || $self->ut_alpha('identifier')
  || $self->ut_money('amount')
  || $self->ut_numbern('seconds')
  || $self->ut_numbern('upbytes')
  || $self->ut_numbern('downbytes')
  || $self->ut_numbern('totalbytes')
  || $self->ut_foreign_keyn('agentnum', 'agent', 'agentnum')
  || $self->SUPER::check
  ;

}

=item agent

Returns the agent (see L<FS::agent>) for this prepaid card, if any.

=cut

sub agent {
  my $self = shift;
  qsearchs('agent', { 'agentnum' => $self->agentnum } );
}

=back

=head1 SUBROUTINES

=over 4

=item generate NUM TYPE LENGTH HASHREF

Generates the specified number of prepaid cards.  Returns an array reference of
the newly generated card identifiers, or a scalar error message.

=cut

#false laziness w/agent::generate_reg_codes
sub generate {
  my( $num, $type, $length, $hashref ) = @_;

  my @codeset = ();
  push @codeset, ( 'A'..'Z' ) if $type =~ /alpha/;
  push @codeset, ( '1'..'9' ) if $type =~ /numeric/;
  $length ||= 8;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $condup = 0; #don't retry forever
  
  my @cards = ();
  for ( 1 ... $num ) {

    my $identifier = join('', map($codeset[int(rand $#codeset)], (1..$length) ) );

    if ( qsearchs('prepay_credit',{identifier=>$identifier}) ) {
      if ( $condup++ < 54 ) {
        warn "$me generate: duplicate identifier $identifier; retrying\n"
          if $DEBUG;
        redo;
      } else {
        warn "$me generate: giving up after 54 tries"
          if $DEBUG;
      }
    }
    $condup = 0;

    my $prepay_credit = new FS::prepay_credit {
      'identifier' => $identifier,
      %$hashref,
    };
    my $error = $prepay_credit->check || $prepay_credit->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "(inserting prepay_credit) $error";
    }
    push @cards, $prepay_credit->identifier;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  \@cards;

}

=head1 BUGS

=head1 SEE ALSO

L<FS::svc_acct>, L<FS::Record>, schema.html from the base documentation.

=cut

1;

