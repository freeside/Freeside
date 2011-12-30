package FS::cdr;

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG $me );
use Exporter;
use Tie::IxHash;
use Date::Parse;
use Date::Format;
use Time::Local;
use FS::UID qw( dbh );
use FS::Conf;
use FS::Record qw( qsearch qsearchs );
use FS::cdr_type;
use FS::cdr_calltype;
use FS::cdr_carrier;
use FS::cdr_batch;
use FS::cdr_termination;
use FS::rate;
use FS::rate_prefix;
use FS::rate_detail;

@ISA = qw(FS::Record);
@EXPORT_OK = qw( _cdr_date_parser_maker _cdr_min_parser_maker );

$DEBUG = 0;
$me = '[FS::cdr]';

=head1 NAME

FS::cdr - Object methods for cdr records

=head1 SYNOPSIS

  use FS::cdr;

  $record = new FS::cdr \%hash;
  $record = new FS::cdr { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cdr object represents an Call Data Record, typically from a telephony
system or provider of some sort.  FS::cdr inherits from FS::Record.  The
following fields are currently supported:

=over 4

=item acctid - primary key

=item calldate - Call timestamp (SQL timestamp)

=item clid - Caller*ID with text

=item src - Caller*ID number / Source number

=item dst - Destination extension

=item dcontext - Destination context

=item channel - Channel used

=item dstchannel - Destination channel if appropriate

=item lastapp - Last application if appropriate

=item lastdata - Last application data

=item startdate - Start of call (UNIX-style integer timestamp)

=item answerdate - Answer time of call (UNIX-style integer timestamp)

=item enddate - End time of call (UNIX-style integer timestamp)

=item duration - Total time in system, in seconds

=item billsec - Total time call is up, in seconds

=item disposition - What happened to the call: ANSWERED, NO ANSWER, BUSY 

=item amaflags - What flags to use: BILL, IGNORE etc, specified on a per channel basis like accountcode. 

=cut

  #ignore the "omit" and "documentation" AMAs??
  #AMA = Automated Message Accounting. 
  #default: Sets the system default. 
  #omit: Do not record calls. 
  #billing: Mark the entry for billing 
  #documentation: Mark the entry for documentation.

=item accountcode - CDR account number to use: account

=item uniqueid - Unique channel identifier (Unitel/RSLCOM Event ID)

=item userfield - CDR user-defined field

=item cdr_type - CDR type - see L<FS::cdr_type> (Usage = 1, S&E = 7, OC&C = 8)

=item charged_party - Service number to be billed

=item upstream_currency - Wholesale currency from upstream

=item upstream_price - Wholesale price from upstream

=item upstream_rateplanid - Upstream rate plan ID

=item rated_price - Rated (or re-rated) price

=item distance - km (need units field?)

=item islocal - Local - 1, Non Local = 0

=item calltypenum - Type of call - see L<FS::cdr_calltype>

=item description - Description (cdr_type 7&8 only) (used for cust_bill_pkg.itemdesc)

=item quantity - Number of items (cdr_type 7&8 only)

=item carrierid - Upstream Carrier ID (see L<FS::cdr_carrier>) 

=cut

#Telstra =1, Optus = 2, RSL COM = 3

=item upstream_rateid - Upstream Rate ID

=item svcnum - Link to customer service (see L<FS::cust_svc>)

=item freesidestatus - NULL, processing-tiered, rated, done

=item freesiderewritestatus - NULL, done, skipped

=item cdrbatch

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new CDR.  To add the CDR to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'cdr'; }

sub table_info {
  {
    'fields' => {
#XXX fill in some (more) nice names
        #'acctid'                => '',
        'calldate'              => 'Call date',
        'clid'                  => 'Caller ID',
        'src'                   => 'Source',
        'dst'                   => 'Destination',
        'dcontext'              => 'Dest. context',
        'channel'               => 'Channel',
        'dstchannel'            => 'Destination channel',
        #'lastapp'               => '',
        #'lastdata'              => '',
        'startdate'             => 'Start date',
        'answerdate'            => 'Answer date',
        'enddate'               => 'End date',
        'duration'              => 'Duration',
        'billsec'               => 'Billable seconds',
        'disposition'           => 'Disposition',
        'amaflags'              => 'AMA flags',
        'accountcode'           => 'Account code',
        #'uniqueid'              => '',
        'userfield'             => 'User field',
        #'cdrtypenum'            => '',
        'charged_party'         => 'Charged party',
        #'upstream_currency'     => '',
        'upstream_price'        => 'Upstream price',
        #'upstream_rateplanid'   => '',
        #'ratedetailnum'         => '',
        'rated_price'           => 'Rated price',
        #'distance'              => '',
        #'islocal'               => '',
        #'calltypenum'           => '',
        #'description'           => '',
        #'quantity'              => '',
        'carrierid'             => 'Carrier ID',
        #'upstream_rateid'       => '',
        'svcnum'                => 'Freeside service',
        'freesidestatus'        => 'Freeside status',
        'freesiderewritestatus' => 'Freeside rewrite status',
        'cdrbatch'              => 'Legacy batch',
        'cdrbatchnum'           => 'Batch',
    },

  };

}

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

Checks all fields to make sure this is a valid CDR.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

Note: Unlike most types of records, we don't want to "reject" a CDR and we want
to process them as quickly as possible, so we allow the database to check most
of the data.

=cut

