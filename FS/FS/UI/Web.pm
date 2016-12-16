package FS::UI::Web;

use strict;
use vars qw($DEBUG @ISA @EXPORT_OK $me);
use Exporter;
use Carp qw( confess );
use HTML::Entities;
use FS::Conf;
use FS::Misc::DateTime qw( parse_datetime day_end );
use FS::Record qw(dbdef);
use FS::cust_main;  # are sql_balance and sql_date_balance in the right module?

#use vars qw(@ISA);
#use FS::UI
#@ISA = qw( FS::UI );
@ISA = qw( Exporter );

@EXPORT_OK = qw( get_page_pref set_page_pref svc_url random_id );

$DEBUG = 0;
$me = '[FS::UID::Web]';

our $NO_RANDOM_IDS;

###
# user prefs
###

=item get_page_pref NAME, TABLENUM

Returns the user's page preference named NAME for the current page. If the
page is a view or edit page or otherwise shows a single record at a time,
it should use TABLENUM to link the preference to that record.

=cut

sub get_page_pref {
  my ($prefname, $tablenum) = @_;

  my $m = $HTML::Mason::Commands::m
    or die "can't get page pref when running outside the UI";
  # what's more useful: to tie prefs to the base_comp (usually where
  # code is executing right now), or to the request_comp (approximately the
  # one in the URL)? not sure.
  $FS::CurrentUser::CurrentUser->get_page_pref( $m->request_comp->path,
                                                $prefname,
                                                $tablenum
                                              );
}

=item set_page_pref NAME, TABLENUM, VALUE

Sets the user's page preference named NAME for the current page. Use TABLENUM
as for get_page_pref.

If VALUE is an empty string, the preference will be deleted (and
C<get_page_pref> will return an empty string).

  my $mypref = set_page_pref('mypref', '', 100);

=cut

sub set_page_pref {
  my ($prefname, $tablenum, $prefvalue) = @_;

  my $m = $HTML::Mason::Commands::m
    or die "can't set page pref when running outside the UI";
  $FS::CurrentUser::CurrentUser->set_page_pref( $m->request_comp->path,
                                                $prefname,
                                                $tablenum,
                                                $prefvalue );
}

###
# date parsing
###

=item parse_beginning_ending CGI [, PREFIX ]

Parses a beginning/ending date range, as used on many reports. This function
recognizes two sets of CGI params: "begin" and "end", the integer timestamp
values, and "beginning" and "ending", the user-readable date fields.

If "begin" contains an integer, that's passed through as the beginning date.
Otherwise, "beginning" is passed to L<DateTime::Format::Natural> and turned
into an integer. If this fails or it doesn't have a value, zero is used as the
beginning date.

The same happens for "end" and "ending", except that if "ending" contains a
date without a time, it gets moved to the end of that day, and if there's no
value, the value returned is the highest unsigned 32-bit time value (some time
in 2037).

PREFIX is optionally a string to prepend (with '_' as a delimiter) to the form
field names.

=cut

use Date::Parse;
sub parse_beginning_ending {
  my($cgi, $prefix) = @_;
  $prefix .= '_' if $prefix;

  my $beginning = 0;
  if ( $cgi->param($prefix.'begin') =~ /^(\d+)$/ ) {
    $beginning = $1;
  } elsif ( $cgi->param($prefix.'beginning') =~ /^([ 0-9\-\/\:]{1,64})$/ ) {
    $beginning = parse_datetime($1) || 0;
  }

  my $ending = 4294967295; #2^32-1
  if ( $cgi->param($prefix.'end') =~ /^(\d+)$/ ) {
    $ending = $1 - 1;
  } elsif ( $cgi->param($prefix.'ending') =~ /^([ 0-9\-\/\:]{1,64})$/ ) {
    $ending = parse_datetime($1);
    $ending = day_end($ending) unless $ending =~ /:/;
  }

  ( $beginning, $ending );
}

=item svc_url

Returns a service URL, first checking to see if there is a service-specific
page to link to, otherwise to a generic service handling page.  Options are
passed as a list of name-value pairs, and include:

=over 4

=item * m - Mason request object ($m)

=item * action - The action for which to construct "edit", "view", or "search"

=item ** part_svc - Service definition (see L<FS::part_svc>)

=item ** svcdb - Service table

=item *** query - Query string

=item *** svc   - FS::cust_svc or FS::svc_* object

=item ahref - Optional flag, if set true returns <A HREF="$url"> instead of just the URL.

