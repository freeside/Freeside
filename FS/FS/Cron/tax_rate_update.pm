#!/usr/bin/perl

=head1 NAME

FS::Cron::tax_rate_update

=head1 DESCRIPTION

Cron routine to update city/district sales tax rates in I<cust_main_county>.
Currently supports sales tax in the state of Washington.

=cut

use strict;
use warnings;
use FS::Conf;
use FS::Record qw(qsearch qsearchs dbh);
use FS::cust_main_county;
use FS::part_pkg_taxclass;
use DateTime;
use LWP::UserAgent;
use File::Temp 'tempdir';
use File::Slurp qw(read_file write_file);
use Text::CSV;
use Exporter;

our @EXPORT_OK = qw(tax_rate_update);
our $DEBUG = 0;

sub tax_rate_update {
  my %opt = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $conf = FS::Conf->new;
  my $method = $conf->config('tax_district_method');
  return if !$method;

  my $taxname = $conf->config('tax_district_taxname') || '';

  if ($method eq 'wa_sales') {
    # download the update file
    my $now = DateTime->now;
    my $yr = $now->year;
    my $qt = $now->quarter;
    my $file = "Rates${yr}Q${qt}.zip";
    my $url = 'http://dor.wa.gov/downloads/Add_Data/'.$file;
    my $dir = tempdir();
    chdir($dir);
    my $ua = LWP::UserAgent->new;
    warn "Downloading $url...\n" if $DEBUG;
    my $response = $ua->get($url);
    if ( ! $response->is_success ) {
      die $response->status_line;
    }
    write_file($file, $response->decoded_content);

    # parse it
    system('unzip', $file);
    $file =~ s/\.zip$/.csv/;
    if (! -f $file) {
      die "$file not found in zip archive.\n";
    }
    open my $fh, '<', $file
      or die "couldn't open $file: $!\n";
    my $csv = Text::CSV->new;
    my $header = $csv->getline($fh);
    $csv->column_names(@$header);
    # columns we care about are headed 'Code' and 'Rate'

    my $total_changed = 0;
    my $total_skipped = 0;
    while ( !$csv->eof ) {
      my $line = $csv->getline_hr($fh);
      my $district = $line->{Code} or next;
      $district = sprintf('%04d', $district);
      my $tax = sprintf('%.1f', $line->{Rate} * 100);
      my $changed = 0;
      my $skipped = 0;
      # find rate(s) in this country+state+district+taxclass that have the
      # wa_sales flag and the configured taxname, and haven't been disabled.
      my @rates = qsearch('cust_main_county', {
          country   => 'US',
          state     => 'WA', # this is specific to WA
          district  => $district,
          taxname   => $taxname,
          source    => 'wa_sales',
          tax       => { op => '>', value => '0' },
      });
      foreach my $rate (@rates) {
        if ( $rate->tax == $tax ) {
          $skipped++;
        } else {
          $rate->set('tax', $tax);
          my $error = $rate->replace;
          die "error updating district $district: $error\n" if $error;
          $changed++;
        }
      } # foreach $taxclass
      print "$district: updated $changed, skipped $skipped\n"
        if $DEBUG and ($changed or $skipped);
      $total_changed += $changed;
      $total_skipped += $skipped;
    }
    print "Updated $total_changed tax rates.\nSkipped $total_skipped unchanged rates.\n" if $DEBUG;
    dbh->commit;
  } # else $method isn't wa_sales, no other methods exist yet
  '';
}
