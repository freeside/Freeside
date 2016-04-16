package FS::Report::Tax::All;

use strict;
use vars qw($DEBUG);
use FS::Record qw(dbh qsearch qsearchs group_concat_sql);
use FS::Report::Tax::ByName;
use Date::Format qw( time2str );

use Data::Dumper;

$DEBUG = 0;

=item report OPTIONS

Constructor. Generates a tax report using the internal tax rate system,
showing all taxes, broken down by tax name and country.

Required parameters:
- beginning, ending: the date range as Unix timestamps.

Optional parameters:
- debug: sets the debug level.  1 will warn the data collected for the report;
2 will also warn all of the SQL statements.

=cut

# because there's not yet a "DBIx::DBSchema::View"...

sub report {
  my $class = shift;
  my %opt = @_;

  $DEBUG ||= $opt{debug};

  my($beginning, $ending) = @opt{'beginning', 'ending'};

  # figure out which reports we need to run
  my @taxname_and_country = qsearch({
      table     => 'cust_main_county',
      select    => 'country, taxname',
      hashref   => {
        tax => { op => '>', value => '0' }
      },
      order_by  => 'GROUP BY country, taxname ORDER BY country, taxname',
  });
  my @table;
  foreach (@taxname_and_country) {
    my $taxname = $_->taxname || 'Tax';
    my $country = $_->country;
    my $report = FS::Report::Tax::ByName->report(
      %opt,
      taxname     => $taxname,
      country     => $country,
      total_only  => 1,
    );
    # will have only one total row (should be only one row at all)
    my ($total_row) = grep { $_->{total} } $report->table;
    $total_row->{total} = 0; # but in this context it's a detail row
    $total_row->{taxname} = $taxname;
    $total_row->{country} = $country;
    $total_row->{label} = "$country - $taxname";
    push @table, $total_row;
  }
  my $self = bless {
    'opt'   => \%opt,
    'table' => \@table,
  }, $class;

  $self;
}

sub opt {
  my $self = shift;
  $self->{opt};
}

sub data {
  my $self = shift;
  $self->{data};
}

# sub fetchall_array...

sub table {
  my $self = shift;
  @{ $self->{table} };
}

sub title {
  my $self = shift;
  my $string = '';
  if ( $self->{opt}->{agentnum} ) {
    my $agent = qsearchs('agent', { agentnum => $self->{opt}->{agentnum} });
    $string .= $agent->agent . ' ';
  }
  $string .= 'Tax Report: '; # XXX localization
  if ( $self->{opt}->{beginning} ) {
    $string .= time2str('%h %o %Y ', $self->{opt}->{beginning});
  }
  $string .= 'through ';
  if ( $self->{opt}->{ending} and $self->{opt}->{ending} < 4294967295 ) {
    $string .= time2str('%h %o %Y', $self->{opt}->{ending});
  } else {
    $string .= 'now';
  }
  $string .= ' - all taxes';
  return $string;
}

1;
