#!/usr/bin/perl

=head1 NAME

FS::Cron::tax_rate_update

=head1 DESCRIPTION

Cron routine to update city/district sales tax rates in I<cust_main_county>.
Currently supports sales tax in the state of Washington.

=head2 wa_sales

=item Tax Rate Download

Once each month, update the tax tables from the WA DOR website.

=item Customer Address Rate Classification

Find cust_location rows in WA with no tax district.  Try to determine
a tax district.  Otherwise, generate a log error that address needs
to be correctd.

=cut

use strict;
use warnings;
use feature 'state';

use Exporter;
our @EXPORT_OK = qw(
  tax_rate_update
  wa_sales_update_tax_table
  wa_sales_log_customer_without_tax_district
);

use Carp qw(croak);
use DateTime;
use File::Temp 'tempdir';
use File::Slurp qw(read_file write_file);
use LWP::UserAgent;
use Spreadsheet::XLSX;
use Text::CSV;

use FS::Conf;
use FS::cust_main;
use FS::cust_main_county;
use FS::geocode_Mixin;
use FS::Log;
use FS::part_pkg_taxclass;
use FS::Record qw(qsearch qsearchs dbh);
use FS::upgrade_journal;

our $DEBUG = 0;

=head1 FUNCTIONS

=head2 tax_rate_update

Cron routine for freeside_daily.

Run one of the available cron functions based on conf value tax_district_method

=cut

sub tax_rate_update {

  # Currently only wa_sales is supported
  my $tax_district_method = conf_tax_district_method();

  return unless $tax_district_method;

  if ( exists &{$tax_district_method} ) {
    my $func = \&{$tax_district_method};
    $func->();
  } else {
    my $log = FS::Log->new('tax_rate_update');
    $log->error( "Unhandled tax_district_method($tax_district_method)" );
  }

}

=head2 wa_sales

Monthly:   Update the complete WA state tax tables
Every Run: Log errors for cust_location records without a district

=cut

sub wa_sales {

  return
    unless conf_tax_district_method()
        && conf_tax_district_method() eq 'wa_sales';

  my $dt_now  = DateTime->now;
  my $year    = $dt_now->year;
  my $quarter = $dt_now->quarter;

  my $journal_label =
    sprintf 'wa_sales_update_tax_table_%sQ%s', $year, $quarter;

  unless ( FS::upgrade_journal->is_done( $journal_label ) ) {
    local $@;

    eval{ wa_sales_update_tax_table(); };
    log_error_and_die( "Error updating tax tables: $@" )
      if $@;
    FS::upgrade_journal->set_done( $journal_label );
  }

  wa_sales_log_customer_without_tax_district();

  '';

}

=head2 wa_sales_log_customer_without_tax_district

For any cust_location records
* In WA state
* Attached to non cancelled packages
* With no tax district

Classify the tax district for the record using the WA State Dept of
Revenue API.  If this fails, generate an error into system log so
address can be corrected

=cut

