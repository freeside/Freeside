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
  my $dbh = $self->opensips_connect;
  my $sth = $dbh->prepare("insert into dr_rules ".
	    "( groupid, prefix, timerec, routeid, gwlist, description ) ".
	    " values ( ?, ?, ?, ?, ?, ? )") or die $dbh->errstr;
  $sth->execute('0',$svc_x->phonenum,'',$svc_x->route,$svc_x->gwlist,
		$svc_x->phone_name) or die $sth->errstr;
  $dbh->disconnect;
  $self->dr_reload;
}

sub opensips_connect {
    my $self = shift;
    DBI->connect($self->option('datasrc'),$self->option('username'),
			$self->option('password')) or die $DBI::errstr;
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
    my @update = ();
    my @paramvalues = ();

    if($old->route ne $new->route){
	push @update, 'routeid = ?';
	push @paramvalues, $new->route;
    }

    if($old->phone_name ne $new->phone_name) {
	push @update, 'description = ?';
	push @paramvalues, $new->phone_name;
    }

    if($old->gwlist ne $new->gwlist) {
	push @update, 'gwlist = ?';
	push @paramvalues, $new->gwlist;
    }

    if(scalar(@update)) {
      my $update_str = join(' and ',@update);
      my $dbh = $self->opensips_connect;
      my $sth = $dbh->prepare("update dr_rules set $update_str " . 
	    " where prefix = ? ") or die $dbh->errstr;
      push @paramvalues, $old->phonenum;
      $sth->execute(@paramvalues) or die $sth->errstr;
      $dbh->disconnect;
      return $self->dr_reload;
    }
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
  $self->dr_reload;
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

