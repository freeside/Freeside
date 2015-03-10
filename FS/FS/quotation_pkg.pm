package FS::quotation_pkg;
use base qw( FS::TemplateItem_Mixin FS::Record );

use strict;
use FS::Record qw( qsearchs dbh ); #qsearch
use FS::part_pkg;
use FS::quotation_pkg_discount; #so its loaded when TemplateItem_Mixin needs it
use List::Util qw(sum);

=head1 NAME

FS::quotation_pkg - Object methods for quotation_pkg records

=head1 SYNOPSIS

  use FS::quotation_pkg;

  $record = new FS::quotation_pkg \%hash;
  $record = new FS::quotation_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::quotation_pkg object represents a quotation package.
FS::quotation_pkg inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item quotationpkgnum

primary key

=item pkgpart

pkgpart (L<FS::part_pkg>) of the package

=item locationnum

locationnum (L<FS::cust_location>) where the package will be in service

=item start_date

expected start date for the package, as a timestamp

=item contract_end

contract end date

=item quantity

quantity

=item waive_setup

'Y' to waive the setup fee

=item unitsetup

The amount per package that will be charged in setup/one-time fees.

=item unitrecur

The amount per package that will be charged per billing cycle.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new quotation package.  To add the quotation package to the database,
see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'quotation_pkg'; }

sub display_table         { 'quotation_pkg'; }

#forget it, just overriding cust_bill_pkg_display entirely
#sub display_table_orderby { 'quotationpkgnum'; } # something else?
#                                                 #  (for invoice display order)

sub discount_table        { 'quotation_pkg_discount'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my ($self, %options) = @_;

  my $dbh = dbh;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  my $error = $self->SUPER::insert;

  if ( !$error and $self->discountnum ) {
    $error = $self->insert_discount;
    $error .= ' (setting discount)' if $error;
  }

  # update $self and any discounts with their amounts
  if ( !$error ) {
    $error = $self->estimate;
    $error .= ' (calculating charges)' if $error;
  }

  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  } else {
    $dbh->commit if $oldAutoCommit;
    return '';
  }
}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  my $dbh = dbh;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  foreach ($self->quotation_pkg_discount, $self->quotation_pkg_tax) {
    my $error = $_->delete;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error . ' (deleting discount)';
    }
  }

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  } else {
    $dbh->commit if $oldAutoCommit;
    return '';
  }
  
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid quotation package.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('quotationpkgnum')
    || $self->ut_foreign_key(  'quotationnum', 'quotation',    'quotationnum' )
    || $self->ut_foreign_key(  'pkgpart',      'part_pkg',     'pkgpart'      )
    || $self->ut_foreign_keyn( 'locationnum', 'cust_location', 'locationnum'  )
    || $self->ut_numbern('start_date')
    || $self->ut_numbern('contract_end')
    || $self->ut_numbern('quantity')
    || $self->ut_moneyn('unitsetup')
    || $self->ut_moneyn('unitrecur')
    || $self->ut_enum('waive_setup', [ '', 'Y'] )
  ;

  if ($self->locationnum eq '') {
    # use the customer default
    my $quotation = $self->quotation;
    if ($quotation->custnum) {
      $self->set('locationnum', $quotation->cust_main->ship_locationnum);
    } elsif ($quotation->prospectnum) {
      # use the first non-disabled location for that prospect
      my $cust_location = qsearchs('cust_location',
        { prospectnum => $quotation->prospectnum,
          disabled => '' });
      $self->set('locationnum', $cust_location->locationnum) if $cust_location;
    } # else the quotation is invalid
  }

  return $error if $error;

  $self->SUPER::check;
}

#it looks redundant with a v4.x+ auto-generated method, but need to override
# FS::TemplateItem_Mixin's version
sub part_pkg {
  my $self = shift;
  qsearchs('part_pkg', { 'pkgpart' => $self->pkgpart } );
}

sub desc {
  my $self = shift;
  $self->part_pkg->pkg;
}