sub check {
  my $self = shift;

# we don't want to "reject" a CDR like other sorts of input...
#  my $error = 
#    $self->ut_numbern('acctid')
##    || $self->ut_('calldate')
#    || $self->ut_text('clid')
#    || $self->ut_text('src')
#    || $self->ut_text('dst')
#    || $self->ut_text('dcontext')
#    || $self->ut_text('channel')
#    || $self->ut_text('dstchannel')
#    || $self->ut_text('lastapp')
#    || $self->ut_text('lastdata')
#    || $self->ut_numbern('startdate')
#    || $self->ut_numbern('answerdate')
#    || $self->ut_numbern('enddate')
#    || $self->ut_number('duration')
#    || $self->ut_number('billsec')
#    || $self->ut_text('disposition')
#    || $self->ut_number('amaflags')
#    || $self->ut_text('accountcode')
#    || $self->ut_text('uniqueid')
#    || $self->ut_text('userfield')
#    || $self->ut_numbern('cdrtypenum')
#    || $self->ut_textn('charged_party')
##    || $self->ut_n('upstream_currency')
##    || $self->ut_n('upstream_price')
#    || $self->ut_numbern('upstream_rateplanid')
##    || $self->ut_n('distance')
#    || $self->ut_numbern('islocal')
#    || $self->ut_numbern('calltypenum')
#    || $self->ut_textn('description')
#    || $self->ut_numbern('quantity')
#    || $self->ut_numbern('carrierid')
#    || $self->ut_numbern('upstream_rateid')
#    || $self->ut_numbern('svcnum')
#    || $self->ut_textn('freesidestatus')
#    || $self->ut_textn('freesiderewritestatus')
#  ;
#  return $error if $error;

  for my $f ( grep { $self->$_ =~ /\D/ } qw(startdate answerdate enddate)){
    $self->$f( str2time($self->$f) );
  }

  $self->calldate( $self->startdate_sql )
    if !$self->calldate && $self->startdate;

  #was just for $format eq 'taqua' but can't see the harm... add something to
  #disable if it becomes a problem
  if ( $self->duration eq '' && $self->enddate && $self->startdate ) {
    $self->duration( $self->enddate - $self->startdate  );
  }
  if ( $self->billsec eq '' && $self->enddate && $self->answerdate ) {
    $self->billsec(  $self->enddate - $self->answerdate );
  } 

  $self->set_charged_party;

  #check the foreign keys even?
  #do we want to outright *reject* the CDR?
  my $error =
       $self->ut_numbern('acctid')

  #add a config option to turn these back on if someone needs 'em
  #
  #  #Usage = 1, S&E = 7, OC&C = 8
  #  || $self->ut_foreign_keyn('cdrtypenum',  'cdr_type',     'cdrtypenum' )
  #
  #  #the big list in appendix 2
  #  || $self->ut_foreign_keyn('calltypenum', 'cdr_calltype', 'calltypenum' )
  #
  #  # Telstra =1, Optus = 2, RSL COM = 3
  #  || $self->ut_foreign_keyn('carrierid', 'cdr_carrier', 'carrierid' )
  ;
  return $error if $error;

  $self->SUPER::check;
}

=item is_tollfree [ COLUMN ]

Returns true when the cdr represents a toll free number and false otherwise.

By default, inspects the dst field, but an optional column name can be passed
to inspect other field.

=cut

sub is_tollfree {
  my $self = shift;
  my $field = scalar(@_) ? shift : 'dst';
  ( $self->$field() =~ /^(\+?1)?8(8|([02-7])\3)/ ) ? 1 : 0;
}

=item set_charged_party

If the charged_party field is already set, does nothing.  Otherwise:

If the cdr-charged_party-accountcode config option is enabled, sets the
charged_party to the accountcode.

Otherwise sets the charged_party normally: to the src field in most cases,
or to the dst field if it is a toll free number.

=cut

sub set_charged_party {
  my $self = shift;

  my $conf = new FS::Conf;

  unless ( $self->charged_party ) {

    if ( $conf->exists('cdr-charged_party-accountcode') && $self->accountcode ){

      my $charged_party = $self->accountcode;
      $charged_party =~ s/^0+//
        if $conf->exists('cdr-charged_party-accountcode-trim_leading_0s');
      $self->charged_party( $charged_party );

    } elsif ( $conf->exists('cdr-charged_party-field') ) {

      my $field = $conf->config('cdr-charged_party-field');
      $self->charged_party( $self->$field() );

    } else {

      if ( $self->is_tollfree ) {
        $self->charged_party($self->dst);
      } else {
        $self->charged_party($self->src);
      }

    }

  }

#  my $prefix = $conf->config('cdr-charged_party-truncate_prefix');
#  my $prefix_len = length($prefix);
#  my $trunc_len = $conf->config('cdr-charged_party-truncate_length');
#
#  $self->charged_party( substr($self->charged_party, 0, $trunc_len) )
#    if $prefix_len && $trunc_len
#    && substr($self->charged_party, 0, $prefix_len) eq $prefix;

}

=item set_status STATUS

Sets the status to the provided string.  If there is an error, returns the
error, otherwise returns false.

=cut

sub set_status {
  my($self, $status) = @_;
  $self->freesidestatus($status);
  $self->replace;
}

=item set_status_and_rated_price STATUS RATED_PRICE [ SVCNUM [ OPTION => VALUE ... ] ]

Sets the status and rated price.

Available options are: inbound, rated_seconds, rated_minutes, rated_classnum, rated_ratename

If there is an error, returns the error, otherwise returns false.

=cut

sub set_status_and_rated_price {
  my($self, $status, $rated_price, $svcnum, %opt) = @_;

  if ($opt{'inbound'}) {

    my $term = $self->cdr_termination( 1 ); #1: inbound
    my $error;
    if ( $term ) {
      warn "replacing existing cdr status (".$self->acctid.")\n" if $term;
      $error = $term->delete;
      return $error if $error;
    }
    $term = FS::cdr_termination->new({
        acctid      => $self->acctid,
        termpart    => 1,
        rated_price => $rated_price,
        status      => $status,
    });
    $term->rated_seconds($opt{rated_seconds}) if exists($opt{rated_seconds});
    $term->rated_minutes($opt{rated_minutes}) if exists($opt{rated_minutes});
    $term->svcnum($svcnum) if $svcnum;
    return $term->insert;

  } else {

    $self->freesidestatus($status);
    $self->rated_price($rated_price);
    $self->$_($opt{$_})
      foreach grep exists($opt{$_}), map "rated_$_",
        qw( pretty_dst regionname seconds minutes granularity
            ratedetailnum classnum ratename );
    $self->svcnum($svcnum) if $svcnum;
    return $self->replace();

  }
}

