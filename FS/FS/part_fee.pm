package FS::part_fee;

use strict;
use base qw( FS::o2m_Common FS::Record );
use vars qw( $DEBUG );
use FS::Record qw( qsearch qsearchs );
use FS::pkg_class;
use FS::cust_bill_pkg_display;
use FS::part_pkg_taxproduct;
use FS::agent;
use FS::part_fee_usage;

$DEBUG = 0;

=head1 NAME

FS::part_fee - Object methods for part_fee records

=head1 SYNOPSIS

  use FS::part_fee;

  $record = new FS::part_fee \%hash;
  $record = new FS::part_fee { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::part_fee object represents the definition of a fee

Fees are like packages, but instead of being ordered and then billed on a 
cycle, they are created by the operation of events and added to a single
invoice.  The fee definition specifies the fee's description, how the amount
is calculated (a flat fee or a percentage of the customer's balance), and 
how to classify the fee for tax and reporting purposes.

FS::part_fee inherits from FS::Record.  The following fields are currently 
supported:

=over 4

=item feepart - primary key

=item comment - a description of the fee for employee use, not shown on 
the invoice

=item disabled - 'Y' if the fee is disabled

=item classnum - the L<FS::pkg_class> that the fee belongs to, for reporting

=item taxable - 'Y' if this fee should be considered a taxable sale.  
Currently, taxable fees will be treated like they exist at the customer's
default service location.

=item taxclass - the tax class the fee belongs to, as a string, for the 
internal tax system

=item taxproductnum - the tax product family the fee belongs to, for the 
external tax system in use, if any

=item pay_weight - Weight (relative to credit_weight and other package/fee 
definitions) that controls payment application to specific line items.

=item credit_weight - Weight that controls credit application to specific
line items.

=item agentnum - the agent (L<FS::agent>) who uses this fee definition.

=item amount - the flat fee to charge, as a decimal amount

=item percent - the percentage of the base to charge (out of 100).  If both
this and "amount" are specified, the fee will be the sum of the two.

=item basis - the method for calculating the base: currently one of "charged",
"owed", or null.

=item minimum - the minimum fee that should be charged

=item maximum - the maximum fee that should be charged

=item limit_credit - 'Y' to set the maximum fee at the customer's credit 
balance, if any.

=item setuprecur - whether the fee should be classified as 'setup' or 
'recur', for reporting purposes.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new fee definition.  To add the record to the database, see 
L<"insert">.

=cut

sub table { 'part_fee'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  $self->set('amount', 0) unless $self->amount;
  $self->set('percent', 0) unless $self->percent;

  my $error = 
    $self->ut_numbern('feepart')
    || $self->ut_textn('comment')
    || $self->ut_flag('disabled')
    || $self->ut_foreign_keyn('classnum', 'pkg_class', 'classnum')
    || $self->ut_flag('taxable')
    || $self->ut_textn('taxclass')
    || $self->ut_numbern('taxproductnum')
    || $self->ut_floatn('pay_weight')
    || $self->ut_floatn('credit_weight')
    || $self->ut_agentnum_acl('agentnum',
                              [ 'Edit global package definitions' ])
    || $self->ut_money('amount')
    || $self->ut_float('percent')
    || $self->ut_moneyn('minimum')
    || $self->ut_moneyn('maximum')
    || $self->ut_flag('limit_credit')
    || $self->ut_enum('basis', [ 'charged', 'owed', 'usage' ])
    || $self->ut_enum('setuprecur', [ 'setup', 'recur' ])
  ;
  return $error if $error;

  if ( $self->get('limit_credit') ) {
    $self->set('maximum', '');
  }

  if ( $self->get('basis') eq 'usage' ) {
    # to avoid confusion, don't also allow charging a percentage
    $self->set('percent', 0);
  }

  $self->SUPER::check;
}

=item explanation

Returns a string describing how this fee is calculated.

=cut

sub explanation {
  my $self = shift;
  # XXX customer currency
  my $money_char = FS::Conf->new->config('money_char') || '$';
  my $money = $money_char . '%.2f';
  my $percent = '%.1f%%';
  my $string = '';
  if ( $self->amount > 0 ) {
    $string = sprintf($money, $self->amount);
  }
  if ( $self->percent > 0 ) {
    if ( $string ) {
      $string .= " plus ";
    }
    $string .= sprintf($percent, $self->percent);
    $string .= ' of the ';
    if ( $self->basis eq 'charged' ) {
      $string .= 'invoice amount';
    } elsif ( $self->basis('owed') ) {
      $string .= 'unpaid invoice balance';
    }
  } elsif ( $self->basis eq 'usage' ) {
    if ( $string ) {
      $string .= " plus \n";
    }
    # append per-class descriptions
    $string .= join("\n", map { $_->explanation } $self->part_fee_usage);
  }

  if ( $self->minimum or $self->maximum or $self->limit_credit ) {
    $string .= "\nbut";
    if ( $self->minimum ) {
      $string .= ' at least '.sprintf($money, $self->minimum);
    }
    if ( $self->maximum ) {
      $string .= ' and' if $self->minimum;
      $string .= ' at most '.sprintf($money, $self->maximum);
    }
    if ( $self->limit_credit ) {
      if ( $self->maximum ) {
        $string .= ", or the customer's credit balance, whichever is less.";
      } else {
        $string .= ' and' if $self->minimum;
        $string .= " not more than the customer's credit balance";
      }
    }
  }
  return $string;
}

=item lineitem INVOICE

Given INVOICE (an L<FS::cust_bill>), returns an L<FS::cust_bill_pkg> object 
representing the invoice line item for the fee, with linked 
L<FS::cust_bill_pkg_fee> record(s) allocating the fee to the invoice or 
its line items, as appropriate.

If the fee is going to be charged on the upcoming invoice (credit card 
processing fees, postal invoice fees), INVOICE should be an uninserted
L<FS::cust_bill> object where the 'cust_bill_pkg' property is an arrayref
of the non-fee line items that will appear on the invoice.

=cut

sub lineitem {
  my $self = shift;
  my $cust_bill = shift;
  my $cust_main = $cust_bill->cust_main;

  my $amount = 0 + $self->get('amount');
  my $total_base;  # sum of base line items
  my @items;       # base line items (cust_bill_pkg records)
  my @item_base;   # charged/owed of that item (sequential w/ @items)
  my @item_fee;    # fee amount of that item (sequential w/ @items)
  my @cust_bill_pkg_fee; # link record

  warn "Calculating fee: ".$self->itemdesc." on ".
    ($cust_bill->invnum ? "invoice #".$cust_bill->invnum : "current invoice").
    "\n" if $DEBUG;
  my $basis = $self->basis;

  # $total_base: the total charged/owed on the invoice
  # %item_base: billpkgnum => fraction of base amount
  if ( $cust_bill->invnum ) {

    # calculate the fee on an already-inserted past invoice.  This may have 
    # payments or credits, so if basis = owed, we need to consider those.
    @items = $cust_bill->cust_bill_pkg;
    if ( $basis ne 'usage' ) {

      $total_base = $cust_bill->$basis; # "charged", "owed"
      my $basis_sql = $basis.'_sql';
      my $sql = 'SELECT ' . FS::cust_bill_pkg->$basis_sql .
                ' FROM cust_bill_pkg WHERE billpkgnum = ?';
      @item_base = map { FS::Record->scalar_sql($sql, $_->billpkgnum) }
                    @items;

      $amount += $total_base * $self->percent / 100;
    }
  } else {
    # the fee applies to _this_ invoice.  It has no payments or credits, so
    # "charged" and "owed" basis are both just the invoice amount, and 
    # the line item amounts (setup + recur)
    @items = @{ $cust_bill->get('cust_bill_pkg') };
    if ( $basis ne 'usage' ) {
      $total_base = $cust_bill->charged;
      @item_base = map { $_->setup + $_->recur }
                    @items;

      $amount += $total_base * $self->percent / 100;
    }
  }

  if ( $basis eq 'usage' ) {

    my %part_fee_usage = map { $_->classnum => $_ } $self->part_fee_usage;

    foreach my $item (@items) { # cust_bill_pkg objects
      my $usage_fee = 0;
      $item->regularize_details;
      my $details;
      if ( $item->billpkgnum ) {
        $details = [
          qsearch('cust_bill_pkg_detail', { billpkgnum => $item->billpkgnum })
        ];
      } else {
        $details = $item->get('details') || [];
      }
      foreach my $d (@$details) {
        # if there's a usage fee defined for this class...
        next if $d->amount eq '' # not a real usage detail
             or $d->amount == 0  # zero charge, probably shouldn't charge fee
        ;
        my $p = $part_fee_usage{$d->classnum} or next;
        $usage_fee += ($d->amount * $p->percent / 100)
                    + $p->amount;
        # we'd create detail records here if we were doing that
      }
      # bypass @item_base entirely
      push @item_fee, $usage_fee;
      $amount += $usage_fee;
    }

  } # if $basis eq 'usage'

  if ( $self->minimum ne '' and $amount < $self->minimum ) {
    warn "Applying mininum fee\n" if $DEBUG;
    $amount = $self->minimum;
  }

  my $maximum = $self->maximum;
  if ( $self->limit_credit ) {
    my $balance = $cust_bill->cust_main->balance;
    if ( $balance >= 0 ) {
      warn "Credit balance is zero, so fee is zero" if $DEBUG;
      return; # don't bother doing estimated tax, etc.
    } elsif ( -1 * $balance < $maximum ) {
      $maximum = -1 * $balance;
    }
  }
  if ( $maximum ne '' and $amount > $maximum ) {
    warn "Applying maximum fee\n" if $DEBUG;
    $amount = $maximum;
  }

  # at this point, if the fee is zero, return nothing
  return if $amount < 0.005;
  $amount = sprintf('%.2f', $amount);

  my $cust_bill_pkg = FS::cust_bill_pkg->new({
      feepart     => $self->feepart,
      pkgnum      => 0,
      # no sdate/edate, right?
      setup       => 0,
      recur       => 0,
  });

  if ( $maximum and $self->taxable ) {
    warn "Estimating taxes on fee.\n" if $DEBUG;
    # then we need to estimate tax to respect the maximum
    # XXX currently doesn't work with external (tax_rate) taxes
    # or batch taxes, obviously
    my $taxlisthash = {};
    my $error = $cust_main->_handle_taxes(
      $taxlisthash,
      $cust_bill_pkg,
      location => $cust_main->ship_location
    );
    my $total_rate = 0;
    # $taxlisthash: tax identifier => [ cust_main_county, cust_bill_pkg... ]
    my @taxes = map { $_->[0] } values %$taxlisthash;
    foreach (@taxes) {
      $total_rate += $_->tax;
    }
    if ($total_rate > 0) {
      my $max_cents = $maximum * 100;
      my $charge_cents = sprintf('%0.f', $max_cents * 100/(100 + $total_rate));
      # the actual maximum that we can charge...
      $maximum = sprintf('%.2f', $charge_cents / 100.00);
      $amount = $maximum if $amount > $maximum;
    }
  } # if $maximum and $self->taxable

  # set the amount that we'll charge
  $cust_bill_pkg->set( $self->setuprecur, $amount );

  # create display record
  my $categoryname = '';
  if ( $self->classnum ) {
    my $pkg_category = $self->pkg_class->pkg_category;
    $categoryname = $pkg_category->categoryname if $pkg_category;
  }
  my $displaytype = ($self->setuprecur eq 'setup') ? 'S' : 'R';
  my $display = FS::cust_bill_pkg_display->new({
      type    => $displaytype,
      section => $categoryname,
      # post_total? summary? who the hell knows?
  });
  $cust_bill_pkg->set('display', [ $display ]);

  # if this is a percentage fee and has line item fractions,
  # adjust them to be proportional and to add up correctly.
  if ( @item_base ) {
    my $cents = $amount * 100;
    # not necessarily the same as percent
    my $multiplier = $amount / $total_base;
    for (my $i = 0; $i < scalar(@items); $i++) {
      my $fee = sprintf('%.2f', $item_base[$i] * $multiplier);
      $item_fee[$i] = $fee;
      $cents -= $fee * 100;
    }
    # correct rounding error
    while ($cents >= 0.5 or $cents < -0.5) {
      foreach my $fee (@item_fee) {
        if ( $cents >= 0.5 ) {
          $fee += 0.01;
          $cents--;
        } elsif ( $cents < -0.5 ) {
          $fee -= 0.01;
          $cents++;
        }
      }
    }
  }
  if ( @item_fee ) {
    # add allocation records to the cust_bill_pkg
    for (my $i = 0; $i < scalar(@items); $i++) {
      if ( $item_fee[$i] > 0 ) {
        push @cust_bill_pkg_fee, FS::cust_bill_pkg_fee->new({
            cust_bill_pkg   => $cust_bill_pkg,
            base_invnum     => $cust_bill->invnum, # may be null
            amount          => $item_fee[$i],
            base_cust_bill_pkg => $items[$i], # late resolve
        });
      }
    }
  } else { # if !@item_fee
    # then this isn't a proportional fee, so it just applies to the 
    # entire invoice.
    push @cust_bill_pkg_fee, FS::cust_bill_pkg_fee->new({
        cust_bill_pkg   => $cust_bill_pkg,
        base_invnum     => $cust_bill->invnum, # may be null
        amount          => $amount,
    });
  }

  # cust_bill_pkg::insert will handle this
  $cust_bill_pkg->set('cust_bill_pkg_fee', \@cust_bill_pkg_fee);
  # avoid misbehavior by usage() and some other things
  $cust_bill_pkg->set('details', []);

  return $cust_bill_pkg;
}

=item itemdesc_locale LOCALE

Returns a customer-viewable description of this fee for the given locale,
from the part_fee_msgcat table.  If the locale is empty or no localized fee
description exists, returns part_fee.itemdesc.

=cut

sub itemdesc_locale {
  my ( $self, $locale ) = @_;
  return $self->itemdesc unless $locale;
  my $part_fee_msgcat = qsearchs('part_fee_msgcat', {
    feepart => $self->feepart,
    locale  => $locale,
  }) or return $self->itemdesc;
  $part_fee_msgcat->itemdesc;
}

=item tax_rates DATA_PROVIDER, GEOCODE

Returns the external taxes (L<FS::tax_rate> objects) that apply to this
fee, in the location specified by GEOCODE.

=cut

sub tax_rates {
  my $self = shift;
  my ($vendor, $geocode) = @_;
  return unless $self->taxproductnum;
  my $taxproduct = FS::part_pkg_taxproduct->by_key($self->taxproductnum);
  # cch stuff
  my @taxclassnums = map { $_->taxclassnum }
                     $taxproduct->part_pkg_taxrate($geocode);
  return unless @taxclassnums;

  warn "Found taxclassnum values of ". join(',', @taxclassnums) ."\n"
  if $DEBUG;
  my $extra_sql = "AND taxclassnum IN (". join(',', @taxclassnums) . ")";
  my @taxes = qsearch({ 'table'     => 'tax_rate',
      'hashref'   => { 'geocode'     => $geocode,
        'data_vendor' => $vendor },
      'extra_sql' => $extra_sql,
    });
  warn "Found taxes ". join(',', map {$_->taxnum} @taxes) ."\n"
  if $DEBUG;

  return @taxes;
}

=item categoryname 

Returns the package category name, or the empty string if there is no package
category.

=cut

sub categoryname {
  my $self = shift;
  my $pkg_class = $self->pkg_class;
  $pkg_class ? $pkg_class->categoryname : '';
}

sub part_pkg_taxoverride {} # we don't do overrides here

sub has_taxproduct {
  my $self = shift;
  return ($self->taxproductnum ? 1 : 0);
}

# stubs that will go away under 4.x

sub pkg_class {
  my $self = shift;
  $self->classnum
    ? FS::pkg_class->by_key($self->classnum)
    : undef;
}

sub part_pkg_taxproduct {
  my $self = shift;
  $self->taxproductnum
    ? FS::part_pkg_taxproduct->by_key($self->taxproductnum)
    : undef;
}

sub agent {
  my $self = shift;
  $self->agentnum
    ? FS::agent->by_key($self->agentnum)
    : undef;
}

sub part_fee_msgcat {
  my $self = shift;
  qsearch( 'part_fee_msgcat', { feepart => $self->feepart } );
}

sub part_fee_usage {
  my $self = shift;
  qsearch( 'part_fee_usage', { feepart => $self->feepart } );
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>

=cut

1;

