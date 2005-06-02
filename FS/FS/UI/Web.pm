package FS::UI::Web;

#use vars qw(@ISA);
#use FS::UI
#@ISA = qw( FS::UI );

use Date::Parse;
sub parse_beginning_ending {
  my($cgi) = @_;

  $cgi->param('beginning') =~ /^([ 0-9\-\/]{0,10})$/;
  my $beginning = str2time($1) || 0;

  #need an option to turn off the + 86399 ???
  $cgi->param('ending') =~ /^([ 0-9\-\/]{0,10})$/;
  my $ending =  ( $1 ? str2time($1) : 4294880896 ) + 86399;

  ( $beginning, $ending );
}

# begin JSRPC code...

package FS::UI::Web::JSRPC;

use strict;
use vars qw(@ISA $DEBUG);
use Storable qw(nfreeze);
use MIME::Base64;
use JavaScript::RPC::Server::CGI;
use FS::UID;
use FS::Record qw(qsearchs);
use FS::queue;

@ISA = qw( JavaScript::RPC::Server::CGI );
$DEBUG = 0;

sub new {
        my $class = shift;
        my $self  = {
                env => {},
                job => shift,
        };

        bless $self, $class;

        return $self;
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
    $error;
  } else {
    $job->jobnum;
  }
  
}

sub job_status {
  my( $self, $jobnum ) = @_; #$url ???

  sleep 5; #could use something better...

  my $job;
  if ( $jobnum =~ /^(\d+)$/ ) {
    $job = qsearchs('queue', { 'jobnum' => $jobnum } );
  } else {
    die "FS::UI::Web::job_status: illegal jobnum $jobnum\n";
  }

  my @return;
  if ( $job && $job->status ne 'failed' ) {
    @return = ( 'progress', $job->statustext );
  } elsif ( !$job ) { #handle job gone case : job sucessful
                      # so close popup, redirect parent window...
    @return = ( 'complete' );
  } else {
    @return = ( 'error', $job ? $job->statustext : $jobnum );
  }

  join("\n",@return);

}

sub get_new_query {
  FS::UID::cgi();
}

1;

