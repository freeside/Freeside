package FS::UI::Web;

#use vars qw(@ISA);
#use FS::UI
#@ISA = qw( FS::UI );


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

  my %param = @_;
  warn "FS::UI::Web::start_job\n".
       join('', map "  $_ => $param{$_}\n", keys %param )
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