sub wa_sales_log_customer_without_tax_district {

  return
    unless conf_tax_district_method()
        && conf_tax_district_method() eq 'wa_sales';

  my %qsearch_cust_location = (
    table => 'cust_location',
    select => '
      cust_location.locationnum,
      cust_location.custnum,
      cust_location.address1,
      cust_location.city,
      cust_location.state,
      cust_location.zip
    ',
    addl_from => '
      LEFT JOIN cust_main USING (custnum)
      LEFT JOIN cust_pkg ON cust_location.locationnum = cust_pkg.locationnum
    ',
    extra_sql => sprintf(q{
        WHERE cust_location.state = 'WA'
        AND (
             cust_location.district IS NULL
          or cust_location.district = ''
        )
        AND cust_pkg.pkgnum IS NOT NULL
        AND (
             cust_pkg.cancel > %s
          OR cust_pkg.cancel IS NULL
        )
      }, time()
    ),
  );

  for my $cust_location ( qsearch( \%qsearch_cust_location )) {
    local $@;
    log_info_and_warn(
      sprintf
        'Attempting to classify district for cust_location ' .
        'locationnum(%s) address(%s)',
          $cust_location->locationnum,
          $cust_location->address1,
    );

    eval {
      FS::geocode_Mixin::process_district_update(
        'FS::cust_location',
        $cust_location->locationnum
      );
    };

    if ( $@ ) {
      # Error indicates a crash, not an error looking up district
      # process_district_udpate will generate log messages for those errors
      log_error_and_warn(
        sprintf "Classify district error for cust_location(%s): %s",
          $cust_location->locationnum,
          $@
      );
    }

    sleep 1; # Be polite to WA DOR API
  }

  for my $cust_location ( qsearch( \%qsearch_cust_location )) {
    log_error_and_warn(
      sprintf
        "Customer address in WA lacking tax district classification. ".
        "custnum(%s) ".
        "locationnum(%s) ".
        "address(%s, %s %s, %s) ".
        "[https://webgis.dor.wa.gov/taxratelookup/SalesTax.aspx]",
          map { $cust_location->$_ }
          qw( custnum locationnum address1 city state zip )
    );
  }

}


=head2 wa_sales_update_tax_table \%args

Update city/district sales tax rates in L<FS::cust_main_county> from the
Washington State Department of Revenue published data files.

Creates, or updates, a L<FS::cust_main_county> row for every tax district
in Washington state. Some cities have different tax rates based on the
address, within the city.  Because of this, some cities have multiple
districts.

If tax classes are enabled, a row is created in every tax class for
every district.

Customer addresses aren't classified into districts here.  Instead,
when a Washington state address is inserted or changed in L<FS::cust_location>,
a job is queued for FS::geocode_Mixin::process_district_update, to ask the
Washington state API which tax district to use for this address.

All arguments are optional:

  filename: Skip file download, and process the specified filename instead

  taxname:  Updated or created records will be set to the given tax name.
            If not specified, conf value 'tax_district_taxname' is used

  year:     Specify year for tax table download.  Defaults to current year

  quarter:  Specify quarter for tax table download.  Defaults to current quarter

=head3 Washington State Department of Revenue Resources

The state of Washington makes data files available via their public website.
It's possible the availability or format of these files may change.  As of now,
the only data file that contains both city and county names is published in
XLSX format.

=over 4

=item WA Dept of Revenue

https://dor.wa.gov

=item Data file downloads

https://dor.wa.gov/find-taxes-rates/sales-and-use-tax-rates/downloadable-database

=item XLSX file example

https://dor.wa.gov/sites/default/files/legacy/Docs/forms/ExcsTx/LocSalUseTx/ExcelLocalSlsUserates_19_Q1.xlsx

=item CSV file example

https://dor.wa.gov/sites/default/files/legacy/downloads/Add_DataRates2018Q4.zip


=item Address lookup API tool

http://webgis.dor.wa.gov/webapi/AddressRates.aspx?output=xml&addr=410 Terry Ave. North&city=&zip=98100

=back

=cut

sub wa_sales_update_tax_table {
  my $args = shift;

  croak 'wa_sales_update_tax_table requires \$args hashref'
    if $args && !ref $args;

  return
    unless conf_tax_district_method()
        && conf_tax_district_method() eq 'wa_sales';

  $args->{taxname} ||= FS::Conf->new->config('tax_district_taxname');
  $args->{year}    ||= DateTime->now->year;
  $args->{quarter} ||= DateTime->now->quarter;

  log_info_and_warn(
    "Begin wa_sales_update_tax_table() ".
    join ', ' => (
      map{ "$_ => ". ( $args->{$_} || 'undef' ) }
      sort keys %$args
    )
  );

  unless ( wa_sales_update_tax_table_sanity_check() ) {
    log_error_and_die(
      'Duplicate district rows exist in the Washington state sales tax table. '.
      'These must be resolved before updating the tax tables. '.
      'See "freeside-wa-tax-table-resolve --check" to repair the tax tables. '
    );
  }

  $args->{temp_dir} ||= tempdir();

  $args->{filename} ||= wa_sales_fetch_xlsx_file( $args );

  $args->{tax_districts} = wa_sales_parse_xlsx_file( $args );

  wa_sales_update_cust_main_county( $args );

  log_info_and_warn( 'Finished wa_sales_update_tax_table()' );
}