=item rate [ OPTION => VALUE ... ]

Rates this CDR according and sets the status to 'rated'.

Available options are: part_pkg, svcnum, single_price_included_minutes, region_group, region_group_included_minutes.

part_pkg is required.

If svcnum is specified, will also associate this CDR with the specified svcnum.

single_price_included_minutes is requried for single_price price plans
(otherwise unused/ignored).  It should be set to a scalar reference of the
number of included minutes and will be decremented by the rated minutes of this
CDR.

region_group_included_minutes is required for prefix price plans which have
included minutes (otherwise unused/ignored).  It should be set to a scalar
reference of the number of included minutes and will be decremented by the
rated minutes of this CDR.

region_group_included_minutes_hashref is required for prefix price plans which
have included minues (otehrwise unused/ignored).  It should be set to an empty
hashref at the start of a month's rating and then preserved across CDRs.

=cut

sub rate {
  my( $self, %opt ) = @_;
  my $part_pkg = $opt{'part_pkg'} or return "No part_pkg specified";

  if ( $DEBUG > 1 ) {
    warn "rating CDR $self\n".
         join('', map { "  $_ => ". $self->{$_}. "\n" } keys %$self );
  }

  my $rating_method = $part_pkg->option_cacheable('rating_method') || 'prefix';
  my $method = "rate_$rating_method";
  $self->$method(%opt);
}

#here?
our %interval_cache = (); # for timed rates

