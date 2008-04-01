package FS::tax_rate;

use strict;
use vars qw( @ISA @EXPORT_OK $conf $DEBUG $me
             %tax_unittypes %tax_maxtypes %tax_basetypes %tax_authorities
             %tax_passtypes
             @tax_rate %tax_rate $countyflag );
use Exporter;
use Date::Parse;
use Tie::IxHash;
use FS::Record qw( qsearchs qsearch dbh );
use FS::tax_class;

@ISA = qw( FS::Record );
@EXPORT_OK = qw( regionselector );

$DEBUG = 1;
$me = '[FS::tax_rate]';

@tax_rate = ();
$countyflag = '';

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::tax_rate'} = sub { 
  $conf = new FS::Conf;
};

=head1 NAME

FS::tax_rate - Object methods for tax_rate objects

=head1 SYNOPSIS

  use FS::tax_rate;

  $record = new FS::tax_rate \%hash;
  $record = new FS::tax_rate { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  ($county_html, $state_html, $country_html) =
    FS::tax_rate::regionselector( $county, $state, $country );

=head1 DESCRIPTION

An FS::tax_rate object represents a tax rate, defined by locale.
FS::tax_rate inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item taxnum

primary key (assigned automatically for new tax rates)

=item geocode

a geographic location code provided by a tax data vendor

=item data_vendor

the tax data vendor

=item location

a location code provided by a tax authority

=item taxclassnum

a foreign key into FS::tax_class - the type of tax
referenced but FS::part_pkg_taxrate

=item effective_date

the time after which the tax applies

=item tax

percentage

=item excessrate

second bracket percentage 

=item taxbase

the amount to which the tax applies (first bracket)

=item taxmax

a cap on the amount of tax if a cap exists

=item usetax

percentage on out of jurisdiction purchases

=item useexcessrate

second bracket percentage on out of jurisdiction purchases

=item unittype

one of the values in %tax_unittypes

=item fee

amount of tax per unit

=item excessfee

second bracket amount of tax per unit

=item feebase

the number of units to which the fee applies (first bracket)

=item feemax

the most units to which fees apply (first and second brackets)

=item maxtype

a value from %tax_maxtypes indicating how brackets accumulate (i.e. monthly, per invoice, etc)

=item taxname

if defined, printed on invoices instead of "Tax"

=item taxauth

a value from %tax_authorities

=item basetype

a value from %tax_basetypes indicating the tax basis

=item passtype

a value from %tax_passtypes indicating how the tax should displayed to the customer

=item passflag

'Y', 'N', or blank indicating the tax can be passed to the customer

=item setuptax

if 'Y', this tax does not apply to setup fees

=item recurtax

if 'Y', this tax does not apply to recurring fees

=item manual

if 'Y', has been manually edited

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new tax rate.  To add the tax rate to the database, see L<"insert">.

=cut

sub table { 'tax_rate'; }

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

  foreach (qw( taxbase taxmax )) {
    $self->$_(0) unless $self->$_;
  }

  $self->ut_numbern('taxnum')
    || $self->ut_text('geocode')
    || $self->ut_textn('data_vendor')
    || $self->ut_textn('location')
    || $self->ut_foreign_key('taxclassnum', 'tax_class', 'taxclassnum')
    || $self->ut_numbern('effective_date')
    || $self->ut_float('tax')
    || $self->ut_floatn('excessrate')
    || $self->ut_money('taxbase')
    || $self->ut_money('taxmax')
    || $self->ut_floatn('usetax')
    || $self->ut_floatn('useexcessrate')
    || $self->ut_numbern('unittype')
    || $self->ut_floatn('fee')
    || $self->ut_floatn('excessfee')
    || $self->ut_floatn('feemax')
    || $self->ut_numbern('maxtype')
    || $self->ut_textn('taxname')
    || $self->ut_numbern('taxauth')
    || $self->ut_numbern('basetype')
    || $self->ut_numbern('passtype')
    || $self->ut_enum('passflag', [ '', 'Y', 'N' ])
    || $self->ut_enum('setuptax', [ '', 'Y' ] )
    || $self->ut_enum('recurtax', [ '', 'Y' ] )
    || $self->ut_enum('manual', [ '', 'Y' ] )
    || $self->SUPER::check
    ;

}

=item taxclass_description

Returns the human understandable value associated with the related
FS::tax_class.

=cut

sub taxclass_description {
  my $self = shift;
  my $tax_class = qsearchs('tax_class', {'taxclassnum' => $self->taxclassnum });
  $tax_class ? $tax_class->description : '';
}

=item unittype_name

Returns the human understandable value associated with the unittype column

=cut

%tax_unittypes = ( '0' => 'access line',
                   '1' => 'minute',
                   '2' => 'account',
);

sub unittype_name {
  my $self = shift;
  $tax_unittypes{$self->unittype};
}

=item maxtype_name

Returns the human understandable value associated with the maxtype column

=cut

%tax_maxtypes = ( '0' => 'receipts per invoice',
                  '1' => 'receipts per item',
                  '2' => 'total utility charges per utility tax year',
                  '3' => 'total charges per utility tax year',
                  '4' => 'receipts per access line',
                  '9' => 'monthly receipts per location',
);

sub maxtype_name {
  my $self = shift;
  $tax_maxtypes{$self->maxtype};
}

=item basetype_name

Returns the human understandable value associated with the basetype column

=cut

