package FS::UI::Web;

#use vars qw(@ISA);
#use FS::UI
#@ISA = qw( FS::UI );


# begin JSRPC code...

package FS::UI::Web::JSRPC;

use vars qw(@ISA $DEBUG);
use Storable qw(nfreeze);
use MIME::Base64;
use JavaScript::RPC::Server::CGI;
use FS::UID;

@ISA = qw( JavaScript::RPC::Server::CGI );
$DEBUG = 1;

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

  #progressbar prototype code...  should be generalized
  
  #first get the CGI params shipped off to a job ASAP so an id can be returned
  #to the caller
  
  #my $job = new FS::queue { 'job' => 'FS::rate::process' };
  my $job = new FS::queue { 'job' => $self->{'job'} };
  
  #too slow to insert all the cgi params as individual args..,?
  #my $error = $queue->insert('_JOB', $cgi->Vars);
  
  #my $bigstring = join(';', map { "$_=". scalar($cgi->param($_)) } $cgi->param );
#  my $bigstring = join(';', map { "$_=". $param{$_} } keys %param );
#  my $error = $job->insert('_JOB', $bigstring);

  #warn 'froze string of size '. length(nfreeze(\%param)). " for job args\n"
  #  if $DEBUG;

  my $error = $job->insert( '_JOB', encode_base64(nfreeze(\%param)) );

  if ( $error ) {
    $error;
  } else {
    $job->jobnum;
  }
  
}