sub rate_prefix {
  my( $self, %opt ) = @_;
  my $part_pkg = $opt{'part_pkg'} or return "No part_pkg specified";

  my $da_rewrote = 0;
  # this will result in those CDRs being marked as done... is that 
  # what we want?
  my @dirass = ();
  if ( $part_pkg->option_cacheable('411_rewrite') ) {
    my $dirass = $part_pkg->option_cacheable('411_rewrite');
    $dirass =~ s/\s//g;
    @dirass = split(',', $dirass);
  }

  if ( length($self->dst) && grep { $self->dst eq $_ } @dirass ) {
    $self->dst('411');
    $da_rewrote = 1;
  }

  my $reason = $part_pkg->check_chargable( $self,
                                           'da_rewrote'   => $da_rewrote,
                                         );
  if ( $reason ) {
    warn "not charging for CDR ($reason)\n" if $DEBUG;
    return $self->set_status_and_rated_price( 'rated',
                                              0,
                                              $opt{'svcnum'},
                                            );
  }

    
  ###
  # look up rate details based on called station id
  # (or calling station id for toll free calls)
  ###

  my( $to_or_from, $number );
  if ( $self->is_tollfree && ! $part_pkg->option_cacheable('disable_tollfree') )
  { #tollfree call
    $to_or_from = 'from';
    $number = $self->src;
  } else { #regular call
    $to_or_from = 'to';
    $number = $self->dst;
  }

  warn "parsing call $to_or_from $number\n" if $DEBUG;

  #remove non-phone# stuff and whitespace
  $number =~ s/\s//g;
#          my $proto = '';
#          $dest =~ s/^(\w+):// and $proto = $1; #sip:
#          my $siphost = '';
#          $dest =~ s/\@(.*)$// and $siphost = $1; # @10.54.32.1, @sip.example.com

  #determine the country code
  my $intl = $part_pkg->option_cacheable('international_prefix') || '011';
  my $countrycode = '';
  if (    $number =~ /^$intl(((\d)(\d))(\d))(\d+)$/
       || $number =~ /^\+(((\d)(\d))(\d))(\d+)$/
     )
  {

    my( $three, $two, $one, $u1, $u2, $rest ) = ( $1,$2,$3,$4,$5,$6 );
    #first look for 1 digit country code
    if ( qsearch('rate_prefix', { 'countrycode' => $one } ) ) {
      $countrycode = $one;
      $number = $u1.$u2.$rest;
    } elsif ( qsearch('rate_prefix', { 'countrycode' => $two } ) ) { #or 2
      $countrycode = $two;
      $number = $u2.$rest;
    } else { #3 digit country code
      $countrycode = $three;
      $number = $rest;
    }

  } else {
    my $domestic_prefix = $part_pkg->option_cacheable('domestic_prefix');
    $countrycode = length($domestic_prefix) ? $domestic_prefix : '1';
    $number =~ s/^$countrycode//;# if length($number) > 10;
  }

  warn "rating call $to_or_from +$countrycode $number\n" if $DEBUG;
  my $pretty_dst = "+$countrycode $number";
  #asterisks here causes inserting the detail to barf, so:
  $pretty_dst =~ s/\*//g;

  my $eff_ratenum = $self->is_tollfree('accountcode')
    ? $part_pkg->option_cacheable('accountcode_tollfree_ratenum')
    : '';

  my $ratename = '';
  my $intrastate_ratenum = $part_pkg->option_cacheable('intrastate_ratenum');
  if ( $intrastate_ratenum && !$self->is_tollfree ) {
    $ratename = 'Interstate'; #until proven otherwise
    # this is relatively easy only because:
    # -assume all numbers are valid NANP numbers NOT in a fully-qualified format
    # -disregard toll-free
    # -disregard private or unknown numbers
    # -there is exactly one record in rate_prefix for a given NPANXX
    # -default to interstate if we can't find one or both of the prefixes
    my $dstprefix = $self->dst;
    $dstprefix =~ /^(\d{6})/;
    $dstprefix = qsearchs('rate_prefix', {   'countrycode' => '1', 
                                                'npa' => $1, 
                                         }) || '';
    my $srcprefix = $self->src;
    $srcprefix =~ /^(\d{6})/;
    $srcprefix = qsearchs('rate_prefix', {   'countrycode' => '1',
                                             'npa' => $1, 
                                         }) || '';
    if ($srcprefix && $dstprefix
        && $srcprefix->state && $dstprefix->state
        && $srcprefix->state eq $dstprefix->state) {
      $eff_ratenum = $intrastate_ratenum;
      $ratename = 'Intrastate'; # XXX possibly just use the ratename?
    }
  }

  $eff_ratenum ||= $part_pkg->option_cacheable('ratenum');
  my $rate = qsearchs('rate', { 'ratenum' => $eff_ratenum })
    or die "ratenum $eff_ratenum not found!";

  my @ltime = localtime($self->startdate);
  my $weektime = $ltime[0] + 
                 $ltime[1]*60 +   #minutes
                 $ltime[2]*3600 + #hours
                 $ltime[6]*86400; #days since sunday
  # if there's no timed rate_detail for this time/region combination,
  # dest_detail returns the default.  There may still be a timed rate 
  # that applies after the starttime of the call, so be careful...
  my $rate_detail = $rate->dest_detail({ 'countrycode' => $countrycode,
                                         'phonenum'    => $number,
                                         'weektime'    => $weektime,
                                         'cdrtypenum'  => $self->cdrtypenum,
                                      });

  unless ( $rate_detail ) {

    if ( $part_pkg->option_cacheable('ignore_unrateable') ) {

      if ( $part_pkg->option_cacheable('ignore_unrateable') == 2 ) {
        # mark the CDR as unrateable
        return $self->set_status_and_rated_price(
          'failed',
          '',
          $opt{'svcnum'},
        );
      } elsif ( $part_pkg->option_cacheable('ignore_unrateable') == 1 ) {
        # warn and continue
        warn "no rate_detail found for CDR.acctid: ". $self->acctid.
             "; skipping\n";
        return '';

      } else {
        die "unknown ignore_unrateable, pkgpart ". $part_pkg->pkgpart;
      }

    } else {

      die "FATAL: no rate_detail found in ".
          $rate->ratenum. ":". $rate->ratename. " rate plan ".
          "for +$countrycode $number (CDR acctid ". $self->acctid. "); ".
          "add a rate or set ignore_unrateable flag on the package def\n";
    }

  }

  my $rate_region = $rate_detail->dest_region;
  my $regionnum = $rate_region->regionnum;
  warn "  found rate for regionnum $regionnum ".
       "and rate detail $rate_detail\n"
    if $DEBUG;

  if ( !exists($interval_cache{$regionnum}) ) {
    my @intervals = (
      sort { $a->stime <=> $b->stime }
      map { my $r = $_->rate_time; $r ? $r->intervals : () }
      $rate->rate_detail
    );
    $interval_cache{$regionnum} = \@intervals;
    warn "  cached ".scalar(@intervals)." interval(s)\n"
      if $DEBUG;
  }

  ###
  # find the price and add detail to the invoice
  ###

  # About this section:
  # We don't round _anything_ (except granularizing) 
  # until the final $charge = sprintf("%.2f"...).

  my $seconds_left = $part_pkg->option_cacheable('use_duration')
                       ? $self->duration
                       : $self->billsec;
  # charge for the first (conn_sec) seconds
  my $seconds = min($seconds_left, $rate_detail->conn_sec);
  $seconds_left -= $seconds; 
  $weektime     += $seconds;
  my $charge = $rate_detail->conn_charge; 

  my $etime;
  while($seconds_left) {
    my $ratetimenum = $rate_detail->ratetimenum; # may be empty

    # find the end of the current rate interval
    if(@{ $interval_cache{$regionnum} } == 0) {
      # There are no timed rates in this group, so just stay 
      # in the default rate_detail for the entire duration.
      # Set an "end" of 1 past the end of the current call.
      $etime = $weektime + $seconds_left + 1;
    } 
    elsif($ratetimenum) {
      # This is a timed rate, so go to the etime of this interval.
      # If it's followed by another timed rate, the stime of that 
      # interval should match the etime of this one.
      my $interval = $rate_detail->rate_time->contains($weektime);
      $etime = $interval->etime;
    }
    else {
      # This is a default rate, so use the stime of the next 
      # interval in the sequence.
      my $next_int = first { $_->stime > $weektime } 
                      @{ $interval_cache{$regionnum} };
      if ($next_int) {
        $etime = $next_int->stime;
      }
      else {
        # weektime is near the end of the week, so decrement 
        # it by a full week and use the stime of the first 
        # interval.
        $weektime -= (3600*24*7);
        $etime = $interval_cache{$regionnum}->[0]->stime;
      }
    }

    my $charge_sec = min($seconds_left, $etime - $weektime);

    $seconds_left -= $charge_sec;

    my $included_min = $opt{'region_group_included_min_hashref'} || {};

    $included_min->{$regionnum}{$ratetimenum} = $rate_detail->min_included
      unless exists $included_min->{$regionnum}{$ratetimenum};

    my $granularity = $rate_detail->sec_granularity;

    my $minutes;
    if ( $granularity ) { # charge per minute
      # Round up to the nearest $granularity
      if ( $charge_sec and $charge_sec % $granularity ) {
        $charge_sec += $granularity - ($charge_sec % $granularity);
      }
      $minutes = $charge_sec / 60; #don't round this
    }
    else { # per call
      $minutes = 1;
      $seconds_left = 0;
    }

    $seconds += $charge_sec;

    my $region_group = ($part_pkg->option_cacheable('min_included') || 0) > 0;

    ${$opt{region_group_included_min}} -= $minutes 
        if $region_group && $rate_detail->region_group;

    $included_min->{$regionnum}{$ratetimenum} -= $minutes;
    if (
         $included_min->{$regionnum}{$ratetimenum} <= 0
         && ( ${$opt{region_group_included_min}} <= 0
              || ! $rate_detail->region_group
            )
       )
    {
                           #should preserve (display?) this
      my $charge_min = 0 - $included_min->{$regionnum}{$ratetimenum};
      $included_min->{$regionnum}{$ratetimenum} = 0;
      $charge += ($rate_detail->min_charge * $charge_min); #still not rounded

    } elsif ( ${$opt{region_group_included_min}} > 0
              && $region_group
              && $rate_detail->region_group 
           )
    {
        $included_min->{$regionnum}{$ratetimenum} = 0 
    }

    # choose next rate_detail
    $rate_detail = $rate->dest_detail({ 'countrycode' => $countrycode,
                                        'phonenum'    => $number,
                                        'weektime'    => $etime,
                                        'cdrtypenum'  => $self->cdrtypenum })
            if($seconds_left);
    # we have now moved forward to $etime
    $weektime = $etime;

  } #while $seconds_left

  # this is why we need regionnum/rate_region....
  warn "  (rate region $rate_region)\n" if $DEBUG;

  $self->set_status_and_rated_price(
    'rated',
    sprintf('%.2f', $charge + 0.000001), # NOW round it.
    $opt{'svcnum'},
    'rated_pretty_dst'    => $pretty_dst,
    'rated_regionname'    => $rate_region->regionname,
    'rated_seconds'       => $seconds,
    'rated_granularity'   => $rate_detail->sec_granularity, #$granularity
    'rated_ratedetailnum' => $rate_detail->ratedetailnum,
    'rated_classnum'      => $rate_detail->classnum, #rated_ratedetailnum?
    'rated_ratename'      => $ratename, #not rate_detail - Intrastate/Interstate
  );

}

