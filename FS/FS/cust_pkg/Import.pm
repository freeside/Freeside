package FS::cust_pkg::Import;

use strict;
use vars qw( $DEBUG ); #$conf );
use Data::Dumper;
use FS::Misc::DateTime qw( parse_datetime );
use FS::Record qw( qsearchs );
use FS::cust_pkg;
use FS::cust_main;
use FS::svc_acct;
use FS::svc_external;
use FS::svc_phone;
use FS::svc_domain;

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
  my $param = shift;
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
  'all_dates'    => [],
  'svc_acct'     => [qw( username _password domsvc )],
  'svc_phone'    => [qw( countrycode phonenum sip_password pin )],
  'svc_external' => [qw( id title )],
  'location'     => [qw( address1 address2 city state zip country )],
);

sub _formatfields {
  \%formatfields;
}

my %import_options = (
  'table'         => 'cust_pkg',

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

  'postinsert_callback' => sub {
    my( $record, $param ) = @_;

    my $formatfields = _formatfields;
    foreach my $svc_x ( grep /^svc/, keys %$formatfields ) {

      my $ff = $formatfields->{$svc_x};

      if ( grep $param->{"$svc_x.$_"}, @$ff ) {
        my $svc = "FS::$svc_x"->new( {
          'pkgnum'  => $record->pkgnum,
          'svcpart' => $record->part_pkg->svcpart($svc_x),
          map { $_ => $param->{"$svc_x.$_"} } @$ff
        } );

        #this whole thing should be turned into a callback or config to turn on
        if ( $svc_x eq 'svc_acct' && $svc->username =~ /\@/ ) {
          my($username, $domain) = split(/\@/, $svc->username);
          my $svc_domain = qsearchs('svc_domain', { 'domain' => $domain } )
                         || new FS::svc_domain { 'svcpart' => 1,
                                                 'domain'  => $domain, };
          unless ( $svc_domain->svcnum ) {
            my $error = $svc_domain->insert;
            return "error auto-inserting domain: $error" if $error;
          }
          $svc->username($username);
          $svc->domsvc($svc_domain->svcnum);
        }

        my $error = $svc->insert;
        return "error inserting service: $error" if $error;
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

  if ( $format =~ /^(.*)-agent_custid(-agent_pkgid)?$/ ) {
    $format = $1;
    my $agent_pkgid = $2;
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
    push @fields, 'agent_pkgid' if $agent_pkgid;
  } else {
    @fields = ( 'custnum' );
  }

  push @fields, ( 'pkgpart', 'discountnum' );

  my @date_fields = ();
  if ( $format =~ /all_dates/ ) {
    @date_fields = qw(
      order_date
      start_date setup bill last_bill susp adjourn
      resume
      cancel expire
      contract_end dundate
    );
  } else {
    @date_fields = qw(
      start_date setup bill last_bill susp adjourn
      cancel expire
    );
  }

  foreach my $field (@date_fields) { 
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

=head1 BUGS

Not enough documentation.

=head1 SEE ALSO

L<FS::cust_main>, L<FS::cust_pkg>,
L<FS::svc_acct>, L<FS::svc_external>, L<FS::svc_phone>

=cut

1;