=head2 wa_sales_update_cust_main_county \%args

Create or update the L<FS::cust_main_county> records with new data

=cut

sub wa_sales_update_cust_main_county {
  my $args = shift;

  return
    unless conf_tax_district_method()
        && conf_tax_district_method() eq 'wa_sales';

  croak 'wa_sales_update_cust_main_county requires $args hashref'
    unless ref $args
        && ref $args->{tax_districts};

  my $insert_count = 0;
  my $update_count = 0;
  my $same_count   = 0;

  # Work within a SQL transaction
  local $FS::UID::AutoCommit = 0;

  for my $taxclass ( FS::part_pkg_taxclass->taxclass_names ) {
    $taxclass ||= undef; # trap empty string when taxclasses are disabled

    # Dupe detection/remediation:
    #
    # Previous code for washington state tax district was creating
    # duplicate entries for tax districts.  This could lead to customers
    # being double-taxed
    #
    # The following code detects and eliminates duplicates that
    # were created by wa_sales district code (source=wa_sales)
    # before updating the tax table with the newly downloaded
    # data

    my %cust_main_county;
    my %cust_main_county_dupe;

    for my $row (
      qsearch(
        cust_main_county => {
          source    => 'wa_sales',
          district  => { op => '!=', value => undef },
          taxclass => $taxclass,
        }
      )
    ) {
      my $district = $row->district;

      # Row belongs to a known dupe group of districts
      if ( $cust_main_county_dupe{$district} ) {
        push @{ $cust_main_county_dupe{$district} }, $row;
        next;
      }

      # Row is the first seen dupe for the given district
      if ( $cust_main_county{$district} ) {
        $cust_main_county_dupe{$district} = [
          delete $cust_main_county{$district},
          $row
        ];
        next;
      }

      # Row is the first seen with this district
      $cust_main_county{$district} = $row;
    }

    # # Merge any dupes, place resulting non-dupe row in %cust_main_county
    # #  Merge, even if one of the dupes has a $0 tax, or some other
    # #  variation on tax row data.  Data for this row will get corrected
    # #  during the following tax import
    # for my $dupe_district_aref ( values %cust_main_county_dupe ) {
    #   my $row_to_keep = shift @$dupe_district_aref;
    #   while ( my $row_to_merge = shift @$dupe_district_aref ) {
    #     $row_to_merge->_merge_into(
    #       $row_to_keep,
    #       { identical_record_check => 0 },
    #     );
    #   }
    #   $cust_main_county{$row_to_keep->district} = $row_to_keep;
    # }

    # If there are duplicate rows, it may be unsafe to auto-resolve them
    if ( %cust_main_county_dupe ) {
      warn "Unable to continue!";
      log_error_and_die( sprintf(
        'Tax district duplicate rows detected(%s) - '.
        'WA Sales tax tables cannot be updated without resolving duplicates - '.
        'Please use tool freeside-wa-tax-table-resolve for tax table repair',
            join( ',', keys %cust_main_county_dupe )
      ));
    }

    for my $district ( @{ $args->{tax_districts} } ) {
      if ( my $row = $cust_main_county{ $district->{district} } ) {

        # District already exists in this taxclass, update if necessary
        #
        # If admin updates value of conf tax_district_taxname, instead of
        # creating an entire separate set of tax rows with
        # the new taxname, update the taxname on existing records

        {
          # Supress warning on taxname comparison, when taxname is undef
          no warnings 'uninitialized';

          if (
            $row->tax == ( $district->{tax_combined} * 100 )
            &&    $row->taxname eq    $args->{taxname}
            && uc $row->county  eq uc $district->{county}
            && uc $row->city    eq uc $district->{city}
          ) {
            $same_count++;
            next;
          }
        }

        $row->city( uc $district->{city} );
        $row->county( uc $district->{county} );
        $row->taxclass( $taxclass );
        $row->taxname( $args->{taxname} || undef );
        $row->tax( $district->{tax_combined} * 100 );

        if ( my $error = $row->replace ) {
          dbh->rollback;
          local $FS::UID::AutoCommit = 1;
          log_error_and_die(
            sprintf
              "Error updating cust_main_county row %s for district %s: %s",
              $row->taxnum,
              $district->{district},
              $error
          );
        }

        $update_count++;

      } else {

        # District doesn't exist, create row

        my $row = FS::cust_main_county->new({
          district => $district->{district},
          city     => uc $district->{city},
          county   => uc $district->{county},
          state    => 'WA',
          country  => 'US',
          taxclass => $taxclass,
          taxname  => $args->{taxname} || undef,
          tax      => $district->{tax_combined} * 100,
          source   => 'wa_sales',
        });

        if ( my $error = $row->insert ) {
          dbh->rollback;
          local $FS::UID::AutoCommit = 1;
          log_error_and_die(
            sprintf
              "Error inserting cust_main_county row for district %s: %s",
              $district->{district},
              $error
          );
        }

        $cust_main_county{ $district->{district} } = $row;
        $insert_count++;
      }

    } # /foreach $district
  } # /foreach $taxclass

  dbh->commit;

  local $FS::UID::AutoCommit = 1;
  log_info_and_warn(
    sprintf
      "WA tax table update completed. ".
      "Inserted %s rows, updated %s rows, identical %s rows",
      $insert_count,
      $update_count,
      $same_count
  );

}

