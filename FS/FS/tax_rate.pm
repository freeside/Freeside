package FS::tax_rate;

use strict;
use vars qw( @ISA $DEBUG $me
             %tax_unittypes %tax_maxtypes %tax_basetypes %tax_authorities
             %tax_passtypes %GetInfoType );
use Date::Parse;
use DateTime;
use DateTime::Format::Strptime;
use Storable qw( thaw );
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
use FS::cust_main;
use FS::Misc qw( csv_from_fixed );

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

  if ($self->maxtype != 0 && $self->maxtype != 9) {
    return $self->_fatal_or_null( 'tax with "'.
                                    $self->maxtype_name. '" threshold'
                                );
  }

  if ($self->maxtype == 9) {
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
    if ($self->unittype == 0) {
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

  $error = "fatal: can't yet handle ". $error;
  my $name = $self->taxname;
  $name = 'Other surcharges'
    if ($self->passtype == 2);

  if ($conf->exists('ignore_incalculable_taxes')) {
    warn $error;
    return { name => $name, amount => 0 };
  } else {
    return $error;
  }
}

=item tax_on_tax CUST_MAIN

Returns a list of taxes which are candidates for taxing taxes for the
given customer (see L<FS::cust_main>)

=cut

sub tax_on_tax {
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
  my ( $count, $last, $min_sec ) = (0, time, 5); #progressbar
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
        die $error if $error;
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
        die $error if $error;
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
        die $error if $error;
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
        die $error if $error;
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

  my $param = thaw(decode_base64(shift));
  my $format = $param->{'format'};        #well... this is all cch specific

  my $files = $param->{'uploaded_files'}
    or die "No files provided.";

  my (%files) = map { /^(\w+):([\.\w]+)$/ ? ($1,$2):() } split /,/, $files;

  if ($format eq 'cch' || $format eq 'cch-fixed') {

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;
    my $error = '';
    my $have_location = 0;

    my @list = ( 'GEOCODE',  'geofile',   \&FS::tax_rate_location::batch_import,
                 'CODE',     'codefile',  \&FS::tax_class::batch_import,
                 'PLUS4',    'plus4file', \&FS::cust_tax_location::batch_import,
                 'ZIP',      'zipfile',   \&FS::cust_tax_location::batch_import,
                 'TXMATRIX', 'txmatrix',  \&FS::part_pkg_taxrate::batch_import,
                 'DETAIL',   'detail',    \&FS::tax_rate::batch_import,
               );
    while( scalar(@list) ) {
      my ($name, $file, $import_sub) = (shift @list, shift @list, shift @list);
      unless ($files{$file}) {
        next if $name eq 'PLUS4';
        $error = "No $name supplied";
        $error = "Neither PLUS4 nor ZIP supplied"
          if ($name eq 'ZIP' && !$have_location);
        next;
      }
      $have_location = 1 if $name eq 'PLUS4';
      my $fmt = $format. ( $name eq 'ZIP' ? '-zip' : '' );
      my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc;
      my $filename = "$dir/".  $files{$file};
      open my $fh, "< $filename" or $error ||= "Can't open $name file: $!";

      $error ||= &{$import_sub}({ 'filehandle' => $fh, 'format' => $fmt }, $job);
      close $fh;
      unlink $filename or warn "Can't delete $filename: $!";
    }
    
    if ($error) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      die $error;
    }else{
      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    }

  }elsif ($format eq 'cch-update' || $format eq 'cch-fixed-update') {

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;
    my $error = '';
    my @insert_list = ();
    my @delete_list = ();

    my @list = ( 'GEOCODE',  'geofile',   \&FS::tax_rate_location::batch_import,
                 'CODE',     'codefile',  \&FS::tax_class::batch_import,
                 'PLUS4',    'plus4file', \&FS::cust_tax_location::batch_import,
                 'ZIP',      'zipfile',   \&FS::cust_tax_location::batch_import,
                 'TXMATRIX', 'txmatrix',  \&FS::part_pkg_taxrate::batch_import,
               );
    my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc;
    while( scalar(@list) ) {
      my ($name, $file, $import_sub) = (shift @list, shift @list, shift @list);
      unless ($files{$file}) {
        my $vendor = $name eq 'ZIP' ? 'cch' : 'cch-zip';
        next     # update expected only for previously installed location data
          if (   ($name eq 'PLUS4' || $name eq 'ZIP')
               && !scalar( qsearch( { table => 'cust_tax_location',
                                      hashref => { data_vendor => $vendor },
                                      select => 'DISTINCT data_vendor',
                                  } )
                         )
             );

        $error = "No $name supplied";
        next;
      }
      my $filename = "$dir/".  $files{$file};
      open my $fh, "< $filename" or $error ||= "Can't open $name file $filename: $!";
      unlink $filename or warn "Can't delete $filename: $!";

      my $ifh = new File::Temp( TEMPLATE => "$name.insert.XXXXXXXX",
                                DIR      => $dir,
                                UNLINK   => 0,     #meh
                              ) or die "can't open temp file: $!\n";

      my $dfh = new File::Temp( TEMPLATE => "$name.delete.XXXXXXXX",
                                DIR      => $dir,
                                UNLINK   => 0,     #meh
                              ) or die "can't open temp file: $!\n";

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

      push @insert_list, $name, $ifh->filename, $import_sub;
      unshift @delete_list, $name, $dfh->filename, $import_sub;

    }
    while( scalar(@insert_list) ) {
      my ($name, $file, $import_sub) =
        (shift @insert_list, shift @insert_list, shift @insert_list);

      my $fmt = $format. ( $name eq 'ZIP' ? '-zip' : '' );
      open my $fh, "< $file" or $error ||= "Can't open $name file $file: $!";
      $error ||=
        &{$import_sub}({ 'filehandle' => $fh, 'format' => $fmt }, $job);
      close $fh;
      unlink $file or warn "Can't delete $file: $!";
    }
    
    $error ||= "No DETAIL supplied"
      unless ($files{detail});
    open my $fh, "< $dir/". $files{detail}
      or $error ||= "Can't open DETAIL file: $!";
    $error ||=
      &FS::tax_rate::batch_import({ 'filehandle' => $fh, 'format' => $format },
                                  $job);
    close $fh;
    unlink "$dir/". $files{detail} or warn "Can't delete $files{detail}: $!"
      if $files{detail};

    while( scalar(@delete_list) ) {
      my ($name, $file, $import_sub) =
        (shift @delete_list, shift @delete_list, shift @delete_list);

      my $fmt = $format. ( $name eq 'ZIP' ? '-zip' : '' );
      open my $fh, "< $file" or $error ||= "Can't open $name file $file: $!";
      $error ||=
        &{$import_sub}({ 'filehandle' => $fh, 'format' => $fmt }, $job);
      close $fh;
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

=item process_download_and_update

Download and process a tax update as a queued JSRPC job

=cut

sub process_download_and_update {
  my $job = shift;

  my $param = thaw(decode_base64(shift));
  my $format = $param->{'format'};        #well... this is all cch specific

  my ( $count, $last, $min_sec, $imported ) = (0, time, 5, 0); #progressbar
  $count = 100;

  if ( $job ) {  # progress bar
    my $error = $job->update_statustext( int( 100 * $imported / $count ) );
    die $error if $error;
  }

  my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc. '/taxdata';
  unless (-d $dir) {
    mkdir $dir or die "can't create $dir: $!\n";
  }

  if ($format eq 'cch') {

    eval "use Text::CSV_XS;";
    die $@ if $@;

    eval "use XBase;";
    die $@ if $@;

    my $conffile = '%%%FREESIDE_CONF%%%/cchconf';
    my $conffh = new IO::File "<$conffile" or die "can't open $conffile: $!\n";
    my ( $urls, $secret, $states ) =
      map { /^(.*)$/ or die "bad config line in $conffile: $_\n"; $1 }
          <$conffh>;

    $dir .= '/cch';

    my $oldAutoCommit = $FS::UID::AutoCommit;
    local $FS::UID::AutoCommit = 0;
    my $dbh = dbh;
    my $error = '';

    # really should get a table EXCLUSIVE lock here
    # check if initial import or update
    
    my $sql = "SELECT count(*) from tax_rate WHERE data_vendor='$format'";
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute() or die $sth->errstr;
    my $upgrade = $sth->fetchrow_arrayref->[0];

    # create cache and/or rotate old tax data

    if (-d $dir) {

      if (-d "$dir.4") {
        opendir(my $dirh, $dir) or die "failed to open $dir.4: $!\n";
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

      die "can't find previous tax data\n" if $upgrade;

    }

    mkdir "$dir.new" or die "can't create $dir.new: $!\n";
    
    # fetch and unpack the zip files

    my $ua = new LWP::UserAgent;
    foreach my $url (split ',', $urls) {
      my @name = split '/', $url;  #somewhat restrictive
      my $name = pop @name;
      $name =~ /(.*)/; # untaint that which we trust;
      $name = $1;
      
      open my $taxfh, ">$dir.new/$name" or die "Can't open $dir.new/$name: $!\n";
     
      my $res = $ua->request(
        new HTTP::Request( GET => $url),
        sub { #my ($data, $response_object) = @_;
              print $taxfh $_[0] or die "Can't write to $dir.new/$name: $!\n";
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
      $secret =~ /(.*)/; # untaint that which we trust;
      $secret = $1;
      system('unzip', "-P", $secret, "-d", "$dir.new",  "$dir.new/$name") == 0
        or die "unzip -P $secret -d $dir.new $dir.new/$name failed";
      #unlink "$dir.new/$name";
    }
 
    # extract csv files from the dbf files

    foreach my $name ( qw( code detail geocode plus4 txmatrix zip ) ) {
      my $error = $job->update_statustext( "0,Unpacking $name" );
      die $error if $error;
      warn "opening $dir.new/$name.dbf\n" if $DEBUG;
      my $table = new XBase 'name' => "$dir.new/$name.dbf";
      die "failed to access $dir.new/$name.dbf: ". XBase->errstr
        unless defined($table);
      $count = $table->last_record; # approximately;
      $imported = 0;
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

    # generate the diff files

    my @insert_list = ();
    my @delete_list = ();

    my @list = (
                 # 'geocode',  \&FS::tax_rate_location::batch_import, 
                 'code',     \&FS::tax_class::batch_import,
                 'plus4',    \&FS::cust_tax_location::batch_import,
                 'zip',      \&FS::cust_tax_location::batch_import,
                 'txmatrix', \&FS::part_pkg_taxrate::batch_import,
                 'detail',   \&FS::tax_rate::batch_import,
               );

    while( scalar(@list) ) {
      my ( $name, $method ) = ( shift @list, shift @list );
      my %oldlines = ();

      my $error = $job->update_statustext( "0,Comparing to previous $name" );
      die $error if $error;

      warn "processing $dir.new/$name.txt\n" if $DEBUG;

      if ($upgrade) {
        open my $oldcsvfh, "$dir.1/$name.txt"
          or die "failed to open $dir.1/$name.txt: $!\n";

        while(<$oldcsvfh>) {
          chomp;
          $oldlines{$_} = 1;
        }
        close $oldcsvfh;
      }

      open my $newcsvfh, "$dir.new/$name.txt"
        or die "failed to open $dir.new/$name.txt: $!\n";
    
      my $ifh = new File::Temp( TEMPLATE => "$name.insert.XXXXXXXX",
                                DIR      => "$dir.new",
                                UNLINK   => 0,     #meh
                              ) or die "can't open temp file: $!\n";

      my $dfh = new File::Temp( TEMPLATE => "$name.delete.XXXXXXXX",
                                DIR      => "$dir.new",
                                UNLINK   => 0,     #meh
                              ) or die "can't open temp file: $!\n";

      while(<$newcsvfh>) {
        chomp;
        if (exists($oldlines{$_})) {
          $oldlines{$_} = 0;
        } else {
          print $ifh $_, ',"I"', "\n";
        }
      }
      close $newcsvfh;

      if ($name eq 'detail') {
        for (keys %oldlines) {  # one file for rate details
          print $ifh $_, ',"D"', "\n" if $oldlines{$_};
        }
      } else {
        for (keys %oldlines) {
          print $dfh $_, ',"D"', "\n" if $oldlines{$_};
        }
      }
      %oldlines = ();

      push @insert_list, $name, $ifh->filename, $method;
      unshift @delete_list, $name, $dfh->filename, $method
        unless $name eq 'detail';

      close $dfh;
      close $ifh;
    }

    while( scalar(@insert_list) ) {
      my ($name, $file, $method) =
        (shift @insert_list, shift @insert_list, shift @insert_list);

      my $fmt = "$format-update";
      $fmt = $fmt. ( $name eq 'zip' ? '-zip' : '' );
      open my $fh, "< $file" or $error ||= "Can't open $name file $file: $!";
      $error ||=
        &{$method}({ 'filehandle' => $fh, 'format' => $fmt }, $job);
      close $fh;
      #unlink $file or warn "Can't delete $file: $!";
    }
    
    while( scalar(@delete_list) ) {
      my ($name, $file, $method) =
        (shift @delete_list, shift @delete_list, shift @delete_list);

      my $fmt = "$format-update";
      $fmt = $fmt. ( $name eq 'zip' ? '-zip' : '' );
      open my $fh, "< $file" or $error ||= "Can't open $name file $file: $!";
      $error ||=
        &{$method}({ 'filehandle' => $fh, 'format' => $fmt }, $job);
      close $fh;
      #unlink $file or warn "Can't delete $file: $!";
    }
    
    if ($error) {
      $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
      die $error;
    }else{
      $dbh->commit or die $dbh->errstr if $oldAutoCommit;
    }

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

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.
#
#

sub _upgrade_data {  # class method
  my ($self, %opts) = @_;
  my $dbh = dbh;

  warn "$me upgrading $self\n" if $DEBUG;

  my @column = qw ( tax excessrate usetax useexcessrate fee excessfee
                    feebase feemax );

  if ( $dbh->{Driver}->{Name} eq 'Pg' ) {

    eval "use DBI::Const::GetInfoType;";
    die $@ if $@;

    my $major_version = 0;
    $dbh->get_info( $GetInfoType{SQL_DBMS_VER} ) =~ /^(\d{2})/
      && ( $major_version = sprintf("%d", $1) );

    if ( $major_version > 7 ) {

      # ideally this would be supported in DBIx-DBSchema and friends

      foreach my $column ( @column ) {
        my $columndef = dbdef->table($self->table)->column($column);
        unless ($columndef->type eq 'numeric') {

          warn "updating tax_rate column $column to numeric\n" if $DEBUG;
          my $sql = "ALTER TABLE tax_rate ALTER $column TYPE numeric(14,8)";
          my $sth = $dbh->prepare($sql) or die $dbh->errstr;
          $sth->execute or die $sth->errstr;

          warn "updating h_tax_rate column $column to numeric\n" if $DEBUG;
          $sql = "ALTER TABLE h_tax_rate ALTER $column TYPE numeric(14,8)";
          $sth = $dbh->prepare($sql) or die $dbh->errstr;
          $sth->execute or die $sth->errstr;

        }
      }

    } else {

      warn "WARNING: tax_rate table upgrade unsupported for this Pg version\n";

    }

  } else {

    warn "WARNING: tax_rate table upgrade only supported for Pg 8+\n";

  }

  '';

}

=back

=head1 BUGS

  Mixing automatic and manual editing works poorly at present.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::cust_bill>, schema.html from the base
documentation.

=cut

1;

