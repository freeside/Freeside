package FS::rate;

use strict;
use vars qw( @ISA $DEBUG );
use FS::Record qw( qsearch qsearchs dbh fields );
use FS::rate_detail;

@ISA = qw(FS::Record);

$DEBUG = 0;

=head1 NAME

FS::rate - Object methods for rate records

=head1 SYNOPSIS

  use FS::rate;

  $record = new FS::rate \%hash;
  $record = new FS::rate { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::rate object represents an rate plan.  FS::rate inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item ratenum - primary key

=item ratename

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new rate plan.  To add the rate plan to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'rate'; }

=item insert [ , OPTION => VALUE ... ]

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

Currently available options are: I<rate_detail>

If I<rate_detail> is set to an array reference of FS::rate_detail objects, the
objects will have their ratenum field set and will be inserted after this
record.

=cut

sub insert {
  my $self = shift;
  my %options = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->check;
  return $error if $error;

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  if ( $options{'rate_detail'} ) {

    my( $num, $last, $min_sec ) = (0, time, 5); #progressbar foo

    foreach my $rate_detail ( @{$options{'rate_detail'}} ) {

      $rate_detail->ratenum($self->ratenum);
      $error = $rate_detail->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }

      if ( $options{'job'} ) {
        $num++;
        if ( time - $min_sec > $last ) {
          my $error = $options{'job'}->update_statustext(
            int( 100 * $num / scalar( @{$options{'rate_detail'}} ) )
          );
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return $error;
          }
          $last = time;
        }
      }

    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}



=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD [ , OPTION => VALUE ... ]

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Currently available options are: I<rate_detail>

If I<rate_detail> is set to an array reference of FS::rate_detail objects, the
objects will have their ratenum field set and will be inserted after this
record.  Any existing rate_detail records associated with this record will be
deleted.

=cut

sub replace {
  my ($new, $old) = (shift, shift);
  my %options = @_;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

#  my @old_rate_detail = ();
#  @old_rate_detail = $old->rate_detail if $options{'rate_detail'};

  my $error = $new->SUPER::replace($old);
  if ($error) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

#  foreach my $old_rate_detail ( @old_rate_detail ) {
#
#    my $error = $old_rate_detail->delete;
#    if ($error) {
#      $dbh->rollback if $oldAutoCommit;
#      return $error;
#    }
#
#    if ( $options{'job'} ) {
#      $num++;
#      if ( time - $min_sec > $last ) {
#        my $error = $options{'job'}->update_statustext(
#          int( 50 * $num / scalar( @old_rate_detail ) )
#        );
#        if ( $error ) {
#          $dbh->rollback if $oldAutoCommit;
#          return $error;
#        }
#        $last = time;
#      }
#    }
#
#  }
  if ( $options{'rate_detail'} ) {
    my $sth = $dbh->prepare('DELETE FROM rate_detail WHERE ratenum = ?') or do {
      $dbh->rollback if $oldAutoCommit;
      return $dbh->errstr;
    };
  
    $sth->execute($old->ratenum) or do {
      $dbh->rollback if $oldAutoCommit;
      return $sth->errstr;
    };

    my( $num, $last, $min_sec ) = (0, time, 5); #progresbar foo
#  $num = 0;
    foreach my $rate_detail ( @{$options{'rate_detail'}} ) {
  
      $rate_detail->ratenum($new->ratenum);
      $error = $rate_detail->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
  
      if ( $options{'job'} ) {
        $num++;
        if ( time - $min_sec > $last ) {
          my $error = $options{'job'}->update_statustext(
            int( 100 * $num / scalar( @{$options{'rate_detail'}} ) )
          );
          if ( $error ) {
            $dbh->rollback if $oldAutoCommit;
            return $error;
          }
          $last = time;
        }
      }
  
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;
  '';

}

=item check

Checks all fields to make sure this is a valid rate plan.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error =
       $self->ut_numbern('ratenum')
    || $self->ut_text('ratename')
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item dest_detail REGIONNUM | RATE_REGION_OBJECTD | HASHREF

Returns the rate detail (see L<FS::rate_detail>) for this rate to the
specificed destination.  Destination can be specified as an FS::rate_detail
object or regionnum (see L<FS::rate_detail>), or as a hashref with two keys:
I<countrycode> and I<phonenum>.

=cut

sub dest_detail {
  my $self = shift;

  my $regionnum;
  if ( ref($_[0]) eq 'HASH' ) {

    my $countrycode = $_->{'countrycode'};
    my $phonenum    = $_->{'phonenum'};

    #find a rate prefix, first look at most specific (4 digits) then 3, etc.,
    # finally trying the country code only
    my $rate_prefix = '';
    for my $len ( reverse(1..6) ) {
      $rate_prefix = qsearchs('rate_prefix', {
        'countrycode' => $countrycode,
        #'npa'         => { op=> 'LIKE', value=> substr($number, 0, $len) }
        'npa'         => substr($phonenum, 0, $len),
      } ) and last;
    }
    $rate_prefix ||= qsearchs('rate_prefix', {
      'countrycode' => $countrycode,
      'npa'         => '',
    });

    #
    #die "Can't find rate for call $to_or_from +$countrycode $number\n"
    die "Can't find rate for +$countrycode $phonenum\n"
      unless $rate_prefix;

    $regionnum = $rate_prefix->regionnum;

    #$rate_region = $rate_prefix->rate_region;

  } else {
    $regionnum = ref($_[0]) ? shift->regionnum : shift;
  }

  qsearchs( 'rate_detail', { 'ratenum'        => $self->ratenum,
                             'dest_regionnum' => $regionnum,     } );
}

=item rate_detail

Returns all region-specific details  (see L<FS::rate_detail>) for this rate.

=cut

sub rate_detail {
  my $self = shift;
  qsearch( 'rate_detail', { 'ratenum' => $self->ratenum } );
}


=back

=head1 SUBROUTINES

=over 4

=item process

Experimental job-queue processor for web interface adds/edits

=cut

use Storable qw(thaw);
use Data::Dumper;
use MIME::Base64;
sub process {
  my $job = shift;

  my $param = thaw(decode_base64(shift));
  warn Dumper($param) if $DEBUG;

  my $old = qsearchs('rate', { 'ratenum' => $param->{'ratenum'} } )
    if $param->{'ratenum'};

  my @rate_detail = map {

    my $regionnum = $_->regionnum;
    if ( $param->{"sec_granularity$regionnum"} ) {

      new FS::rate_detail {
        'dest_regionnum'  => $regionnum,
        map { $_ => $param->{"$_$regionnum"} }
            qw( min_included min_charge sec_granularity )
      };

    } else {

      new FS::rate_detail {
        'dest_regionnum'  => $regionnum,
        'min_included'    => 0,
        'min_charge'      => 0,
        'sec_granularity' => '60'
      };

    }
    
  } qsearch('rate_region', {} );
  
  my $rate = new FS::rate {
    map { $_ => $param->{$_} }
        fields('rate')
  };

  my $error = '';
  if ( $param->{'ratenum'} ) {
    warn "$rate replacing $old (". $param->{'ratenum'}. ")\n" if $DEBUG;
    $error = $rate->replace( $old,
                             'rate_detail' => \@rate_detail,
                             'job'         => $job,
                           );
  } else {
    warn "inserting $rate\n" if $DEBUG;
    $error = $rate->insert( 'rate_detail' => \@rate_detail,
                            'job'         => $job,
                          );
    #$ratenum = $rate->getfield('ratenum');
  }

  die "$error\n" if $error;

}

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

