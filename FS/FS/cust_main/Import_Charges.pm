package FS::cust_main::Import_Charges;
#actually no specific reason it lives under FS::cust_main:: othan than it calls
# a thing on cust_main objects.  not part of the inheritence, just providess a
# subroutine for misc/process/cust_main-import_charges.cgi

use strict;
use FS::UID qw( dbh );
use FS::CurrentUser;
use FS::Record qw( qsearchs );
use FS::cust_main;

=head1 NAME

FS::cust_main::Import_Charges - Batch charge importing

=head1 SYNOPSIS

  use FS::cust_main::Import_Charges;

  my $error = 
    FS::cust_main::Import_charges::batch_charge( {
      filehandle => $fh,
      'agentnum' => scalar($cgi->param('agentnum')),
      'format'   => scalar($cgi->param('format')),
    } );

=head1 DESCRIPTION

Batch customer charging.


=head1 SUBROUTINES

=over 4

=item batch_charge

=cut

sub batch_charge {
  my $job = shift;
  my $param = shift;
  #warn join('-',keys %$param);
  my $agentnum = $param->{agentnum};
  my $format = $param->{format};

  my $files = $param->{'uploaded_files'}
    or die "No files provided.\n";

  my (%files) = map { /^(\w+):([\.\w]+)$/ ? ($1,$2):() } split /,/, $files;

  my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc. '/';
  my $filename = $dir. $files{'file'};

  my $type;
  if ( $filename =~ /\.(\w+)$/i ) {
    $type = lc($1);
  } else {
    #or error out???
    warn "can't parse file type from filename $filename; defaulting to CSV";
    $type = 'csv';
  }

  my $extra_sql = ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql;

  my @fields;
  my %charges;
  if ( $format eq 'simple' ) {
    @fields = qw( custnum agent_custid amount pkg );
  } elsif ( $format eq 'ooma' ) {
    @fields = ( 'userfield1', 'userfield2', 'userfield3', 'userfield4', 'userfield5', 'userfield6', 'userfield7', 'userfield8', 'userfield9', 'userfield10', 'amount', 'userfield12', 'userfield13', 'userfield14', 'userfield15', 'userfield16', 'userfield17', 'userfield18', 'pkg', 'userfield20', 'custnum', 'userfield22', 'userfield23', 'userfield24', 'userfield25', );
  ##should charges to charge be a config option?
    %charges = (
      'DISABILITY ACCESS/ENHANCED 911 SERVICES SURCHARGE' => '1',
      'FEDERAL TRS FUND'                                  => '1',
      'FEDERAL UNIVERSAL SERVICE FUND'                    => '1',
      'STATE SALES TAX'                                   => '1',
    );
  } else {
    die "unknown format $format";
  }

  my $count;
  my $parser;
  my @buffer = ();

  if ( $type eq 'csv' ) {

    eval "use Text::CSV_XS;";
    eval "use File::Slurp qw( slurp );";
    die $@ if $@;

    $parser = new Text::CSV_XS;

    @buffer = split(/\r?\n/, slurp($filename) );
    $count = scalar(@buffer);

  } elsif ( $type eq 'xls' ) {
    eval "use Spreadsheet::ParseExcel;";
    die $@ if $@;

    my $excel = Spreadsheet::ParseExcel::Workbook->new->Parse($filename);
    $parser = $excel->{Worksheet}[0]; #first sheet

    $count = $parser->{MaxRow} || $parser->{MinRow};
    $count++;

  } else {
    die "Unknown file type $type\n";
  }

  my $imported = 0;
  #my $columns;

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
  my $row = 0;
  my %data = ();
  my( $last, $min_sec ) = ( time, 5 ); #progressbar foo
  while (1) {
    my @columns = ();

    if ( $type eq 'csv' ) {

      last unless scalar(@buffer);
      $line = shift(@buffer);

      $parser->parse($line) or do {
        $dbh->rollback if $oldAutoCommit;
        return "can't parse: ". $parser->error_input();
      };
      @columns = $parser->fields();

    } elsif ( $type eq 'xls' ) {
      last if $row > ($parser->{MaxRow} || $parser->{MinRow})
           || ! $parser->{Cells}[$row];

      my @row = @{ $parser->{Cells}[$row] };
      @columns = map $_->{Val}, @row;

    } else {
      die "Unknown file type $type\n";
    }

    #warn join('-',@columns);

    my %row = ();
    foreach my $field ( @fields ) {
      $row{$field} = shift @columns;
    }

    if ( $row{custnum} && $row{agent_custid} ) {
      dbh->rollback if $oldAutoCommit;
      return "can't specify custnum with agent_custid $row{agent_custid}";
    }

    my $id;
    my %hash = ();

    if ( $row{agent_custid} && $agentnum ) {
      $id = $row{agent_custid};
      $data{$id}{cust} = (
        'agent_custid' => $row{agent_custid},
        'agentnum'     => $agentnum,
      );
      %hash = ( 'agent_custid' => $row{agent_custid},
                'agentnum'     => $agentnum,
              );
    }

    if ( $row{custnum} ) {
      $id = $row{custnum};
      $data{$id}{cust} = {
        'custnum' => $row{custnum},
        'testnum' => 'test',
      };
      %hash = ( 'custnum' => $row{custnum} );
    }

    unless ( scalar(keys %hash) ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't find customer without custnum or agent_custid and agentnum";
    }

    ## add new pkg data or upate existing by adding new amount for custnum
    $data{$id}{pkg}{$row{pkg}} = $data{$id}{pkg}{$row{pkg}} ? $data{$id}{pkg}{$row{pkg}} + $row{'amount'} : $row{'amount'};

    $row++;

    if ( $job && time - $min_sec > $last ) { #progress bar
      $job->update_statustext( int(100 * $row / $count) );
      $last = time;
    }

  }

  ### run through data hash to post all charges.
  foreach my $k (keys %data) {
    my %pkg_hash  = %{$data{$k}{pkg}};
    my %cust_hash = %{$data{$k}{cust}};

    my $cust_main = qsearchs('cust_main', { %cust_hash } );
    unless ( $cust_main ) {
      $dbh->rollback if $oldAutoCommit;
      my $custnum = $cust_hash{custnum} || $cust_hash{agent_custid};
      return "unknown custnum $custnum";
    }

    foreach my $pkg_key (keys %pkg_hash) {
      my $pkg = $pkg_key;
      my $amount = $pkg_hash{$pkg_key};

      if (%charges) { next unless $charges{$pkg}; }

      if ( $amount > 0 ) {
        my $error = $cust_main->charge($amount, $pkg);
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
        $imported++;
      } elsif ( $amount < 0 ) {
        my $error = $cust_main->credit( sprintf( "%.2f", 0-$amount ), $pkg );
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return $error;
        }
        $imported++;
      } else {
      #hmm?
      }
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  unlink $filename;

  return "Empty file!" unless $imported;

  ''; #no error

}

1;