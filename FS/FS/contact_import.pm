package FS::contact_import;

use strict;
use vars qw( $DEBUG ); #$conf );
use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
use FS::Misc::DateTime qw( parse_datetime );
use FS::Record qw( qsearchs );
use FS::contact;
use FS::cust_main;

$DEBUG = 0;

=head1 NAME

FS::contact_import - Batch contact importing

=head1 SYNOPSIS

  use FS::contact_import;

  #import
  FS::contact_import::batch_import( {
    file      => $file,      #filename
    type      => $type,      #csv or xls
    format    => $format,    #default
    agentnum  => $agentnum,
    job       => $job,       #optional job queue job, for progressbar updates
    pkgbatch  => $pkgbatch,  #optional batch unique identifier
  } );
  die $error if $error;

  #ajax helper
  use FS::UI::Web::JSRPC;
  my $server =
    new FS::UI::Web::JSRPC 'FS::contact_import::process_batch_import', $cgi;
  print $server->process;

=head1 DESCRIPTION

Batch contact importing.

=head1 SUBROUTINES

=item process_batch_import

Load a batch import as a queued JSRPC job

=cut

sub process_batch_import {
  my $job = shift;
  #my $param = shift;
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
    FS::contact_import::batch_import( {
      job      => $job,
      file     => $file,
      type     => $type,
      agentnum => $param->{'agentnum'},
      'format' => $param->{'format'},
    } );

  unlink $file;

  die "$error\n" if $error;

}

=item batch_import

=cut

my %formatfields = (
  'default'      => [ qw( custnum last first title comment selfservice_access emailaddress phonetypenum1 phonetypenum3 phonetypenum2 ) ],
);

sub _formatfields {
  \%formatfields;
}

## not tested but maybe allow 2nd format to attach location in the future
my %import_options = (
  'table'         => 'contact',

  'preinsert_callback'  => sub {
    my($record, $param) = @_;
    my @location_params = grep /^location\./, keys %$param;
    if (@location_params) {
      my $cust_location = FS::cust_location->new({
          'custnum' => $record->custnum,
      });
      foreach my $p (@location_params) {
        $p =~ /^location.(\w+)$/;
        $cust_location->set($1, $param->{$p});
      }

      my $error = $cust_location->find_or_insert; # this avoids duplicates
      return "error creating location: $error" if $error;
      $record->set('locationnum', $cust_location->locationnum);
    }
    '';
  },

);

sub _import_options {
  \%import_options;
}

sub batch_import {
  my $opt = shift;

  my $iopt = _import_options;
  $opt->{$_} = $iopt->{$_} foreach keys %$iopt;

  my $format = delete $opt->{'format'};

  my $formatfields = _formatfields();
    die "unknown format $format" unless $formatfields->{$format};

  my @fields;
  foreach my $field ( @{ $formatfields->{$format} } ) {
    push @fields, $field;
  }

  $opt->{'fields'} = \@fields;

  FS::Record::batch_import( $opt );

}

=head1 BUGS

Not enough documentation.

=head1 SEE ALSO

L<FS::contact>

=cut

1;