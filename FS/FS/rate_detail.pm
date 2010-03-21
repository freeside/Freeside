package FS::rate_detail;

use strict;
use vars qw( @ISA $DEBUG $me );
use FS::Record qw( qsearch qsearchs dbh );
use FS::rate;
use FS::rate_region;
use Tie::IxHash;

@ISA = qw(FS::Record);

$DEBUG = 0;
$me = '[FS::rate_detail]';

=head1 NAME

FS::rate_detail - Object methods for rate_detail records

=head1 SYNOPSIS

  use FS::rate_detail;

  $record = new FS::rate_detail \%hash;
  $record = new FS::rate_detail { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rate_detail object represents an call plan rate.  FS::rate_detail
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item ratedetailnum - primary key

=item ratenum - rate plan (see L<FS::rate>)

=item orig_regionnum - call origination region

=item dest_regionnum - call destination region

=item min_included - included minutes

=item min_charge - charge per minute

=item sec_granularity - granularity in seconds, i.e. 6 or 60; 0 for per-call

=item classnum - usage class (see L<FS::usage_class>) if any for this rate

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new call plan rate.  To add the call plan rate to the database, see
L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rate_detail'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid call plan rate.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
       $self->ut_numbern('ratedetailnum')
    || $self->ut_foreign_key('ratenum', 'rate', 'ratenum')
    || $self->ut_foreign_keyn('orig_regionnum', 'rate_region', 'regionnum' )
    || $self->ut_foreign_key('dest_regionnum', 'rate_region', 'regionnum' )
    || $self->ut_number('min_included')

    #|| $self->ut_money('min_charge')
    #good enough for now...
    || $self->ut_float('min_charge')

    || $self->ut_number('sec_granularity')

    || $self->ut_foreign_keyn('classnum', 'usage_class', 'classnum' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item rate 

Returns the parent call plan (see L<FS::rate>) associated with this call plan
rate.

=cut

sub rate {
  my $self = shift;
  qsearchs('rate', { 'ratenum' => $self->ratenum } );
}

=item orig_region 

Returns the origination region (see L<FS::rate_region>) associated with this
call plan rate.

=cut

sub orig_region {
  my $self = shift;
  qsearchs('rate_region', { 'regionnum' => $self->orig_regionnum } );
}

=item dest_region 

Returns the destination region (see L<FS::rate_region>) associated with this
call plan rate.

=cut

sub dest_region {
  my $self = shift;
  qsearchs('rate_region', { 'regionnum' => $self->dest_regionnum } );
}

=item dest_regionname

Returns the name of the destination region (see L<FS::rate_region>) associated
with this call plan rate.

=cut

sub dest_regionname {
  my $self = shift;
  $self->dest_region->regionname;
}

=item dest_regionname

Returns a short list of the prefixes for the destination region
(see L<FS::rate_region>) associated with this call plan rate.

=cut

sub dest_prefixes_short {
  my $self = shift;
  $self->dest_region->prefixes_short;
}

=item classname

Returns the name of the usage class (see L<FS::usage_class>) associated with
this call plan rate.

=cut

sub classname {
  my $self = shift;
  my $usage_class = qsearchs('usage_class', { classnum => $self->classnum });
  $usage_class ? $usage_class->classname : '';
}


=back

=head1 SUBROUTINES

=over 4

=item granularities

  Returns an (ordered) hash of granularity => name pairs

=cut

tie my %granularities, 'Tie::IxHash',
  '1', => '1 second',
  '6'  => '6 second',
  '30' => '30 second', # '1/2 minute',
  '60' => 'minute',
  '0'  => 'call',
;

sub granularities {
  %granularities;
}

=item conn_secs

  Returns an (ordered) hash of conn_sec => name pairs

=cut

tie my %conn_secs, 'Tie::IxHash',
    '0' => 'connection',
    '1' => 'first second',
    '6' => 'first 6 seconds',
   '30' => 'first 30 seconds', # '1/2 minute',
   '60' => 'first minute',
  '120' => 'first 2 minutes',
  '180' => 'first 3 minutes',
  '300' => 'first 5 minutes',
;

sub conn_secs {
  %conn_secs;
}

=item process_edit_import

=cut

use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
sub process_edit_import {
  my $job = shift;

  #do we actually belong in rate_detail, like 'table' says?  even though we
  # can possible create new rate records, that's a side effect, mostly we
  # do edit rate_detail records in batch...

  my $opt = { 'table'          => 'rate_detail',
              'params'         => [], #required, apparantly
              'formats'        => { 'default' => [
                'dest_regionnum',
                '', #regionname
                '', #country
                '', #prefixes
                #loop these
                'min_included',
                'min_charge',
                sub {
                  my( $rate_detail, $g ) = @_;
                  $g  = 0  if $g =~ /^\s*(per-)?call\s*$/i;
                  $g  = 60 if $g =~ /^\s*minute\s*$/i;
                  $g  =~ /^(\d+)/ or die "can't parse granularity: $g".
                                         " for record ". Dumper($rate_detail);
                  $rate_detail->sec_granularity($1);
                },
                'classnum',
              ] },
              'format_headers' => { 'default' => 1, },
              'format_types'   => { 'default' => 'xls' },
            };

  #false laziness w/
  #FS::Record::process_batch_import( $job, $opt, @_ );
  
  my $table = $opt->{table};
  my @pass_params = @{ $opt->{params} };
  my %formats = %{ $opt->{formats} };

  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;
  
  my $files = $param->{'uploaded_files'}
    or die "No files provided.\n";

  my (%files) = map { /^(\w+):([\.\w]+)$/ ? ($1,$2):() } split /,/, $files;

  my $dir = '%%%FREESIDE_CACHE%%%/cache.'. $FS::UID::datasrc. '/';
  my $file = $dir. $files{'file'};

  my $error =
    #false laziness w/
    #FS::Record::batch_import( {
    FS::rate_detail::edit_import( {
      #class-static
      table                      => $table,
      formats                    => \%formats,
      format_types               => $opt->{format_types},
      format_headers             => $opt->{format_headers},
      format_sep_chars           => $opt->{format_sep_chars},
      format_fixedlength_formats => $opt->{format_fixedlength_formats},
      #per-import
      job                        => $job,
      file                       => $file,
      #type                       => $type,
      format                     => $param->{format},
      params                     => { map { $_ => $param->{$_} } @pass_params },
      #?
      default_csv                => $opt->{default_csv},
    } );

  unlink $file;

  die "$error\n" if $error;

}

=item edit_import

=cut

#false laziness w/ #FS::Record::batch_import, grep "edit_import" for differences
#could be turned into callbacks or something
use Text::CSV_XS;
sub edit_import {
  my $param = shift;

  warn "$me edit_import call with params: \n". Dumper($param)
    if $DEBUG;

  my $table   = $param->{table};
  my $formats = $param->{formats};

  my $job     = $param->{job};
  my $file    = $param->{file};
  my $format  = $param->{'format'};
  my $params  = $param->{params} || {};

  die "unknown format $format" unless exists $formats->{ $format };

  my $type = $param->{'format_types'}
             ? $param->{'format_types'}{ $format }
             : $param->{type} || 'csv';

  unless ( $type ) {
    if ( $file =~ /\.(\w+)$/i ) {
      $type = lc($1);
    } else {
      #or error out???
      warn "can't parse file type from filename $file; defaulting to CSV";
      $type = 'csv';
    }
    $type = 'csv'
      if $param->{'default_csv'} && $type ne 'xls';
  }

  my $header = $param->{'format_headers'}
                 ? $param->{'format_headers'}{ $param->{'format'} }
                 : 0;

  my $sep_char = $param->{'format_sep_chars'}
                   ? $param->{'format_sep_chars'}{ $param->{'format'} }
                   : ',';

  my $fixedlength_format =
    $param->{'format_fixedlength_formats'}
      ? $param->{'format_fixedlength_formats'}{ $param->{'format'} }
      : '';

  my @fields = @{ $formats->{ $format } };

  my $row = 0;
  my $count;
  my $parser;
  my @buffer = ();
  my @header = (); #edit_import
  if ( $type eq 'csv' || $type eq 'fixedlength' ) {

    if ( $type eq 'csv' ) {

      my %attr = ();
      $attr{sep_char} = $sep_char if $sep_char;
      $parser = new Text::CSV_XS \%attr;

    } elsif ( $type eq 'fixedlength' ) {

      eval "use Parse::FixedLength;";
      die $@ if $@;
      $parser = new Parse::FixedLength $fixedlength_format;
 
    } else {
      die "Unknown file type $type\n";
    }

    @buffer = split(/\r?\n/, slurp($file) );
    splice(@buffer, 0, ($header || 0) );
    $count = scalar(@buffer);

  } elsif ( $type eq 'xls' ) {

    eval "use Spreadsheet::ParseExcel;";
    die $@ if $@;

    eval "use DateTime::Format::Excel;";
    #for now, just let the error be thrown if it is used, since only CDR
    # formats bill_west and troop use it, not other excel-parsing things
    #die $@ if $@;

    my $excel = Spreadsheet::ParseExcel::Workbook->new->Parse($file);

    $parser = $excel->{Worksheet}[0]; #first sheet

    $count = $parser->{MaxRow} || $parser->{MinRow};
    $count++;

    $row = $header || 0;

    #edit_import - need some magic to parse the header
    if ( $header ) {
      my @header_row = @{ $parser->{Cells}[$0] };
      @header = map $_->{Val}, @header_row;
    }

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

  #edit_import - use the header to setup looping over different rates
  my @rate = ();
  if ( @header ) {
    splice(@header,0,4); # # Region Country Prefixes
    while ( my @next = splice(@header,0,4) ) {
      my $rate;
      if ( $next[0] =~ /^(\d+):\s*([^:]+):/ ) {
        $rate = qsearchs('rate', { 'ratenum' => $1 } )
          or die "unknown ratenum $1";
      } elsif ( $next[0] =~ /^(NEW:)?\s*([^:]+)/i ) {
        $rate = new FS::rate { 'ratename' => $2 };
        my $error = $rate->insert;
        if ( $error ) {
          $dbh->rollback if $oldAutoCommit;
          return "error inserting new rate: $error\n";
        }
      }
      push @rate, $rate;
    }
  }
  die unless @rate;
  
  my $line;
  my $imported = 0;
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

    } elsif ( $type eq 'fixedlength' ) {

      @columns = $parser->parse($line);

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

    #edit_import loop

    my @repeat = @columns[0..3];

    foreach my $rate ( @rate ) {

      my @later = ();
      my %hash = %$params;

      foreach my $field ( @fields ) {

        my $value = shift @columns;
       
        if ( ref($field) eq 'CODE' ) {
          #&{$field}(\%hash, $value);
          push @later, $field, $value;
        #} else {
        } elsif ($field) { #edit_import
          #??? $hash{$field} = $value if length($value);
          $hash{$field} = $value if defined($value) && length($value);
        }

      }

      unshift @columns, @repeat; #edit_import put these back on for next time

      my $class = "FS::$table";

      my $record = $class->new( \%hash );

      $record->ratenum($rate->ratenum); #edit_import

      #edit_improt n/a my $param = {};
      while ( scalar(@later) ) {
        my $sub = shift @later;
        my $data = shift @later;
        #&{$sub}($record, $data, $conf, $param);# $record->&{$sub}($data, $conf);
        &{$sub}($record, $data); #edit_import - don't have $conf
        #edit_import wrong loop last if exists( $param->{skiprow} );
      }
      #edit_import wrong loop next if exists( $param->{skiprow} );

      #edit_import update or insert, not just insert
      my $old = qsearchs({
        'table'   => $table,
        'hashref' => { map { $_ => $record->$_() } qw(ratenum dest_regionnum) },
      });

      my $error;
      if ( $old ) {
        $record->ratedetailnum($old->ratedetailnum);
        $error = $record->replace($old)
      } else {
        $record->insert;
      }

      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "can't insert record". ( $line ? " for $line" : '' ). ": $error";
      }

    }

    $row++;
    $imported++;

    if ( $job && time - $min_sec > $last ) { #progress bar
      $job->update_statustext( int(100 * $imported / $count) );
      $last = time;
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;;

  return "Empty file!" unless $imported || $param->{empty_ok};

  ''; #no error

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::rate>, L<FS::rate_region>, L<FS::Record>,
schema.html from the base documentation.

=cut

1;