sub rate_upstream_simple {
  my( $self, %opt ) = @_;

  $self->set_status_and_rated_price( 'rated',
                                     sprintf('%.3f', $self->upstream_price),
                                     $opt{'svcnum'},
                                   );
}

sub rate_single_price {
  my( $self, %opt ) = @_;
  my $part_pkg = $opt{'part_pkg'} or return "No part_pkg specified";

  # a little false laziness w/abov
  # $rate_detail = new FS::rate_detail({sec_granularity => ... }) ?

  my $granularity = length($part_pkg->option_cacheable('sec_granularity'))
                      ? $part_pkg->option_cacheable('sec_granularity')
                      : 60;

  my $seconds = $part_pkg->option_cacheable('use_duration')
                  ? $self->duration
                  : $self->billsec;

  $seconds += $granularity - ( $seconds % $granularity )
    if $seconds      # don't granular-ize 0 billsec calls (bills them)
    && $granularity  # 0 is per call
    && $seconds % $granularity;
  my $minutes = $granularity ? ($seconds / 60) : 1;

  my $charge_min = $minutes;

  ${$opt{single_price_included_min}} -= $minutes;
  if ( ${$opt{single_price_included_min}} > 0 ) {
    $charge_min = 0;
  } else {
     $charge_min = 0 - ${$opt{single_price_included_min}};
     ${$opt{single_price_included_min}} = 0;
  }

  my $charge =
    sprintf('%.4f', ( $part_pkg->option_cacheable('min_charge') * $charge_min )
                    + 0.0000000001 ); #so 1.00005 rounds to 1.0001

  $self->set_status_and_rated_price( 'rated',
                                     $charge,
                                     $opt{'svcnum'},
                                   );

}

=item cdr_termination [ TERMPART ]

=cut

sub cdr_termination {
  my $self = shift;

  if ( scalar(@_) && $_[0] ) {
    my $termpart = shift;

    qsearchs('cdr_termination', { acctid   => $self->acctid,
                                  termpart => $termpart,
                                }
            );

  } else {

    qsearch('cdr_termination', { acctid => $self->acctid, } );

  }

}

=item calldate_unix 

Parses the calldate in SQL string format and returns a UNIX timestamp.

=cut

sub calldate_unix {
  str2time(shift->calldate);
}

=item startdate_sql

Parses the startdate in UNIX timestamp format and returns a string in SQL
format.

=cut

sub startdate_sql {
  my($sec,$min,$hour,$mday,$mon,$year) = localtime(shift->startdate);
  $mon++;
  $year += 1900;
  "$year-$mon-$mday $hour:$min:$sec";
}

=item cdr_carrier

Returns the FS::cdr_carrier object associated with this CDR, or false if no
carrierid is defined.

=cut

my %carrier_cache = ();

sub cdr_carrier {
  my $self = shift;
  return '' unless $self->carrierid;
  $carrier_cache{$self->carrierid} ||=
    qsearchs('cdr_carrier', { 'carrierid' => $self->carrierid } );
}

=item carriername 

Returns the carrier name (see L<FS::cdr_carrier>), or the empty string if
no FS::cdr_carrier object is assocated with this CDR.

=cut

sub carriername {
  my $self = shift;
  my $cdr_carrier = $self->cdr_carrier;
  $cdr_carrier ? $cdr_carrier->carriername : '';
}

=item cdr_calltype

Returns the FS::cdr_calltype object associated with this CDR, or false if no
calltypenum is defined.

=cut

my %calltype_cache = ();

sub cdr_calltype {
  my $self = shift;
  return '' unless $self->calltypenum;
  $calltype_cache{$self->calltypenum} ||=
    qsearchs('cdr_calltype', { 'calltypenum' => $self->calltypenum } );
}

=item calltypename 

Returns the call type name (see L<FS::cdr_calltype>), or the empty string if
no FS::cdr_calltype object is assocated with this CDR.

