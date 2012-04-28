package FS::cust_main_county;

use strict;
use vars qw( @ISA @EXPORT_OK $conf
             @cust_main_county %cust_main_county $countyflag ); # $cityflag );
use Exporter;
use FS::Record qw( qsearch dbh );
use FS::cust_bill_pkg;
use FS::cust_bill;
use FS::cust_pkg;
use FS::part_pkg;
use FS::cust_tax_exempt;
use FS::cust_tax_exempt_pkg;

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
    || $self->SUPER::check
    ;

}

sub taxname {
  my $self = shift;
  if ( $self->dbdef_table->column('taxname') ) {
    return $self->setfield('taxname', $_[0]) if @_;
    return $self->getfield('taxname');
  }  
  return '';
}

sub setuptax {
  my $self = shift;
  if ( $self->dbdef_table->column('setuptax') ) {
    return $self->setfield('setuptax', $_[0]) if @_;
    return $self->getfield('setuptax');
  }  
  return '';
}

sub recurtax {
  my $self = shift;
  if ( $self->dbdef_table->column('recurtax') ) {
    return $self->setfield('recurtax', $_[0]) if @_;
    return $self->getfield('recurtax');
  }  
  return '';
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

Returns a listref of a name and an amount of tax calculated for the list of
packages or amounts referenced by TAXABLES_ARRAYREF.  Returns a scalar error
message on error.  

Options include custnum and invoice_date and are hints to this method

=cut

sub taxline {
  my( $self, $taxables, %opt ) = @_;

  my @exemptions = ();
  push @exemptions, @{ $_->_cust_tax_exempt_pkg }
    for grep { ref($_) } @$taxables;
    
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
  my $amount = 0;

  foreach my $cust_bill_pkg (@$taxables) {

    my $cust_pkg  = $cust_bill_pkg->cust_pkg;
    my $cust_bill = $cust_pkg->cust_bill if $cust_pkg;
    my $custnum   = $cust_pkg ? $cust_pkg->custnum : $opt{custnum};
    my $part_pkg  = $cust_bill_pkg->part_pkg;
    my $invoice_date = $cust_bill ? $cust_bill->_date : $opt{invoice_date};
  
    my $taxable_charged = 0;
    $taxable_charged += $cust_bill_pkg->setup
      unless $part_pkg->setuptax =~ /^Y$/i
          || $self->setuptax =~ /^Y$/i;
    $taxable_charged += $cust_bill_pkg->recur
      unless $part_pkg->recurtax =~ /^Y$/i
          || $self->recurtax =~ /^Y$/i;

    next unless $taxable_charged;
  
    if ( $self->exempt_amount && $self->exempt_amount > 0 ) {
      #my ($mon,$year) = (localtime($cust_bill_pkg->sdate) )[4,5];
      my ($mon,$year) =
        (localtime( $cust_bill_pkg->sdate || $invoice_date ) )[4,5];
      $mon++;
      my $freq = $cust_bill_pkg->freq;
      unless ($freq) {
        $freq = $part_pkg->freq || 1;  # less trustworthy fallback
      }
      if ( $freq !~ /(\d+)$/ ) {
        $dbh->rollback if $oldAutoCommit;
        return "daily/weekly package definitions not (yet?)".
               " compatible with monthly tax exemptions";
      }
      my $taxable_per_month =
        sprintf("%.2f", $taxable_charged / $freq );

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

      foreach my $which_month ( 1 .. $freq ) {
  
        #maintain the new exemption table now
        my $sql = "
          SELECT SUM(amount)
            FROM cust_tax_exempt_pkg
              LEFT JOIN cust_bill_pkg USING ( billpkgnum )
              LEFT JOIN cust_bill     USING ( invnum     )
            WHERE custnum = ?
              AND taxnum  = ?
              AND year    = ?
              AND month   = ?
        ";
        my $sth = dbh->prepare($sql) or do {
          $dbh->rollback if $oldAutoCommit;
          return "fatal: can't lookup exising exemption: ". dbh->errstr;
        };
        $sth->execute(
          $custnum,
          $self->taxnum,
          1900+$year,
          $mon,
        ) or do {
          $dbh->rollback if $oldAutoCommit;
          return "fatal: can't lookup exising exemption: ". dbh->errstr;
        };
        my $existing_exemption = $sth->fetchrow_arrayref->[0] || 0;

        foreach ( grep { $_->taxnum == $self->taxnum &&
                         $_->month  == $mon          &&
                         $_->year   == 1900+$year
                       } @exemptions
                )
        {
          $existing_exemption += $_->amount;
        }
        
        my $remaining_exemption =
          $self->exempt_amount - $existing_exemption;
        if ( $remaining_exemption > 0 ) {
          my $addl = $remaining_exemption > $taxable_per_month
            ? $taxable_per_month
            : $remaining_exemption;
          $taxable_charged -= $addl;

          my $cust_tax_exempt_pkg = new FS::cust_tax_exempt_pkg ( {
            'taxnum'     => $self->taxnum,
            'year'       => 1900+$year,
            'month'      => $mon,
            'amount'     => sprintf("%.2f", $addl ),
          } );
          if ($cust_bill_pkg->billpkgnum) {
            $cust_tax_exempt_pkg->billpkgnum($cust_bill_pkg->billpkgnum);
            my $error = $cust_tax_exempt_pkg->insert;
            if ( $error ) {
              $dbh->rollback if $oldAutoCommit;
              return "fatal: can't insert cust_tax_exempt_pkg: $error";
            }
          }else{
            push @exemptions, $cust_tax_exempt_pkg;
            push @{ $cust_bill_pkg->_cust_tax_exempt_pkg }, $cust_tax_exempt_pkg;
          } # if $cust_bill_pkg->billpkgnum
        } # if $remaining_exemption > 0

        #++
        $mon++;
        #until ( $mon < 12 ) { $mon -= 12; $year++; }
        until ( $mon < 13 ) { $mon -= 12; $year++; }

      } #foreach $which_month

    } #if $tax->exempt_amount

    $taxable_charged = sprintf( "%.2f", $taxable_charged);

    $amount += $taxable_charged * $self->tax / 100
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return {
    'name'   => $name,
    'amount' => $amount,
  };

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

=back

=head1 BUGS

regionselector?  putting web ui components in here?  they should probably live
somewhere else...

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_bill>, schema.html from the base
documentation.

=cut

1;

