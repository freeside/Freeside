package FS::part_export::cpanel;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::part_export;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'user'       => { label=>'Remote access username' },
  'accesshash' => { label=>'Remote access key', type=>'textarea' },
  'debug'      => { label=>'Enable debugging', type=>'checkbox' },
;

%info = (
  'svc'      => 'svc_acct',
  'desc'     => 'Real-time export to Cpanel control panel.',
  'options'  => \%options,
  'nodomain' => 'Y',
  'notes'    => 'Real time export to a the <a href="http://www.cpanel.net/">Cpanel</a> control panel software.  Service definition names are exported as Cpanel packages.  Requires installation of the Cpanel::Accounting perl module distributed with Cpanel.',
);

sub rebless { shift; }

sub _export_insert { 
  my($self, $svc_acct) = (shift, shift);
  $err_or_queue = $self->cpanel_queue( $svc_acct->svcnum, 'insert',
    $svc_acct->domain,
    $svc_acct->username,
    $svc_acct->_password,
    $svc_acct->cust_svc->part_svc->svc,
  );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return "can't change username with cpanel"
    if $old->username ne $new->username;
  return "can't change password with cpanel"
    if $old->_passsword ne $new->_password;
  return "can't change domain with cpanel"
    if $old->domain ne $new->domain;

  '';

  ##return '' unless $old->_password ne $new->_password;
  #$err_or_queue = $self->cpanel_queue( $new->svcnum,
  #  'replace', $new->username, $new->_password );
  #ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_delete {
  my( $self, $svc_acct ) = (shift, shift);
  $err_or_queue = $self->cpanel_queue( $svc_acct->svcnum,
    'delete', $svc_acct->username
  );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_suspend {
  my( $self, $svc_acct ) = (shift, shift);
  $err_or_queue = $self->cpanel_queue( $svc_acct->svcnum,
    'suspend', $svc_acct->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}

sub _export_unsuspend {
  my( $self, $svc_acct ) = (shift, shift);
  $err_or_queue = $self->cpanel_queue( $svc_acct->svcnum,
    'unsuspend', $svc_acct->username );
  ref($err_or_queue) ? '' : $err_or_queue;
}


sub cpanel_queue {
  my( $self, $svcnum, $method ) = (shift, shift, shift);
  my $queue = new FS::queue {
    'svcnum' => $svcnum,
    'job'    => "FS::part_export::cpanel::cpanel_$method",
  };
  $queue->insert(
    $self->machine,
    $self->option('user'),
    $self->option('accesshash'),
    $self->option('debug'),
    @_ 
  ) or $queue;
}


sub cpanel_insert { #subroutine, not method
  my( $machine, $user, $accesshash, $debug ) = splice(@_,0,4);

#  my $whm = cpanel_connect($machine, $user, $accesshash, $debug);
#  warn "  cpanel->createacct ". join(', ', @_). "\n"
#    if $debug;
#  my $response = $whm->createacct(@_);
#  die $whm->{'error'} if $whm->{'error'};
#  warn "  cpanel response: $response\n"
#    if $debug;

  warn "cpanel_insert: attempting web interface to add POP"
    if $debug;

  my($domain, $username, $password, $svc) = @_;

  use LWP::UserAgent;
  use HTTP::Request::Common qw(POST);

  my $url =
    "http://$user:$accesshash\@$domain:2082/frontend/x/mail/addpop2.html";

  my $ua = LWP::UserAgent->new();

  #$req->authorization_basic($user, $accesshash);

  my $res = $ua->request(
    POST( $url,
          [ 
            'email'    => $username,
            'domain'   => $domain,
            'password' => $password,
            'quota'    => 10, #?
          ] 
        )
  );

  die "Error submitting data to $url: ". $res->status_line
    unless $res->is_success;

  die "Username in use"
    if $res->content =~ /exists/;

  die "Account not created: ". $res->content
    if $res->content =~ /failure/;

}

#sub cpanel_replace { #subroutine, not method
#}

sub cpanel_delete { #subroutine, not method
  my( $machine, $user, $accesshash, $debug ) = splice(@_,0,4);
  my $whm = cpanel_connect($machine, $user, $accesshash, $debug);
  warn "  cpanel->killacct ". join(', ', @_). "\n"
    if $debug;
  my $response = $whm->killacct(shift);
  die $whm->{'error'} if $whm->{'error'};
  warn "  cpanel response: $response\n"
    if $debug;
}

sub cpanel_suspend { #subroutine, not method
  my( $machine, $user, $accesshash, $debug ) = splice(@_,0,4);
  my $whm = cpanel_connect($machine, $user, $accesshash, $debug);
  warn "  cpanel->suspend ". join(', ', @_). "\n"
    if $debug;
  my $response = $whm->suspend(shift);
  die $whm->{'error'} if $whm->{'error'};
  warn "  cpanel response: $response\n"
    if $debug;
}

sub cpanel_unsuspend { #subroutine, not method
  my( $machine, $user, $accesshash, $debug ) = splice(@_,0,4);
  my $whm = cpanel_connect($machine, $user, $accesshash, $debug);
  warn "  cpanel->unsuspend ". join(', ', @_). "\n"
    if $debug;
  my $response = $whm->unsuspend(shift);
  die $whm->{'error'} if $whm->{'error'};
  warn "  cpanel response: $response\n"
    if $debug;
}

sub cpanel_connect {
  my( $host, $user, $accesshash, $debug ) = @_;

  eval "use Cpanel::Accounting;";
  die $@ if $@;

  warn "creating new Cpanel::Accounting connection to $user@$host\n"
    if $debug;

  my $whm = new Cpanel::Accounting;
  $whm->{'host'}       = $host;
  $whm->{'user'}       = $user;
  $whm->{'accesshash'} = $accesshash;
  $whm->{'usessl'}     = 1;

  $whm;
}

1;
