package FS::UI::Web;

use vars qw($DEBUG);
use FS::Conf;
use FS::Record qw(dbdef);

#use vars qw(@ISA);
#use FS::UI
#@ISA = qw( FS::UI );

$DEBUG = 0;

use Date::Parse;
sub parse_beginning_ending {
  my($cgi) = @_;

  my $beginning = 0;
  if ( $cgi->param('begin') =~ /^(\d+)$/ ) {
    $beginning = $1;
  } elsif ( $cgi->param('beginning') =~ /^([ 0-9\-\/]{1,64})$/ ) {
    $beginning = str2time($1) || 0;
  }

  my $ending = 4294967295; #2^32-1
  if ( $cgi->param('end') =~ /^(\d+)$/ ) {
    $ending = $1 - 1;
  } elsif ( $cgi->param('ending') =~ /^([ 0-9\-\/]{1,64})$/ ) {
    #probably need an option to turn off the + 86399
    $ending = str2time($1) + 86399;
  }

  ( $beginning, $ending );
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

    if ( $cgi->param($field."_$op") =~ /^\s*\$?\s*([\d\,\s]+(\.\d\d)?)\s*$/ ) {

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

sub bytecount_unexact {
  my $bc = shift;
  return("$bc bytes")
    if ($bc < 1000);
  return(sprintf("%.2f Kbytes", $bc/1000))
    if ($bc < 1000000);
  return(sprintf("%.2f Mbytes", $bc/1000000))
    if ($bc < 1000000000);
  return(sprintf("%.2f Gbytes", $bc/1000000000));
}

###
# cust_main report subroutines
###


=item cust_header [ CUST_FIELDS_VALUE ]

Returns an array of customer information headers according to the supplied
customer fields value, or if no value is supplied, the B<cust-fields>
configuration value.

=cut

use vars qw( @cust_fields );

sub cust_header {

  warn "FS::svc_Common::cust_header called"
    if $DEBUG;

  my %header2method = (
    'Customer'                 => 'name',
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
    'Invoicing email(s)'       => 'invoicing_list_emailonly',
  );

  my $cust_fields;
  my @cust_header;
  if ( @_ && $_[0] ) {

    warn "  using supplied cust-fields override".
          " (ignoring cust-fields config file)"
      if $DEBUG;
    $cust_fields = shift;

  } else {

    my $conf = new FS::Conf;
    if (    $conf->exists('cust-fields')
         && $conf->config('cust-fields') =~ /^([\w \|\#\(\)]+):?/
       )
    {
      warn "  found cust-fields configuration value"
        if $DEBUG;
      $cust_fields = $1;
    } else { 
      warn "  no cust-fields configuration value found; using default 'Customer'"
        if $DEBUG;
      $cust_fields = 'Customer';
    }
  
  }

  @cust_header = split(/ \| /, $cust_fields);
  @cust_fields = map { $header2method{$_} } @cust_header;

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
  push @fields,
    grep { my $field = $_; grep { $_ eq $field } @cust_fields }
         qw( address1 address2 city state zip daytime night );

  map "cust_main.$_", @fields;
}

=item cust_fields SVC_OBJECT [ CUST_FIELDS_VALUE ]

Given a svc_ object that contains fields from cust_main (say, from a
JOINed search.  See httemplate/search/svc_* for examples), returns an array
of customer information, or "(unlinked)" if this service is not linked to a
customer.

As with L<the cust_header subroutine|/cust_header>, the fields returned are
defined by the supplied customer fields setting, or if no customer fields
setting is supplied, the <B>cust-fields</B> configuration value. 

=cut

sub cust_fields {
  my $svc_x = shift;
  warn "FS::svc_Common::cust_fields called for $svc_x ".
       "(cust_fields: @cust_fields)"
    if $DEBUG > 1;

  #cust_header(@_) unless @cust_fields; #now need to cache to keep cust_fields
  #                                     #override incase we were passed as a sub

  my $seen_unlinked = 0;
  map { 
    if ( $svc_x->custnum ) {
      warn "  $svc_x -> $_"
        if $DEBUG > 1;
      $svc_x->$_(@_);
    } else {
      warn "  ($svc_x unlinked)"
        if $DEBUG > 1;
      $seen_unlinked++ ? '' : '(unlinked)';
    }
  } @cust_fields;
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
use FS::UID;
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

