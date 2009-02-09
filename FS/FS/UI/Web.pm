package FS::UI::Web;

use strict;
use vars qw($DEBUG @ISA @EXPORT_OK $me);
use Exporter;
use FS::Conf;
use FS::Record qw(dbdef);
use FS::cust_main;  # are sql_balance and sql_date_balance in the right module?

#use vars qw(@ISA);
#use FS::UI
#@ISA = qw( FS::UI );
@ISA = qw( Exporter );

@EXPORT_OK = qw( svc_url );

$DEBUG = 0;
$me = '[FS::UID::Web]';

###
# date parsing
###

use Date::Parse;
sub parse_beginning_ending {
  my($cgi, $prefix) = @_;
  $prefix .= '_' if $prefix;

  my $beginning = 0;
  if ( $cgi->param($prefix.'begin') =~ /^(\d+)$/ ) {
    $beginning = $1;
  } elsif ( $cgi->param($prefix.'beginning') =~ /^([ 0-9\-\/]{1,64})$/ ) {
    $beginning = str2time($1) || 0;
  }

  my $ending = 4294967295; #2^32-1
  if ( $cgi->param($prefix.'end') =~ /^(\d+)$/ ) {
    $ending = $1 - 1;
  } elsif ( $cgi->param($prefix.'ending') =~ /^([ 0-9\-\/]{1,64})$/ ) {
    #probably need an option to turn off the + 86399
    $ending = str2time($1) + 86399;
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
  } else {

    my $generic = $opt{action} eq 'search' ? 'cust_svc' : 'svc_Common';

    $url = "$generic.html?svcdb=$svcdb;";
    $url .= 'svcnum=' if $query =~ /^\d+(;|$)/ or $query eq '';
  }

  import FS::CGI 'rooturl'; #WTF!  why is this necessary
  my $return = rooturl(). "$opt{action}/$url$query";

  $return = qq!<A HREF="$return">! if $opt{ahref};

  $return;
}

sub svc_link {
  my($m, $part_svc, $cust_svc) = @_ or return '';
  svc_X_link( $part_svc->svc, @_ );
}

sub svc_label_link {
  my($m, $part_svc, $cust_svc) = @_ or return '';
  svc_X_link( ($cust_svc->label)[1], @_ );
}

sub svc_X_link {
  my ($x, $m, $part_svc, $cust_svc) = @_ or return '';

  return $x
   unless $FS::CurrentUser::CurrentUser->access_right('View customer services');

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
  my($cgi, $field) = @_;

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
      my $search = "$field $op{$op} $num";
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
    'Cust. Status'             => 'ucfirst_cust_status',
    'Cust#'                    => 'custnum',
    'Name'                     => 'contact',
    'Company'                  => 'company',
    '(bill) Customer'          => 'name',
    '(service) Customer'       => 'ship_name',
    '(bill) Name'              => 'contact',
    '(service) Name'           => 'ship_contact',
    '(bill) Company'           => 'company',
    '(service) Company'        => 'ship_company',
    'Address 1'                => 'address1',
    'Address 2'                => 'address2',
    'City'                     => 'city',
    'State'                    => 'state',
    'Zip'                      => 'zip',
    'Country'                  => 'country_full',
    'Day phone'                => 'daytime', # XXX should use msgcat, but how?
    'Night phone'              => 'night',   # XXX should use msgcat, but how?
    'Fax number'               => 'fax',
    '(bill) Address 1'         => 'address1',
    '(bill) Address 2'         => 'address2',
    '(bill) City'              => 'city',
    '(bill) State'             => 'state',
    '(bill) Zip'               => 'zip',
    '(bill) Country'           => 'country_full',
    '(bill) Day phone'         => 'daytime', # XXX should use msgcat, but how?
    '(bill) Night phone'       => 'night',   # XXX should use msgcat, but how?
    '(bill) Fax number'        => 'fax',
    '(service) Address 1'      => 'ship_address1',
    '(service) Address 2'      => 'ship_address2',
    '(service) City'           => 'ship_city',
    '(service) State'          => 'ship_state',
    '(service) Zip'            => 'ship_zip',
    '(service) Country'        => 'ship_country_full',
    '(service) Day phone'      => 'ship_daytime', # XXX should use msgcat, how?
    '(service) Night phone'    => 'ship_night',   # XXX should use msgcat, how?
    '(service) Fax number'     => 'ship_fax',
    'Invoicing email(s)'       => 'invoicing_list_emailonly_scalar',
    'Payment Type'             => 'payby',
    'Current Balance'          => 'current_balance',
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

=item cust_sql_fields [ CUST_FIELDS_VALUE ]

Returns a list of fields for the SELECT portion of an SQL query.

As with L<the cust_header subroutine|/cust_header>, the fields returned are
defined by the supplied customer fields setting, or if no customer fields
setting is supplied, the <B>cust-fields</B> configuration value. 

=cut

sub cust_sql_fields {

  my @fields = qw( last first company );
  push @fields, map "ship_$_", @fields;
  push @fields, 'country';

  cust_header(@_);
  #inefficientish, but tiny lists and only run once per page

  my @add_fields = qw( address1 address2 city state zip daytime night fax );
  push @fields,
    grep { my $field = $_; grep { $_ eq $field } @cust_fields }
         ( @add_fields, ( map "ship_$_", @add_fields ), 'payby' );

  my @extra_fields = ();
  if (grep { $_ eq 'current_balance' } @cust_fields) {
    push @extra_fields, FS::cust_main->balance_sql . " AS current_balance";
  }

  map("cust_main.$_", @fields), @extra_fields;
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
      warn "  $record -> $_"
        if $DEBUG > 1;
      $record->$_(@_);
    } else {
      warn "  ($record unlinked)"
        if $DEBUG > 1;
      $seen_unlinked++ ? '' : '(unlinked)';
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

###
# begin JSRPC code...
###

package FS::UI::Web::JSRPC;

use strict;
use vars qw($DEBUG);
use Carp;
use Storable qw(nfreeze);
use MIME::Base64;
use JSON;
use FS::UID qw(getotaker);
use FS::Record qw(qsearchs);
use FS::queue;

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
  $param{CurrentUser} = getotaker();
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
  
  #warn 'froze string of size '. length(nfreeze(\%param)). " for job args\n"
  #  if $DEBUG;

  my $error = $job->insert( '_JOB', encode_base64(nfreeze(\%param)) );

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
  if ( $job && $job->status ne 'failed' ) {
    @return = ( 'progress', $job->statustext );
  } elsif ( !$job ) { #handle job gone case : job successful
                      # so close popup, redirect parent window...
    @return = ( 'complete' );
  } else {
    @return = ( 'error', $job ? $job->statustext : $jobnum );
  }

  objToJson(\@return);

}

1;

