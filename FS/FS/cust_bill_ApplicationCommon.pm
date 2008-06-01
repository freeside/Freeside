package FS::cust_bill_ApplicationCommon;

use strict;
use vars qw( @ISA $DEBUG $me );
use List::Util qw(min);
use FS::Schema qw( dbdef );
use FS::Record qw( qsearch qsearchs dbh );

@ISA = qw( FS::Record );

$DEBUG = 0;
$me = '[FS::cust_bill_ApplicationCommon]';

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
  warn "$me ". scalar(@open). " open line items for invoice ".
       $self->cust_bill->invnum. ": ". join(', ', @open). "\n"
    if $DEBUG;
  my $total = 0;
  $total += $_->setup + $_->recur foreach @open;
  $total = sprintf('%.2f', $total);

  if ( $self->amount > $total ) {
    $dbh->rollback if $oldAutoCommit;
    return "Can't apply a ". $self->_app_source_name. ' of $'. $self->amount.
           " greater than the remaining owed on line items (\$$total)";
  }

  #easy cases:
  # - one lineitem (a simple special case of:)
  # - amount is for whole invoice (well, all of remaining lineitem links)
  if ( $self->amount == $total ) {

    warn "$me application amount covers remaining balance of invoice in full;".
         "applying to those lineitems\n"
      if $DEBUG;

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
    if ( scalar(@same) == 1 ) {
      warn "$me application amount exactly and uniquely matches one lineitem;".
           " applying to that lineitem\n"
        if $DEBUG;
      @apply = map { [ $_, $self->amount ]; } @same
    }

  }

  unless ( @apply ) {

    warn "$me applying amount based on package weights\n"
      if $DEBUG;

    #and the rest:
    # - apply based on weights...

    my $weight_col = $self->_app_part_pkg_weight_column;
    my @openweight = map { 
                           my $open = $_;
                           my $cust_pkg = $open->cust_pkg;
                           my $weight =
                             $cust_pkg
                               ? ( $cust_pkg->part_pkg->$weight_col() || 0 )
                               : 0; #default or per-tax weight?
                           [ $open, $weight ]
                         }
                         @open;

    my %saw = ();
    my @weights = sort { $b <=> $a }     # highest weight first
                  grep { ! $saw{$_}++ }  # want a list of unique weights
		  map  { $_->[1] }
                       @openweight;
  
    my $remaining_amount = $self->amount;
    foreach my $weight ( @weights ) {

      #i hate it when my schwartz gets tangled
      my @items = map { $_->[0] } grep { $weight == $_->[1] } @openweight;

      my $itemtotal = 0;
      foreach my $item (@items) { $itemtotal += $item->setup || $item->recur; }
      my $applytotal = min( $itemtotal, $remaining_amount );
      $remaining_amount -= $applytotal;

      warn "$me applying $applytotal ($remaining_amount remaining)".
           " to ". scalar(@items). " lineitems with weight $weight\n"
        if $DEBUG;

      #if some items are less than applytotal/num_items, then apply then in full
      my $lessflag;
      do {
	$lessflag = 0;

	#no, not sprintf("%.2f",
	# we want this rounded DOWN for purposes of checking for line items
	# less than it, we don't want .66666 becoming .67 and causing this
	# to trigger when it shouldn't
        my $applyeach = int( 100 * $applytotal / scalar(@items) ) / 100;

	my @newitems = ();
	foreach my $item ( @items ) {
	  my $itemamount = $item->setup || $item->recur;
          if ( $itemamount < $applyeach ) {
	    warn "$me applying full $itemamount".
	         " to small line item (cust_bill_pkg ". $item->billpkgnum. ")\n"
	      if $DEBUG;
	    push @apply, [ $item, $itemamount ];
	    $applytotal -= $itemamount;
            $lessflag=1;
	  } else {
	    push @newitems, $item;
	  }
	}
	@items = @newitems;

      } while ( $lessflag );

      #and now that we've fallen out of the loop, distribute the rest equally...

      # should cust_bill_pay_pkg and cust_credit_bill_pkg amount columns
      # become real instead of numeric(10,2) ???  no..
      my $applyeach = sprintf("%.2f", $applytotal / scalar(@items) );

      my @equi_apply = map { [ $_, $applyeach ] } @items;

      # or should we futz with pennies instead?  yes, bah!
      my $diff =
        sprintf('%.0f', 100 * ( $applytotal - $applyeach * scalar(@items) ) );
      $diff = 0 if $diff eq '-0'; #yay ieee fp
      if ( abs($diff) > scalar(@items) ) {
        #we must have done something really wrong, the difference is more than
	#a penny an item
	$dbh->rollback if $oldAutoCommit;
	return 'Error distributing pennies applying '. $self->_app_source_name.
	       " - can't distribute difference of $diff pennies".
	       ' among '. scalar(@items). ' line items';
      }

      warn "$me futzing with $diff pennies difference\n"
        if $DEBUG && $diff;

      my $futz = 0;
      while ( $diff != 0 && $futz < scalar(@equi_apply) ) {
        if ( $diff > 0 ) { 
	  $equi_apply[$futz++]->[1] += .01;
	  $diff -= 1;
	} elsif ( $diff < 0 ) {
	  $equi_apply[$futz++]->[1] -= .01;
	  $diff += 1;
	} else {
	  die "guru exception #5 (in fortran tongue the answer)";
	}
      }

      if ( sprintf('%.0f', $diff ) ) {
        $dbh->rollback if $oldAutoCommit;
	return "couldn't futz with pennies enough: still $diff left";
      }

      if ( $DEBUG ) {
        warn "$me applying ". $_->[1].
	     " to line item (cust_bill_pkg ". $_->[0]->billpkgnum. ")\n"
	  foreach @equi_apply;
      }


      push @apply, @equi_apply;

      #$remaining_amount -= $applytotal;
      last unless $remaining_amount;

    }

  }

  # do the applicaiton(s)
  my $table = $self->lineitem_breakdown_table;
  my $source_key = dbdef->table($self->table)->primary_key;
  my $applied = 0;
  foreach my $apply ( @apply ) {
    my ( $cust_bill_pkg, $amount ) = @$apply;
    $applied += $amount;
    my $application = "FS::$table"->new( {
      $source_key  => $self->$source_key(),
      'billpkgnum' => $cust_bill_pkg->billpkgnum,
      'amount'     => sprintf('%.2f', $amount),
      'setuprecur' => ( $cust_bill_pkg->setup > 0 ? 'setup' : 'recur' ),
      'sdate'      => $cust_bill_pkg->sdate,
      'edate'      => $cust_bill_pkg->edate,
    });
    my $error = $application->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  #everything should always be applied to line items in full now... sanity check
  $applied = sprintf('%.2f', $applied);
  unless ( $applied == $self->amount ) {
    $dbh->rollback if $oldAutoCommit;
    return 'Error applying '. $self->_app_source_name. ' of $'. $self->amount.
           ' to line items - only $'. $applied. ' was applied.';
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
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

=item applied_to_invoice

Returns a string representing the invoice (see L<FS::cust_bill), for example:
"applied to Invoice #54 (3/20/2008)"

=cut

sub applied_to_invoice {
  my $self = shift;
  'applied to '. $self->cust_bill->invnum_date_pretty;
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

