package FS::quotation;
use base qw( FS::Template_Mixin FS::cust_main_Mixin FS::otaker_Mixin FS::Record
           );

use strict;
use Tie::RefHash;
use FS::CurrentUser;
use FS::UID qw( dbh myconnect );
use FS::Maketext qw( emt );
use FS::Record qw( qsearch qsearchs );
use FS::Conf;
use FS::cust_main;
use FS::cust_pkg;
use FS::quotation_pkg;
use FS::quotation_pkg_tax;
use FS::type_pkgs;
use List::MoreUtils;

our $DEBUG = 0;
use Data::Dumper;

=head1 NAME

FS::quotation - Object methods for quotation records

=head1 SYNOPSIS

  use FS::quotation;

  $record = new FS::quotation \%hash;
  $record = new FS::quotation { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::quotation object represents a quotation.  FS::quotation inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item quotationnum

primary key

=item prospectnum

prospectnum

=item custnum

custnum

=item _date

_date

=item disabled

disabled

=item usernum

usernum


=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new quotation.  To add the quotation to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'quotation'; }
sub notice_name { 'Quotation'; }
sub template_conf { 'quotation_'; }
sub has_sections { 1; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid quotation.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('quotationnum')
    || $self->ut_foreign_keyn('prospectnum', 'prospect_main', 'prospectnum' )
    || $self->ut_foreign_keyn('custnum', 'cust_main', 'custnum' )
    || $self->ut_numbern('_date')
    || $self->ut_enum('disabled', [ '', 'Y' ])
    || $self->ut_numbern('usernum')
  ;
  return $error if $error;

  $self->_date(time) unless $self->_date;

  $self->usernum($FS::CurrentUser::CurrentUser->usernum) unless $self->usernum;

  return 'prospectnum or custnum must be specified'
    if ! $self->prospectnum
    && ! $self->custnum;

  $self->SUPER::check;
}

=item prospect_main

=item cust_main

=item cust_bill_pkg

=cut

sub cust_bill_pkg { #actually quotation_pkg objects
  shift->quotation_pkg(@_);
}

=item total_setup

=cut

sub total_setup {
  my $self = shift;
  sprintf('%.2f', $self->_total('setup') + $self->_total('setup_tax'));
}

=item total_recur [ FREQ ]

=cut

sub total_recur {
  my $self = shift;
#=item total_recur [ FREQ ]
  #my $freq = @_ ? shift : '';
  sprintf('%.2f', $self->_total('recur') + $self->_total('recur_tax'));
}

sub _total {
  my( $self, $method ) = @_;

  my $total = 0;
  $total += $_->$method() for $self->quotation_pkg;
  sprintf('%.2f', $total);

}

sub email {
  my $self = shift;
  my $opt = shift || {};
  if ($opt and !ref($opt)) {
    die ref($self). '->email called with positional parameters';
  }

  my $conf = $self->conf;

  my $from = delete $opt->{from};

  # this is where we set the From: address
  $from ||= $conf->config('quotation_from', $self->cust_or_prospect->agentnum )
        ||  $conf->invoice_from_full( $self->cust_or_prospect->agentnum );
  $self->SUPER::email( {
    'from' => $from,
    %$opt,
  });

}

sub email_subject {
  my $self = shift;

  my $subject =
    $self->conf->config('quotation_subject') #, $self->cust_main->agentnum)
      || 'Quotation';

  #my $cust_main = $self->cust_main;
  #my $name = $cust_main->name;
  #my $name_short = $cust_main->name_short;
  #my $invoice_number = $self->invnum;
  #my $invoice_date = $self->_date_pretty;

  eval qq("$subject");
}

=item cust_or_prosect

=cut

sub cust_or_prospect {
  my $self = shift;
  $self->custnum ? $self->cust_main : $self->prospect_main;
}

=item cust_or_prospect_label_link

HTML links to either the customer or prospect.

Returns a list consisting of two elements.  The first is a text label for the
link, and the second is the URL.

=cut

