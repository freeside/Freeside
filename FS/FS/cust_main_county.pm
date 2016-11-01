package FS::cust_main_county;

use strict;
use vars qw( @ISA @EXPORT_OK $conf
             @cust_main_county %cust_main_county $countyflag ); # $cityflag );
use Exporter;
use FS::Record qw( qsearch qsearchs dbh );
use FS::cust_bill_pkg;
use FS::cust_bill;
use FS::cust_pkg;
use FS::part_pkg;
use FS::cust_tax_exempt;
use FS::cust_tax_exempt_pkg;
use FS::upgrade_journal;

@ISA = qw( FS::Record );
@EXPORT_OK = qw( regionselector );

@cust_main_county = ();
$countyflag = '';
#$cityflag = '';

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::cust_main_county'} = sub { 
  $conf = new FS::Conf;
};

=head1 NAME

FS::cust_main_county - Object methods for cust_main_county objects

=head1 SYNOPSIS

  use FS::cust_main_county;

  $record = new FS::cust_main_county \%hash;
  $record = new FS::cust_main_county { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  ($county_html, $state_html, $country_html) =
    FS::cust_main_county::regionselector( $county, $state, $country );

=head1 DESCRIPTION

An FS::cust_main_county object represents a tax rate, defined by locale.
FS::cust_main_county inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item taxnum - primary key (assigned automatically for new tax rates)

=item district - tax district (optional)

=item city

=item county

=item state

=item country

=item tax - percentage

=item taxclass

=item exempt_amount

=item taxname - if defined, printed on invoices instead of "Tax"

=item setuptax - if 'Y', this tax does not apply to setup fees

=item recurtax - if 'Y', this tax does not apply to recurring fees

=item source - the tax lookup method that created this tax record. For records
created manually, this will be null.

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax rate.  To add the tax rate to the database, see L<"insert">.

=cut

sub table { 'cust_main_county'; }

=item insert

Adds this tax rate to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Deletes this tax rate from the database.  If there is an error, returns the
error, otherwise returns false.

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=item check

Checks all fields to make sure this is a valid tax rate.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

=cut

sub check {
  my $self = shift;

  $self->trim_whitespace(qw(district city county state country));
  $self->set('city', uc($self->get('city'))); # also county?

  $self->exempt_amount(0) unless $self->exempt_amount;

  $self->ut_numbern('taxnum')
    || $self->ut_alphan('district')
    || $self->ut_textn('city')
    || $self->ut_textn('county')
    || $self->ut_anything('state')
    || $self->ut_text('country')
    || $self->ut_float('tax')
    || $self->ut_textn('taxclass') # ...
    || $self->ut_money('exempt_amount')
    || $self->ut_textn('taxname')
    || $self->ut_enum('setuptax', [ '', 'Y' ] )
    || $self->ut_enum('recurtax', [ '', 'Y' ] )
    || $self->ut_textn('source')
    || $self->SUPER::check
    ;

}

=item label OPTIONS

Returns a label looking like "Anytown, Alameda County, CA, US".

If the taxname field is set, it will look like
"CA Sales Tax (Anytown, Alameda County, CA, US)".

If the taxclass is set, then it will be
"Anytown, Alameda County, CA, US (International)".

OPTIONS may contain "with_taxclass", "with_city", and "with_district" to show
those fields.  It may also contain "out", in which case, if this region 
(district+city+county+state+country) contains no non-zero taxes, the label 
will read "Out of taxable region(s)".

=cut

sub label {
  my ($self, %opt) = @_;
  if ( $opt{'out'} 
       and $self->tax == 0
       and !defined(qsearchs('cust_main_county', {
           'district' => $self->district,
           'city'     => $self->city,
           'county'   => $self->county,
           'state'    => $self->state,
           'country'  => $self->country,
           'tax'  => { op => '>', value => 0 },
        })) )
  {
    return 'Out of taxable region(s)';
  }
  my $label = $self->country;
  $label = $self->state.", $label" if $self->state;
  $label = $self->county." County, $label" if $self->county;
  if ($opt{with_city}) {
    $label = $self->city.", $label" if $self->city;
    if ($opt{with_district} and $self->district) {
      $label = $self->district . ", $label";
    }
  }
  # ugly labels when taxclass and taxname are both non-null...
  # but this is how the tax report does it
  if ($opt{with_taxclass}) {
    $label = "$label (".$self->taxclass.')' if $self->taxclass;
  }
  $label = $self->taxname." ($label)" if $self->taxname;

  $label;
}

=item sql_taxclass_sameregion

Returns an SQL WHERE fragment or the empty string to search for entries
with different tax classes.

=cut

#hmm, description above could be better...

sub sql_taxclass_sameregion {
  my $self = shift;

  my $same_query = 'SELECT DISTINCT taxclass FROM cust_main_county '.
                   ' WHERE taxnum != ? AND country = ?';
  my @same_param = ( 'taxnum', 'country' );
  foreach my $opt_field (qw( state county )) {
    if ( $self->$opt_field() ) {
      $same_query .= " AND $opt_field = ?";
      push @same_param, $opt_field;
    } else {
      $same_query .= " AND $opt_field IS NULL";
    }
  }

  my @taxclasses = $self->_list_sql( \@same_param, $same_query );

  return '' unless scalar(@taxclasses);

  '( taxclass IS NULL OR ( '.  #only if !$self->taxclass ??
     join(' AND ', map { 'taxclass != '.dbh->quote($_) } @taxclasses ). 
  ' ) ) ';
}

sub _list_sql {
  my( $self, $param, $sql ) = @_;
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute( map $self->$_(), @$param )
    or die "Unexpected error executing statement $sql: ". $sth->errstr;
  map $_->[0], @{ $sth->fetchall_arrayref };
}

=item taxline TAXABLES_ARRAYREF, [ OPTION => VALUE ... ]

Takes an arrayref of L<FS::cust_bill_pkg> objects representing taxable
line items, and returns a new L<FS::cust_bill_pkg> object representing
the tax on them under this tax rate.

This will have a pseudo-field, "cust_bill_pkg_tax_location", containing 
an arrayref of L<FS::cust_bill_pkg_tax_location> objects.  Each of these 
will in turn have a "taxable_cust_bill_pkg" pseudo-field linking it to one
of the taxable items.  All of these links must be resolved as the objects
are inserted.

Options may include 'custnum' and 'invoice_time' in case the cust_bill_pkg
objects belong to an invoice that hasn't been inserted yet.

Options may include 'exemptions', an arrayref of L<FS::cust_tax_exempt_pkg>
objects belonging to the same customer, to be counted against the monthly 
tax exemption limit if there is one.

=cut

# XXX change tax_rate.pm to work like this

sub taxline {
  my( $self, $taxables, %opt ) = @_;
  $taxables = [ $taxables ] unless ref($taxables) eq 'ARRAY';
  # remove any charge class identifiers; they're not supported here
  @$taxables = grep { ref $_ } @$taxables;

  return 'taxline called with no line items' unless @$taxables;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $name = $self->taxname || 'Tax';
  my $taxable_total = 0;
  my $tax_cents = 0;

  my $round_per_line_item = $conf->exists('tax-round_per_line_item');

  my $cust_bill = $taxables->[0]->cust_bill;
  my $custnum   = $cust_bill ? $cust_bill->custnum : $opt{'custnum'};
  my $invoice_time = $cust_bill ? $cust_bill->_date : $opt{'invoice_time'};
  my $cust_main = FS::cust_main->by_key($custnum) if $custnum > 0;
  # (to avoid complications with estimated tax on quotations, assume it's
  # taxable if there is no customer)
  #if (!$cust_main) {
    #die "unable to calculate taxes for an unknown customer\n";
  #}

  # Gather any exemptions that are already attached to these cust_bill_pkgs
  # so that we can deduct them from the customer's monthly limit.
  my @existing_exemptions = @{ $opt{'exemptions'} };
  push @existing_exemptions, @{ $_->cust_tax_exempt_pkg }
    for @$taxables;

  my $tax_item = FS::cust_bill_pkg->new({
      'pkgnum'    => 0,
      'recur'     => 0,
      'sdate'     => '',
      'edate'     => '',
      'itemdesc'  => $name,
  });
  my @tax_location;

  foreach my $cust_bill_pkg (@$taxables) {
    # careful... may be a cust_bill_pkg or a quotation_pkg

    my $taxable_charged = $cust_bill_pkg->setup + $cust_bill_pkg->recur;
    foreach ( grep { $_->taxnum == $self->taxnum }
              @{ $cust_bill_pkg->cust_tax_exempt_pkg }
    ) {
      # deal with exemptions that have been set on this line item, and 
      # pertain to this tax def
      $taxable_charged -= $_->amount;
    }

    # can't determine the tax_locationnum directly for fees; they're not
    # yet linked to an invoice
    my $locationnum = $cust_bill_pkg->tax_locationnum
                   || $cust_main->ship_locationnum;

    ### Monthly capped exemptions ### 
    if ( $self->exempt_amount && $self->exempt_amount > 0 
      and $taxable_charged > 0
      and $cust_main ) {

      # XXX monthly exemptions currently don't work on quotations

      # If the billing period extends across multiple calendar months, 
      # there may be several months of exemption available.
      my $sdate = $cust_bill_pkg->sdate || $invoice_time;
      my $start_month = (localtime($sdate))[4] + 1;
      my $start_year  = (localtime($sdate))[5] + 1900;
      my $edate = $cust_bill_pkg->edate || $invoice_time;
      my $end_month   = (localtime($edate))[4] + 1;
      my $end_year    = (localtime($edate))[5] + 1900;

      # If the partial last month + partial first month <= one month,
      # don't use the exemption in the last month
      # (unless the last month is also the first month, e.g. one-time
      # charges)
      if ( (localtime($sdate))[3] >= (localtime($edate))[3]
           and ($start_month != $end_month or $start_year != $end_year)
      ) { 
        $end_month--;
        if ( $end_month == 0 ) {
          $end_year--;
          $end_month = 12;
        }
      }

      # number of months of exemption available
      my $freq = ($end_month - $start_month) +
                 ($end_year  - $start_year) * 12 +
                 1;

      # divide equally among all of them
      my $permonth = sprintf('%.2f', $taxable_charged / $freq);

      #call the whole thing off if this customer has any old
      #exemption records...
      my @cust_tax_exempt =
        qsearch( 'cust_tax_exempt' => { custnum=> $custnum } );
      if ( @cust_tax_exempt ) {
        $dbh->rollback if $oldAutoCommit;
        return
          'this customer still has old-style tax exemption records; '.
          'run bin/fs-migrate-cust_tax_exempt?';
      }

      my ($mon, $year) = ($start_month, $start_year);
      while ($taxable_charged > 0.005 and 
             ($year < $end_year or
               ($year == $end_year and $mon <= $end_month)
             )
      ) {
 
        # find the sum of the exemption used by this customer, for this tax,
        # in this month
        my $sql = "
          SELECT SUM(amount)
            FROM cust_tax_exempt_pkg
              LEFT JOIN cust_bill_pkg USING ( billpkgnum )
              LEFT JOIN cust_bill     USING ( invnum     )
            WHERE custnum = ?
              AND taxnum  = ?
              AND year    = ?
              AND month   = ?
              AND exempt_monthly = 'Y'
        ";
        my $sth = dbh->prepare($sql) or do {
          $dbh->rollback if $oldAutoCommit;
          return "fatal: can't lookup existing exemption: ". dbh->errstr;
        };
        $sth->execute(
          $custnum,
          $self->taxnum,
          $year,
          $mon,
        ) or do {
          $dbh->rollback if $oldAutoCommit;
          return "fatal: can't lookup existing exemption: ". dbh->errstr;
        };
        my $existing_exemption = $sth->fetchrow_arrayref->[0] || 0;

        # add any exemption we're already using for another line item
        foreach ( grep { $_->taxnum == $self->taxnum &&
                         $_->exempt_monthly eq 'Y'   &&
                         $_->month  == $mon          &&
                         $_->year   == $year 
                       } @existing_exemptions
                )
        {
          $existing_exemption += $_->amount;
        }

        my $remaining_exemption =
          $self->exempt_amount - $existing_exemption;
        if ( $remaining_exemption > 0 ) {
          my $addl = $remaining_exemption > $permonth
            ? $permonth
            : $remaining_exemption;
          $addl = $taxable_charged if $addl > $taxable_charged;

          my $new_exemption = 
            FS::cust_tax_exempt_pkg->new({
              amount          => sprintf('%.2f', $addl),
              exempt_monthly  => 'Y',
              year            => $year,
              month           => $mon,
              taxnum          => $self->taxnum,
              taxtype         => ref($self)
            });
          $taxable_charged -= $addl;

          # create a record of it
          push @{ $cust_bill_pkg->cust_tax_exempt_pkg }, $new_exemption;
          # and allow it to be counted against the limit for other packages
          push @existing_exemptions, $new_exemption;
        }
        # if they're using multiple months of exemption for a multi-month
        # package, then record the exemptions in separate months
        $mon++;
        if ( $mon > 12 ) {
          $mon -= 12;
          $year++;
        }

      }
    } # if exempt_amount and $cust_main

    $taxable_charged = sprintf( "%.2f", $taxable_charged);
    next if $taxable_charged == 0;

    my $this_tax_cents = $taxable_charged * $self->tax;
    if ( $round_per_line_item ) {
      # Round the tax to the nearest cent for each line item, instead of
      # across the whole invoice.
      $this_tax_cents = sprintf('%.0f', $this_tax_cents);
    } else {
      # Otherwise truncate it so that rounding error is always positive.
      $this_tax_cents = int($this_tax_cents);
    }

    my $location = FS::cust_bill_pkg_tax_location->new({
        'taxnum'      => $self->taxnum,
        'taxtype'     => ref($self),
        'cents'       => $this_tax_cents,
        'pkgnum'      => $cust_bill_pkg->pkgnum,
        'locationnum' => $locationnum,
        'taxable_cust_bill_pkg' => $cust_bill_pkg,
        'tax_cust_bill_pkg'     => $tax_item,
    });
    push @tax_location, $location;

    $taxable_total += $taxable_charged;
    $tax_cents += $this_tax_cents;
  } #foreach $cust_bill_pkg


  # calculate tax and rounding error for the whole group: total taxable
  # amount times tax rate (as cents per dollar), minus the tax already
  # charged
  # and force 0.5 to round up
  my $extra_cents = sprintf('%.0f',
    ($taxable_total * $self->tax) - $tax_cents + 0.00000001
  );

  # if we're rounding per item, then ignore that and don't distribute any
  # extra cents.
  if ( $round_per_line_item ) {
    $extra_cents = 0;
  }

  if ( $extra_cents < 0 ) {
    die "nonsense extra_cents value $extra_cents";
  }
  $tax_cents += $extra_cents;
  my $i = 0;
  foreach (@tax_location) { # can never require more than a single pass, yes?
    my $cents = $_->get('cents');
    if ( $extra_cents > 0 ) {
      $cents++;
      $extra_cents--;
    }
    $_->set('amount', sprintf('%.2f', $cents/100));
  }
  $tax_item->set('setup' => sprintf('%.2f', $tax_cents / 100));
  $tax_item->set('cust_bill_pkg_tax_location', \@tax_location);
  
  return $tax_item;
}

=back

=head1 SUBROUTINES

=over 4

=item regionselector [ COUNTY STATE COUNTRY [ PREFIX [ ONCHANGE [ DISABLED ] ] ] ]

=cut

sub regionselector {
  my ( $selected_county, $selected_state, $selected_country,
       $prefix, $onchange, $disabled ) = @_;

  $prefix = '' unless defined $prefix;

  $countyflag = 0;

#  unless ( @cust_main_county ) { #cache 
    @cust_main_county = qsearch('cust_main_county', {} );
    foreach my $c ( @cust_main_county ) {
      $countyflag=1 if $c->county;
      #push @{$cust_main_county{$c->country}{$c->state}}, $c->county;
      $cust_main_county{$c->country}{$c->state}{$c->county} = 1;
    }
#  }
  $countyflag=1 if $selected_county;

  my $script_html = <<END;
    <SCRIPT>
    function opt(what,value,text) {
      var optionName = new Option(text, value, false, false);
      var length = what.length;
      what.options[length] = optionName;
    }
    function ${prefix}country_changed(what) {
      country = what.options[what.selectedIndex].text;
      for ( var i = what.form.${prefix}state.length; i >= 0; i-- )
          what.form.${prefix}state.options[i] = null;
END
      #what.form.${prefix}state.options[0] = new Option('', '', false, true);

  foreach my $country ( sort keys %cust_main_county ) {
    $script_html .= "\nif ( country == \"$country\" ) {\n";
    foreach my $state ( sort keys %{$cust_main_county{$country}} ) {
      ( my $dstate = $state ) =~ s/[\n\r]//g;
      my $text = $dstate || '(n/a)';
      $script_html .= qq!opt(what.form.${prefix}state, "$dstate", "$text");\n!;
    }
    $script_html .= "}\n";
  }

  $script_html .= <<END;
    }
    function ${prefix}state_changed(what) {
END

  if ( $countyflag ) {
    $script_html .= <<END;
      state = what.options[what.selectedIndex].text;
      country = what.form.${prefix}country.options[what.form.${prefix}country.selectedIndex].text;
      for ( var i = what.form.${prefix}county.length; i >= 0; i-- )
          what.form.${prefix}county.options[i] = null;
END

    foreach my $country ( sort keys %cust_main_county ) {
      $script_html .= "\nif ( country == \"$country\" ) {\n";
      foreach my $state ( sort keys %{$cust_main_county{$country}} ) {
        $script_html .= "\nif ( state == \"$state\" ) {\n";
          #foreach my $county ( sort @{$cust_main_county{$country}{$state}} ) {
          foreach my $county ( sort keys %{$cust_main_county{$country}{$state}} ) {
            my $text = $county || '(n/a)';
            $script_html .=
              qq!opt(what.form.${prefix}county, "$county", "$text");\n!;
          }
        $script_html .= "}\n";
      }
      $script_html .= "}\n";
    }
  }

  $script_html .= <<END;
    }
    </SCRIPT>
END

  my $county_html = $script_html;
  if ( $countyflag ) {
    $county_html .= qq!<SELECT NAME="${prefix}county" onChange="$onchange" $disabled>!;
    $county_html .= '</SELECT>';
  } else {
    $county_html .=
      qq!<INPUT TYPE="hidden" NAME="${prefix}county" VALUE="$selected_county">!;
  }

  my $state_html = qq!<SELECT NAME="${prefix}state" !.
                   qq!onChange="${prefix}state_changed(this); $onchange" $disabled>!;
  foreach my $state ( sort keys %{ $cust_main_county{$selected_country} } ) {
    my $text = $state || '(n/a)';
    my $selected = $state eq $selected_state ? 'SELECTED' : '';
    $state_html .= qq(\n<OPTION $selected VALUE="$state">$text</OPTION>);
  }
  $state_html .= '</SELECT>';

  $state_html .= '</SELECT>';

  my $country_html = qq!<SELECT NAME="${prefix}country" !.
                     qq!onChange="${prefix}country_changed(this); $onchange" $disabled>!;
  my $countrydefault = $conf->config('countrydefault') || 'US';
  foreach my $country (
    sort { ($b eq $countrydefault) <=> ($a eq $countrydefault) or $a cmp $b }
      keys %cust_main_county
  ) {
    my $selected = $country eq $selected_country ? ' SELECTED' : '';
    $country_html .= qq(\n<OPTION$selected VALUE="$country">$country</OPTION>");
  }
  $country_html .= '</SELECT>';

  ($county_html, $state_html, $country_html);

}

sub _merge_into {
  # for internal use: takes another cust_main_county object, transfers
  # all existing references to this record to that one, and deletes this
  # one.
  my $record = shift;
  my $other = shift or die "record to merge into must be provided";
  my $new_taxnum = $other->taxnum;
  my $old_taxnum = $record->taxnum;
  if ($other->tax != $record->tax or
      $other->exempt_amount != $record->exempt_amount) {
    # don't assume these are the same.
    warn "Found duplicate taxes (#$new_taxnum and #$old_taxnum) but they have different rates and can't be merged.\n";
  } else {
    warn "Merging tax #$old_taxnum into #$new_taxnum\n";
    foreach my $table (qw(
      cust_bill_pkg_tax_location
      cust_bill_pkg_tax_location_void
      cust_tax_exempt_pkg
      cust_tax_exempt_pkg_void
    )) {
      foreach my $row (qsearch($table, { 'taxnum' => $old_taxnum })) {
        $row->set('taxnum' => $new_taxnum);
        my $error = $row->replace;
        die $error if $error;
      }
    }
    my $error = $record->delete;
    die $error if $error;
  }
}

sub _upgrade_data {
  my $class = shift;
  # assume taxes in Washington with district numbers, and null name, or 
  # named 'sales tax', are looked up via the wa_sales method. mark them.
  my $journal = 'cust_main_county__source_wa_sales';
  if (!FS::upgrade_journal->is_done($journal)) {
    my @taxes = qsearch({
        'table'     => 'cust_main_county',
        'extra_sql' => " WHERE tax > 0 AND country = 'US' AND state = 'WA'".
                       " AND district IS NOT NULL AND ( taxname IS NULL OR ".
                       " taxname ~* 'sales tax' )",
    });
    if ( @taxes ) {
      warn "Flagging Washington state sales taxes: ".scalar(@taxes)." records.\n";
      foreach (@taxes) {
        $_->set('source', 'wa_sales');
        my $error = $_->replace;
        die $error if $error;
      }
    }
    FS::upgrade_journal->set_done($journal);
  }
  my @key_fields = (qw(city county state country district taxname taxclass));

  # remove duplicates (except disabled records)
  my @duplicate_sets = qsearch({
    table => 'cust_main_county',
    select => FS::Record::group_concat_sql('taxnum', ',') . ' AS taxnums, ' .
              join(',', @key_fields),
    extra_sql => ' WHERE tax > 0
      GROUP BY city, county, state, country, district, taxname, taxclass
      HAVING COUNT(*) > 1'
  });
  warn "Found ".scalar(@duplicate_sets)." set(s) of duplicate tax definitions\n"
    if @duplicate_sets;
  foreach my $set (@duplicate_sets) {
    my @taxnums = split(',', $set->get('taxnums'));
    my $first = FS::cust_main_county->by_key(shift @taxnums);
    foreach my $taxnum (@taxnums) {
      my $record = FS::cust_main_county->by_key($taxnum);
      $record->_merge_into($first);
    }
  }

  # trim whitespace and convert to uppercase in the 'city' field.
  foreach my $record (qsearch({
    table => 'cust_main_county',
    extra_sql => " WHERE city LIKE ' %' OR city LIKE '% ' OR city != UPPER(city)",
  })) {
    # any with-trailing-space records probably duplicate other records
    # from the same city, and if we just fix the record in place, we'll
    # create an exact duplicate.
    # so find the record this one would duplicate, and merge them.
    $record->check; # trims whitespace
    my %match = map { $_ => $record->get($_) } @key_fields;
    my $other = qsearchs('cust_main_county', \%match);
    if ($other) {
      $record->_merge_into($other);
    } else {
      # else there is no record this one duplicates, so just fix it
      my $error = $record->replace;
      die $error if $error;
    }
  } # foreach $record
  '';
}

=back

=head1 BUGS

regionselector?  putting web ui components in here?  they should probably live
somewhere else...

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_bill>, schema.html from the base
documentation.

=cut

1;