%tax_basetypes = ( '0'  => 'sale price',
                   '1'  => 'gross receipts',
                   '2'  => 'sales taxable telecom revenue',
                   '3'  => 'minutes carried',
                   '4'  => 'minutes billed',
                   '5'  => 'gross operating revenue',
                   '6'  => 'access line',
                   '7'  => 'account',
                   '8'  => 'gross revenue',
                   '9'  => 'portion gross receipts attributable to interstate service',
                   '10' => 'access line',
                   '11' => 'gross profits',
                   '12' => 'tariff rate',
                   '14' => 'account',
);

sub basetype_name {
  my $self = shift;
  $tax_basetypes{$self->basetype};
}

=item taxauth_name

Returns the human understandable value associated with the taxauth column

=cut

%tax_authorities = ( '0' => 'federal',
                     '1' => 'state',
                     '2' => 'county',
                     '3' => 'city',
                     '4' => 'local',
                     '5' => 'county administered by state',
                     '6' => 'city administered by state',
                     '7' => 'city administered by county',
                     '8' => 'local administered by state',
                     '9' => 'local administered by county',
);

sub taxauth_name {
  my $self = shift;
  $tax_authorities{$self->taxauth};
}

=item passtype_name

Returns the human understandable value associated with the passtype column

=cut

%tax_passtypes = ( '0' => 'separate tax line',
                   '1' => 'separate surcharge line',
                   '2' => 'surcharge not separated',
                   '3' => 'included in base rate',
);

sub passtype_name {
  my $self = shift;
  $tax_passtypes{$self->passtype};
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

#  unless ( @tax_rate ) { #cache 
    @tax_rate = qsearch('tax_rate', {} );
    foreach my $c ( @tax_rate ) {
      $countyflag=1 if $c->county;
      #push @{$tax_rate{$c->country}{$c->state}}, $c->county;
      $tax_rate{$c->country}{$c->state}{$c->county} = 1;
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

  foreach my $country ( sort keys %tax_rate ) {
    $script_html .= "\nif ( country == \"$country\" ) {\n";
    foreach my $state ( sort keys %{$tax_rate{$country}} ) {
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

    foreach my $country ( sort keys %tax_rate ) {
      $script_html .= "\nif ( country == \"$country\" ) {\n";
      foreach my $state ( sort keys %{$tax_rate{$country}} ) {
        $script_html .= "\nif ( state == \"$state\" ) {\n";
          #foreach my $county ( sort @{$tax_rate{$country}{$state}} ) {
          foreach my $county ( sort keys %{$tax_rate{$country}{$state}} ) {
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
  foreach my $state ( sort keys %{ $tax_rate{$selected_country} } ) {
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
      keys %tax_rate
  ) {
    my $selected = $country eq $selected_country ? ' SELECTED' : '';
    $country_html .= qq(\n<OPTION$selected VALUE="$country">$country</OPTION>");
  }
  $country_html .= '</SELECT>';

  ($county_html, $state_html, $country_html);

}

sub batch_import {
  my $param = shift;

  my $fh = $param->{filehandle};
  my $format = $param->{'format'};

  my @fields;
  my $hook;
  if ( $format eq 'cch' ) {
    @fields = qw( geocode inoutcity inoutlocal tax location taxbase taxmax
                  excessrate effective_date taxauth taxtype taxcat taxname
                  usetax useexcessrate fee unittype feemax maxtype passflag
                  passtype basetype );
    $hook = sub {
      my $hash = shift;

      $hash->{'effective_date'} = str2time($hash->{'effective_date'});

      my $taxclassid =
        join(':', map{ $hash->{$_} } qw(taxtype taxcat) );

      my %tax_class = ( 'data_vendor'  => 'cch', 
                        'taxclass' => $taxclassid,
                      );

      my $tax_class = qsearchs( 'tax_class', \%tax_class );
      return "Error inserting tax rate: no tax class $taxclassid"
        unless $tax_class;

      $hash->{'taxclassnum'} = $tax_class->taxclassnum;

      foreach (qw( inoutcity inoutlocal taxtype taxcat )) {
        delete($hash->{$_});
      }

      my %passflagmap = ( '0' => '',
                          '1' => 'Y',
                          '2' => 'N',
                        );
      $hash->{'passflag'} = $passflagmap{$hash->{'passflag'}}
        if exists $passflagmap{$hash->{'passflag'}};

      foreach (keys %$hash) {
        $hash->{$_} = substr($hash->{$_}, 0, 80)
          if length($hash->{$_}) > 80;
      }

    };

  } elsif ( $format eq 'extended' ) {
    die "unimplemented\n";
    @fields = qw( );
    $hook = sub {};
  } else {
    die "unknown format $format";
  }

  eval "use Text::CSV_XS;";
  die $@ if $@;

  my $csv = new Text::CSV_XS;

  my $imported = 0;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  
  my $line;
  while ( defined($line=<$fh>) ) {
    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    warn "$me batch_import: $imported\n" 
      if (!($imported % 100) && $DEBUG);

    my @columns = $csv->fields();

    my %tax_rate = ( 'data_vendor' => $format );
    foreach my $field ( @fields ) {
      $tax_rate{$field} = shift @columns; 
    }
    my $error = &{$hook}(\%tax_rate);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

    my $tax_rate = new FS::tax_rate( \%tax_rate );
    $error = $tax_rate->insert;

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't insert tax_rate for $line: $error";
    }

    $imported++;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return "Empty file!" unless $imported;

  ''; #no error

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