sub cust_or_prospect_label_link {
  my( $self, $p ) = @_;

  if ( my $custnum = $self->custnum ) {
    my $display_custnum = $self->cust_main->display_custnum;
    my $target = $FS::CurrentUser::CurrentUser->default_customer_view eq 'jumbo'
                   ? '#quotations'
                   : ';show=quotations';
    (
      emt("View this customer (#[_1])",$display_custnum) =>
        "${p}view/cust_main.cgi?custnum=$custnum$target"
    );
  } elsif ( my $prospectnum = $self->prospectnum ) {
    (
      emt("View this prospect (#[_1])",$prospectnum) =>
        "${p}view/prospect_main.html?$prospectnum"
    );
  } else { #die?
    ( '', '' );
  }

}

sub _items_sections {
  my $self = shift;
  my %opt = @_;
  my $escape = $opt{escape}; # the only one we care about

  my %subtotals; # package frequency => subtotal
  foreach my $pkg ($self->quotation_pkg) {
    my $recur_freq = $pkg->part_pkg->freq;
    ($subtotals{0} ||= 0) += $pkg->setup + $pkg->setup_tax;
    ($subtotals{$recur_freq} ||= 0) += $pkg->recur + $pkg->recur_tax;
  }
  my @pkg_freq_order = keys %{ FS::Misc->pkg_freqs };

  my @sections;
  foreach my $freq (keys %subtotals) {

    next if $subtotals{$freq} == 0;

    my $weight = 
      List::MoreUtils::first_index { $_ eq $freq } @pkg_freq_order;
    my $desc;
    if ( $freq eq '0' ) {
      if ( scalar(keys(%subtotals)) == 1 ) {
        # there are no recurring packages
        $desc = $self->mt('Charges');
      } else {
        $desc = $self->mt('Setup Charges');
      }
    } else { # recurring
      $desc = $self->mt('Recurring Charges') . ' - ' .
              ucfirst($self->mt(FS::Misc->pkg_freqs->{$freq}))
    }

    push @sections, {
      'description' => &$escape($desc),
      'sort_weight' => $weight,
      'category'    => $freq,
      'subtotal'    => sprintf('%.2f',$subtotals{$freq}),
    };
  }
  return \@sections, [];
}

=item enable_previous

=cut

sub enable_previous { 0 }

=item convert_cust_main

If this quotation already belongs to a customer, then returns that customer, as
an FS::cust_main object.

Otherwise, creates a new customer (FS::cust_main object and record, and
associated) based on this quotation's prospect, then orders this quotation's
packages as real packages for the customer.

If there is an error, returns an error message, otherwise, returns the
newly-created FS::cust_main object.

=cut

sub convert_cust_main {
  my $self = shift;

  my $cust_main = $self->cust_main;
  return $cust_main if $cust_main; #already converted, don't again

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $cust_main = $self->prospect_main->convert_cust_main;
  unless ( ref($cust_main) ) { # eq 'FS::cust_main' ) {
    $dbh->rollback if $oldAutoCommit;
    return $cust_main;
  }

  $self->prospectnum('');
  $self->custnum( $cust_main->custnum );
  my $error = $self->replace || $self->order;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  $cust_main;

}

=item order [ HASHREF ]

This method is for use with quotations which are already associated with a customer.

Orders this quotation's packages as real packages for the customer.

If there is an error, returns an error message, otherwise returns false.

If HASHREF is passed, it will be filled with a hash mapping the 
C<quotationpkgnum> of each quoted package to the C<pkgnum> of the package
as ordered.

=cut

sub order {
  my $self = shift;
  my $pkgnum_map = shift || {};

  tie my %all_cust_pkg, 'Tie::RefHash';
  foreach my $quotation_pkg ($self->quotation_pkg) {
    my $cust_pkg = FS::cust_pkg->new;
    $pkgnum_map->{ $quotation_pkg->quotationpkgnum } = $cust_pkg;

    foreach (qw(pkgpart locationnum start_date contract_end quantity waive_setup)) {
      $cust_pkg->set( $_, $quotation_pkg->get($_) );
    }

    # currently only one discount each
    my ($pkg_discount) = $quotation_pkg->quotation_pkg_discount;
    if ( $pkg_discount ) {
      $cust_pkg->set('discountnum', $pkg_discount->discountnum);
    }

    $all_cust_pkg{$cust_pkg} = []; # no services
  }

  my $error = $self->cust_main->order_pkgs( \%all_cust_pkg );
  
  foreach my $quotationpkgnum (keys %$pkgnum_map) {
    # convert the objects to just pkgnums
    my $cust_pkg = $pkgnum_map->{$quotationpkgnum};
    $pkgnum_map->{$quotationpkgnum} = $cust_pkg->pkgnum;
  }

  $error;
}

