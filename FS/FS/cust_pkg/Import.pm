package FS::cust_pkg::Import;

use strict;
use vars qw( $DEBUG ); #$conf );
use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
use FS::Misc::DateTime qw( parse_datetime );
use FS::Record qw( qsearchs );
use FS::cust_pkg;
use FS::cust_main;
use FS::svc_acct;
use FS::svc_external;
use FS::svc_phone;

$DEBUG = 0;

#install_callback FS::UID sub {
#  $conf = new FS::Conf;
#};

=head1 NAME

FS::cust_pkg::Import - Batch customer importing

=head1 SYNOPSIS

  use FS::cust_pkg::Import;

  #import
  FS::cust_pkg::Import::batch_import( {
    file      => $file,      #filename
    type      => $type,      #csv or xls
    format    => $format,    #extended, extended-plus_company, svc_external,
                             # or svc_external_svc_phone
    agentnum  => $agentnum,
    job       => $job,       #optional job queue job, for progressbar updates
    pkgbatch  => $pkgbatch, #optional batch unique identifier
  } );
  die $error if $error;

  #ajax helper
  use FS::UI::Web::JSRPC;
  my $server =
    new FS::UI::Web::JSRPC 'FS::cust_pkg::Import::process_batch_import', $cgi;
  print $server->process;

=head1 DESCRIPTION

Batch package importing.

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
    FS::cust_pkg::Import::batch_import( {
      job      => $job,
      file     => $file,
      type     => $type,
      'params' => { pkgbatch => $param->{pkgbatch} },
      agentnum => $param->{'agentnum'},
      'format' => $param->{'format'},
    } );

  unlink $file;

  die "$error\n" if $error;

}

=item batch_import

=cut

my %formatfields = (
  'default'      => [],
  'svc_acct'     => [qw( username _password )],
  'svc_phone'    => [qw( countrycode phonenum sip_password pin )],
  'svc_external' => [qw( id title )],
);

sub _formatfields {
  \%formatfields;
}

my %import_options = (
  'table'         => 'cust_pkg',

  'postinsert_callback' => sub {
    my( $record, $param ) = @_;

    my $formatfields = _formatfields;
    foreach my $svc_x ( grep { $_ ne 'default' } keys %$formatfields ) {

      my $ff = $formatfields->{$svc_x};

      if ( grep $param->{"$svc_x.$_"}, @$ff ) {
        my $svc_x = "FS::$svc_x"->new( {
          'pkgnum'  => $record->pkgnum,
          'svcpart' => $record->part_pkg->svcpart($svc_x),
          map { $_ => $param->{"$svc_x.$_"} } @$ff
        } );
        my $error = $svc_x->insert;
        return $error if $error;
      }

    }

    return ''; #no error

  },
);

sub _import_options {
  \%import_options;
}

sub batch_import {
  my $opt = shift;

  my $iopt = _import_options;
  $opt->{$_} = $iopt->{$_} foreach keys %$iopt;

  my $agentnum  = delete $opt->{agentnum}; # i like closures (delete though?)

  my $format = delete $opt->{'format'};
  my @fields = ();

  if ( $format =~ /^(.*)-agent_custid$/ ) {
    $format = $1;
    @fields = (
      sub {
        my( $self, $value ) = @_; # $conf, $param
        my $cust_main = qsearchs('cust_main', {
          'agentnum'     => $agentnum,
          'agent_custid' => $value,
        });
        $self->custnum($cust_main->custnum) if $cust_main;
      },
    );
  } else {
    @fields = ( 'custnum' );
  }

  push @fields, ( 'pkgpart', 'discountnum' );

  foreach my $field ( 
    qw( start_date setup bill last_bill susp adjourn cancel expire )
  ) {
    push @fields, sub {
      my( $self, $value ) = @_; # $conf, $param
      #->$field has undesirable effects
      $self->set($field, parse_datetime($value) ); #$field closure
    };
  }

  my $formatfields = _formatfields();

  die "unknown format $format" unless $formatfields->{$format};

  foreach my $field ( @{ $formatfields->{$format} } ) {

    push @fields, sub {
      my( $self, $value, $conf, $param ) = @_;
      $param->{"$format.$field"} = $value;
    };

  }

  $opt->{'fields'} = \@fields;

  FS::Record::batch_import( $opt );

}

=for comment

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
