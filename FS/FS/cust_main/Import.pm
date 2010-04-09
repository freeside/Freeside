package FS::cust_main::Import;

use strict;
use vars qw( $DEBUG $conf );
use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
use File::Slurp qw( slurp );
use FS::Misc::DateTime qw( parse_datetime );
use FS::UID qw( dbh );
use FS::Record qw( qsearchs );
use FS::cust_main;
use FS::svc_acct;
use FS::svc_external;
use FS::svc_phone;
use FS::part_referral;

$DEBUG = 0;

install_callback FS::UID sub {
  $conf = new FS::Conf;
};

=head1 NAME

FS::cust_main::Import - Batch customer importing

=head1 SYNOPSIS

  use FS::cust_main::Import;

  #import
  FS::cust_main::Import::batch_import( {
    file      => $file,      #filename
    type      => $type,      #csv or xls
    format    => $format,    #extended, extended-plus_company, svc_external,
                             # or svc_external_svc_phone
    agentnum  => $agentnum,
    refnum    => $refnum,
    pkgpart   => $pkgpart,
    job       => $job,       #optional job queue job, for progressbar updates
    custbatch => $custbatch, #optional batch unique identifier
  } );
  die $error if $error;

  #ajax helper
  use FS::UI::Web::JSRPC;
  my $server =
    new FS::UI::Web::JSRPC 'FS::cust_main::Import::process_batch_import', $cgi;
  print $server->process;

=head1 DESCRIPTION

Batch customer importing.

=head1 SUBROUTINES

=item process_batch_import

Load a batch import as a queued JSRPC job

=cut

sub process_batch_import {
  my $job = shift;

  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;
  
  my $files = $param->{'uploaded_files'}
    or die "No files provided.\n";

  my (%files) = map { /^(\w+):([\.\w]+)$/ ? ($1,$2):() } split /,/, $files;

  my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc. '/';
  my $file = $dir. $files{'file'};

  my $type;
  if ( $file =~ /\.(\w+)$/i ) {
    $type = lc($1);
  } else {
    #or error out???
    warn "can't parse file type from filename $file; defaulting to CSV";
    $type = 'csv';
  }

  my $error =
    FS::cust_main::Import::batch_import( {
      job       => $job,
      file      => $file,
      type      => $type,
      custbatch => $param->{custbatch},
      agentnum  => $param->{'agentnum'},
      refnum    => $param->{'refnum'},
      pkgpart   => $param->{'pkgpart'},
      #'fields'  => [qw( cust_pkg.setup dayphone first last address1 address2
      #                 city state zip comments                          )],
      'format'  => $param->{'format'},
    } );

  unlink $file;

  die "$error\n" if $error;

}

=item batch_import

=cut


