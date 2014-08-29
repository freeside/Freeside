package FS::cust_bill_void;
use base qw( FS::Template_Mixin FS::cust_main_Mixin FS::otaker_Mixin FS::Record );

use strict;
use FS::Record qw( qsearch qsearchs dbh fields );
use FS::cust_statement;
use FS::access_user;
use FS::cust_bill_pkg_void;
use FS::cust_bill;

=head1 NAME

FS::cust_bill_void - Object methods for cust_bill_void records

=head1 SYNOPSIS

  use FS::cust_bill_void;

  $record = new FS::cust_bill_void \%hash;
  $record = new FS::cust_bill_void { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_void object represents a voided invoice.  FS::cust_bill_void
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item invnum

primary key

=item custnum

custnum

=item _date

_date

=item charged

charged

=item invoice_terms

invoice_terms

=item previous_balance

previous_balance

=item billing_balance

billing_balance

=item closed

closed

=item statementnum

statementnum

=item agent_invid

agent_invid

=item promised_date

promised_date

=item void_date

void_date

=item reason

reason

=item void_usernum

void_usernum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new voided invoice.  To add the voided invoice to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_bill_void'; }
sub notice_name { 'VOIDED Invoice'; }
#XXXsub template_conf { 'quotation_'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

=item unvoid 

"Un-void"s this invoice: Deletes the voided invoice from the database and adds
back a normal invoice (and related tables).

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

  my $cust_bill = new FS::cust_bill ( {
    map { $_ => $self->get($_) } fields('cust_bill')
  } );
  my $error = $cust_bill->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  foreach my $cust_bill_pkg_void ( $self->cust_bill_pkg ) {
    my $error = $cust_bill_pkg_void->unvoid;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
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

Delete this record from the database.

=cut

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

=item check

Checks all fields to make sure this is a valid voided invoice.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_number('invnum')
    || $self->ut_foreign_key('custnum', 'cust_main', 'custnum' )
    || $self->ut_numbern('_date')
    || $self->ut_money('charged')
    || $self->ut_textn('invoice_terms')
    || $self->ut_moneyn('previous_balance')
    || $self->ut_moneyn('billing_balance')
    || $self->ut_enum('closed', [ '', 'Y' ])
    || $self->ut_foreign_keyn('statementnum', 'cust_statement', 'statementnum')
    || $self->ut_numbern('agent_invid')
    || $self->ut_numbern('promised_date')
    || $self->ut_numbern('void_date')
    || $self->ut_textn('reason')
    || $self->ut_numbern('void_usernum')
  ;
  return $error if $error;

  $self->void_date(time) unless $self->void_date;

  $self->void_usernum($FS::CurrentUser::CurrentUser->usernum)
    unless $self->void_usernum;

  $self->SUPER::check;
}

=item display_invnum

Returns the displayed invoice number for this invoice: agent_invid if
cust_bill-default_agent_invid is set and it has a value, invnum otherwise.

=cut

sub display_invnum {
  my $self = shift;
  my $conf = $self->conf;
  if ( $conf->exists('cust_bill-default_agent_invid') && $self->agent_invid ){
    return $self->agent_invid;
  } else {
    return $self->invnum;
  }
}

=item void_access_user

Returns the voiding employee object (see L<FS::access_user>).

=cut

sub void_access_user {
  my $self = shift;
  qsearchs('access_user', { 'usernum' => $self->void_usernum } );
}

=item cust_main

=item cust_bill_pkg

=cut

sub cust_bill_pkg { #actually cust_bill_pkg_void objects
  my $self = shift;
  qsearch('cust_bill_pkg_void', { invnum=>$self->invnum });
}

=back

=item cust_pkg

Returns the packages (see L<FS::cust_pkg>) corresponding to the line items for
this invoice.

=cut

sub cust_pkg {
  my $self = shift;
  my @cust_pkg = map { $_->pkgnum > 0 ? $_->cust_pkg : () }
                 $self->cust_bill_pkg;
  my %saw = ();
  grep { ! $saw{$_->pkgnum}++ } @cust_pkg;
}

=item search_sql_where HASHREF

Class method which returns an SQL WHERE fragment to search for parameters
specified in HASHREF.  Accepts the following parameters for 
L<FS::cust_bill::search_sql_where>: C<_date>, C<invnum_min>, C<invnum_max>,
C<agentnum>, C<custnum>, C<cust_classnum>, C<refnum>, C<payby>.  Also 
accepts the following:

=over 4

=item void_date

Arrayref of start and end date to find invoices voided in a date range.

=item void_usernum

User identifier (L<FS::access_user> key) that voided the invoice.

=back

=cut

sub search_sql_where {
  my($class, $param) = @_;

  my $cust_bill_param = {
    map { $_ => $param->{$_} }
    grep { exists($param->{$_}) }
    qw( _date invnum_min invnum_max agentnum custnum cust_classnum 
        refnum payby )
  };
  my $search_sql = FS::cust_bill->search_sql_where($cust_bill_param);
  $search_sql =~ s/cust_bill/cust_bill_void/g;
  my @search = ($search_sql);

  if ( $param->{void_date} ) {
    my($beginning, $ending) = @{$param->{void_date}};
    push @search, "cust_bill_void.void_date >= $beginning",
                  "cust_bill_void.void_date <  $ending";
  }

  if ( $param->{void_usernum} =~ /^(\d+)$/ ) {
    my $usernum = $1;
    push @search, "cust_bill_void.void_usernum = $1";
  }

  join(" AND ", @search);
}


=item enable_previous

=cut

sub enable_previous { 0 }

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