=head2 wa_sales_parse_xlsx_file \%args

Parse given XLSX file for tax district information
Return an arrayref of district information hashrefs

=cut

sub wa_sales_parse_xlsx_file {
  my $args = shift;

  croak 'wa_sales_parse_xlsx_file requires $args hashref containing a filename'
    unless ref $args
        && $args->{filename};

  # About the file format:
  #
  # The current spreadsheet contains the following @columns.
  # Rows 1 and 2 are a marquee header
  # Row 3 is the column labels.  We will test these to detect
  #   changes in the data format
  # Rows 4+ are the tax district data
  #
  # The "city" column is being parsed from "Location"

  my @columns = qw( city county district tax_local tax_state tax_combined );

  log_error_and_die( "Unable to access XLSX file: $args->{filename}" )
    unless -r $args->{filename};

  my $xls_parser = Spreadsheet::XLSX->new( $args->{filename} )
    or log_error_and_die( "Error parsing XLSX file: $!" );

  my $sheet = $xls_parser->{Worksheet}->[0]
    or log_error_and_die(" Unable to access worksheet 1 in XLSX file" );

  my $cells = $sheet->{Cells}
    or log_error_and_die( "Unable to read cells in XLSX file" );

  # Read the column labels and verify
  my %labels =
    map{ $columns[$_] => $cells->[2][$_]->{Val} }
    0 .. scalar(@columns)-1;

  my %expected_labels = (
    city         => 'Location',
    county       => 'County',
    district     => 'Location Code',
    tax_local    => 'Local Rate',
    tax_state    => 'State Rate',
    tax_combined => 'Combined Sales Tax',
  );

  if (
    my @error_labels =
      grep { lc $labels{$_} ne lc $expected_labels{$_} }
      @columns
  ) {
    my $error = "Error parsing XLS file - ".
                "Data format may have been updated with WA DOR! ";
    $error .= "Expected column $expected_labels{$_}, found $labels{$_}! "
      for @error_labels;
    log_error_and_die( $error );
  }

  # Parse the rows into an array of hashes
  my @districts;
  for my $row ( 3..$sheet->{MaxRow} ) {
    my %district = (
      map { $columns[$_] => $cells->[$row][$_]->{Val} }
      0 .. scalar(@columns)-1
    );

    if (
         $district{city}
      && $district{county}
      && $district{district}     =~ /^\d+$/
      && $district{tax_local}    =~ /^\d?\.\d+$/
      && $district{tax_state}    =~ /^\d?\.\d+$/
      && $district{tax_combined} =~ /^\d?\.\d+$/
    ) {

      # For some reason, city may contain line breaks!
      $district{city} =~ s/[\r\n]//g;

      push @districts, \%district;
    } else {
      log_warn_and_warn(
        "Non-usable row found in spreadsheet:\n" . Dumper( \%district )
      );
    }

  }

  log_error_and_die( "No \@districts found in data file!" )
    unless @districts;

  log_info_and_warn(
    sprintf "Parsed %s districts from data file", scalar @districts
  );

  \@districts;

}