#some false laziness w/cdr.pm now
sub batch_import {
  my $param = shift;

  my $job       = $param->{job};

  my $filename  = $param->{file};
  my $type      = $param->{type} || 'csv';

  my $custbatch = $param->{custbatch};

  my $agentnum  = $param->{agentnum};
  my $refnum    = $param->{refnum};
  my $pkgpart   = $param->{pkgpart};

  my $format    = $param->{'format'};

  my @fields;
  my $payby;
  if ( $format eq 'simple' ) {
    @fields = qw( cust_pkg.setup dayphone first last
                  address1 address2 city state zip comments );
    $payby = 'BILL';
  } elsif ( $format eq 'extended' ) {
    @fields = qw( agent_custid refnum
                  last first address1 address2 city state zip country
                  daytime night
                  ship_last ship_first ship_address1 ship_address2
                  ship_city ship_state ship_zip ship_country
                  payinfo paycvv paydate
                  invoicing_list
                  cust_pkg.pkgpart
                  svc_acct.username svc_acct._password 
                );
    $payby = 'BILL';
 } elsif ( $format eq 'extended-plus_company' ) {
    @fields = qw( agent_custid refnum
                  last first company address1 address2 city state zip country
                  daytime night
                  ship_last ship_first ship_company ship_address1 ship_address2
                  ship_city ship_state ship_zip ship_country
                  payinfo paycvv paydate
                  invoicing_list
                  cust_pkg.pkgpart
                  svc_acct.username svc_acct._password 
                );
    $payby = 'BILL';
 } elsif ( $format =~ /^svc_external/ ) {
    @fields = qw( agent_custid refnum
                  last first company address1 address2 city state zip country
                  daytime night
                  ship_last ship_first ship_company ship_address1 ship_address2
                  ship_city ship_state ship_zip ship_country
                  payinfo paycvv paydate
                  invoicing_list
                  cust_pkg.pkgpart cust_pkg.bill
                  svc_external.id svc_external.title
                );
    push @fields, map "svc_phone.$_", qw( countrycode phonenum sip_password pin)
      if $format eq 'svc_external_svc_phone';
    $payby = 'BILL';
  } else {
    die "unknown format $format";
  }

  my $count;
  my $parser;
  my @buffer = ();
  if ( $type eq 'csv' ) {

    eval "use Text::CSV_XS;";
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

      #my $z = 'A';
      #warn $z++. ": $_\n" for @columns;

    } else {
      die "Unknown file type $type\n";
    }

    #warn join('-',@columns);

    my %cust_main = (
      custbatch => $custbatch,
      agentnum  => $agentnum,
      refnum    => $refnum,
      country   => $conf->config('countrydefault') || 'US',
      payby     => $payby, #default
      paydate   => '12/2037', #default
    );
    my $billtime = time;
    my %cust_pkg = ( pkgpart => $pkgpart );
    my %svc_x = ();
    foreach my $field ( @fields ) {

      if ( $field =~ /^cust_pkg\.(pkgpart|setup|bill|susp|adjourn|expire|cancel)$/ ) {

        #$cust_pkg{$1} = parse_datetime( shift @$columns );
        if ( $1 eq 'pkgpart' ) {
          $cust_pkg{$1} = shift @columns;
        } elsif ( $1 eq 'setup' ) {
          $billtime = parse_datetime(shift @columns);
        } else {
          $cust_pkg{$1} = parse_datetime( shift @columns );
        } 

      } elsif ( $field =~ /^svc_acct\.(username|_password)$/ ) {

        $svc_x{$1} = shift @columns;

      } elsif ( $field =~ /^svc_external\.(id|title)$/ ) {

        $svc_x{$1} = shift @columns;

      } elsif ( $field =~ /^svc_phone\.(countrycode|phonenum|sip_password|pin)$/ ) {
        $svc_x{$1} = shift @columns;
       
      } else {

        #refnum interception
        if ( $field eq 'refnum' && $columns[0] !~ /^\s*(\d+)\s*$/ ) {

          my $referral = $columns[0];
          my %hash = ( 'referral' => $referral,
                       'agentnum' => $agentnum,
                       'disabled' => '',
                     );

          my $part_referral = qsearchs('part_referral', \%hash )
                              || new FS::part_referral \%hash;

          unless ( $part_referral->refnum ) {
            my $error = $part_referral->insert;
            if ( $error ) {
              $dbh->rollback if $oldAutoCommit;
              return "can't auto-insert advertising source: $referral: $error";
            }
          }

          $columns[0] = $part_referral->refnum;
        }

        my $value = shift @columns;
        $cust_main{$field} = $value if length($value);
      }
    }

    $cust_main{'payby'} = 'CARD'
      if defined $cust_main{'payinfo'}
      && length  $cust_main{'payinfo'};

    my $invoicing_list = $cust_main{'invoicing_list'}
                           ? [ delete $cust_main{'invoicing_list'} ]
                           : [];

    my $cust_main = new FS::cust_main ( \%cust_main );

    use Tie::RefHash;
    tie my %hash, 'Tie::RefHash'; #this part is important

    if ( $cust_pkg{'pkgpart'} ) {
      my $cust_pkg = new FS::cust_pkg ( \%cust_pkg );

      my @svc_x = ();
      my $svcdb = '';
      if ( $svc_x{'username'} ) {
        $svcdb = 'svc_acct';
      } elsif ( $svc_x{'id'} || $svc_x{'title'} ) {
        $svcdb = 'svc_external';
      }

      my $svc_phone = '';
      if ( $svc_x{'countrycode'} || $svc_x{'phonenum'} ) {
        $svc_phone = FS::svc_phone->new( {
          map { $_ => delete($svc_x{$_}) }
              qw( countrycode phonenum sip_password pin)
        } );
      }

      if ( $svcdb || $svc_phone ) {
        my $part_pkg = $cust_pkg->part_pkg;
	unless ( $part_pkg ) {
	  $dbh->rollback if $oldAutoCommit;
	  return "unknown pkgpart: ". $cust_pkg{'pkgpart'};
	} 
        if ( $svcdb ) {
          $svc_x{svcpart} = $part_pkg->svcpart_unique_svcdb( $svcdb );
          my $class = "FS::$svcdb";
          push @svc_x, $class->new( \%svc_x );
        }
        if ( $svc_phone ) {
          $svc_phone->svcpart( $part_pkg->svcpart_unique_svcdb('svc_phone') );
          push @svc_x, $svc_phone;
        }
      }

      $hash{$cust_pkg} = \@svc_x;
    }

    my $error = $cust_main->insert( \%hash, $invoicing_list );

    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "can't insert customer". ( $line ? " for $line" : '' ). ": $error";
    }

    if ( $format eq 'simple' ) {

      #false laziness w/bill.cgi
      $error = $cust_main->bill( 'time' => $billtime );
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't bill customer for $line: $error";
      }
  
      $error = $cust_main->apply_payments_and_credits;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't bill customer for $line: $error";
      }

      $error = $cust_main->collect();
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't collect customer for $line: $error";
      }

    }

    $row++;

    if ( $job && time - $min_sec > $last ) { #progress bar
      $job->update_statustext( int(100 * $row / $count) );
      $last = time;
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;;

  return "Empty file!" unless $row;

  ''; #no error

}

=head1 BUGS

Not enough documentation.

=head1 SEE ALSO

L<FS::cust_main>, L<FS::cust_pkg>,
L<FS::svc_acct>, L<FS::svc_external>, L<FS::svc_phone>

=cut

1;