=item estimate

Update the quotation_pkg record with the estimated setup and recurring 
charges for the package. Returns nothing on success, or an error message
on failure.

=cut

sub estimate {
  my $self = shift;
  my $part_pkg = $self->part_pkg;
  my $quantity = $self->quantity || 1;
  my ($unitsetup, $unitrecur);
  # calculate base fees
  if ( $self->waive_setup eq 'Y' || $self->{'_NO_SETUP_KLUDGE'} ) {
    $unitsetup = '0.00';
  } else {
    $unitsetup = $part_pkg->base_setup;
  }
  if ( $self->{'_NO_RECUR_KLUDGE'} ) {
    $unitrecur = '0.00';
  } else {
    $unitrecur = $part_pkg->base_recur;
  }

  #XXX add-on packages

  $self->set('unitsetup', $unitsetup);
  $self->set('unitrecur', $unitrecur);
  my $error = $self->replace;
  return $error if $error;

  # semi-duplicates calc_discount
  my $setup_discount = 0;
  my $recur_discount = 0;

  my %setup_discounts; # quotationpkgdiscountnum => amount
  my %recur_discounts; # quotationpkgdiscountnum => amount

  # XXX the order of applying discounts is ill-defined, which matters
  # if there are percentage and amount discounts on the same package.
  #
  # but right now there can only be one discount on any package, so 
  # it doesn't matter
  foreach my $pkg_discount ($self->quotation_pkg_discount) {

    my $discount = $pkg_discount->discount;
    my $this_setup_discount = 0;
    my $this_recur_discount = 0;

    if ( $discount->percent > 0 ) {

      if ( $discount->setup ) {
        $this_setup_discount = ($discount->percent * $unitsetup / 100);
      }
      $this_recur_discount = ($discount->percent * $unitrecur / 100);

    } elsif ( $discount->amount > 0 ) {

      my $discount_left = $discount->amount;
      if ( $discount->setup ) {
        if ( $discount_left > $unitsetup - $setup_discount ) {
          # then discount the setup to zero
          $discount_left -= $unitsetup - $setup_discount;
          $this_setup_discount = $unitsetup - $setup_discount;
        } else {
          # not enough discount to fully cover the setup
          $this_setup_discount = $discount_left;
          $discount_left = 0;
        }
      }
      # same logic for recur
      if ( $discount_left > $unitrecur - $recur_discount ) {
        $this_recur_discount = $unitrecur - $recur_discount;
      } else {
        $this_recur_discount = $discount_left;
      }

    }

    # increment the total discountage
    $setup_discount += $this_setup_discount;
    $recur_discount += $this_recur_discount;
    # and update the pkg_discount object
    $pkg_discount->set('setup_amount', sprintf('%.2f', $setup_discount));
    $pkg_discount->set('recur_amount', sprintf('%.2f', $recur_discount));
    my $error = $pkg_discount->replace;
    return $error if $error;
  }

  '';
}

=item insert_discount