=back 

* Required fields

** part_svc OR svcdb is required

*** query OR svc is required

=cut

  # ##
  # #required
  # ##
  #  'm'        => $m, #mason request object
  #  'action'   => 'edit', #or 'view'
  #
  #  'part_svc' => $part_svc, #usual
  #   #OR
  #  'svcdb'    => 'svc_table',
  #
  #  'query'    => #optional query string
  #                # (pass a blank string if you want a "raw" URL to add your
  #                #  own svcnum to)
  #   #OR
  #  'svc'      => $svc_x, #or $cust_svc, it just needs a svcnum
  #
  # ##
  # #optional
  # ##
  #  'ahref'    => 1, # if set true, returns <A HREF="$url">

use FS::CGI qw(rooturl);
sub svc_url {
  my %opt = @_;

  #? return '' unless ref($opt{part_svc});

  my $svcdb = $opt{svcdb} || $opt{part_svc}->svcdb;
  my $query = exists($opt{query}) ? $opt{query} : $opt{svc}->svcnum;
  my $url;
  warn "$me [svc_url] checking for /$opt{action}/$svcdb.cgi component"
    if $DEBUG;
  if ( $opt{m}->interp->comp_exists("/$opt{action}/$svcdb.cgi") ) {
    $url = "$svcdb.cgi?";
  } elsif ( $opt{m}->interp->comp_exists("/$opt{action}/$svcdb.html") ) {
    $url = "$svcdb.html?";
  } else {
    my $generic = $opt{action} eq 'search' ? 'cust_svc' : 'svc_Common';

    $url = "$generic.html?svcdb=$svcdb;";
    $url .= 'svcnum=' if $query =~ /^\d+(;|$)/ or $query eq '';
  }

  my $return = FS::CGI::rooturl(). "$opt{action}/$url$query";

  $return = qq!<A HREF="$return">! if $opt{ahref};

  $return;
}

sub svc_link {
  my($m, $part_svc, $cust_svc) = @_ or return '';
  svc_X_link( $part_svc->svc, @_ );
}

sub svc_label_link {
  my($m, $part_svc, $cust_svc) = @_ or return '';
  my($svc, $label, $svcdb) = $cust_svc->label;
  svc_X_link( $label, @_ );
}

sub svc_X_link {
  my ($x, $m, $part_svc, $cust_svc) = @_ or return '';

  return $x
   unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

  confess "svc_X_link called without a service ($x, $m, $part_svc, $cust_svc)\n"
    unless $cust_svc;

  my $ahref = svc_url(
    'ahref'    => 1,
    'm'        => $m,
    'action'   => 'view',
    'part_svc' => $part_svc,
    'svc'      => $cust_svc,
  );

  "$ahref$x</A>";
}

#this probably needs an ACL too...
sub svc_export_links {
  my ($m, $part_svc, $cust_svc) = @_ or return '';

  my $ahref = $cust_svc->export_links;

  join('', @$ahref);
}

sub parse_lt_gt {
  my($cgi, $field) = (shift, shift);
  my $table = ( @_ && length($_[0]) ) ? shift.'.' : '';

  my @search = ();

  my %op = ( 
    'lt' => '<',
    'gt' => '>',
  );

  foreach my $op (keys %op) {

    warn "checking for ${field}_$op field\n"
      if $DEBUG;

    if ( $cgi->param($field."_$op") =~ /^\s*\$?\s*(-?[\d\,\s]+(\.\d\d)?)\s*$/ ) {

      my $num = $1;
      $num =~ s/[\,\s]+//g;
      my $search = "$table$field $op{$op} $num";
      push @search, $search;

      warn "found ${field}_$op field; adding search element $search\n"
        if $DEBUG;
    }

  }

  @search;

}

###
# cust_main report subroutines
###

=over 4

=item cust_header [ CUST_FIELDS_VALUE ]

Returns an array of customer information headers according to the supplied
customer fields value, or if no value is supplied, the B<cust-fields>
configuration value.

=cut

use vars qw( @cust_fields @cust_colors @cust_styles @cust_aligns );

