package FS::part_export::phone_sqlradius;

use vars qw(@ISA $DEBUG %info );
use Tie::IxHash;
use FS::Record qw( dbh str2time_sql ); #qsearch qsearchs );
#use FS::part_export;
use FS::part_export::sqlradius;
#use FS::svc_phone;
#use FS::export_svc;
#use Carp qw( cluck );

@ISA = qw(FS::part_export::sqlradius);

$DEBUG = 0;

tie %options, 'Tie::IxHash',
  'datasrc'  => { label=>'DBI data source ' },
  'username' => { label=>'Database username' },
  'password' => { label=>'Database password' },
  'ignore_accounting' => {
    type  => 'checkbox',
    label => 'Ignore accounting records from this database'
  },
  'hide_ip' => {
    type  => 'checkbox',
    label => 'Hide IP address information on session reports',
  },
  'hide_data' => {
    type  => 'checkbox',
    label => 'Hide download/upload information on session reports',
  },

  #should be default for this one, right?
  #'show_called_station' => {
  #  type  => 'checkbox',
  #  label => 'Show the Called-Station-ID on session reports',
  #},

  #N/A
  #'overlimit_groups' => { label => 'Radius groups to assign to svc_acct which has exceeded its bandwidth or time limit', } ,
  #'groups_susp_reason' => { label =>
  #                           'Radius group mapping to reason (via template user) (svcnum|username|username@domain  reasonnum|reason)',
  #                          type  => 'textarea',
  #                        },

;

%info = (
  'svc'      => 'svc_phone',
  'desc'     => 'Real-time export to SQL-backed RADIUS (FreeRADIUS, ICRADIUS) for phone provisioning and rating',
  'options'  => \%options,
  'notes'    => <<END,
Real-time export of <b>radcheck</b> table
<!--, <b>radreply</b> and <b>usergroup</b>-- tables>
to any SQL database for <a href="http://www.freeradius.org/">FreeRADIUS</a>
or <a href="http://radius.innercite.com/">ICRADIUS</a>.
<br><br>

This export is for phone/VoIP provisioning and rating.  For a regular RADIUS
export, see sqlradius.
<br><br>

<!--An existing RADIUS database will be updated in realtime, but you can use
<a href="http://www.freeside.biz/mediawiki/index.php/Freeside:1.9:Documentation:Developer/bin/freeside-phone_sqlradius-reset">freeside-phone_sqlradius-reset</a>
to delete the entire RADIUS database and repopulate the tables from the
Freeside database.
<br><br>
-->

See the
<a href="http://search.cpan.org/dist/DBI/DBI.pm#connect">DBI documentation</a>
and the
<a href="http://search.cpan.org/search?mode=module&query=DBD%3A%3A">documentation for your DBD</a>
for the exact syntax of a DBI data source.

END
);

sub rebless { shift; }

sub export_username {
  my($self, $svc_phone) = (shift, shift);
  $svc_phone->countrycode. $svc_phone->phonenum;
}

sub _export_suspend {}
sub _export_unsuspend {}

#probably harmless that we ->can('usage_sessions').... ?

#we want to feed these into CDRs, not update svc_acct records
sub update_svc {
  my $self = shift;

  my $fdbh = dbh;
  my $dbh = sqlradius_connect( map $self->option($_),
                                   qw( datasrc username password ) );

  my $str2time = str2time_sql( $dbh->{Driver}->{Name} );



  my @fields = qw( radacctid username realm acctsessiontime );

  my @param = ();
  my $where = '';

  my $sth = $dbh->prepare("
    SELECT RadAcctId, UserName, AcctSessionTime,
           $str2time AcctStartTime),  $str2time AcctStopTime), 
           CallingStationID, CalledStationID
      FROM radacct
      WHERE FreesideStatus IS NULL
        AND AcctStopTime != 0
  ") or die $dbh->errstr;
  $sth->execute() or die $sth->errstr;

  while ( my $row = $sth->fetchrow_arrayref ) {
    my( $RadAcctId, $UserName, $AcctSessionTime,
        $AcctStartTime, $AcctStopTime, 
        $CallingStationID, $CalledStationID,
      )= @$row;
    warn "processing record: ".
         "$RadAcctId ($UserName for ${AcctSessionTime}s"
      if $DEBUG;

    my $oldAutoCommit = $FS::UID::AutoCommit; # can't undo side effects, but at
    local $FS::UID::AutoCommit = 0;           # least we can avoid over counting

    my $cdr = new FS::cdr {
      'src'           => $CallingStationID,
      'charged_party' => $UserName,
      'dst'           => $CalledStationID,
      'startdate'     => $AcctStartTime,
      'enddate'       => $AcctStopTime,
      'duration'      => $AcctStopTime - $AcctStartTime,
      'billsec'       => $AcctSessionTime,
    };

    my $errinfo = "for RADIUS detail RadAcctID $RadAcctId ".
                  "(UserName $UserName)";

    my $error = $cdr->insert;
    my $status = $error ? 'skipped' : 'done';

    warn "setting FreesideStatus to $status $errinfo\n" if $DEBUG; 
    my $psth = $dbh->prepare("UPDATE radacct
                                SET FreesideStatus = ?
                                WHERE RadAcctId = ?"
    ) or die $dbh->errstr;
    $psth->execute($status, $RadAcctId) or die $psth->errstr;

    $fdbh->commit or die $fdbh->errstr if $oldAutoCommit;

  }

}

1;