Associates this package with a discount (see L<FS::cust_pkg_discount>,
possibly inserting a new discount on the fly (see L<FS::discount>). Properties
of the discount will be taken from this object.

=cut

sub insert_discount {
  #my ($self, %options) = @_;
  my $self = shift;

  my $quotation_pkg_discount = FS::quotation_pkg_discount->new( {
    'quotationpkgnum' => $self->quotationpkgnum,
    'discountnum'     => $self->discountnum,
    #for the create a new discount case
    '_type'           => $self->discountnum__type,
    'amount'      => $self->discountnum_amount,
    'percent'     => $self->discountnum_percent,
    'months'      => $self->discountnum_months,
    'setup'       => $self->discountnum_setup,
  } );

  $quotation_pkg_discount->insert;
}

sub _item_discount {
  my $self = shift;
  my @pkg_discounts = $self->pkg_discount;
  return if @pkg_discounts == 0;
  
  my @ext;
  my $d = {
    _is_discount    => 1,
    description     => $self->mt('Discount'),
    setup_amount    => 0,
    recur_amount    => 0,
    amount          => 0,
    ext_description => \@ext,
    # maybe should show quantity/unit discount?
  };
  foreach my $pkg_discount (@pkg_discounts) {
    push @ext, $pkg_discount->description;
    $d->{setup_amount} -= $pkg_discount->setup_amount;
    $d->{recur_amount} -= $pkg_discount->recur_amount;
  }
  $d->{setup_amount} *= $self->quantity || 1;
  $d->{recur_amount} *= $self->quantity || 1;
  $d->{amount} = $d->{setup_amount} + $d->{recur_amount};
  
  return $d;
}

sub setup {
  my $self = shift;
  ($self->unitsetup - sum(0, map { $_->setup_amount } $self->pkg_discount))
    * ($self->quantity || 1);
}

sub recur {
  my $self = shift;
  ($self->unitrecur - sum(0, map { $_->recur_amount } $self->pkg_discount))
    * ($self->quantity || 1);
}

=item part_pkg_currency_option OPTIONNAME

Returns a two item list consisting of the currency of this quotation's customer
or prospect, if any, and a value for the provided option.  If the customer or
prospect has a currency, the value is the option value the given name and the
currency (see L<FS::part_pkg_currency>).  Otherwise, if the customer or
prospect has no currency, is the regular option value for the given name (see
L<FS::part_pkg_option>).

=cut

#false laziness w/cust_pkg->part_pkg_currency_option
sub part_pkg_currency_option {
  my( $self, $optionname ) = @_;
  my $part_pkg = $self->part_pkg;
  my $prospect_or_customer = $self->cust_main || $self->prospect_main;
  if ( my $currency = $prospect_or_customer->currency ) {
    ($currency, $part_pkg->part_pkg_currency_option($currency, $optionname) );
  } else {
    ('', $part_pkg->option($optionname) );
  }
}


=item cust_bill_pkg_display [ type => TYPE ]

=cut

sub cust_bill_pkg_display {
  my ( $self, %opt ) = @_;

  my $type = $opt{type} if exists $opt{type};
  return () if $type eq 'U'; #quotations don't have usage

  if ( $self->get('display') ) {
    return ( grep { defined($type) ? ($type eq $_->type) : 1 }
               @{ $self->get('display') }
           );
  } else {

    #??
    my $setup = $self->new($self->hashref);
    $setup->{'_NO_RECUR_KLUDGE'} = 1;
    $setup->{'type'} = 'S';
    my $recur = $self->new($self->hashref);
    $recur->{'_NO_SETUP_KLUDGE'} = 1;
    $recur->{'type'} = 'R';

    if ( $type eq 'S' ) {
sub tax_locationnum {
  my $self = shift;
  $self->locationnum;
}

      return ($setup);
    } elsif ( $type eq 'R' ) {
      return ($recur);
    } else {
      #return ($setup, $recur);
      return ($self);
    }

  }

}

=item cust_main

Returns the customer (L<FS::cust_main> object).

=cut

sub cust_main {
  my $self = shift;
  my $quotation = $self->quotation or return '';
  $quotation->cust_main;
}

=item prospect_main

Returns the prospect (L<FS::prospect_main> object).

=cut

sub prospect_main {
  my $self = shift;
  my $quotation = $self->quotation or return '';
  $quotation->prospect_main;
}


sub _upgrade_data {
  my $class = shift;
  my @quotation_pkg_without_location =
    qsearch( 'quotation_pkg', { locationnum => '' } );
  if (@quotation_pkg_without_location) {
    warn "setting default location on quotation_pkg records\n";
    foreach my $quotation_pkg (@quotation_pkg_without_location) {
      # check() will fix this
      my $error = $quotation_pkg->replace;
      if ($error) {
        die "quotation #".$quotation_pkg->quotationnum.": $error\n";
      }
    }
  }
  '';
}

=back

=head1 BUGS

Doesn't support fees, or add-on packages.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

