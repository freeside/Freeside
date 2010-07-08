package FS::tax_rate;

use strict;
use vars qw( @ISA $DEBUG $me
             %tax_unittypes %tax_maxtypes %tax_basetypes %tax_authorities
             %tax_passtypes %GetInfoType $keep_cch_files );
use Date::Parse;
use DateTime;
use DateTime::Format::Strptime;
use Storable qw( thaw nfreeze );
use IO::File;
use File::Temp;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use MIME::Base64;
use DBIx::DBSchema;
use DBIx::DBSchema::Table;
use DBIx::DBSchema::Column;
use FS::Record qw( qsearch qsearchs dbh dbdef );
use FS::tax_class;
use FS::cust_bill_pkg;
use FS::cust_tax_location;
use FS::tax_rate_location;
use FS::part_pkg_taxrate;
use FS::part_pkg_taxproduct;
use FS::cust_main;
use FS::Misc qw( csv_from_fixed );

use URI::Escape;

@ISA = qw( FS::Record );

$DEBUG = 0;
$me = '[FS::tax_rate]';
$keep_cch_files = 0;

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
    || $self->ut_snumbern('effective_date')
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
    || $self->ut_enum('inoutcity', [ '', 'I', 'O' ] )
    || $self->ut_enum('inoutlocal', [ '', 'I', 'O' ] )
    || $self->ut_enum('manual', [ '', 'Y' ] )
    || $self->ut_enum('disabled', [ '', 'Y' ] )
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
                   '15' => 'prior year gross receipts',
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

=item taxline TAXABLES, [ OPTIONSHASH ]

Returns a listref of a name and an amount of tax calculated for the list
of packages/amounts referenced by TAXABLES.  If an error occurs, a message
is returned as a scalar.

=cut

sub taxline {
  my $self = shift;

  my $taxables;
  my %opt = ();

  if (ref($_[0]) eq 'ARRAY') {
    $taxables = shift;
    %opt = @_;
  }else{
    $taxables = [ @_ ];
    #exemptions would be broken in this case
  }

  my $name = $self->taxname;
  $name = 'Other surcharges'
    if ($self->passtype == 2);
  my $amount = 0;
  
  if ( $self->disabled ) { # we always know how to handle disabled taxes
    return {
      'name'   => $name,
      'amount' => $amount,
    };
  }

  my $taxable_charged = 0;
  my @cust_bill_pkg = grep { $taxable_charged += $_ unless ref; ref; }
                      @$taxables;

  warn "calculating taxes for ". $self->taxnum. " on ".
    join (",", map { $_->pkgnum } @cust_bill_pkg)
    if $DEBUG;

  if ($self->passflag eq 'N') {
    # return "fatal: can't (yet) handle taxes not passed to the customer";
    # until someone needs to track these in freeside
    return {
      'name'   => $name,
      'amount' => 0,
    };
  }

  my $maxtype = $self->maxtype || 0;
  if ($maxtype != 0 && $maxtype != 9) {
    return $self->_fatal_or_null( 'tax with "'.
                                    $self->maxtype_name. '" threshold'
                                );
  }

  if ($maxtype == 9) {
    return
      $self->_fatal_or_null( 'tax with "'. $self->maxtype_name. '" threshold' );
                                                                # "texas" tax
  }

  # we treat gross revenue as gross receipts and expect the tax data
  # to DTRT (i.e. tax on tax rules)
  if ($self->basetype != 0 && $self->basetype != 1 &&
      $self->basetype != 5 && $self->basetype != 6 &&
      $self->basetype != 7 && $self->basetype != 8 &&
      $self->basetype != 14
  ) {
    return
      $self->_fatal_or_null( 'tax with "'. $self->basetype_name. '" basis' );
  }

  unless ($self->setuptax =~ /^Y$/i) {
    $taxable_charged += $_->setup foreach @cust_bill_pkg;
  }
  unless ($self->recurtax =~ /^Y$/i) {
    $taxable_charged += $_->recur foreach @cust_bill_pkg;
  }

  my $taxable_units = 0;
  unless ($self->recurtax =~ /^Y$/i) {
    if (( $self->unittype || 0 ) == 0) {
      my %seen = ();
      foreach (@cust_bill_pkg) {
        $taxable_units += $_->units
          unless $seen{$_->pkgnum};
        $seen{$_->pkgnum}++;
      }
    }elsif ($self->unittype == 1) {
      return $self->_fatal_or_null( 'fee with minute unit type' );
    }elsif ($self->unittype == 2) {
      $taxable_units = 1;
    }else {
      return $self->_fatal_or_null( 'unknown unit type in tax'. $self->taxnum );
    }
  }

  #
  # XXX insert exemption handling here
  #
  # the tax or fee is applied to taxbase or feebase and then
  # the excessrate or excess fee is applied to taxmax or feemax
  #

  $amount += $taxable_charged * $self->tax;
  $amount += $taxable_units * $self->fee;
  
  warn "calculated taxes as [ $name, $amount ]\n"
    if $DEBUG;

  return {
    'name'   => $name,
    'amount' => $amount,
  };

}

sub _fatal_or_null {
  my ($self, $error) = @_;

  my $conf = new FS::Conf;

  $error = "can't yet handle ". $error;
  my $name = $self->taxname;
  $name = 'Other surcharges'
    if ($self->passtype == 2);

  if ($conf->exists('ignore_incalculable_taxes')) {
    warn "WARNING: $error; billing anyway per ignore_incalculable_taxes conf\n";
    return { name => $name, amount => 0 };
  } else {
    return "fatal: $error";
  }
}

=item tax_on_tax CUST_MAIN

Returns a list of taxes which are candidates for taxing taxes for the
given customer (see L<FS::cust_main>)

=cut

    #hot
sub tax_on_tax {
       #akshun
  my $self = shift;
  my $cust_main = shift;

  warn "looking up taxes on tax ". $self->taxnum. " for customer ".
    $cust_main->custnum
    if $DEBUG;

  my $geocode = $cust_main->geocode($self->data_vendor);

  # CCH oddness in m2m
  my $dbh = dbh;
  my $extra_sql = ' AND ('.
    join(' OR ', map{ 'geocode = '. $dbh->quote(substr($geocode, 0, $_)) }
                 qw(10 5 2)
        ).
    ')';

  my $order_by = 'ORDER BY taxclassnum, length(geocode) desc';
  my $select   = 'DISTINCT ON(taxclassnum) *';

  # should qsearch preface columns with the table to facilitate joins?
  my @taxclassnums = map { $_->taxclassnum }
    qsearch( { 'table'     => 'part_pkg_taxrate',
               'select'    => $select,
               'hashref'   => { 'data_vendor'      => $self->data_vendor,
                                'taxclassnumtaxed' => $self->taxclassnum,
                              },
               'extra_sql' => $extra_sql,
               'order_by'  => $order_by,
           } );

  return () unless @taxclassnums;

  $extra_sql =
    "AND (".  join(' OR ', map { "taxclassnum = $_" } @taxclassnums ). ")";

  qsearch({ 'table'     => 'tax_rate',
            'hashref'   => { 'geocode' => $geocode, },
            'extra_sql' => $extra_sql,
         })

}

