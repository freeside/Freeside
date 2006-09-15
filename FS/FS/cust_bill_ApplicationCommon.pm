package FS::cust_bill_ApplicationCommon;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Schema qw( dbdef );
use FS::Record qw( qsearch qsearchs dbh );

@ISA = qw( FS::Record );

$DEBUG = 1;

=head1 NAME

FS::cust_bill_ApplicationCommon - Base class for bill application classes

=head1 SYNOPSIS

use FS::cust_bill_ApplicationCommon;

@ISA = qw( FS::cust_bill_ApplicationCommon );

sub _app_source_name  { 'payment'; }
sub _app_source_table { 'cust_pay'; }
sub _app_lineitem_breakdown_table { 'cust_bill_pay_pkg'; }

=head1 DESCRIPTION

FS::cust_bill_ApplicationCommon is intended as a base class for classes which
represent application of things to invoices, currently payments
(see L<FS::cust_bill_pay>) or credits (see L<FS::cust_credit_bill>).

=head1 METHODS

=item insert

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

  my $error =    $self->SUPER::insert(@_)
              || $self->apply_to_lineitems;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

=cut

sub delete {
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

  foreach my $app ( $self->lineitem_applications ) {
    my $error = $app->delete;
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

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item apply_to_lineitems

Auto-applies this invoice application to specific line items, if possible.

=cut

sub apply_to_lineitems {
  my $self = shift;

  my @apply = ();

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my @open = $self->cust_bill->open_cust_bill_pkg; #FOR UPDATE...?
  warn scalar(@open). " open line items for invoice ".
       $self->cust_bill->invnum. "\n"
    if $DEBUG;
  my $total = 0;
  $total += $_->setup + $_->recur foreach @open;
  $total = sprintf('%.2f', $total);

  if ( $self->amount > $total ) {
    dbh->rollback if $oldAutoCommit;
    return "Can't apply a ". $self->_app_source_name. ' of $'. $self->amount.
           " greater than the remaining owed on line items (\$$total)";
  }

  #easy cases:
  # - one lineitem (a simple special case of:)
  # - amount is for whole invoice (well, all of remaining lineitem links)
  if ( $self->amount == $total ) {

    #@apply = map { [ $_, $_->amount ]; } @open;
    @apply = map { [ $_, $_->setup || $_->recur ]; } @open;

  } else {

    #slightly magic case:
    # - amount exactly and uniquely matches a single open lineitem
    #   (you must be trying to pay or credit that item, then)

    my @same = grep {    $_->setup == $self->amount
                      || $_->recur == $self->amount
                    }
                    @open;
    @apply = map { [ $_, $self->amount ]; } @same
      if scalar(@same) == 1;

  }

  #and the rest:
  # - leave unapplied, for now
  # - eventually, auto-apply?  sequentially?  pro-rated against total remaining?

  # do the applicaiton(s)
  my $table = $self->lineitem_breakdown_table;
  my $source_key = dbdef->table($self->table)->primary_key;
  foreach my $apply ( @apply ) {
    my ( $cust_bill_pkg, $amount ) = @$apply;
    my $application = "FS::$table"->new( {
      $source_key  => $self->$source_key(),
      'billpkgnum' => $cust_bill_pkg->billpkgnum,
      'amount'     => $amount,
      'setuprecur' => ( $cust_bill_pkg->setup > 0 ? 'setup' : 'recur' ),
      'sdate'      => $cust_bill_pkg->sdate,
      'edate'      => $cust_bill_pkg->edate,
    });
    my $error = $application->insert;
    if ( $error ) {
      dbh->rollbck if $oldAutoCommit;
      return $error;
    }
  }

  '';

}

=item lineitem_applications

Returns all the specific line item applications for this invoice application.

=cut

sub lineitem_applications {
  my $self = shift;
  my $primary_key = dbdef->table($self->table)->primary_key;
  qsearch({
    'table'   => $self->lineitem_breakdown_table, 
    'hashref' => { $primary_key => $self->$primary_key() },
  });

}

=item cust_bill 

Returns the invoice (see L<FS::cust_bill>)

=cut

sub cust_bill {
  my $self = shift;
  qsearchs( 'cust_bill', { 'invnum' => $self->invnum } );
}

=item lineitem_breakdown_table 

=cut

sub lineitem_breakdown_table {
  my $self = shift;
  $self->_load_table($self->_app_lineitem_breakdown_table);
}

sub _load_table {
  my( $self, $table ) = @_;
  eval "use FS::$table";
  die $@ if $@;
  $table;
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::cust_bill_pay> and L<FS::cust_bill_pay_pkg>,
L<FS::cust_credit_bill> and L<FS::cust_credit_bill_pkg>

=cut

1;