=item charge

One-time charges, like FS::cust_main::charge()

=cut

#super false laziness w/cust_main::charge
sub charge {
  my $self = shift;
  my ( $amount, $setup_cost, $quantity, $start_date, $classnum );
  my ( $pkg, $comment, $additional );
  my ( $setuptax, $taxclass );   #internal taxes
  my ( $taxproduct, $override ); #vendor (CCH) taxes
  my $no_auto = '';
  my $cust_pkg_ref = '';
  my ( $bill_now, $invoice_terms ) = ( 0, '' );
  my $locationnum;
  if ( ref( $_[0] ) ) {
    $amount     = $_[0]->{amount};
    $setup_cost = $_[0]->{setup_cost};
    $quantity   = exists($_[0]->{quantity}) ? $_[0]->{quantity} : 1;
    $start_date = exists($_[0]->{start_date}) ? $_[0]->{start_date} : '';
    $no_auto    = exists($_[0]->{no_auto}) ? $_[0]->{no_auto} : '';
    $pkg        = exists($_[0]->{pkg}) ? $_[0]->{pkg} : 'One-time charge';
    $comment    = exists($_[0]->{comment}) ? $_[0]->{comment}
                                           : '$'. sprintf("%.2f",$amount);
    $setuptax   = exists($_[0]->{setuptax}) ? $_[0]->{setuptax} : '';
    $taxclass   = exists($_[0]->{taxclass}) ? $_[0]->{taxclass} : '';
    $classnum   = exists($_[0]->{classnum}) ? $_[0]->{classnum} : '';
    $additional = $_[0]->{additional} || [];
    $taxproduct = $_[0]->{taxproductnum};
    $override   = { '' => $_[0]->{tax_override} };
    $cust_pkg_ref = exists($_[0]->{cust_pkg_ref}) ? $_[0]->{cust_pkg_ref} : '';
    $bill_now = exists($_[0]->{bill_now}) ? $_[0]->{bill_now} : '';
    $invoice_terms = exists($_[0]->{invoice_terms}) ? $_[0]->{invoice_terms} : '';
    $locationnum = $_[0]->{locationnum};
  } else {
    $amount     = shift;
    $setup_cost = '';
    $quantity   = 1;
    $start_date = '';
    $pkg        = @_ ? shift : 'One-time charge';
    $comment    = @_ ? shift : '$'. sprintf("%.2f",$amount);
    $setuptax   = '';
    $taxclass   = @_ ? shift : '';
    $additional = [];
  }

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $part_pkg = new FS::part_pkg ( {
    'pkg'           => $pkg,
    'comment'       => $comment,
    'plan'          => 'flat',
    'freq'          => 0,
    'disabled'      => 'Y',
    'classnum'      => ( $classnum ? $classnum : '' ),
    'setuptax'      => $setuptax,
    'taxclass'      => $taxclass,
    'taxproductnum' => $taxproduct,
    'setup_cost'    => $setup_cost,
  } );

  my %options = ( ( map { ("additional_info$_" => $additional->[$_] ) }
                        ( 0 .. @$additional - 1 )
                  ),
                  'additional_count' => scalar(@$additional),
                  'setup_fee' => $amount,
                );

  my $error = $part_pkg->insert( options       => \%options,
                                 tax_overrides => $override,
                               );
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  my $pkgpart = $part_pkg->pkgpart;

  #DIFF
  my %type_pkgs = ( 'typenum' => $self->cust_or_prospect->agent->typenum, 'pkgpart' => $pkgpart );

  unless ( qsearchs('type_pkgs', \%type_pkgs ) ) {
    my $type_pkgs = new FS::type_pkgs \%type_pkgs;
    $error = $type_pkgs->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  #except for DIFF, eveything above is idential to cust_main version
  #but below is our own thing pretty much (adding a quotation package instead
  # of ordering a customer package, no "bill now")

  my $quotation_pkg = new FS::quotation_pkg ( {
    'quotationnum'  => $self->quotationnum,
    'pkgpart'       => $pkgpart,
    'quantity'      => $quantity,
    #'start_date' => $start_date,
    #'no_auto'    => $no_auto,
    'locationnum'=> $locationnum,
  } );

  $error = $quotation_pkg->insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  #} elsif ( $cust_pkg_ref ) {
  #  ${$cust_pkg_ref} = $cust_pkg;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  return '';

}

=item disable

Disables this quotation (sets disabled to Y, which hides the quotation on
prospects and customers).

If there is an error, returns an error message, otherwise returns false.

=cut

sub disable {
  my $self = shift;
  $self->disabled('Y');
  $self->replace();
}

=item enable

Enables this quotation.

If there is an error, returns an error message, otherwise returns false.

=cut

sub enable {
  my $self = shift;
  $self->disabled('');
  $self->replace();
}

=item estimate

Calculates current prices for all items on this quotation, including 
discounts and taxes, and updates the quotation_pkg records accordingly.

=cut

sub estimate {
  my $self = shift;
  my $conf = FS::Conf->new;

  my %pkgnum_of; # quotationpkgnum => temporary pkgnum

  my $me = "[quotation #".$self->quotationnum."]"; # for debug messages

  my @return_bill = ([]);
  my $error;

  ###### BEGIN TRANSACTION ######
  local $@;
  eval {
    my $temp_dbh = myconnect();
    local $FS::UID::dbh = $temp_dbh;
    local $FS::UID::AutoCommit = 0;

    my $fake_self = FS::quotation->new({ $self->hash });

    # if this is a prospect, make them into a customer for now
    # XXX prospects currently can't have service locations
    my $cust_or_prospect = $self->cust_or_prospect;
    my $cust_main;
    if ( $cust_or_prospect->isa('FS::prospect_main') ) {
      $cust_main = $cust_or_prospect->convert_cust_main;
      die "$cust_main (simulating customer signup)\n" unless ref $cust_main;
      $fake_self->set('prospectnum', '');
      $fake_self->set('custnum', $cust_main->custnum);
    } else {
      $cust_main = $cust_or_prospect;
    }

    # order packages
    $error = $fake_self->order(\%pkgnum_of);
    die "$error (simulating package order)\n" if $error;

    my @new_pkgs = map { FS::cust_pkg->by_key($_) } values(%pkgnum_of);

    # simulate the first bill
    my %bill_opt = (
      'estimate'        => 1,
      'pkg_list'        => \@new_pkgs,
      'time'            => time, # an option to adjust this?
      'return_bill'     => $return_bill[0],
      'no_usage_reset'  => 1,
    );
    $error = $cust_main->bill(%bill_opt);
    die "$error (simulating initial billing)\n" if $error;

    # pick dates for future bills
    my %next_bill_pkgs;
    foreach (@new_pkgs) {
      my $bill = $_->get('bill');
      next if !$bill;
      push @{ $next_bill_pkgs{$bill} ||= [] }, $_;
    }

    my $i = 1;
    foreach my $next_bill (keys %next_bill_pkgs) {
      $bill_opt{'time'} = $next_bill;
      $bill_opt{'return_bill'} = $return_bill[$i] = [];
      $bill_opt{'pkg_list'} = $next_bill_pkgs{$next_bill};
      $error = $cust_main->bill(%bill_opt);
      die "$error (simulating recurring billing cycle $i)\n" if $error;
      $i++;
    }

    $temp_dbh->rollback;
  };
  return $@ if $@;
  ###### END TRANSACTION ######
  my %quotationpkgnum_of = reverse %pkgnum_of;

  if ($DEBUG) {
    warn "pkgnums:\n".Dumper(\%pkgnum_of);
    warn Dumper(\@return_bill);
  }

  # Careful: none of the foreign keys in here are correct outside the sandbox.
  # We have a translation table for pkgnums; all others are total lies.

  my %quotation_pkg; # quotationpkgnum => quotation_pkg
  foreach my $qp ($self->quotation_pkg) {
    $quotation_pkg{$qp->quotationpkgnum} = $qp;
    $qp->set($_, 0) foreach qw(unitsetup unitrecur);
    $qp->set('freq', '');
    # flush old tax records
    foreach ($qp->quotation_pkg_tax) {
      $error = $_->delete;
      return "$error (flushing tax records for pkgpart ".$qp->part_pkg->pkgpart.")" 
        if $error;
    }
  }

  my %quotation_pkg_tax; # quotationpkgnum => tax name => quotation_pkg_tax obj
  my %quotation_pkg_discount; # quotationpkgnum => quotation_pkg_discount obj

  for (my $i = 0; $i < scalar(@return_bill); $i++) {
    my $this_bill = $return_bill[$i]->[0];
    if (!$this_bill) {
      warn "$me billing cycle $i produced no invoice\n";
      next;
    }

    my @nonpkg_lines;
    my %cust_bill_pkg;
    foreach my $cust_bill_pkg (@{ $this_bill->get('cust_bill_pkg') }) {
      my $pkgnum = $cust_bill_pkg->pkgnum;
      $cust_bill_pkg{ $cust_bill_pkg->billpkgnum } = $cust_bill_pkg;
      if ( !$pkgnum ) {
        # taxes/fees; come back to it
        push @nonpkg_lines, $cust_bill_pkg;
        next;
      }
      my $quotationpkgnum = $quotationpkgnum_of{$pkgnum};
      my $qp = $quotation_pkg{$quotationpkgnum};
      if (!$qp) {
        # XXX supplemental packages could do this (they have separate pkgnums)
        # handle that special case at some point
        warn "$me simulated bill returned a package not on the quotation (pkgpart ".$cust_bill_pkg->pkgpart.")\n";
        next;
      }
      if ( $i == 0 ) {
        # then this is the first (setup) invoice
        $qp->set('start_date', $cust_bill_pkg->sdate);
        $qp->set('unitsetup', $qp->unitsetup + $cust_bill_pkg->unitsetup);
        # pkgpart_override is a possibility
      } else {
        # recurring invoice (should be only one of these per package, though
        # it may have multiple lineitems with the same pkgnum)
        $qp->set('unitrecur', $qp->unitrecur + $cust_bill_pkg->unitrecur);
      }

      # discounts
      if ( $cust_bill_pkg->get('discounts') ) {
        my $discount = $cust_bill_pkg->get('discounts')->[0];
        # discount records are generated as (setup, recur).
        # well, not always, sometimes it's just (recur), but fixing this
        # is horribly invasive.
        my $qpd = $quotation_pkg_discount{$quotationpkgnum}
              ||= qsearchs('quotation_pkg_discount', {
                  'quotationpkgnum' => $quotationpkgnum
                  });

        if (!$qpd) { #can't happen
          warn "$me simulated bill returned a discount but no discount is in effect.\n";
        }
        if ($discount and $qpd) {
          if ( $i == 0 ) {
            $qpd->set('setup_amount', $discount->amount);
          } else {
            $qpd->set('recur_amount', $discount->amount);
          }
        }
      } # end of discount stuff

    }

    # create tax records
    foreach my $cust_bill_pkg (@nonpkg_lines) {

      my $itemdesc = $cust_bill_pkg->itemdesc;

      if ($cust_bill_pkg->feepart) {
        warn "$me simulated bill included a non-package fee (feepart ".
          $cust_bill_pkg->feepart.")\n";
        next;
      }
      my $links = $cust_bill_pkg->get('cust_bill_pkg_tax_location') ||
                  $cust_bill_pkg->get('cust_bill_pkg_tax_rate_location') ||
                  [];
      # breadth-first unrolled recursion:
      # take each tax link and any tax-on-tax descendants, and merge them 
      # into a single quotation_pkg_tax record for each pkgnum/taxname 
      # combination
      while (my $tax_link = shift @$links) {
        my $target = $cust_bill_pkg{ $tax_link->taxable_billpkgnum }
          or die "$me unable to resolve tax link\n";
        if ($target->pkgnum) {
          my $quotationpkgnum = $quotationpkgnum_of{$target->pkgnum};
          # create this if there isn't one yet
          my $qpt = $quotation_pkg_tax{$quotationpkgnum}{$itemdesc} ||=
            FS::quotation_pkg_tax->new({
              quotationpkgnum => $quotationpkgnum,
              itemdesc        => $itemdesc,
              setup_amount    => 0,
              recur_amount    => 0,
            });
          if ( $i == 0 ) { # first invoice
            $qpt->set('setup_amount', $qpt->setup_amount + $tax_link->amount);
          } else { # subsequent invoices
            # this isn't perfectly accurate, but that's why it's an estimate
            $qpt->set('recur_amount', $qpt->recur_amount + $tax_link->amount);
            $qpt->set('setup_amount', sprintf('%.2f', $qpt->setup_amount - $tax_link->amount));
            $qpt->set('setup_amount', 0) if $qpt->setup_amount < 0;
          }
        } elsif ($target->feepart) {
          # do nothing; we already warned for the fee itself
        } else {
          # tax on tax: the tax target is another tax item.
          # since this is an estimate, I'm just going to assign it to the 
          # first of the underlying packages. (RT#5243 is why we can't have
          # nice things.)
          my $sublinks = $target->cust_bill_pkg_tax_rate_location;
          if ($sublinks and $sublinks->[0]) {
            $tax_link->set('taxable_billpkgnum', $sublinks->[0]->taxable_billpkgnum);
            push @$links, $tax_link; #try again
          } else {
            warn "$me unable to assign tax on tax; ignoring\n";
          }
        }
      } # while my $tax_link

    } # foreach my $cust_bill_pkg
  }
  foreach my $quotation_pkg (values %quotation_pkg) {
    $error = $quotation_pkg->replace;
    return "$error (recording estimate for ".$quotation_pkg->part_pkg->pkg.")"
      if $error;
  }
  foreach my $quotation_pkg_discount (values %quotation_pkg_discount) {
    $error = $quotation_pkg_discount->replace;
    return "$error (recording estimated discount)"
      if $error;
  }
  foreach my $quotation_pkg_tax (map { values %$_ } values %quotation_pkg_tax) {
    $error = $quotation_pkg_tax->insert;
    return "$error (recording estimated tax for ".$quotation_pkg_tax->itemdesc.")"
    if $error;
  }
  return;
}

=back

=head1 CLASS METHODS

=over 4


=item search_sql_where HASHREF

Class method which returns an SQL WHERE fragment to search for parameters
specified in HASHREF.  Valid parameters are

=over 4

=item _date

List reference of start date, end date, as UNIX timestamps.

=item invnum_min

=item invnum_max

=item agentnum

=item charged

List reference of charged limits (exclusive).

=item owed

List reference of charged limits (exclusive).

=item open

flag, return open invoices only

=item net

flag, return net invoices only

=item days

=item newest_percust

=back

Note: validates all passed-in data; i.e. safe to use with unchecked CGI params.

=cut

sub search_sql_where {
  my($class, $param) = @_;
  #if ( $DEBUG ) {
  #  warn "$me search_sql_where called with params: \n".
  #       join("\n", map { "  $_: ". $param->{$_} } keys %$param ). "\n";
  #}

  my @search = ();

  #agentnum
  if ( $param->{'agentnum'} =~ /^(\d+)$/ ) {
    push @search, "( prospect_main.agentnum = $1 OR cust_main.agentnum = $1 )";
  }

#  #refnum
#  if ( $param->{'refnum'} =~ /^(\d+)$/ ) {
#    push @search, "cust_main.refnum = $1";
#  }

  #prospectnum
  if ( $param->{'prospectnum'} =~ /^(\d+)$/ ) {
    push @search, "quotation.prospectnum = $1";
  }

  #custnum
  if ( $param->{'custnum'} =~ /^(\d+)$/ ) {
    push @search, "cust_bill.custnum = $1";
  }

  #_date
  if ( $param->{_date} ) {
    my($beginning, $ending) = @{$param->{_date}};

    push @search, "quotation._date >= $beginning",
                  "quotation._date <  $ending";
  }

  #quotationnum
  if ( $param->{'quotationnum_min'} =~ /^(\d+)$/ ) {
    push @search, "quotation.quotationnum >= $1";
  }
  if ( $param->{'quotationnum_max'} =~ /^(\d+)$/ ) {
    push @search, "quotation.quotationnum <= $1";
  }

#  #charged
#  if ( $param->{charged} ) {
#    my @charged = ref($param->{charged})
#                    ? @{ $param->{charged} }
#                    : ($param->{charged});
#
#    push @search, map { s/^charged/cust_bill.charged/; $_; }
#                      @charged;
#  }

  my $owed_sql = FS::cust_bill->owed_sql;

  #days
  push @search, "quotation._date < ". (time-86400*$param->{'days'})
    if $param->{'days'};

  #agent virtualization
  my $curuser = $FS::CurrentUser::CurrentUser;
  #false laziness w/search/quotation.html
  push @search,' (    '. $curuser->agentnums_sql( table=>'prospect_main' ).
               '   OR '. $curuser->agentnums_sql( table=>'cust_main' ).
               ' )    ';

  join(' AND ', @search );

}

=item _items_pkg

Return line item hashes for each package on this quotation.

=cut

sub _items_pkg {
  my ($self, %options) = @_;
  my $escape = $options{'escape_function'};
  my $locale = $self->cust_or_prospect->locale;

  my $preref = $options{'preref_callback'};

  my $section = $options{'section'};
  my $freq = $section->{'category'};
  my @pkgs = $self->quotation_pkg;
  my @items;
  die "_items_pkg called without section->{'category'}"
    unless defined $freq;

  my %tax_item; # taxname => hashref, will be aggregated AT DISPLAY TIME
                # like we should have done in the first place

  foreach my $quotation_pkg (@pkgs) {
    my $part_pkg = $quotation_pkg->part_pkg;
    my $setuprecur;
    my $this_item = {
      'pkgnum'          => $quotation_pkg->quotationpkgnum,
      'description'     => $quotation_pkg->desc($locale),
      'ext_description' => [],
      'quantity'        => $quotation_pkg->quantity,
    };
    if ($freq eq '0') {
      # setup/one-time
      $setuprecur = 'setup';
      if ($part_pkg->freq ne '0') {
        # indicate that it's a setup fee on a recur package (cust_bill does 
        # this too)
        $this_item->{'description'} .= ' Setup';
      }
    } else {
      # recur for this frequency
      next if $freq ne $part_pkg->freq;
      $setuprecur = 'recur';
    }

    $this_item->{'unit_amount'} = sprintf('%.2f', 
      $quotation_pkg->get('unit'.$setuprecur));
    $this_item->{'amount'} = sprintf('%.2f', $this_item->{'unit_amount'}
                                             * $quotation_pkg->quantity);
    next if $this_item->{'amount'} == 0;

    if ( $preref ) {
      $this_item->{'preref_html'} = &$preref($quotation_pkg);
    }

    push @items, $this_item;
    my $discount = $quotation_pkg->_item_discount(setuprecur => $setuprecur);
    if ($discount) {
      $_ = &{$escape}($_) foreach @{ $discount->{ext_description} };
      push @items, $discount;
    }

    # each quotation_pkg_tax has two amounts: the amount charged on the 
    # setup invoice, and the amount on the recurring invoice.
    foreach my $qpt ($quotation_pkg->quotation_pkg_tax) {
      my $this_tax = $tax_item{$qpt->itemdesc} ||= {
        'pkgnum'          => 0,
        'description'     => $qpt->itemdesc,
        'ext_description' => [],
        'amount'          => 0,
      };
      $this_tax->{'amount'} += $qpt->get($setuprecur.'_amount');
    }
  } # foreach $quotation_pkg

  foreach my $taxname ( sort { $a cmp $b } keys (%tax_item) ) {
    my $this_tax = $tax_item{$taxname};
    $this_tax->{'amount'} = sprintf('%.2f', $this_tax->{'amount'});
    next if $this_tax->{'amount'} == 0;
    push @items, $this_tax;
  }

  return @items;
}

sub _items_tax {
  ();
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