=cut

sub calltypename {
  my $self = shift;
  my $cdr_calltype = $self->cdr_calltype;
  $cdr_calltype ? $cdr_calltype->calltypename : '';
}

=item downstream_csv [ OPTION => VALUE, ... ]

=cut

my %export_names = (
  'simple'  => {
    'name'           => 'Simple',
    'invoice_header' => "Date,Time,Name,Destination,Duration,Price",
  },
  'simple2' => {
    'name'           => 'Simple with source',
    'invoice_header' => "Date,Time,Called From,Destination,Duration,Price",
                       #"Date,Time,Name,Called From,Destination,Duration,Price",
  },
  'basic' => {
    'name'           => 'Basic',
    'invoice_header' => "Date/Time,Called Number,Min/Sec,Price",
  },
  'default' => {
    'name'           => 'Default',
    'invoice_header' => 'Date,Time,Number,Destination,Duration,Price',
  },
  'source_default' => {
    'name'           => 'Default with source',
    'invoice_header' => 'Caller,Date,Time,Number,Destination,Duration,Price',
  },
  'accountcode_default' => {
    'name'           => 'Default plus accountcode',
    'invoice_header' => 'Date,Time,Account,Number,Destination,Duration,Price',
  },
  'description_default' => {
    'name'           => 'Default with description field as destination',
    'invoice_header' => 'Caller,Date,Time,Number,Destination,Duration,Price',
  },
  'sum_duration' => {
    'name'           => 'Summary (one line per service, with duration)',
    'invoice_header' => 'Caller,Rate,Calls,Minutes,Price',
  },
  'sum_count' => {
    'name'           => 'Summary (one line per service, with count)',
    'invoice_header' => 'Caller,Rate,Messages,Price',
  },
);

my %export_formats = ();
sub export_formats {
  #my $self = shift;

  return %export_formats if keys %export_formats;

  my $conf = new FS::Conf;
  my $date_format = $conf->config('date_format') || '%m/%d/%Y';

  # call duration in the largest units that accurately reflect the  granularity
  my $duration_sub = sub {
    my($cdr, %opt) = @_;
    my $sec = $opt{seconds} || $cdr->billsec;
    if ( defined $opt{granularity} && 
         $opt{granularity} == 0 ) { #per call
      return '1 call';
    }
    elsif ( defined $opt{granularity} && $opt{granularity} == 60 ) {#full minutes
      my $min = int($sec/60);
      $min++ if $sec%60;
      return $min.'m';
    }
    else { #anything else
      return sprintf("%dm %ds", $sec/60, $sec%60);
    }
  };

  my $price_sub = sub {
    my ($cdr, %opt) = @_;
    my $price;
    if ( defined($opt{charge}) ) {
      $price = $opt{charge};
    }
    elsif ( $opt{inbound} ) {
      my $term = $cdr->cdr_termination(1); # 1 = inbound
      $price = $term->rated_price if defined $term;
    }
    else {
      $price = $cdr->rated_price;
    }
    length($price) ? ($opt{money_char} . $price) : '';
  };

  %export_formats = (
    'simple' => [
      sub { time2str($date_format, shift->calldate_unix ) },   #DATE
      sub { time2str('%r', shift->calldate_unix ) },   #TIME
      'userfield',                                     #USER
      'dst',                                           #NUMBER_DIALED
      $duration_sub,                                   #DURATION
      #sub { sprintf('%.3f', shift->upstream_price ) }, #PRICE
      $price_sub,
    ],
    'simple2' => [
      sub { time2str($date_format, shift->calldate_unix ) },   #DATE
      sub { time2str('%r', shift->calldate_unix ) },   #TIME
      #'userfield',                                     #USER
      'src',                                           #called from
      'dst',                                           #NUMBER_DIALED
      $duration_sub,                                   #DURATION
      #sub { sprintf('%.3f', shift->upstream_price ) }, #PRICE
      $price_sub,
    ],
    'sum_duration' => [ 
      # for summary formats, the CDR is a fictitious object containing the 
      # total billsec and the phone number of the service
      'src',
      sub { my($cdr, %opt) = @_; $opt{ratename} },
      sub { my($cdr, %opt) = @_; $opt{count} },
      sub { my($cdr, %opt) = @_; int($opt{seconds}/60).'m' },
      $price_sub,
    ],
    'sum_count' => [
      'src',
      sub { my($cdr, %opt) = @_; $opt{ratename} },
      sub { my($cdr, %opt) = @_; $opt{count} },
      $price_sub,
    ],
    'basic' => [
      sub { time2str('%d %b - %I:%M %p', shift->calldate_unix) },
      'dst',
      $duration_sub,
      $price_sub,
    ],
    'default' => [

      #DATE
      sub { time2str($date_format, shift->calldate_unix ) },
            # #time2str("%Y %b %d - %r", $cdr->calldate_unix ),

      #TIME
      sub { time2str('%r', shift->calldate_unix ) },
            # time2str("%c", $cdr->calldate_unix),  #XXX this should probably be a config option dropdown so they can select US vs- rest of world dates or whatnot

      #DEST ("Number")
      sub { my($cdr, %opt) = @_; $opt{pretty_dst} || $cdr->dst; },

      #REGIONNAME ("Destination")
      sub { my($cdr, %opt) = @_; $opt{dst_regionname}; },

      #DURATION
      $duration_sub,

      #PRICE
      $price_sub,
    ],
  );
  $export_formats{'source_default'} = [ 'src', @{ $export_formats{'default'} }, ];
  $export_formats{'accountcode_default'} =
    [ @{ $export_formats{'default'} }[0,1],
      'accountcode',
      @{ $export_formats{'default'} }[2..5],
    ];
  my @default = @{ $export_formats{'default'} };
  $export_formats{'description_default'} = 
    [ 'src', @default[0..2], 
      sub { my($cdr, %opt) = @_; $cdr->description },
      @default[4,5] ];

  return %export_formats;
}