=item tax_rate_location

Returns an object representing the location associated with this tax
(see L<FS::tax_rate_location>)

=cut

sub tax_rate_location {
  my $self = shift;

  qsearchs({ 'table'     => 'tax_rate_location',
             'hashref'   => { 'data_vendor' => $self->data_vendor, 
                              'geocode'     => $self->geocode,
                              'disabled'    => '',
                            },
          }) ||
  new FS::tax_rate_location;

}

=back

=head1 SUBROUTINES

=over 4

=item batch_import

=cut

sub _progressbar_foo {
  return (0, time, 5);
}

sub batch_import {
  my ($param, $job) = @_;

  my $fh = $param->{filehandle};
  my $format = $param->{'format'};

  my %insert = ();
  my %delete = ();

  my @fields;
  my $hook;

  my @column_lengths = ();
  my @column_callbacks = ();
  if ( $format eq 'cch-fixed' || $format eq 'cch-fixed-update' ) {
    $format =~ s/-fixed//;
    my $date_format = sub { my $r='';
                            /^(\d{4})(\d{2})(\d{2})$/ && ($r="$3/$2/$1");
                            $r;
                          };
    my $trim = sub { my $r = shift; $r =~ s/^\s*//; $r =~ s/\s*$//; $r };
    push @column_lengths, qw( 10 1 1 8 8 5 8 8 8 1 2 2 30 8 8 10 2 8 2 1 2 2 );
    push @column_lengths, 1 if $format eq 'cch-update';
    push @column_callbacks, $trim foreach (@column_lengths); # 5, 6, 15, 17 esp
    $column_callbacks[8] = $date_format;
  }
  
  my $line;
  my ( $count, $last, $min_sec ) = _progressbar_foo();
  if ( $job || scalar(@column_callbacks) ) {
    my $error =
      csv_from_fixed(\$fh, \$count, \@column_lengths, \@column_callbacks);
    return $error if $error;
  }
  $count *=2;

  if ( $format eq 'cch' || $format eq 'cch-update' ) {
    @fields = qw( geocode inoutcity inoutlocal tax location taxbase taxmax
                  excessrate effective_date taxauth taxtype taxcat taxname
                  usetax useexcessrate fee unittype feemax maxtype passflag
                  passtype basetype );
    push @fields, 'actionflag' if $format eq 'cch-update';

    $hook = sub {
      my $hash = shift;

      $hash->{'actionflag'} ='I' if ($hash->{'data_vendor'} eq 'cch');
      $hash->{'data_vendor'} ='cch';
      my $parser = new DateTime::Format::Strptime( pattern => "%m/%d/%Y",
                                                   time_zone => 'floating',
                                                 );
      my $dt = $parser->parse_datetime( $hash->{'effective_date'} );
      $hash->{'effective_date'} = $dt ? $dt->epoch : '';

      $hash->{$_} =~ s/\s//g foreach qw( inoutcity inoutlocal ) ; 
      $hash->{$_} = sprintf("%.2f", $hash->{$_}) foreach qw( taxbase taxmax );

      my $taxclassid =
        join(':', map{ $hash->{$_} } qw(taxtype taxcat) );

      my %tax_class = ( 'data_vendor'  => 'cch', 
                        'taxclass' => $taxclassid,
                      );

      my $tax_class = qsearchs( 'tax_class', \%tax_class );
      return "Error updating tax rate: no tax class $taxclassid"
        unless $tax_class;

      $hash->{'taxclassnum'} = $tax_class->taxclassnum;

      foreach (qw( taxtype taxcat )) {
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

      my $actionflag = delete($hash->{'actionflag'});

      $hash->{'taxname'} =~ s/`/'/g; 
      $hash->{'taxname'} =~ s|\\|/|g;

      return '' if $format eq 'cch';  # but not cch-update

      if ($actionflag eq 'I') {
        $insert{ $hash->{'geocode'}. ':'. $hash->{'taxclassnum'} } = { %$hash };
      }elsif ($actionflag eq 'D') {
        $delete{ $hash->{'geocode'}. ':'. $hash->{'taxclassnum'} } = { %$hash };
      }else{
        return "Unexpected action flag: ". $hash->{'actionflag'};
      }

      delete($hash->{$_}) for keys %$hash;

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
  
  while ( defined($line=<$fh>) ) {
    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    if ( $job ) {  # progress bar
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $imported / $count ). ",Importing tax rates"
        );
        if ($error) {
          $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
          die $error;
        }
        $last = time;
      }
    }

    my @columns = $csv->fields();

    my %tax_rate = ( 'data_vendor' => $format );
    foreach my $field ( @fields ) {
      $tax_rate{$field} = shift @columns; 
    }
    if ( scalar( @columns ) ) {
      $dbh->rollback if $oldAutoCommit;
      return "Unexpected trailing columns in line (wrong format?): $line";
    }

    my $error = &{$hook}(\%tax_rate);
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }

    if (scalar(keys %tax_rate)) { #inserts only, not updates for cch

      my $tax_rate = new FS::tax_rate( \%tax_rate );
      $error = $tax_rate->insert;

      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't insert tax_rate for $line: $error";
      }

    }

    $imported++;

  }

  for (grep { !exists($delete{$_}) } keys %insert) {
    if ( $job ) {  # progress bar
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $imported / $count ). ",Importing tax rates"
        );
        if ($error) {
          $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
          die $error;
        }
        $last = time;
      }
    }

    my $tax_rate = new FS::tax_rate( $insert{$_} );
    my $error = $tax_rate->insert;

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      my $hashref = $insert{$_};
      $line = join(", ", map { "$_ => ". $hashref->{$_} } keys(%$hashref) );
      return "can't insert tax_rate for $line: $error";
    }

    $imported++;
  }

  for (grep { exists($delete{$_}) } keys %insert) {
    if ( $job ) {  # progress bar
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $imported / $count ). ",Importing tax rates"
        );
        if ($error) {
          $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
          die $error;
        }
        $last = time;
      }
    }

    my $old = qsearchs( 'tax_rate', $delete{$_} );
    unless ($old) {
      $dbh->rollback if $oldAutoCommit;
      $old = $delete{$_};
      return "can't find tax_rate to replace for: ".
        #join(" ", map { "$_ => ". $old->{$_} } @fields);
        join(" ", map { "$_ => ". $old->{$_} } keys(%$old) );
    }
    my $new = new FS::tax_rate({ $old->hash, %{$insert{$_}}, 'manual' => ''  });
    $new->taxnum($old->taxnum);
    my $error = $new->replace($old);

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      my $hashref = $insert{$_};
      $line = join(", ", map { "$_ => ". $hashref->{$_} } keys(%$hashref) );
      return "can't replace tax_rate for $line: $error";
    }

    $imported++;
    $imported++;
  }

  for (grep { !exists($insert{$_}) } keys %delete) {
    if ( $job ) {  # progress bar
      if ( time - $min_sec > $last ) {
        my $error = $job->update_statustext(
          int( 100 * $imported / $count ). ",Importing tax rates"
        );
        if ($error) {
          $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
          die $error;
        }
        $last = time;
      }
    }

    my $tax_rate = qsearchs( 'tax_rate', $delete{$_} );
    unless ($tax_rate) {
      $dbh->rollback if $oldAutoCommit;
      $tax_rate = $delete{$_};
      return "can't find tax_rate to delete for: ".
        #join(" ", map { "$_ => ". $tax_rate->{$_} } @fields);
        join(" ", map { "$_ => ". $tax_rate->{$_} } keys(%$tax_rate) );
    }
    my $error = $tax_rate->delete;

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      my $hashref = $delete{$_};
      $line = join(", ", map { "$_ => ". $hashref->{$_} } keys(%$hashref) );
      return "can't delete tax_rate for $line: $error";
    }

    $imported++;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return "Empty file!" unless ($imported || $format eq 'cch-update');

  ''; #no error

}

=item process_batch_import

Load a batch import as a queued JSRPC job

=cut

sub process_batch_import {
  my $job = shift;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $param = thaw(decode_base64(shift));
  my $args = '$job, encode_base64( nfreeze( $param ) )';

  my $method = '_perform_batch_import';
  if ( $param->{reload} ) {
    $method = 'process_batch_reload';
  }

  eval "$method($args);";
  if ($@) {
    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    die $@;
  }

  #success!
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
}

sub _perform_batch_import {
  my $job = shift;

  my $param = thaw(decode_base64(shift));
  my $format = $param->{'format'};        #well... this is all cch specific

  my $files = $param->{'uploaded_files'}
    or die "No files provided.";

  my (%files) = map { /^(\w+):((taxdata\/\w+\.\w+\/)?[\.\w]+)$/ ? ($1,$2):() }
                split /,/, $files;

  if ( $format eq 'cch' || $format eq 'cch-fixed'
    || $format eq 'cch-update' || $format eq 'cch-fixed-update' )
  {

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;
    my $error = '';
    my @insert_list = ();
    my @delete_list = ();
    my @predelete_list = ();
    my $insertname = '';
    my $deletename = '';
    my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc;

    my @list = ( 'GEOCODE',  \&FS::tax_rate_location::batch_import,
                 'CODE',     \&FS::tax_class::batch_import,
                 'PLUS4',    \&FS::cust_tax_location::batch_import,
                 'ZIP',      \&FS::cust_tax_location::batch_import,
                 'TXMATRIX', \&FS::part_pkg_taxrate::batch_import,
                 'DETAIL',   \&FS::tax_rate::batch_import,
               );
    while( scalar(@list) ) {
      my ( $name, $import_sub ) = splice( @list, 0, 2 );
      my $file = lc($name). 'file';

      unless ($files{$file}) {
        $error = "No $name supplied";
        next;
      }
      next if $name eq 'DETAIL' && $format =~ /update/;

      my $filename = "$dir/".  $files{$file};

      if ( $format =~ /update/ ) {

        ( $error, $insertname, $deletename ) =
          _perform_cch_insert_delete_split( $name, $filename, $dir, $format )
          unless $error;
        last if $error;

        unlink $filename or warn "Can't delete $filename: $!"
          unless $keep_cch_files;
        push @insert_list, $name, $insertname, $import_sub, $format;
        if ( $name eq 'GEOCODE' ) { #handle this whole ordering issue better
          unshift @predelete_list, $name, $deletename, $import_sub, $format;
        } else {
          unshift @delete_list, $name, $deletename, $import_sub, $format;
        }

      } else {

        push @insert_list, $name, $filename, $import_sub, $format;

      }

    }

    push @insert_list,
      'DETAIL', "$dir/".$files{detail}, \&FS::tax_rate::batch_import, $format
      if $format =~ /update/;

    $error ||= _perform_cch_tax_import( $job,
                                        [ @predelete_list ],
                                        [ @insert_list ],
                                        [ @delete_list ],
    );
    
    
    @list = ( @predelete_list, @insert_list, @delete_list );
    while( !$keep_cch_files && scalar(@list) ) {
      my ( undef, $file, undef, undef ) = splice( @list, 0, 4 );
      unlink $file or warn "Can't delete $file: $!";
    }

    if ($error) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      die $error;
    }else{
      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    }

  }else{
    die "Unknown format: $format";
  }

}


sub _perform_cch_tax_import {
  my ( $job, $predelete_list, $insert_list, $delete_list ) = @_;

  my $error = '';
  foreach my $list ($predelete_list, $insert_list, $delete_list) {
    while( scalar(@$list) ) {
      my ( $name, $file, $method, $format ) = splice( @$list, 0, 4 );
      my $fmt = "$format-update";
      $fmt = $format. ( lc($name) eq 'zip' ? '-zip' : '' );
      open my $fh, "< $file" or $error ||= "Can't open $name file $file: $!";
      $error ||= &{$method}({ 'filehandle' => $fh, 'format' => $fmt }, $job);
      close $fh;
    }
  }

  return $error;
}

sub _perform_cch_insert_delete_split {
  my ($name, $filename, $dir, $format) = @_;

  my $error = '';

  open my $fh, "< $filename"
    or $error ||= "Can't open $name file $filename: $!";

  my $ifh = new File::Temp( TEMPLATE => "$name.insert.XXXXXXXX",
                            DIR      => $dir,
                            UNLINK   => 0,     #meh
                          ) or die "can't open temp file: $!\n";
  my $insertname = $ifh->filename;

  my $dfh = new File::Temp( TEMPLATE => "$name.delete.XXXXXXXX",
                            DIR      => $dir,
                            UNLINK   => 0,     #meh
                          ) or die "can't open temp file: $!\n";
  my $deletename = $dfh->filename;

  my $insert_pattern = ($format eq 'cch-update') ? qr/"I"\s*$/ : qr/I\s*$/;
  my $delete_pattern = ($format eq 'cch-update') ? qr/"D"\s*$/ : qr/D\s*$/;
  while(<$fh>) {
    my $handle = '';
    $handle = $ifh if $_ =~ /$insert_pattern/;
    $handle = $dfh if $_ =~ /$delete_pattern/;
    unless ($handle) {
      $error = "bad input line: $_" unless $handle;
      last;
    }
    print $handle $_;
  }
  close $fh;
  close $ifh;
  close $dfh;

  return ($error, $insertname, $deletename);
}

sub _perform_cch_diff {
  my ($name, $newdir, $olddir) = @_;

  my %oldlines = ();

  if ($olddir) {
    open my $oldcsvfh, "$olddir/$name.txt"
      or die "failed to open $olddir/$name.txt: $!\n";

    while(<$oldcsvfh>) {
      chomp;
      $oldlines{$_} = 1;
    }
    close $oldcsvfh;
  }

  open my $newcsvfh, "$newdir/$name.txt"
    or die "failed to open $newdir/$name.txt: $!\n";
    
  my $dfh = new File::Temp( TEMPLATE => "$name.diff.XXXXXXXX",
                            DIR      => "$newdir",
                            UNLINK   => 0,     #meh
                          ) or die "can't open temp file: $!\n";
  my $diffname = $dfh->filename;

  while(<$newcsvfh>) {
    chomp;
    if (exists($oldlines{$_})) {
      $oldlines{$_} = 0;
    } else {
      print $dfh $_, ',"I"', "\n";
    }
  }
  close $newcsvfh;

  for (keys %oldlines) {
    print $dfh $_, ',"D"', "\n" if $oldlines{$_};
  }

  close $dfh;

  return $diffname;
}

sub _cch_fetch_and_unzip {
  my ( $job, $urls, $secret, $dir ) = @_;

  my $ua = new LWP::UserAgent;
  foreach my $url (split ',', $urls) {
    my @name = split '/', $url;  #somewhat restrictive
    my $name = pop @name;
    $name =~ /([\w.]+)/; # untaint that which we don't trust so much any more
    $name = $1;
      
    open my $taxfh, ">$dir/$name" or die "Can't open $dir/$name: $!\n";
     
    my ( $imported, $last, $min_sec ) = _progressbar_foo();
    my $res = $ua->request(
      new HTTP::Request( GET => $url ),
      sub {
            print $taxfh $_[0] or die "Can't write to $dir/$name: $!\n";
            my $content_length = $_[1]->content_length;
            $imported += length($_[0]);
            if ( time - $min_sec > $last ) {
              my $error = $job->update_statustext(
                ($content_length ? int(100 * $imported/$content_length) : 0 ).
                ",Downloading data from CCH"
              );
              die $error if $error;
              $last = time;
            }
      },
    );
    die "download of $url failed: ". $res->status_line
      unless $res->is_success;
      
    close $taxfh;
    my $error = $job->update_statustext( "0,Unpacking data" );
    die $error if $error;
    $secret =~ /([\w.]+)/; # untaint that which we don't trust so much any more
    $secret = $1;
    system('unzip', "-P", $secret, "-d", "$dir",  "$dir/$name") == 0
      or die "unzip -P $secret -d $dir $dir/$name failed";
    #unlink "$dir/$name";
  }
}
 
sub _cch_extract_csv_from_dbf {
  my ( $job, $dir, $name ) = @_;

  eval "use Text::CSV_XS;";
  die $@ if $@;

  eval "use XBase;";
  die $@ if $@;

  my ( $imported, $last, $min_sec ) = _progressbar_foo();
  my $error = $job->update_statustext( "0,Unpacking $name" );
  die $error if $error;
  warn "opening $dir.new/$name.dbf\n" if $DEBUG;
  my $table = new XBase 'name' => "$dir.new/$name.dbf";
  die "failed to access $dir.new/$name.dbf: ". XBase->errstr
    unless defined($table);
  my $count = $table->last_record; # approximately;
  open my $csvfh, ">$dir.new/$name.txt"
    or die "failed to open $dir.new/$name.txt: $!\n";

  my $csv = new Text::CSV_XS { 'always_quote' => 1 };
  my @fields = $table->field_names;
  my $cursor = $table->prepare_select;
  my $format_date =
    sub { my $date = shift;
          $date =~ /^(\d{4})(\d{2})(\d{2})$/ && ($date = "$2/$3/$1");
          $date;
        };
  while (my $row = $cursor->fetch_hashref) {
    $csv->combine( map { ($table->field_type($_) eq 'D')
                         ? &{$format_date}($row->{$_}) 
                         : $row->{$_}
                       }
                   @fields
    );
    print $csvfh $csv->string, "\n";
    $imported++;
    if ( time - $min_sec > $last ) {
      my $error = $job->update_statustext(
        int(100 * $imported/$count).  ",Unpacking $name"
      );
      die $error if $error;
      $last = time;
    }
  }
  $table->close;
  close $csvfh;
}

sub _remember_disabled_taxes {
  my ( $job, $format, $disabled_tax_rate ) = @_;

  # cch specific hash

  my ( $imported, $last, $min_sec ) = _progressbar_foo();

  my @items = qsearch( { table   => 'tax_rate',
                         hashref => { disabled => 'Y',
                                      data_vendor => $format,
                                    },
                         select  => 'geocode, taxclassnum',
                       }
                     );
  my $count = scalar(@items);
  foreach my $tax_rate ( @items ) {
    if ( time - $min_sec > $last ) {
      $job->update_statustext(
        int( 100 * $imported / $count ). ",Remembering disabled taxes"
      );
      $last = time;
    }
    $imported++;
    my $tax_class =
      qsearchs( 'tax_class', { taxclassnum => $tax_rate->taxclassnum } );
    unless ( $tax_class ) {
      warn "failed to find tax_class ". $tax_rate->taxclassnum;
      next;
    }
    $disabled_tax_rate->{$tax_rate->geocode. ':'. $tax_class->taxclass} = 1;
  }
}

sub _remember_tax_products {
  my ( $job, $format, $taxproduct ) = @_;

  # XXX FIXME  this loop only works when cch is the only data provider

  my ( $imported, $last, $min_sec ) = _progressbar_foo();

  my $extra_sql = "WHERE taxproductnum IS NOT NULL OR ".
                  "0 < ( SELECT count(*) from part_pkg_option WHERE ".
                  "       part_pkg_option.pkgpart = part_pkg.pkgpart AND ".
                  "       optionname LIKE 'usage_taxproductnum_%' AND ".
                  "       optionvalue != '' )";
  my @items = qsearch( { table => 'part_pkg',
                         select  => 'DISTINCT pkgpart,taxproductnum',
                         hashref => {},
                         extra_sql => $extra_sql,
                       }
                     );
  my $count = scalar(@items);
  foreach my $part_pkg ( @items ) {
    if ( time - $min_sec > $last ) {
      $job->update_statustext(
        int( 100 * $imported / $count ). ",Remembering tax products"
      );
      $last = time;
    }
    $imported++;
    warn "working with package part ". $part_pkg->pkgpart.
      "which has a taxproductnum of ". $part_pkg->taxproductnum. "\n" if $DEBUG;
    my $part_pkg_taxproduct = $part_pkg->taxproduct('');
    $taxproduct->{$part_pkg->pkgpart}->{''} = $part_pkg_taxproduct->taxproduct
      if $part_pkg_taxproduct && $part_pkg_taxproduct->data_vendor eq $format;

    foreach my $option ( $part_pkg->part_pkg_option ) {
      next unless $option->optionname =~ /^usage_taxproductnum_(\w+)$/;
      my $class = $1;

      $part_pkg_taxproduct = $part_pkg->taxproduct($class);
      $taxproduct->{$part_pkg->pkgpart}->{$class} =
          $part_pkg_taxproduct->taxproduct
        if $part_pkg_taxproduct && $part_pkg_taxproduct->data_vendor eq $format;
    }
  }
}

sub _restore_remembered_tax_products {
  my ( $job, $format, $taxproduct ) = @_;

  # cch specific

  my ( $imported, $last, $min_sec ) = _progressbar_foo();
  my $count = scalar(keys %$taxproduct);
  foreach my $pkgpart ( keys %$taxproduct ) {
    warn "restoring taxproductnums on pkgpart $pkgpart\n" if $DEBUG;
    if ( time - $min_sec > $last ) {
      $job->update_statustext(
        int( 100 * $imported / $count ). ",Restoring tax products"
      );
      $last = time;
    }
    $imported++;

    my $part_pkg = qsearchs('part_pkg', { pkgpart => $pkgpart } );
    unless ( $part_pkg ) {
      return "somehow failed to find part_pkg with pkgpart $pkgpart!\n";
    }

    my %options = $part_pkg->options;
    my %pkg_svc = map { $_->svcpart => $_->quantity } $part_pkg->pkg_svc;
    my $primary_svc = $part_pkg->svcpart;
    my $new = new FS::part_pkg { $part_pkg->hash };

    foreach my $class ( keys %{ $taxproduct->{$pkgpart} } ) {
      warn "working with class '$class'\n" if $DEBUG;
      my $part_pkg_taxproduct =
        qsearchs( 'part_pkg_taxproduct',
                  { taxproduct  => $taxproduct->{$pkgpart}->{$class},
                    data_vendor => $format,
                  }
                );

      unless ( $part_pkg_taxproduct ) {
        return "failed to find part_pkg_taxproduct (".
          $taxproduct->{pkgpart}->{$class}. ") for pkgpart $pkgpart\n";
      }

      if ( $class eq '' ) {
        $new->taxproductnum($part_pkg_taxproduct->taxproductnum);
        next;
      }

      $options{"usage_taxproductnum_$class"} =
        $part_pkg_taxproduct->taxproductnum;

    }

    my $error = $new->replace( $part_pkg,
                               'pkg_svc' => \%pkg_svc,
                               'primary_svc' => $primary_svc,
                               'options' => \%options,
    );
      
    return $error if $error;

  }

  '';
}

sub _restore_remembered_disabled_taxes {
  my ( $job, $format, $disabled_tax_rate ) = @_;

  my ( $imported, $last, $min_sec ) = _progressbar_foo();
  my $count = scalar(keys %$disabled_tax_rate);
  foreach my $key (keys %$disabled_tax_rate) {
    if ( time - $min_sec > $last ) {
      $job->update_statustext(
        int( 100 * $imported / $count ). ",Disabling tax rates"
      );
      $last = time;
    }
    $imported++;
    my ($geocode,$taxclass) = split /:/, $key, 2;
    my @tax_class = qsearch( 'tax_class', { data_vendor => $format,
                                            taxclass    => $taxclass,
                                          } );
    return "found multiple tax_class records for format $format class $taxclass"
      if scalar(@tax_class) > 1;
      
    unless (scalar(@tax_class)) {
      warn "no tax_class for format $format class $taxclass\n";
      next;
    }

    my @tax_rate =
      qsearch('tax_rate', { data_vendor  => $format,
                            geocode      => $geocode,
                            taxclassnum  => $tax_class[0]->taxclassnum,
                          }
    );

    if (scalar(@tax_rate) > 1) {
      return "found multiple tax_rate records for format $format geocode ".
             "$geocode and taxclass $taxclass ( taxclassnum ".
             $tax_class[0]->taxclassnum.  " )";
    }
      
    if (scalar(@tax_rate)) {
      $tax_rate[0]->disabled('Y');
      my $error = $tax_rate[0]->replace;
      return $error if $error;
    }
  }
}

sub _remove_old_tax_data {
  my ( $job, $format ) = @_;

  my $dbh = dbh;
  my $error = $job->update_statustext( "0,Removing old tax data" );
  die $error if $error;

  my $sql = "UPDATE public.tax_rate_location SET disabled='Y' ".
    "WHERE data_vendor = ".  $dbh->quote($format);
  $dbh->do($sql) or return "Failed to execute $sql: ". $dbh->errstr;

  my @table = qw(
    tax_rate part_pkg_taxrate part_pkg_taxproduct tax_class cust_tax_location
  );
  foreach my $table ( @table ) {
    $sql = "DELETE FROM public.$table WHERE data_vendor = ".
      $dbh->quote($format);
    $dbh->do($sql) or return "Failed to execute $sql: ". $dbh->errstr;
  }

  if ( $format eq 'cch' ) {
    $sql = "DELETE FROM public.cust_tax_location WHERE data_vendor = ".
      $dbh->quote("$format-zip");
    $dbh->do($sql) or return "Failed to execute $sql: ". $dbh->errstr;
  }

  '';
}

sub _create_temporary_tables {
  my ( $job, $format ) = @_;

  my $dbh = dbh;
  my $error = $job->update_statustext( "0,Creating temporary tables" );
  die $error if $error;

  my @table = qw( tax_rate
                  tax_rate_location
                  part_pkg_taxrate
                  part_pkg_taxproduct
                  tax_class
                  cust_tax_location
  );
  foreach my $table ( @table ) {
    my $sql =
      "CREATE TEMPORARY TABLE $table ( LIKE $table INCLUDING DEFAULTS )";
    $dbh->do($sql) or return "Failed to execute $sql: ". $dbh->errstr;
  }

  '';
}

sub _copy_from_temp {
  my ( $job, $format ) = @_;

  my $dbh = dbh;
  my $error = $job->update_statustext( "0,Making permanent" );
  die $error if $error;

  my @table = qw( tax_rate
                  tax_rate_location
                  part_pkg_taxrate
                  part_pkg_taxproduct
                  tax_class
                  cust_tax_location
  );
  foreach my $table ( @table ) {
    my $sql =
      "INSERT INTO public.$table SELECT * from $table";
    $dbh->do($sql) or return "Failed to execute $sql: ". $dbh->errstr;
  }

  '';
}

=item process_download_and_reload

Download and process a tax update as a queued JSRPC job after wiping the
existing wipable tax data.

=cut

sub process_download_and_reload {
  _process_reload('process_download_and_update', @_);
}

  
=item process_batch_reload

Load and process a tax update from the provided files as a queued JSRPC job
after wiping the existing wipable tax data.

=cut

sub process_batch_reload {
  _process_reload('_perform_batch_import', @_);
}

  
sub _process_reload {
  my ( $method, $job ) = ( shift, shift );

  my $param = thaw(decode_base64($_[0]));
  my $format = $param->{'format'};        #well... this is all cch specific

  my ( $imported, $last, $min_sec ) = _progressbar_foo();

  if ( $job ) {  # progress bar
    my $error = $job->update_statustext( 0 );
    die $error if $error;
  }

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;
  my $error = '';

  my $sql =
    "SELECT count(*) FROM part_pkg_taxoverride JOIN tax_class ".
    "USING (taxclassnum) WHERE data_vendor = '$format'";
  my $sth = $dbh->prepare($sql) or die $dbh->errstr;
  $sth->execute
    or die "Unexpected error executing statement $sql: ". $sth->errstr;
  die "Don't (yet) know how to handle part_pkg_taxoverride records."
    if $sth->fetchrow_arrayref->[0];

  # really should get a table EXCLUSIVE lock here

  #remember disabled taxes
  my %disabled_tax_rate = ();
  $error ||= _remember_disabled_taxes( $job, $format, \%disabled_tax_rate );

  #remember tax products
  my %taxproduct = ();
  $error ||= _remember_tax_products( $job, $format, \%taxproduct );

  #create temp tables
  $error ||= _create_temporary_tables( $job, $format );

  #import new data
  unless ($error) {
    my $args = '$job, @_';
    eval "$method($args);";
    $error = $@ if $@;
  }

  #restore taxproducts
  $error ||= _restore_remembered_tax_products( $job, $format, \%taxproduct );

  #disable tax_rates
  $error ||=
   _restore_remembered_disabled_taxes( $job, $format, \%disabled_tax_rate );

  #wipe out the old data
  $error ||= _remove_old_tax_data( $job, $format ); 

  #untemporize
  $error ||= _copy_from_temp( $job, $format );

  if ($error) {
    $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
    die $error;
  }

  #success!
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
}


=item process_download_and_update

Download and process a tax update as a queued JSRPC job

=cut

sub process_download_and_update {
  my $job = shift;

  my $param = thaw(decode_base64(shift));
  my $format = $param->{'format'};        #well... this is all cch specific

  my ( $imported, $last, $min_sec ) = _progressbar_foo();

  if ( $job ) {  # progress bar
    my $error = $job->update_statustext( 0);
    die $error if $error;
  }

  my $cache_dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc. '/';
  my $dir = $cache_dir. 'taxdata';
  unless (-d $dir) {
    mkdir $dir or die "can't create $dir: $!\n";
  }

  if ($format eq 'cch') {

    my @namelist = qw( code detail geocode plus4 txmatrix zip );

    my $conf = new FS::Conf;
    die "direct download of tax data not enabled\n" 
      unless $conf->exists('taxdatadirectdownload');
    my ( $urls, $username, $secret, $states ) =
      $conf->config('taxdatadirectdownload');
    die "No tax download URL provided.  ".
        "Did you set the taxdatadirectdownload configuration value?\n"
      unless $urls;

    $dir .= '/cch';

    my $dbh = dbh;
    my $error = '';

    # really should get a table EXCLUSIVE lock here
    # check if initial import or update
    #
    # relying on mkdir "$dir.new" as a mutex
    
    my $sql = "SELECT count(*) from tax_rate WHERE data_vendor='$format'";
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute() or die $sth->errstr;
    my $update = $sth->fetchrow_arrayref->[0];

    # create cache and/or rotate old tax data

    if (-d $dir) {

      if (-d "$dir.4") {
        opendir(my $dirh, "$dir.4") or die "failed to open $dir.4: $!\n";
        foreach my $file (readdir($dirh)) {
          unlink "$dir.4/$file" if (-f "$dir.4/$file");
        }
        closedir($dirh);
        rmdir "$dir.4";
      }

      for (3, 2, 1) {
        if ( -e "$dir.$_" ) {
          rename "$dir.$_", "$dir.". ($_+1) or die "can't rename $dir.$_: $!\n";
        }
      }
      rename "$dir", "$dir.1" or die "can't rename $dir: $!\n";

    } else {

      die "can't find previous tax data\n" if $update;

    }

    mkdir "$dir.new" or die "can't create $dir.new: $!\n";
    
    # fetch and unpack the zip files

    _cch_fetch_and_unzip( $job, $urls, $secret, "$dir.new" );
 
    # extract csv files from the dbf files

    foreach my $name ( @namelist ) {
      _cch_extract_csv_from_dbf( $job, $dir, $name ); 
    }

    # generate the diff files

    my @list = ();
    foreach my $name ( @namelist ) {
      my $difffile = "$dir.new/$name.txt";
      if ($update) {
        my $error = $job->update_statustext( "0,Comparing to previous $name" );
        die $error if $error;
        warn "processing $dir.new/$name.txt\n" if $DEBUG;
        my $olddir = $update ? "$dir.1" : "";
        $difffile = _perform_cch_diff( $name, "$dir.new", $olddir );
      }
      $difffile =~ s/^$cache_dir//;
      push @list, "${name}file:$difffile";
    }

    # perform the import
    local $keep_cch_files = 1;
    $param->{uploaded_files} = join( ',', @list );
    $param->{format} .= '-update' if $update;
    $error ||=
      _perform_batch_import( $job, encode_base64( nfreeze( $param ) ) );
    
    rename "$dir.new", "$dir"
      or die "cch tax update processed, but can't rename $dir.new: $!\n";

  }else{
    die "Unknown format: $format";
  }
}

=item browse_queries PARAMS

Returns a list consisting of a hashref suited for use as the argument
to qsearch, and sql query string.  Each is based on the PARAMS hashref
of keys and values which frequently would be passed as C<scalar($cgi->Vars)>
from a form.  This conveniently creates the query hashref and count_query
string required by the browse and search elements.  As a side effect, 
the PARAMS hashref is untainted and keys with unexpected values are removed.

=cut

sub browse_queries {
  my $params = shift;

  my $query = {
                'table'     => 'tax_rate',
                'hashref'   => {},
                'order_by'  => 'ORDER BY geocode, taxclassnum',
              },

  my $extra_sql = '';

  if ( $params->{data_vendor} =~ /^(\w+)$/ ) {
    $extra_sql .= ' WHERE data_vendor = '. dbh->quote($1);
  } else {
    delete $params->{data_vendor};
  }
   
  if ( $params->{geocode} =~ /^(\w+)$/ ) {
    $extra_sql .= ( $extra_sql =~ /WHERE/i ? ' AND ' : ' WHERE ' ).
                    'geocode LIKE '. dbh->quote($1.'%');
  } else {
    delete $params->{geocode};
  }

  if ( $params->{taxclassnum} =~ /^(\d+)$/ &&
       qsearchs( 'tax_class', {'taxclassnum' => $1} )
     )
  {
    $extra_sql .= ( $extra_sql =~ /WHERE/i ? ' AND ' : ' WHERE ' ).
                  ' taxclassnum  = '. dbh->quote($1)
  } else {
    delete $params->{taxclassnun};
  }

  my $tax_type = $1
    if ( $params->{tax_type} =~ /^(\d+)$/ );
  delete $params->{tax_type}
    unless $tax_type;

  my $tax_cat = $1
    if ( $params->{tax_cat} =~ /^(\d+)$/ );
  delete $params->{tax_cat}
    unless $tax_cat;

  my @taxclassnum = ();
  if ($tax_type || $tax_cat ) {
    my $compare = "LIKE '". ( $tax_type || "%" ). ":". ( $tax_cat || "%" ). "'";
    $compare = "= '$tax_type:$tax_cat'" if ($tax_type && $tax_cat);
    @taxclassnum = map { $_->taxclassnum } 
                   qsearch({ 'table'     => 'tax_class',
                             'hashref'   => {},
                             'extra_sql' => "WHERE taxclass $compare",
                          });
  }

  $extra_sql .= ( $extra_sql =~ /WHERE/i ? ' AND ' : ' WHERE ' ). '( '.
                join(' OR ', map { " taxclassnum  = $_ " } @taxclassnum ). ' )'
    if ( @taxclassnum );

  unless ($params->{'showdisabled'}) {
    $extra_sql .= ( $extra_sql =~ /WHERE/i ? ' AND ' : ' WHERE ' ).
                  "( disabled = '' OR disabled IS NULL )";
  }

  $query->{extra_sql} = $extra_sql;

  return ($query, "SELECT COUNT(*) FROM tax_rate $extra_sql");
}

=item queue_liability_report PARAMS

Launches a tax liability report.
=cut

sub queue_liability_report {
  my $job = shift;
  my $param = thaw(decode_base64(shift));

  my $cgi = new CGI;
  $cgi->param('beginning', $param->{beginning});
  $cgi->param('ending', $param->{ending});
  my($beginning, $ending) = FS::UI::Web::parse_beginning_ending($cgi);
  my $agentnum = $param->{agentnum};
  if ($agentnum =~ /^(\d+)$/) { $agentnum = $1; } else { $agentnum = ''; };
  generate_liability_report(
    'beginning' => $beginning,
    'ending'    => $ending,
    'agentnum'  => $agentnum,
    'p'         => $param->{RootURL},
    'job'       => $job,
  );
}

=item generate_liability_report PARAMS

Generates a tax liability report.  Provide a hash including desired
agentnum, beginning, and ending

=cut

sub generate_liability_report {
  my %args = @_;

  my ( $count, $last, $min_sec ) = _progressbar_foo();

  #let us open the temp file early
  my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc;
  my $report = new File::Temp( TEMPLATE => 'report.tax.liability.XXXXXXXX',
                               DIR      => $dir,
                               UNLINK   => 0, # not so temp
                             ) or die "can't open report file: $!\n";

  my $conf = new FS::Conf;
  my $money_char = $conf->config('money_char') || '$';

  my $join_cust = "
      JOIN cust_bill USING ( invnum ) 
      LEFT JOIN cust_main USING ( custnum )
  ";

  my $join_loc =
    "LEFT JOIN cust_bill_pkg_tax_rate_location USING ( billpkgnum )";
  my $join_tax_loc = "LEFT JOIN tax_rate_location USING ( taxratelocationnum )";

  my $addl_from = " $join_cust $join_loc $join_tax_loc "; 

  my $where = "WHERE _date >= $args{beginning} AND _date <= $args{ending} ";

  my $agentname = '';
  if ( $args{agentnum} =~ /^(\d+)$/ ) {
    my $agent = qsearchs('agent', { 'agentnum' => $1 } );
    die "agent not found" unless $agent;
    $agentname = $agent->agent;
    $where .= ' AND cust_main.agentnum = '. $agent->agentnum;
  }

  # my ( $location_sql, @location_param ) = FS::cust_pkg->location_sql;
  # $where .= " AND $location_sql";
  #my @taxparam = ( 'itemdesc', @location_param );
  # now something along the lines of geocode matching ?
  #$where .= FS::cust_pkg->_location_sql_where('cust_tax_location');;
  my @taxparam = ( 'itemdesc', 'tax_rate_location.state', 'tax_rate_location.county', 'tax_rate_location.city', 'cust_bill_pkg_tax_rate_location.locationtaxid' );

  my $select = 'DISTINCT itemdesc,locationtaxid,tax_rate_location.state,tax_rate_location.county,tax_rate_location.city';

  #false laziness w/FS::Report::Table::Monthly (sub should probably be moved up
  #to FS::Report or FS::Record or who the fuck knows where)
  my $scalar_sql = sub {
    my( $r, $param, $sql ) = @_;
    my $sth = dbh->prepare($sql) or die dbh->errstr;
    $sth->execute( map $r->$_(), @$param )
      or die "Unexpected error executing statement $sql: ". $sth->errstr;
    $sth->fetchrow_arrayref->[0] || 0;
  };

  my $tax = 0;
  my $credit = 0;
  my %taxes = ();
  my %basetaxes = ();
  my $calculated = 0;
  my @tax_and_location = qsearch({ table     => 'cust_bill_pkg',
                                   select    => $select,
                                   hashref   => { pkgpart => 0 },
                                   addl_from => $addl_from,
                                   extra_sql => $where,
                                });
  $count = scalar(@tax_and_location);
  foreach my $t ( @tax_and_location ) {

    if ( $args{job} ) {
      if ( time - $min_sec > $last ) {
        $args{job}->update_statustext( int( 100 * $calculated / $count ).
                                       ",Calculated"
                                     );
        $last = time;
      }
    }

    my @params = map { my $f = $_; $f =~ s/.*\.//; $f } @taxparam;
    my $label = join('~', map { $t->$_ } @params);
    $label = 'Tax'. $label if $label =~ /^~/;
    unless ( exists( $taxes{$label} ) ) {
      my ($baselabel, @trash) = split /~/, $label;

      $taxes{$label}->{'label'} = join(', ', split(/~/, $label) );
      $taxes{$label}->{'url_param'} =
        join(';', map { "$_=". uri_escape($t->$_) } @params);

      my $taxwhere = "FROM cust_bill_pkg $addl_from $where AND payby != 'COMP' ".
        "AND ". join( ' AND ', map { "( $_ = ? OR ? = '' AND $_ IS NULL)" } @taxparam );

      my $sql = "SELECT SUM(cust_bill_pkg.setup+cust_bill_pkg.recur) ".
                " $taxwhere AND cust_bill_pkg.pkgnum = 0";

      my $x = &{$scalar_sql}($t, [ map { $_, $_ } @params ], $sql );
      $tax += $x;
      $taxes{$label}->{'tax'} += $x;

      my $creditfrom = " JOIN cust_credit_bill_pkg USING (billpkgnum,billpkgtaxratelocationnum) ";
      my $creditwhere = "FROM cust_bill_pkg $addl_from $creditfrom $where ".
        "AND payby != 'COMP' ".
        "AND ". join( ' AND ', map { "( $_ = ? OR ? = '' AND $_ IS NULL)" } @taxparam );

      $sql = "SELECT SUM(cust_credit_bill_pkg.amount) ".
             " $creditwhere AND cust_bill_pkg.pkgnum = 0";

      my $y = &{$scalar_sql}($t, [ map { $_, $_ } @params ], $sql );
      $credit += $y;
      $taxes{$label}->{'credit'} += $y;

      unless ( exists( $taxes{$baselabel} ) ) {

        $basetaxes{$baselabel}->{'label'} = $baselabel;
        $basetaxes{$baselabel}->{'url_param'} = "itemdesc=$baselabel";
        $basetaxes{$baselabel}->{'base'} = 1;

      }

      $basetaxes{$baselabel}->{'tax'} += $x;
      $basetaxes{$baselabel}->{'credit'} += $y;
      
    }

    # calculate customer-exemption for this tax
    # calculate package-exemption for this tax
    # calculate monthly exemption (texas tax) for this tax
    # count up all the cust_tax_exempt_pkg records associated with
    # the actual line items.
  }


  #ordering

  if ( $args{job} ) {
    $args{job}->update_statustext( "0,Sorted" );
    $last = time;
  }

  my @taxes = ();

  foreach my $tax ( sort { $a cmp $b } keys %taxes ) {
    my ($base, @trash) = split '~', $tax;
    my $basetax = delete( $basetaxes{$base} );
    if ($basetax) {
      if ( $basetax->{tax} == $taxes{$tax}->{tax} ) {
        $taxes{$tax}->{base} = 1;
      } else {
        push @taxes, $basetax;
      }
    }
    push @taxes, $taxes{$tax};
  }

  push @taxes, {
    'label'          => 'Total',
    'url_param'      => '',
    'tax'            => $tax,
    'credit'         => $credit,
    'base'           => 1,
  };


  my $dateagentlink = "begin=$args{beginning};end=$args{ending}";
  $dateagentlink .= ';agentnum='. $args{agentnum}
    if length($agentname);
  my $baselink   = $args{p}. "search/cust_bill_pkg.cgi?$dateagentlink";


  print $report <<EOF;
  
    <% include("/elements/header.html", "$agentname Tax Report - ".
                  ( $args{beginning}
                      ? time2str('%h %o %Y ', $args{beginning} )
                      : ''
                  ).
                  'through '.
                  ( $args{ending} == 4294967295
                      ? 'now'
                      : time2str('%h %o %Y', $args{ending} )
                  )
              )
    %>

    <% include('/elements/table-grid.html') %>

    <TR>
      <TH CLASS="grid" BGCOLOR="#cccccc"></TH>
      <TH CLASS="grid" BGCOLOR="#cccccc"></TH>
      <TH CLASS="grid" BGCOLOR="#cccccc">Tax collected</TH>
      <TH CLASS="grid" BGCOLOR="#cccccc">&nbsp;&nbsp;&nbsp;&nbsp;</TH>
      <TH CLASS="grid" BGCOLOR="#cccccc"></TH>
      <TH CLASS="grid" BGCOLOR="#cccccc">Tax credited</TH>
    </TR>
EOF

  my $bgcolor1 = '#eeeeee';
  my $bgcolor2 = '#ffffff';
  my $bgcolor = '';
 
  $count = scalar(@taxes);
  $calculated = 0;
  foreach my $tax ( @taxes ) {
 
    if ( $args{job} ) {
      if ( time - $min_sec > $last ) {
        $args{job}->update_statustext( int( 100 * $calculated / $count ).
                                       ",Generated"
                                     );
        $last = time;
      }
    }

    if ( $bgcolor eq $bgcolor1 ) {
      $bgcolor = $bgcolor2;
    } else {
      $bgcolor = $bgcolor1;
    }
 
    my $link = '';
    if ( $tax->{'label'} ne 'Total' ) {
      $link = ';'. $tax->{'url_param'};
    }
 
    print $report <<EOF;
      <TR>
        <TD CLASS="grid" BGCOLOR="<% '$bgcolor' %>"><% '$tax->{label}' %></TD>
        <% ($tax->{base}) ? qq!<TD CLASS="grid" BGCOLOR="$bgcolor"></TD>! : '' %>
        <TD CLASS="grid" BGCOLOR="<% '$bgcolor' %>" ALIGN="right">
          <A HREF="<% '$baselink$link' %>;istax=1"><% '$money_char' %><% sprintf('%.2f', $tax->{'tax'} ) %></A>
        </TD>
        <% !($tax->{base}) ? qq!<TD CLASS="grid" BGCOLOR="$bgcolor"></TD>! : '' %>
        <TD CLASS="grid" BGCOLOR="<% '$bgcolor' %>"></TD>
        <% ($tax->{base}) ? qq!<TD CLASS="grid" BGCOLOR="$bgcolor"></TD>! : '' %>
        <TD CLASS="grid" BGCOLOR="<% '$bgcolor' %>" ALIGN="right">
          <A HREF="<% '$baselink$link' %>;istax=1;iscredit=rate"><% '$money_char' %><% sprintf('%.2f', $tax->{'credit'} ) %></A>
        </TD>
        <% !($tax->{base}) ? qq!<TD CLASS="grid" BGCOLOR="$bgcolor"></TD>! : '' %>
      </TR>
EOF
  } 

  print $report <<EOF;
    </TABLE>

    </BODY>
    </HTML>
EOF

  my $reportname = $report->filename;
  close $report;

  my $dropstring = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc. '/report.';
  $reportname =~ s/^$dropstring//;

  my $reporturl = "%%%ROOTURL%%%/misc/queued_report?report=$reportname";
  die "<a href=$reporturl>view</a>\n";

}



=back

=head1 BUGS

  Mixing automatic and manual editing works poorly at present.

  Tax liability calculations take too long and arguably don't belong here.
  Tax liability report generation not entirely safe (escaped).

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_bill>, schema.html from the base
documentation.

=cut

1;