=head2 wa_sales_fetch_xlsx_file \%args

Download data file from WA state DOR to temporary storage,
return filename

=cut

sub wa_sales_fetch_xlsx_file {
  my $args = shift;

  return
    unless conf_tax_district_method()
        && conf_tax_district_method() eq 'wa_sales';

  croak 'wa_sales_fetch_xlsx_file requires \$args hashref'
    unless ref $args
        && $args->{temp_dir};

  my $url_base = 'https://dor.wa.gov'.
                 '/sites/default/files/legacy/Docs/forms/ExcsTx/LocSalUseTx';

  my $year    = $args->{year}    || DateTime->now->year;
  my $quarter = $args->{quarter} || DateTime->now->quarter;
  $year = substr( $year, 2, 2 ) if $year >= 1000;

  my $fn = sprintf( 'ExcelLocalSlsUserates_%s_Q%s.xlsx', $year, $quarter );
  my $url = "$url_base/$fn";

  my $write_fn = "$args->{temp_dir}/$fn";

  log_info_and_warn( "Begin download from url: $url" );

  my $ua = LWP::UserAgent->new;
  my $res = $ua->get( $url );

  log_error_and_die( "Download error: ".$res->status_line )
    unless $res->is_success;

  local $@;
  eval { write_file( $write_fn, $res->decoded_content ); };
  log_error_and_die( "Problem writing download to disk: $@" )
    if $@;

  log_info_and_warn( "Temporary file: $write_fn" );
  $write_fn;

}

=head2 wa_sales_update_tax_table_sanity_check

There should be no duplicate tax table entries in the tax table,
with the same district value, within a tax class, where source=wa_sales.

If there are, custome taxes may have been user-entered in the
freeside UI, and incorrectly labelled as source=wa_sales.  Or, the
dupe record may have been created by issues with older wa_sales code.

If these dupes exist, the sysadmin must solve the problem by hand
with the freeeside-wa-tax-table-resolve script

Returns 1 unless problem sales tax entries are detected

=cut

sub wa_sales_update_tax_table_sanity_check {
  FS::cust_main_county->find_wa_tax_dupes ? 0 : 1;
}

sub log {
  state $log = FS::Log->new('tax_rate_update');
  $log;
}

sub log_info_and_warn {
  my $log_message = shift;
  warn "$log_message\n";
  &log()->info( $log_message );
}

sub log_warn_and_warn {
  my $log_message = shift;
  warn "$log_message\n";
  &log()->warn( $log_message );
}

sub log_error_and_die {
  my $log_message = shift;
  &log()->error( $log_message );
  warn( "$log_message\n" );
  die( "$log_message\n" );
}

sub log_error_and_warn {
  my $log_message = shift;
  warn "$log_message\n";
  &log()->error( $log_message );
}

sub conf_tax_district_method {
  state $tax_district_method = FS::Conf->new->config('tax_district_method');
  $tax_district_method;
}


1;