sub cust_header {

  warn "FS::UI:Web::cust_header called"
    if $DEBUG;

  my $conf = new FS::Conf;

  my %header2method = (
    'Customer'                 => 'name',
    'Cust. Status'             => 'cust_status_label',
    'Cust#'                    => 'custnum',
    'Name'                     => 'contact',
    'Company'                  => 'company',

    # obsolete but might still be referenced in configuration
    '(bill) Customer'          => 'name',
    '(service) Customer'       => 'ship_name',
    '(bill) Name'              => 'contact',
    '(service) Name'           => 'ship_contact',
    '(bill) Company'           => 'company',
    '(service) Company'        => 'ship_company',
    '(bill) Day phone'         => 'daytime',
    '(bill) Night phone'       => 'night',
    '(bill) Fax number'        => 'fax',
 
    'Customer'                 => 'name',
    'Address 1'                => 'bill_address1',
    'Address 2'                => 'bill_address2',
    'City'                     => 'bill_city',
    'State'                    => 'bill_state',
    'Zip'                      => 'bill_zip',
    'Country'                  => 'bill_country_full',
    'Day phone'                => 'daytime', # XXX should use msgcat, but how?
    'Night phone'              => 'night',   # XXX should use msgcat, but how?
    'Mobile phone'             => 'mobile',  # XXX should use msgcat, but how?
    'Fax number'               => 'fax',
    '(bill) Address 1'         => 'bill_address1',
    '(bill) Address 2'         => 'bill_address2',
    '(bill) City'              => 'bill_city',
    '(bill) State'             => 'bill_state',
    '(bill) Zip'               => 'bill_zip',
    '(bill) Country'           => 'bill_country_full',
    '(bill) Latitude'          => 'bill_latitude',
    '(bill) Longitude'         => 'bill_longitude',
    '(service) Address 1'      => 'ship_address1',
    '(service) Address 2'      => 'ship_address2',
    '(service) City'           => 'ship_city',
    '(service) State'          => 'ship_state',
    '(service) Zip'            => 'ship_zip',
    '(service) Country'        => 'ship_country_full',
    '(service) Latitude'       => 'ship_latitude',
    '(service) Longitude'      => 'ship_longitude',
    'Invoicing email(s)'       => 'invoicing_list_emailonly_scalar',
# FS::Upgrade::upgrade_config removes this from existing cust-fields settings
#    'Payment Type'             => 'cust_payby',
    'Current Balance'          => 'current_balance',
    'Agent Cust#'              => 'agent_custid',
    'Agent'                    => 'agent_name',
    'Agent Cust# or Cust#'     => 'display_custnum',
    'Advertising Source'       => 'referral',
  );
  $header2method{'Cust#'} = 'display_custnum'
    if $conf->exists('cust_main-default_agent_custid');

  my %header2colormethod = (
    'Cust. Status' => 'cust_statuscolor',
  );
  my %header2style = (
    'Cust. Status' => 'b',
  );
  my %header2align = (
    'Cust. Status' => 'c',
    'Cust#'        => 'r',
  );

  my $cust_fields;
  my @cust_header;
  if ( @_ && $_[0] ) {

    warn "  using supplied cust-fields override".
          " (ignoring cust-fields config file)"
      if $DEBUG;
    $cust_fields = shift;

  } else {

    if (    $conf->exists('cust-fields')
         && $conf->config('cust-fields') =~ /^([\w\. \|\#\(\)]+):?/
       )
    {
      warn "  found cust-fields configuration value"
        if $DEBUG;
      $cust_fields = $1;
    } else { 
      warn "  no cust-fields configuration value found; using default 'Cust. Status | Customer'"
        if $DEBUG;
      $cust_fields = 'Cust. Status | Customer';
    }
  
  }

  @cust_header = split(/ \| /, $cust_fields);
  @cust_fields = map { $header2method{$_} || $_ } @cust_header;
  @cust_colors = map { exists $header2colormethod{$_}
                         ? $header2colormethod{$_}
                         : ''
                     }
                     @cust_header;
  @cust_styles = map { exists $header2style{$_} ? $header2style{$_} : '' }
                     @cust_header;
  @cust_aligns = map { exists $header2align{$_} ? $header2align{$_} : 'l' }
                     @cust_header;

  #my $svc_x = shift;
  @cust_header;
}

sub cust_sort_fields {
  cust_header(@_) if( @_ or !@cust_fields );
  #inefficientish, but tiny lists and only run once per page

  map { $_ eq 'custnum' ? 'custnum' : '' } @cust_fields;

}

=item cust_sql_fields [ CUST_FIELDS_VALUE ]

Returns a list of fields for the SELECT portion of an SQL query.

As with L<the cust_header subroutine|/cust_header>, the fields returned are
defined by the supplied customer fields setting, or if no customer fields
setting is supplied, the <B>cust-fields</B> configuration value. 

=cut

sub cust_sql_fields {

  my @fields = qw( last first company );
#  push @fields, map "ship_$_", @fields;

  cust_header(@_) if( @_ or !@cust_fields );
  #inefficientish, but tiny lists and only run once per page

  my @location_fields;
  foreach my $field (qw( address1 address2 city state zip latitude longitude )) {
    foreach my $pre ('bill_','ship_') {
      if ( grep { $_ eq $pre.$field } @cust_fields ) {
        push @location_fields, $pre.'location.'.$field.' AS '.$pre.$field;
      }
    }
  }
  foreach my $pre ('bill_','ship_') {
    if ( grep { $_ eq $pre.'country_full' } @cust_fields ) {
      push @location_fields, $pre.'locationnum';
    }
  }

  foreach my $field (qw(daytime night mobile fax )) {
    push @fields, $field if (grep { $_ eq $field } @cust_fields);
  }
  push @fields, 'agent_custid';

  push @fields, 'agentnum' if grep { $_ eq 'agent_name' } @cust_fields;

  my @extra_fields = ();
  if (grep { $_ eq 'current_balance' } @cust_fields) {
    push @extra_fields, FS::cust_main->balance_sql . " AS current_balance";
  }

  push @extra_fields, 'part_referral_x.referral AS referral'
    if grep { $_ eq 'referral' } @cust_fields;

  map("cust_main.$_", @fields), @location_fields, @extra_fields;
}

=item join_cust_main [ TABLE[.CUSTNUM] ] [ LOCATION_TABLE[.LOCATIONNUM] ]

Returns an SQL join phrase for the FROM clause so that the fields listed
in L<cust_sql_fields> will be available.  Currently joins to cust_main 
itself, as well as cust_location (under the aliases 'bill_location' and
'ship_location') if address fields are needed.  L<cust_header()> should have
been called already.

All of these will be left joins; if you want to exclude rows with no linked
cust_main record (or bill_location/ship_location), you can do so in the 
WHERE clause.

TABLE is the table containing the custnum field.  If CUSTNUM (a field name
in that table) is specified, that field will be joined to cust_main.custnum.
Otherwise, this function will assume the field is named "custnum".  If the 
argument isn't present at all, the join will just say "USING (custnum)", 
which might work.

As a special case, if TABLE is 'cust_main', only the joins to cust_location
will be returned.

LOCATION_TABLE is an optional table name to use for joining ship_location,
in case your query also includes package information and you want the 
"service address" columns to reflect package addresses.

=cut

sub join_cust_main {
  my ($cust_table, $location_table) = @_;
  my ($custnum, $locationnum);
  ($cust_table, $custnum) = split(/\./, $cust_table);
  $custnum ||= 'custnum';
  ($location_table, $locationnum) = split(/\./, $location_table);
  $locationnum ||= 'locationnum';

  my $sql = '';
  if ( $cust_table ) {
    $sql = " LEFT JOIN cust_main ON (cust_main.custnum = $cust_table.$custnum)"
      unless $cust_table eq 'cust_main';
  } else {
    $sql = " LEFT JOIN cust_main USING (custnum)";
  }

  if ( !@cust_fields or grep /^bill_/, @cust_fields ) {

    $sql .= ' LEFT JOIN cust_location bill_location'.
            ' ON (bill_location.locationnum = cust_main.bill_locationnum)';

  }

  if ( !@cust_fields or grep /^ship_/, @cust_fields ) {

    if (!$location_table) {
      $location_table = 'cust_main';
      $locationnum = 'ship_locationnum';
    }

    $sql .= ' LEFT JOIN cust_location ship_location'.
            " ON (ship_location.locationnum = $location_table.$locationnum) ";
  }

  if ( !@cust_fields or grep { $_ eq 'referral' } @cust_fields ) {
    $sql .= ' LEFT JOIN (select refnum, referral from part_referral) AS part_referral_x ON (cust_main.refnum = part_referral_x.refnum) ';
  }

  $sql;
}

=item cust_fields OBJECT [ CUST_FIELDS_VALUE ]

Given an object that contains fields from cust_main (say, from a
JOINed search.  See httemplate/search/svc_* for examples), returns an array
of customer information, or "(unlinked)" if this service is not linked to a
customer.

As with L<the cust_header subroutine|/cust_header>, the fields returned are
defined by the supplied customer fields setting, or if no customer fields
setting is supplied, the <B>cust-fields</B> configuration value. 

=cut


sub cust_fields {
  my $record = shift;
  warn "FS::UI::Web::cust_fields called for $record ".
       "(cust_fields: @cust_fields)"
    if $DEBUG > 1;

  #cust_header(@_) unless @cust_fields; #now need to cache to keep cust_fields
  #                                     #override incase we were passed as a sub
  
  my $seen_unlinked = 0;

  map { 
    if ( $record->custnum ) {
      warn "  $record -> $_" if $DEBUG > 1;
      encode_entities( $record->$_(@_) );
    } else {
      warn "  ($record unlinked)" if $DEBUG > 1;
      $seen_unlinked++ ? '' : '(unlinked)';
    }
  } @cust_fields;
}

=item cust_fields_subs

Returns an array of subroutine references for returning customer field values.
This is similar to cust_fields, but returns each field's sub as a distinct 
element.

=cut

sub cust_fields_subs {
  my $unlinked_warn = 0;

  return map { 
    my $f = $_;
    if ( $unlinked_warn++ ) {

      sub {
        my $record = shift;
        if ( $record->custnum ) {
          encode_entities( $record->$f(@_) );
        } else {
          '(unlinked)'
        };
      };

    } else {

      sub {
        my $record = shift;
        $record->custnum ? encode_entities( $record->$f(@_) ) : '';
      };

    }

  } @cust_fields;
}

=item cust_colors

Returns an array of subroutine references (or empty strings) for returning
customer information colors.

As with L<the cust_header subroutine|/cust_header>, the fields returned are
defined by the supplied customer fields setting, or if no customer fields
setting is supplied, the <B>cust-fields</B> configuration value. 

=cut

sub cust_colors {
  map { 
    my $method = $_;
    if ( $method ) {
      sub { shift->$method(@_) };
    } else {
      '';
    }
  } @cust_colors;
}

=item cust_styles

Returns an array of customer information styles.

As with L<the cust_header subroutine|/cust_header>, the fields returned are
defined by the supplied customer fields setting, or if no customer fields
setting is supplied, the <B>cust-fields</B> configuration value. 

=cut

sub cust_styles {
  map { 
    if ( $_ ) {
      $_;
    } else {
      '';
    }
  } @cust_styles;
}

=item cust_aligns

Returns an array or scalar (depending on context) of customer information
alignments.

As with L<the cust_header subroutine|/cust_header>, the fields returned are
defined by the supplied customer fields setting, or if no customer fields
setting is supplied, the <B>cust-fields</B> configuration value. 

=cut

sub cust_aligns {
  if ( wantarray ) {
    @cust_aligns;
  } else {
    join('', @cust_aligns);
  }
}

=item cust_links

Returns an array of links to view/cust_main.cgi, for use with cust_fields.

=cut

sub cust_links {
  my $link = [ FS::CGI::rooturl().'view/cust_main.cgi?', 'custnum' ];

  return map { $_ eq 'cust_status_label' ? '' : $link }
    @cust_fields;
}

=item is_mobile

Utility function to determine if the client is a mobile browser.

=cut

sub is_mobile {
  my $ua = $ENV{'HTTP_USER_AGENT'} || '';
  if ( $ua =~ /(?:hiptop|Blazer|Novarra|Vagabond|SonyEricsson|Symbian|NetFront|UP.Browser|UP.Link|Windows CE|MIDP|J2ME|DoCoMo|J-PHONE|PalmOS|PalmSource|iPhone|iPod|AvantGo|Nokia|Android|WebOS|S60|Opera Mini|Opera Mobi)/io ) {
    return 1;
  }
  return 0;
}

=item random_id [ DIGITS ]

Returns a random number of length DIGITS, or if unspecified, a long random 
identifier consisting of the timestamp, process ID, and a random number.
Anything in the UI that needs a random identifier should use this.

=cut

sub random_id {
  my $digits = shift;
  if (!defined $NO_RANDOM_IDS) {
    my $conf = FS::Conf->new;
    $NO_RANDOM_IDS = $conf->exists('no_random_ids') ? 1 : 0;
    warn "TEST MODE--RANDOM ID NUMBERS DISABLED\n" if $NO_RANDOM_IDS;
  }
  if ( $NO_RANDOM_IDS ) {
    if ( $digits > 0 ) {
      return 0;
    } else {
      return '0000000000-0000-000000000.000000';
    }
  } else {
    if ($digits > 0) {
      return int(rand(10 ** $digits));
    } else {
      return time . "-$$-" . rand() * 2**32;
    }
  }
}

=back

=cut

###
# begin JSRPC code...
###

package FS::UI::Web::JSRPC;

use strict;
use vars qw($DEBUG);
use Carp;
use Storable qw(nfreeze);
use MIME::Base64;
use Cpanel::JSON::XS;
use FS::CurrentUser;
use FS::Record qw(qsearchs);
use FS::queue;
use FS::CGI qw(rooturl);

$DEBUG = 0;

sub new {
        my $class = shift;
        my $self  = {
                env => {},
                job => shift,
                cgi => shift,
        };

        bless $self, $class;

        croak "CGI object required as second argument" unless $self->{'cgi'};

        return $self;
}

sub process {

  my $self = shift;

  my $cgi = $self->{'cgi'};

  # XXX this should parse JSON foo and build a proper data structure
  my @args = $cgi->param('arg');

  #work around konqueror bug!
  @args = map { s/\x00$//; $_; } @args;

  my $sub = $cgi->param('sub'); #????

  warn "FS::UI::Web::JSRPC::process:\n".
       "  cgi=$cgi\n".
       "  sub=$sub\n".
       "  args=".join(', ',@args)."\n"
    if $DEBUG;

  if ( $sub eq 'start_job' ) {

    $self->start_job(@args);

  } elsif ( $sub eq 'job_status' ) {

    $self->job_status(@args);

  } else {

    die "unknown sub $sub";

  }

}

sub start_job {
  my $self = shift;

  warn "FS::UI::Web::start_job: ". join(', ', @_) if $DEBUG;
#  my %param = @_;
  my %param = ();
  while ( @_ ) {
    my( $field, $value ) = splice(@_, 0, 2);
    unless ( exists( $param{$field} ) ) {
      $param{$field} = $value;
    } elsif ( ! ref($param{$field}) ) {
      $param{$field} = [ $param{$field}, $value ];
    } else {
      push @{$param{$field}}, $value;
    }
  }
  $param{CurrentUser} = $FS::CurrentUser::CurrentUser->username;
  $param{RootURL} = rooturl($self->{cgi}->self_url);
  warn "FS::UI::Web::start_job\n".
       join('', map {
                      if ( ref($param{$_}) ) {
                        "  $_ => [ ". join(', ', @{$param{$_}}). " ]\n";
                      } else {
                        "  $_ => $param{$_}\n";
                      }
                    } keys %param )
    if $DEBUG;

  #first get the CGI params shipped off to a job ASAP so an id can be returned
  #to the caller
  
  my $job = new FS::queue { 'job' => $self->{'job'} };
  
  #too slow to insert all the cgi params as individual args..,?
  #my $error = $queue->insert('_JOB', $cgi->Vars);
  
  #rely on FS::queue smartness to freeze/encode the param hash

  my $error = $job->insert( '_JOB', \%param );

  if ( $error ) {

    warn "job not inserted: $error\n"
      if $DEBUG;

    $error;  #this doesn't seem to be handled well,
             # will trigger "illegal jobnum" below?
             # (should never be an error inserting the job, though, only thing
             #  would be Pg f%*kage)
  } else {

    warn "job inserted successfully with jobnum ". $job->jobnum. "\n"
      if $DEBUG;

    $job->jobnum;
  }
  
}

sub job_status {
  my( $self, $jobnum ) = @_; #$url ???

  sleep 1; # XXX could use something better...

  my $job;
  if ( $jobnum =~ /^(\d+)$/ ) {
    $job = qsearchs('queue', { 'jobnum' => $jobnum } );
  } else {
    die "FS::UI::Web::job_status: illegal jobnum $jobnum\n";
  }

  my @return;
  if ( $job && $job->status ne 'failed' && $job->status ne 'done' ) {
    my ($progress, $action) = split ',', $job->statustext, 2; 
    $action ||= 'Server processing job';
    @return = ( 'progress', $progress, $action );
  } elsif ( !$job ) { #handle job gone case : job successful
                      # so close popup, redirect parent window...
    @return = ( 'complete' );
  } elsif ( $job->status eq 'done' ) {
    @return = ( 'done', $job->statustext, '' );
  } else {
    @return = ( 'error', $job ? $job->statustext : $jobnum );
  }

  encode_json \@return;

}

1;

