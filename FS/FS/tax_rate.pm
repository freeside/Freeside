package FS::tax_rate;

use strict;
use vars qw( @ISA $DEBUG $me
             %tax_unittypes %tax_maxtypes %tax_basetypes %tax_authorities
             %tax_passtypes );
use Date::Parse;
use FS::Record qw( qsearchs dbh );
use FS::tax_class;
use FS::cust_bill_pkg;

@ISA = qw( FS::Record );

$DEBUG = 0;
$me = '[FS::tax_rate]';

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
eitem effective_date

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

=item taxline CUST_BILL_PKG, ...

Returns a listref of a name and an amount of tax calculated for the list
of packages.  If an error occurs, a message is returned as a scalar.

=cut

sub taxline {
  my $self = shift;
  my @cust_bill_pkg = @_;

  if ($self->passflag eq 'N') {
    return "fatal: can't (yet) handle taxes not passed to the customer";
  }

  if ($self->maxtype != 0 && $self->maxtype != 9) {
    return qq!fatal: can't (yet) handle tax with "!. $self->maxtype_name. 
      '" threshold';
  }

  if ($self->maxtype == 9) {
    return qq!fatal: can't (yet) handle tax with "!. $self->maxtype_name. 
      '" threshold';  # "texas" tax
  }

  if ($self->basetype != 0 && $self->basetype != 1 &&
      $self->basetype != 6 && $self->basetype != 7 &&
      $self->basetype != 14
  ) {
    return qq!fatal: can't (yet) handle tax with "!. $self->basetype_name. 
      '" basis';
  }

  my $name = $self->taxname;
  $name = 'Other surcharges'
    if ($self->passtype == 2);
  my $amount = 0;
  
  my $taxable_charged = 0;
  unless ($self->setuptax =~ /^Y$/i) {
    $taxable_charged += $_->setup foreach @cust_bill_pkg;
  }
  unless ($self->recurtax =~ /^Y$/i) {
    $taxable_charged += $_->recur foreach @cust_bill_pkg;
  }

  my $taxable_units = 0;
  unless ($self->recurtax =~ /^Y$/i) {
    $taxable_units += $_->units foreach @cust_bill_pkg;
  }

  #
  # XXX insert exemption handling here
  #
  # the tax or fee is applied to taxbase or feebase and then
  # the excessrate or excess fee is applied to taxmax or feemax
  #

  $amount += $taxable_charged * $self->tax;
  $amount += $taxable_units * $self->fee;
  
  return [$name, $amount];

}

=back

=head1 SUBROUTINES

=over 4

=item batch_import

=cut

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

      '';

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

