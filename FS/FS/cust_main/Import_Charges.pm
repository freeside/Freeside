package FS::cust_main::Import_Charges;
#actually no specific reason it lives under FS::cust_main:: othan than it calls
# a thing on cust_main objects.  not part of the inheritence, just providess a
# subroutine for misc/process/cust_main-import_charges.cgi

use strict;
use Text::CSV_XS;
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
  my $param = shift;
  #warn join('-',keys %$param);
  my $fh = $param->{filehandle};
  my $agentnum = $param->{agentnum};
  my $format = $param->{format};

  my $extra_sql = ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql;

  my @fields;
  if ( $format eq 'simple' ) {
    @fields = qw( custnum agent_custid amount pkg );
  } else {
    die "unknown format $format";
  }

  my $csv = new Text::CSV_XS;
  #warn $csv;
  #warn $fh;

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
  
  #while ( $columns = $csv->getline($fh) ) {
  my $line;
  while ( defined($line=<$fh>) ) {

    $csv->parse($line) or do {
      $dbh->rollback if $oldAutoCommit;
      return "can't parse: ". $csv->error_input();
    };

    my @columns = $csv->fields();
    #warn join('-',@columns);

    my %row = ();
    foreach my $field ( @fields ) {
      $row{$field} = shift @columns;
    }

    if ( $row{custnum} && $row{agent_custid} ) {
      dbh->rollback if $oldAutoCommit;
      return "can't specify custnum with agent_custid $row{agent_custid}";
    }

    my %hash = ();
    if ( $row{agent_custid} && $agentnum ) {
      %hash = ( 'agent_custid' => $row{agent_custid},
                'agentnum'     => $agentnum,
              );
    }

    if ( $row{custnum} ) {
      %hash = ( 'custnum' => $row{custnum} );
    }

    unless ( scalar(keys %hash) ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't find customer without custnum or agent_custid and agentnum";
    }

    my $cust_main = qsearchs('cust_main', { %hash } );
    unless ( $cust_main ) {
      $dbh->rollback if $oldAutoCommit;
      my $custnum = $row{custnum} || $row{agent_custid};
      return "unknown custnum $custnum";
    }

    if ( $row{'amount'} > 0 ) {
      my $error = $cust_main->charge($row{'amount'}, $row{'pkg'});
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      $imported++;
    } elsif ( $row{'amount'} < 0 ) {
      my $error = $cust_main->credit( sprintf( "%.2f", 0-$row{'amount'} ),
                                      $row{'pkg'}                         );
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
      $imported++;
    } else {
      #hmm?
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  return "Empty file!" unless $imported;

  ''; #no error

}

1;