=item downstream_csv OPTION => VALUE ...

Returns a string of formatted call details for display on an invoice.

Options:

format

charge - override the 'rated_price' field of the CDR

seconds - override the 'billsec' field of the CDR

count - number of usage events included in this record, for summary formats

ratename - name of the rate table used to rate this call

granularity

=cut

sub downstream_csv {
  my( $self, %opt ) = @_;

  my $format = $opt{'format'};
  my %formats = $self->export_formats;
  return "Unknown format $format" unless exists $formats{$format};

  #my $conf = new FS::Conf;
  #$opt{'money_char'} ||= $conf->config('money_char') || '$';
  $opt{'money_char'} ||= FS::Conf->new->config('money_char') || '$';

  eval "use Text::CSV_XS;";
  die $@ if $@;
  my $csv = new Text::CSV_XS;

  my @columns =
    map {
          ref($_) ? &{$_}($self, %opt) : $self->$_();
        }
    @{ $formats{$format} };

  return @columns if defined $opt{'keeparray'};

  my $status = $csv->combine(@columns);
  die "FS::CDR: error combining ". $csv->error_input(). "into downstream CSV"
    unless $status;

  $csv->string;

}

=back

=head1 CLASS METHODS

=over 4

=item invoice_formats

Returns an ordered list of key value pairs containing invoice format names
as keys (for use with part_pkg::voip_cdr) and "pretty" format names as values.

=cut

sub invoice_formats {
  map { ($_ => $export_names{$_}->{'name'}) }
    grep { $export_names{$_}->{'invoice_header'} }
    keys %export_names;
}

=item invoice_header FORMAT

Returns a scalar containing the CSV column header for invoice format FORMAT.

=cut

sub invoice_header {
  my $format = shift;
  $export_names{$format}->{'invoice_header'};
}

=item clear_status 

Clears cdr and any associated cdr_termination statuses - used for 
CDR reprocessing.

=cut

sub clear_status {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $self->freesidestatus('');
  my $error = $self->replace;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  } 

  foreach my $cdr_termination ( $self->cdr_termination ) {
      #$cdr_termination->status('');
      #$error = $cdr_termination->replace;
      $error = $cdr_termination->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      } 
  }
  
  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';
}

=item import_formats

Returns an ordered list of key value pairs containing import format names
as keys (for use with batch_import) and "pretty" format names as values.

=cut

#false laziness w/part_pkg & part_export

my %cdr_info;
foreach my $INC ( @INC ) {
  warn "globbing $INC/FS/cdr/*.pm\n" if $DEBUG;
  foreach my $file ( glob("$INC/FS/cdr/*.pm") ) {
    warn "attempting to load CDR format info from $file\n" if $DEBUG;
    $file =~ /\/(\w+)\.pm$/ or do {
      warn "unrecognized file in $INC/FS/cdr/: $file\n";
      next;
    };
    my $mod = $1;
    my $info = eval "use FS::cdr::$mod; ".
                    "\\%FS::cdr::$mod\::info;";
    if ( $@ ) {
      die "error using FS::cdr::$mod (skipping): $@\n" if $@;
      next;
    }
    unless ( keys %$info ) {
      warn "no %info hash found in FS::cdr::$mod, skipping\n";
      next;
    }
    warn "got CDR format info from FS::cdr::$mod: $info\n" if $DEBUG;
    if ( exists($info->{'disabled'}) && $info->{'disabled'} ) {
      warn "skipping disabled CDR format FS::cdr::$mod" if $DEBUG;
      next;
    }
    $cdr_info{$mod} = $info;
  }
}

tie my %import_formats, 'Tie::IxHash',
  map  { $_ => $cdr_info{$_}->{'name'} }
  sort { $cdr_info{$a}->{'weight'} <=> $cdr_info{$b}->{'weight'} }
  grep { exists($cdr_info{$_}->{'import_fields'}) }
  keys %cdr_info;

sub import_formats {
  %import_formats;
}

sub _cdr_min_parser_maker {
  my $field = shift;
  my @fields = ref($field) ? @$field : ($field);
  @fields = qw( billsec duration ) unless scalar(@fields) && $fields[0];
  return sub {
    my( $cdr, $min ) = @_;
    my $sec = eval { _cdr_min_parse($min) };
    die "error parsing seconds for @fields from $min minutes: $@\n" if $@;
    $cdr->$_($sec) foreach @fields;
  };
}

sub _cdr_min_parse {
  my $min = shift;
  sprintf('%.0f', $min * 60 );
}

sub _cdr_date_parser_maker {
  my $field = shift;
  my %options = @_;
  my @fields = ref($field) ? @$field : ($field);
  return sub {
    my( $cdr, $datestring ) = @_;
    my $unixdate = eval { _cdr_date_parse($datestring, %options) };
    die "error parsing date for @fields from $datestring: $@\n" if $@;
    $cdr->$_($unixdate) foreach @fields;
  };
}

