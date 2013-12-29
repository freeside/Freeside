package FS::cust_bill_pkg_tax_location;
use base qw( FS::Record );

use strict;
use List::Util qw(sum min);
use FS::Record qw( dbh qsearch qsearchs );
use FS::cust_bill_pkg;
use FS::cust_pkg;
use FS::cust_bill_pay_pkg;
use FS::cust_credit_bill_pkg;
use FS::cust_main_county;
use FS::Log;

=head1 NAME

FS::cust_bill_pkg_tax_location - Object methods for cust_bill_pkg_tax_location records

=head1 SYNOPSIS

  use FS::cust_bill_pkg_tax_location;

  $record = new FS::cust_bill_pkg_tax_location \%hash;
  $record = new FS::cust_bill_pkg_tax_location { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_bill_pkg_tax_location object represents an record of taxation
based on package location.  FS::cust_bill_pkg_tax_location inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item billpkgtaxlocationnum

billpkgtaxlocationnum

=item billpkgnum

billpkgnum

=item taxnum

taxnum

=item taxtype

taxtype

=item pkgnum

pkgnum

=item locationnum

locationnum

=item amount

amount

=item taxable_billpkgnum

The billpkgnum of the L<FS::cust_bill_pkg> that this tax was charged on.
It may specifically be on any portion of that line item (setup, recurring,
or a usage class).

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_bill_pkg_tax_location'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid record.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('billpkgtaxlocationnum')
    || $self->ut_foreign_key('billpkgnum', 'cust_bill_pkg', 'billpkgnum' )
    || $self->ut_number('taxnum') #cust_bill_pkg/tax_rate key, based on taxtype
    || $self->ut_enum('taxtype', [ qw( FS::cust_main_county FS::tax_rate ) ] )
    || $self->ut_foreign_key('pkgnum', 'cust_pkg', 'pkgnum' )
    || $self->ut_foreign_key('locationnum', 'cust_location', 'locationnum' )
    || $self->ut_money('amount')
    || $self->ut_foreign_key('taxable_billpkgnum', 'cust_bill_pkg', 'billpkgnum')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item cust_bill_pkg

Returns the associated cust_bill_pkg object (i.e. the tax charge).

=item taxable_cust_bill_pkg

Returns the cust_bill_pkg object for the I<taxable> charge.

=item cust_location

Returns the associated cust_location object

=item desc

Returns a description for this tax line item constituent.  Currently this
is the desc of the associated line item followed by the state/county/city
for the location in parentheses.

=cut

sub desc {
  my $self = shift;
  my $cust_location = $self->cust_location;
  my $location = join('/', grep { $_ }                 # leave in?
                           map { $cust_location->$_ }
                           qw( state county city )     # country?
  );
  my $cust_bill_pkg_desc = $self->billpkgnum
                         ? $self->cust_bill_pkg->desc
                         : $self->cust_bill_pkg_desc;
  "$cust_bill_pkg_desc ($location)";
}

=item owed

Returns the amount owed (still outstanding) on this tax line item which is
the amount of this record minus all payment applications and credit
applications.

=cut

sub owed {
  my $self = shift;
  my $balance = $self->amount;
  $balance -= $_->amount foreach ( $self->cust_bill_pay_pkg('setup') );
  $balance -= $_->amount foreach ( $self->cust_credit_bill_pkg('setup') );
  $balance = sprintf( '%.2f', $balance );
  $balance =~ s/^\-0\.00$/0.00/; #yay ieee fp
  $balance;
}

sub cust_bill_pay_pkg {
  my $self = shift;
  qsearch( 'cust_bill_pay_pkg',
           { map { $_ => $self->$_ } qw( billpkgtaxlocationnum billpkgnum ) }
         );
}

sub cust_credit_bill_pkg {
  my $self = shift;
  qsearch( 'cust_credit_bill_pkg',
           { map { $_ => $self->$_ } qw( billpkgtaxlocationnum billpkgnum ) }
         );
}

sub cust_main_county {
  my $self = shift;
  return '' unless $self->taxtype eq 'FS::cust_main_county';
  qsearchs( 'cust_main_county', { 'taxnum' => $self->taxnum } );
}

sub _upgrade_data {
  eval {
    use FS::queue;
    use Date::Parse 'str2time';
  };
  my $class = shift;
  my $upgrade = 'tax_location_taxable_billpkgnum';
  return if FS::upgrade_journal->is_done($upgrade);
  my $job = FS::queue->new({ job => 
      'FS::cust_bill_pkg_tax_location::upgrade_taxable_billpkgnum'
  });
  $job->insert($class, 's' => str2time('2012-01-01'));
  FS::upgrade_journal->set_done($upgrade);
}

sub upgrade_taxable_billpkgnum {
  # Associate these records to the correct taxable line items.
  # The cust_bill_pkg upgrade now does this also for pre-3.0 records that 
  # aren't broken out by pkgnum, so we only need to deal with the case of 
  # multiple line items for the same pkgnum.
  # Despite appearances, this has almost no relation to the upgrade in
  # FS::cust_bill_pkg.

  my ($class, %opt) = @_;
  my $dbh = dbh;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $log = FS::Log->new('upgrade_taxable_billpkgnum');

  my $date_where = '';
  if ( $opt{s} ) {
    $date_where .= " AND cust_bill._date >= $opt{s}";
  }
  if ( $opt{e} ) {
    $date_where .= " AND cust_bill._date < $opt{e}";
  }

  my @need_to_upgrade = qsearch({
      select => 'cust_bill_pkg_tax_location.*',
      table => 'cust_bill_pkg_tax_location',
      hashref => { taxable_billpkgnum => '' },
      addl_from => 'JOIN cust_bill_pkg USING (billpkgnum)'.
                   'JOIN cust_bill     USING (invnum)',
      extra_sql => $date_where,
  });
  $log->info('Starting upgrade of '.scalar(@need_to_upgrade).
      ' cust_bill_pkg_tax_location records.');

  # keys are billpkgnums
  my %cust_bill_pkg;
  my %tax_location;
  foreach (@need_to_upgrade) {
    my $tax_billpkgnum = $_->billpkgnum;
    $cust_bill_pkg{ $tax_billpkgnum } ||= FS::cust_bill_pkg->by_key($tax_billpkgnum);
    $tax_location{ $tax_billpkgnum } ||= [];
    push @{ $tax_location{ $tax_billpkgnum } }, $_;
  }

  TAX_ITEM: foreach my $tax_item (values %cust_bill_pkg) {
    my $tax_locations = $tax_location{ $tax_item->billpkgnum };
    my $invnum = $tax_item->invnum;
    my $cust_bill = FS::cust_bill->by_key($tax_item->invnum);
    my %tax_on_pkg; # keys are tax identifiers
    TAX_LOCATION: foreach my $tax_location (@$tax_locations) {
    # recapitulate the "cust_main_county $taxnum $pkgnum" tax identifier,
    # in a way
      my $taxid = join(' ',
        $tax_location->taxtype,
        $tax_location->taxnum,
        $tax_location->pkgnum,
        $tax_location->locationnum
      );
      $tax_on_pkg{$taxid} ||= [];
      push @{ $tax_on_pkg{$taxid} }, $tax_location;
    }
    PKGNUM: foreach my $taxid (keys %tax_on_pkg) {
      my ($taxtype, $taxnum, $pkgnum, $locationnum) = split(' ', $taxid);
      $log->info("tax#$taxnum, pkg#$pkgnum", object => $cust_bill);
      my @pkg_items = $cust_bill->cust_bill_pkg_pkgnum($pkgnum);
      if (!@pkg_items) {
        # then how is there tax on it? should never happen
        $log->error("no line items with pkg#$pkgnum", object => $cust_bill);
        next PKGNUM;
      }
      my $pkg_amount = 0;
      foreach my $pkg_item (@pkg_items) {
        # find the taxable amount of each one
        my $amount = $pkg_item->setup + $pkg_item->recur;
        # subtract any exemptions that apply to this taxdef
        foreach (qsearch('cust_tax_exempt_pkg', {
                  taxnum      => $taxnum,
                  billpkgnum  => $pkg_item->billpkgnum
                 }) )
        {
          $amount -= $_->amount;
        }
        $pkg_item->set('amount' => $pkg_item->setup + $pkg_item->recur);
        $pkg_amount += $amount;
      } #$pkg_item
      next PKGNUM if $pkg_amount == 0; # probably because it's fully exempted
      # now sort them descending by taxable amount
      @pkg_items = sort { $b->amount <=> $a->amount }
                   @pkg_items;
      # and do the same with the tax links
      # (there should be one per taxed item)
      my @tax_links = sort { $b->amount <=> $a->amount }
                      @{ $tax_on_pkg{$taxid} };

      if (scalar(@tax_links) == scalar(@pkg_items)) {
        # the relatively simple case: they match 1:1
        for my $i (0 .. scalar(@tax_links) - 1) {
          $tax_links[$i]->set('taxable_billpkgnum', 
                              $pkg_items[$i]->billpkgnum);
          my $error = $tax_links[$i]->replace;
          if ( $error ) {
            $log->error("failed to set taxable_billpkgnum in tax on pkg#$pkgnum",
              object => $cust_bill);
            next PKGNUM;
          }
        } #for $i
      } else {
        # the more complicated case
        $log->warn("mismatched charges and tax links in pkg#$pkgnum",
          object => $cust_bill);
        my $tax_amount = sum(map {$_->amount} @tax_links);
        # remove all tax link records and recreate them to be 1:1 with 
        # taxable items
        my (%billpaynum, %creditbillnum);
        my $link_type;
        foreach my $tax_link (@tax_links) {
          $link_type ||= ref($tax_link);
          my $error = $tax_link->delete;
          if ( $error ) {
            $log->error("error unlinking tax#$taxnum pkg#$pkgnum",
              object => $cust_bill);
            next PKGNUM;
          }
          my $pkey = $tax_link->primary_key;
          # also remove all applications that reference this tax link
          # (they will be applications to the tax item)
          my %hash = ($pkey => $tax_link->get($pkey));
          foreach (qsearch('cust_bill_pay_pkg', \%hash)) {
            $billpaynum{$_->billpaynum} += $_->amount;
            my $error = $_->delete;
            die "error unapplying payment: $error" if ( $error );
          }
          foreach (qsearch('cust_credit_bill_pkg', \%hash)) {
            $creditbillnum{$_->creditbillnum} += $_->amount;
            my $error = $_->delete;
            die "error unapplying credit: $error" if ( $error );
          }
        }
        @tax_links = ();
        my $cents_remaining = int(100 * $tax_amount);
        foreach my $pkg_item (@pkg_items) {
          my $cents = int(100 * $pkg_item->amount * $tax_amount / $pkg_amount);
          my $tax_link = $link_type->new({
              taxable_billpkgnum => $pkg_item->billpkgnum,
              billpkgnum  => $tax_item->billpkgnum,
              taxnum      => $taxnum,
              taxtype     => $taxtype,
              pkgnum      => $pkgnum,
              locationnum => $locationnum,
              cents       => $cents,
          });
          push @tax_links, $tax_link;
          $cents_remaining -= $cents;
        }
        my $nlinks = scalar @tax_links;
        my $i = 0;
        while ($cents_remaining) {
          $tax_links[$i % $nlinks]->set('cents' =>
            $tax_links[$i % $nlinks]->cents + 1
          );
          $cents_remaining--;
          $i++;
        }
        foreach my $tax_link (@tax_links) {
          $tax_link->set('amount' => sprintf('%.2f', $tax_link->cents / 100));
          my $error = $tax_link->insert;
          if ( $error ) {
            $log->error("error relinking tax#$taxnum pkg#$pkgnum",
              object => $cust_bill);
            next PKGNUM;
          }
        }

        $i = 0;
        my $error;
        my $left = 0; # the amount "left" on the last tax link after 
                      # applying payments, but before credits, so that 
                      # it can receive both a payment and a credit if 
                      # necessary
        # reapply payments/credits...this sucks
        foreach my $billpaynum (keys %billpaynum) {
          my $pay_amount = $billpaynum{$billpaynum};
          while ($i < $nlinks and $pay_amount > 0) {
            my $this_amount = min($pay_amount, $tax_links[$i]->amount);
            $left = $tax_links[$i]->amount - $this_amount;
            my $app = FS::cust_bill_pay_pkg->new({
                billpaynum            => $billpaynum,
                billpkgnum            => $tax_links[$i]->billpkgnum,
                billpkgtaxlocationnum => $tax_links[$i]->billpkgtaxlocationnum,
                amount                => $this_amount,
                setuprecur            => 'setup',
                # sdate/edate are null
            });
            my $error ||= $app->insert;
            $pay_amount -= $this_amount;
            $i++ if $left == 0;
          }
        }
        foreach my $creditbillnum (keys %creditbillnum) {
          my $credit_amount = $creditbillnum{$creditbillnum};
          while ($i < $nlinks and $credit_amount > 0) {
            my $this_amount = min($left, $credit_amount, $tax_links[$i]->amount);
            $left = $credit_amount * 2; # just so it can't be selected twice
            $i++ if    $this_amount == $left 
                    or $this_amount == $tax_links[$i]->amount;
            my $app = FS::cust_credit_bill_pkg->new({
                creditbillnum         => $creditbillnum,
                billpkgnum            => $tax_links[$i]->billpkgnum,
                billpkgtaxlocationnum => $tax_links[$i]->billpkgtaxlocationnum,
                amount                => $this_amount,
                setuprecur            => 'setup',
                # sdate/edate are null
            });
            my $error ||= $app->insert;
            $credit_amount -= $this_amount;
          }
        }
        if ( $error ) {
          # we've just unapplied a bunch of stuff, so if it won't reapply
          # we really need to revert the whole transaction
          die "error reapplying payments/credits: $error; upgrade halted";
        }
      } # scalar(@tax_links) ?= scalar(@pkg_items)
    } #taxnum/pkgnum
  } #TAX_ITEM

  $log->info('finish');

  $dbh->commit if $oldAutoCommit;
  return;
}

=cut

=back

=head1 BUGS

The presence of FS::cust_main_county::delete makes the cust_main_county method
unreliable.

Pre-3.0 versions of Freeside would only create one cust_bill_pkg_tax_location
per tax definition (taxtype/taxnum) per invoice.  The pkgnum and locationnum 
fields were arbitrarily set to those of the first line item subject to the 
tax.  This created problems if the tax contribution of each line item ever 
needed to be determined (for example, when applying credits).  For several
months in 2012, this was changed to create one record per tax definition 
per I<package> per invoice, which was still not specific enough to identify
a line item.

The current behavior is to create one record per tax definition per taxable
line item, and to store the billpkgnum of the taxed line item in the record.
The upgrade will try to convert existing records to the new format, but this 
is not perfectly reliable.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

