package FS::part_export::phone_sqlopensips;

use vars qw(@ISA @EXPORT_OK %info %options);
use Exporter;
use Tie::IxHash;
use FS::Record qw( dbh qsearch qsearchs );
use FS::part_export;
use FS::svc_phone;
use FS::export_svc;
use LWP::UserAgent;

@ISA = qw(FS::part_export);

tie %options, 'Tie::IxHash',
  'datasrc'  => { label=>'DBI data source ' },
  'username' => { label=>'Database username' },
  'password' => { label=>'Database password' },
  'xmlrpc_url' => { label=>'XMLRPC URL' },
  # XXX: in future, add non-agent-virtualized config, i.e. per-export setting of gwlist, routeid, description, etc.
  # and/or setting description from the phone_name column
;

%info = (
  'svc'      => 'svc_phone',
  'desc'     => 'Export DIDs to OpenSIPs dr_rules table',
  'options'  => \%options,
  'notes'    => 'Export DIDs to OpenSIPs dr_rules table',
);

sub rebless { shift; }

sub _export_insert {
  my($self, $svc_x) = (shift, shift);

  my $conf = new FS::Conf;
  my $agentnum = $svc_x->cust_svc->cust_pkg->cust_main->agentnum || 0;
  my $gwlist = $conf->config('opensips_gwlist',$agentnum) || '';
  my $description = $conf->config('opensips_description',$agentnum) || '';
  my $route = $conf->config('opensips_route',$agentnum) || '';

  my $dbh = $self->opensips_connect;
  my $sth = $dbh->prepare("insert into dr_rules ".
	    "( groupid, prefix, timerec, routeid, gwlist, description ) ".
	    " values ( ?, ?, ?, ?, ?, ? )") or die $dbh->errstr;
  $sth->execute('0',$svc_x->phonenum,'',$route,$gwlist,$description)
	    or die $sth->errstr;
  $dbh->disconnect;
  $self->dr_reload; # XXX: if this fails, do we delete what we just inserted?
}

sub opensips_connect {
    my $self = shift;
    DBI->connect($self->option('datasrc'),$self->option('username'),
			$self->option('password')) or die $DBI::errstr;
}

sub _export_replace {
   '';
}

sub _export_suspend {
  my( $self, $svc_phone ) = (shift, shift);
  '';
}

sub _export_unsuspend {
  my( $self, $svc_phone ) = (shift, shift);
  '';
}

sub _export_delete {
  my( $self, $svc_x ) = (shift, shift);
  my $dbh = $self->opensips_connect;
  my $sth = $dbh->prepare("delete from dr_rules where prefix = ?")
    or die $dbh->errstr;
  $sth->execute($svc_x->phonenum) or die $sth->errstr;
  $dbh->disconnect;
  $self->dr_reload; # XXX: if this fails, do we re-insert what we just deleted?
}

sub dr_reload {
    my $self = shift;
    my $reqxml = "<?xml version=\"1.0\"?>
<methodCall>
  <methodName>dr_reload</methodName>
</methodCall>";
    my $ua = LWP::UserAgent->new;
    my $resp = $ua->post(   $self->option('xmlrpc_url'),
			    Content_Type => 'text/xml', 
			    Content => $reqxml );
    return "invalid HTTP response from OpenSIPS: " . $resp->status_line
	unless $resp->is_success;
    '';
}