sub _cdr_date_parse {
  my $date = shift;
  my %options = @_;

  return '' unless length($date); #that's okay, it becomes NULL
  return '' if $date eq 'NA'; #sansay

  if ( $date =~ /^([a-z]{3})\s+([a-z]{3})\s+(\d{1,2})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})\s+(\d{4})$/i && $7 > 1970 ) {
    my $time = str2time($date);
    return $time if $time > 100000; #just in case
  }

  my($year, $mon, $day, $hour, $min, $sec);

  #$date =~ /^\s*(\d{4})[\-\/]\(\d{1,2})[\-\/](\d{1,2})\s+(\d{1,2}):(\d{1,2}):(\d{1,2})\s*$/
  #taqua  #2007-10-31 08:57:24.113000000

  if ( $date =~ /^\s*(\d{4})\D(\d{1,2})\D(\d{1,2})\D+(\d{1,2})\D(\d{1,2})\D(\d{1,2})(\D|$)/ ) {
    ($year, $mon, $day, $hour, $min, $sec) = ( $1, $2, $3, $4, $5, $6 );
  } elsif ( $date  =~ /^\s*(\d{1,2})\D(\d{1,2})\D(\d{4})\s+(\d{1,2})\D(\d{1,2})(?:\D(\d{1,2}))?(\D|$)/ ) {
    # 8/26/2010 12:20:01
    # optionally without seconds
    ($mon, $day, $year, $hour, $min, $sec) = ( $1, $2, $3, $4, $5, $6 );
    $sec = 0 if !defined($sec);
  } elsif ( $date  =~ /^\s*(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d+\.\d+)(\D|$)/ ) {
    # broadsoft: 20081223201938.314
    ($year, $mon, $day, $hour, $min, $sec) = ( $1, $2, $3, $4, $5, $6 );
  } elsif ( $date  =~ /^\s*(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\d+(\D|$)/ ) {
    # Taqua OM:  20050422203450943
    ($year, $mon, $day, $hour, $min, $sec) = ( $1, $2, $3, $4, $5, $6 );
  } elsif ( $date  =~ /^\s*(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/ ) {
    # WIP: 20100329121420
    ($year, $mon, $day, $hour, $min, $sec) = ( $1, $2, $3, $4, $5, $6 );
  } elsif ( $date =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})Z$/) {
    # Telos
    ($year, $mon, $day, $hour, $min, $sec) = ( $1, $2, $3, $4, $5, $6 );
    $options{gmt} = 1;
  } else {
     die "unparsable date: $date"; #maybe we shouldn't die...
  }

  return '' if ( $year == 1900 || $year == 1970 ) && $mon == 1 && $day == 1
            && $hour == 0 && $min == 0 && $sec == 0;

  if ($options{gmt}) {
    timegm($sec, $min, $hour, $day, $mon-1, $year);
  } else {
    timelocal($sec, $min, $hour, $day, $mon-1, $year);
  }
}

=item batch_import HASHREF

Imports CDR records.  Available options are:

=over 4

=item file

Filename

=item format

=item params

Hash reference of preset fields, typically cdrbatch

=item empty_ok

Set true to prevent throwing an error on empty imports

=back

=cut

my %import_options = (
  'table'         => 'cdr',

  'batch_keycol'  => 'cdrbatchnum',
  'batch_table'   => 'cdr_batch',
  'batch_namecol' => 'cdrbatch',

  'formats' => { map { $_ => $cdr_info{$_}->{'import_fields'}; }
                     keys %cdr_info
               },

                          #drop the || 'csv' to allow auto xls for csv types?
  'format_types' => { map { $_ => lc($cdr_info{$_}->{'type'} || 'csv'); }
                          keys %cdr_info
                    },

  'format_headers' => { map { $_ => ( $cdr_info{$_}->{'header'} || 0 ); }
                            keys %cdr_info
                      },

  'format_sep_chars' => { map { $_ => $cdr_info{$_}->{'sep_char'}; }
                              keys %cdr_info
                        },

  'format_fixedlength_formats' =>
    { map { $_ => $cdr_info{$_}->{'fixedlength_format'}; }
          keys %cdr_info
    },

  'format_xml_formats' =>
    { map { $_ => $cdr_info{$_}->{'xml_format'}; }
          keys %cdr_info
    },

  'format_row_callbacks' => { map { $_ => $cdr_info{$_}->{'row_callback'}; }
                                  keys %cdr_info
                            },
);

sub _import_options {
  \%import_options;
}

sub batch_import {
  my $opt = shift;

  my $iopt = _import_options;
  $opt->{$_} = $iopt->{$_} foreach keys %$iopt;

  if ( defined $opt->{'cdrtypenum'} ) {
        $opt->{'preinsert_callback'} = sub {
                my($record,$param) = (shift,shift);
                $record->cdrtypenum($opt->{'cdrtypenum'});
                '';
        };
  }

  FS::Record::batch_import( $opt );

}

=item process_batch_import

=cut

sub process_batch_import {
  my $job = shift;

  my $opt = _import_options;
#  $opt->{'params'} = [ 'format', 'cdrbatch' ];

  FS::Record::process_batch_import( $job, $opt, @_ );

}
#  if ( $format eq 'simple' ) { #should be a callback or opt in FS::cdr::simple
#    @columns = map { s/^ +//; $_; } @columns;
#  }

# _ upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

sub _upgrade_data {
  my ($class, %opts) = @_;

  warn "$me upgrading $class\n" if $DEBUG;

  my $sth = dbh->prepare(
    'SELECT DISTINCT(cdrbatch) FROM cdr WHERE cdrbatch IS NOT NULL'
  ) or die dbh->errstr;

  $sth->execute or die $sth->errstr;

  my %cdrbatchnum = ();
  while (my $row = $sth->fetchrow_arrayref) {

    my $cdr_batch = qsearchs( 'cdr_batch', { 'cdrbatch' => $row->[0] } );
    unless ( $cdr_batch ) {
      $cdr_batch = new FS::cdr_batch { 'cdrbatch' => $row->[0] };
      my $error = $cdr_batch->insert;
      die $error if $error;
    }

    $cdrbatchnum{$row->[0]} = $cdr_batch->cdrbatchnum;
  }

  $sth = dbh->prepare('UPDATE cdr SET cdrbatch = NULL, cdrbatchnum = ? WHERE cdrbatch IS NOT NULL AND cdrbatch = ?') or die dbh->errstr;

  foreach my $cdrbatch (keys %cdrbatchnum) {
    $sth->execute($cdrbatchnum{$cdrbatch}, $cdrbatch) or die $sth->errstr;
  }

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

