package FS::quotation;
use base qw( FS::Template_Mixin FS::cust_main_Mixin FS::otaker_Mixin FS::Record
           );

use strict;
use Tie::RefHash;
use FS::CurrentUser;
use FS::UID qw( dbh );
use FS::Maketext qw( emt );
use FS::Record qw( qsearch qsearchs );
use FS::Conf;
use FS::cust_main;
use FS::cust_pkg;
use FS::quotation_pkg;
use FS::quotation_pkg_tax;
use FS::type_pkgs;

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
  $self->_total('setup');
}

=item total_recur [ FREQ ]

=cut

sub total_recur {
  my $self = shift;
#=item total_recur [ FREQ ]
  #my $freq = @_ ? shift : '';
  $self->_total('recur');
}

sub _total {
  my( $self, $method ) = @_;

  my $total = 0;
  $total += $_->$method() for $self->cust_bill_pkg;
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

=item cust_or_prospect_label_link P

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

sub _items_tax {
  ();
}

sub _items_nontax {
  shift->cust_bill_pkg;
}

sub _items_total {
  my $self = shift;
  $self->quotationnum =~ /^(\d+)$/ or return ();

  my @items;

  # show taxes in here also; the setup/recurring breakdown is different
  # from what Template_Mixin expects
  my @setup_tax = qsearch({
      select      => 'itemdesc, SUM(setup_amount) as setup_amount',
      table       => 'quotation_pkg_tax',
      addl_from   => ' JOIN quotation_pkg USING (quotationpkgnum) ',
      extra_sql   => ' WHERE quotationnum = '.$1,
      order_by    => ' GROUP BY itemdesc HAVING SUM(setup_amount) > 0' .
                     ' ORDER BY itemdesc',
  });
  # recurs need to be grouped by frequency, and to have a pkgpart
  my @recur_tax = qsearch({
      select      => 'freq, itemdesc, SUM(recur_amount) as recur_amount, MAX(pkgpart) as pkgpart',
      table       => 'quotation_pkg_tax',
      addl_from   => ' JOIN quotation_pkg USING (quotationpkgnum)'.
                     ' JOIN part_pkg USING (pkgpart)',
      extra_sql   => ' WHERE quotationnum = '.$1,
      order_by    => ' GROUP BY freq, itemdesc HAVING SUM(recur_amount) > 0' .
                     ' ORDER BY freq, itemdesc',
  });

  my $total_setup = $self->total_setup;
  foreach my $pkg_tax (@setup_tax) {
    if ($pkg_tax->setup_amount > 0) {
      $total_setup += $pkg_tax->setup_amount;
      push @items, {
        'total_item'    => $pkg_tax->itemdesc . ' ' . $self->mt('(setup)'),
        'total_amount'  => $pkg_tax->setup_amount,
      };
    }
  }

  if ( $total_setup > 0 ) {
    push @items, {
      'total_item'   => $self->mt( $self->total_recur > 0 ? 'Total Setup' : 'Total' ),
      'total_amount' => sprintf('%.2f',$total_setup),
      'break_after'  => ( scalar(@recur_tax) ? 1 : 0 )
    };
  }

  #could/should add up the different recurring frequencies on lines of their own
  # but this will cover the 95% cases for now
  my $total_recur = $self->total_recur;
  # label these with the frequency
  foreach my $pkg_tax (@recur_tax) {
    if ($pkg_tax->recur_amount > 0) {
      $total_recur += $pkg_tax->recur_amount;
      # an arbitrary part_pkg, but with the right frequency
      # XXX localization
      my $part_pkg = qsearchs('part_pkg', { pkgpart => $pkg_tax->pkgpart });
      push @items, {
        'total_item'    => $pkg_tax->itemdesc . ' (' .  $part_pkg->freq_pretty . ')',
        'total_amount'  => $pkg_tax->recur_amount,
      };
    }
  }

  if ( $total_recur > 0 ) {
    push @items, {
      'total_item'   => $self->mt('Total Recurring'),
      'total_amount' => sprintf('%.2f',$total_recur),
      'break_after'  => 1,
    };
  }

  return @items;

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

=item order

This method is for use with quotations which are already associated with a customer.

Orders this quotation's packages as real packages for the customer.

If there is an error, returns an error message, otherwise returns false.

=cut

sub order {
  my $self = shift;

  tie my %all_cust_pkg, 'Tie::RefHash';
  foreach my $quotation_pkg ($self->quotation_pkg) {
    my $cust_pkg = FS::cust_pkg->new;
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

  $self->cust_main->order_pkgs( \%all_cust_pkg );

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

  my $dbh = dbh;
  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;

  # bring individual items up to date (set setup/recur and discounts)
  my @quotation_pkg = $self->quotation_pkg;
  foreach my $pkg (@quotation_pkg) {
    my $error = $pkg->estimate;
    if ($error) {
      $dbh->rollback if $oldAutoCommit;
      die "error calculating estimate for pkgpart " . $pkg->pkgpart.": $error\n";
    }

    # delete old tax records
    foreach my $quotation_pkg_tax ($pkg->quotation_pkg_tax) {
      $error = $quotation_pkg_tax->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        die "error flushing tax records for pkgpart ". $pkg->pkgpart.": $error\n";
      }
    }
  }

  # annoyingly duplicates handle_taxes--fix this in 4.x 
  if ( $conf->exists('enable_taxproducts') ) {
    warn "can't calculate external taxes for quotations yet\n";
    # then we're done
    return;
  }

  my %taxnum_exemptions; # for monthly exemptions; as yet unused

  foreach my $pkg (@quotation_pkg) {
    my $location = $pkg->cust_location;

    my $part_item = $pkg->part_pkg; # we don't have fees on these yet
    my @loc_keys = qw( district city county state country);
    my %taxhash = map { $_ => $location->$_ } @loc_keys;
    $taxhash{'taxclass'} = $part_item->taxclass;
    my @taxes;
    my %taxhash_elim = %taxhash;
    my @elim = qw( district city county state );
    do {
      @taxes = qsearch( 'cust_main_county', \%taxhash_elim );
      if ( !scalar(@taxes) && $taxhash_elim{'taxclass'} ) {
        #then try a match without taxclass
        my %no_taxclass = %taxhash_elim;
        $no_taxclass{ 'taxclass' } = '';
        @taxes = qsearch( 'cust_main_county', \%no_taxclass );
      }
    
      $taxhash_elim{ shift(@elim) } = '';
    } while ( !scalar(@taxes) && scalar(@elim) );

    foreach my $tax_def (@taxes) {
      my $taxnum = $tax_def->taxnum;
      $taxnum_exemptions{$taxnum} ||= [];

      # XXX do some kind of equivalent to set_exemptions here
      # but for now just declare that there are no exemptions,
      # and then hack the taxable amounts if the package def
      # excludes setup/recur
      $pkg->set('cust_tax_exempt_pkg', []);

      if ( $part_item->setuptax or $tax_def->setuptax ) {
        $pkg->set('unitsetup', 0);
      }
      if ( $part_item->recurtax or $tax_def->recurtax ) {
        $pkg->set('unitrecur', 0);
      }

      my %taxline;
      foreach my $pass (qw(first recur)) {
        if ($pass eq 'recur') {
          $pkg->set('unitsetup', 0);
        }

        my $taxline = $tax_def->taxline(
          [ $pkg ],
          exemptions => $taxnum_exemptions{$taxnum}
        );
        if ($taxline and !ref($taxline)) {
          $dbh->rollback if $oldAutoCommit;
          die "error calculating '".$tax_def->taxname .
              "' for pkgpart '".$pkg->pkgpart."': $taxline\n";
        }
        $taxline{$pass} = $taxline;
      }

      my $quotation_pkg_tax = FS::quotation_pkg_tax->new({
          quotationpkgnum => $pkg->quotationpkgnum,
          itemdesc        => $tax_def->taxname,
          taxnum          => $taxnum,
          taxtype         => ref($tax_def),
      });
      my $setup_amount = 0;
      my $recur_amount = 0;
      if ($taxline{first}) {
        $setup_amount = $taxline{first}->setup; # "first cycle", not setup
      }
      if ($taxline{recur}) {
        $recur_amount = $taxline{recur}->setup;
        $setup_amount -= $recur_amount; # to get the actual setup amount
      }
      if ( $recur_amount > 0 or $setup_amount > 0 ) {
        $quotation_pkg_tax->set('setup_amount', sprintf('%.2f', $setup_amount));
        $quotation_pkg_tax->set('recur_amount', sprintf('%.2f', $recur_amount));

        my $error = $quotation_pkg_tax->insert;
        if ($error) {
          $dbh->rollback if $oldAutoCommit;
          die "error recording '".$tax_def->taxname .
              "' for pkgpart '".$pkg->pkgpart."': $error\n";
        } # if $error
      } # else there are no non-zero taxes; continue
    } # foreach $tax_def
  } # foreach $pkg

  $dbh->commit if $oldAutoCommit;
  '';
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

Return line item hashes for each package on this quotation. Differs from the
base L<FS::Template_Mixin> version in that it recalculates each quoted package
first, and doesn't implement the "condensed" option.

=cut

sub _items_pkg {
  my ($self, %options) = @_;
  $self->estimate;
  # run it through the Template_Mixin engine
  return $self->_items_cust_bill_pkg([ $self->quotation_pkg ], %options);
}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

