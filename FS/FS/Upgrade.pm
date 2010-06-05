package FS::Upgrade;

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG );
use Exporter;
use Tie::IxHash;
use FS::UID qw( dbh driver_name );
use FS::Conf;
use FS::Record qw(qsearchs str2time_sql);

use FS::svc_domain;
$FS::svc_domain::whois_hack = 1;

@ISA = qw( Exporter );
@EXPORT_OK = qw( upgrade upgrade_sqlradius );

$DEBUG = 1;

=head1 NAME

FS::Upgrade - Database upgrade routines

=head1 SYNOPSIS

  use FS::Upgrade;

=head1 DESCRIPTION

Currently this module simply provides a place to store common subroutines for
database upgrades.

=head1 SUBROUTINES

=over 4

=item

=cut

sub upgrade {
  my %opt = @_;

  my $data = upgrade_data(%opt);

  foreach my $table ( keys %$data ) {

    my $class = "FS::$table";
    eval "use $class;";
    die $@ if $@;

    if ( $class->can('_upgrade_data') ) {
      warn "Upgrading $table...\n";

      my $start = time;

      my $oldAutoCommit = $FS::UID::AutoCommit;
      local $FS::UID::AutoCommit = 0;
      local $FS::UID::AutoCommit = 0;

      $class->_upgrade_data(%opt);

      if ( $oldAutoCommit ) {
        dbh->commit or die dbh->errstr;
      }
      
      #warn "\e[1K\rUpgrading $table... done in ". (time-$start). " seconds\n";
      warn "  done in ". (time-$start). " seconds\n";

    } else {
      warn "WARNING: asked for upgrade of $table,".
           " but FS::$table has no _upgrade_data method\n";
    }

#    my @records = @{ $data->{$table} };
#
#    foreach my $record ( @records ) {
#      my $args = delete($record->{'_upgrade_args'}) || [];
#      my $object = $class->new( $record );
#      my $error = $object->insert( @$args );
#      die "error inserting record into $table: $error\n"
#        if $error;
#    }

  }

}


sub upgrade_data {
  my %opt = @_;

  tie my %hash, 'Tie::IxHash', 

    #cust_main (remove paycvv from history)
    'cust_main' => [],

    #msgcat
    'msgcat' => [],

    #reason type and reasons
    'reason_type'     => [],
    'cust_pkg_reason' => [],

    #need part_pkg before cust_credit...
    'part_pkg' => [],

    #customer credits
    'cust_credit' => [],

    #duplicate history records
    'h_cust_svc'  => [],

    #populate cust_pay.otaker
    'cust_pay'    => [],

    #populate part_pkg_taxclass for starters
    'part_pkg_taxclass' => [],

    #remove bad pending records
    'cust_pay_pending' => [],

    #replace invnum and pkgnum with billpkgnum
    'cust_bill_pkg_detail' => [],

    #usage_classes if we have none
    'usage_class' => [],

    #phone_type if we have none
    'phone_type' => [],

    #fixup access rights
    'access_right' => [],

    #change recur_flat and enable_prorate
    'part_pkg_option' => [],

    #add weights to pkg_category
    'pkg_category' => [],

    #cdrbatch fixes
    'cdr' => [],

    #otaker->usernum
    'cust_attachment' => [],
    #'cust_credit' => [],
    #'cust_main' => [],
    'cust_main_note' => [],
    #'cust_pay' => [],
    'cust_pay_void' => [],
    'cust_pkg' => [],
    #'cust_pkg_reason' => [],
    'cust_pkg_discount' => [],
    'cust_refund' => [],
    'banned_pay' => [],

  ;

  \%hash;

}

sub upgrade_sqlradius {
  #my %opt = @_;

  my $conf = new FS::Conf;

  my @part_export = FS::part_export::sqlradius->all_sqlradius_withaccounting();

  foreach my $part_export ( @part_export ) {

    my $errmsg = 'Error adding FreesideStatus to '.
                 $part_export->option('datasrc'). ': ';

    my $dbh = DBI->connect(
      ( map $part_export->option($_), qw ( datasrc username password ) ),
      { PrintError => 0, PrintWarn => 0 }
    ) or do {
      warn $errmsg.$DBI::errstr;
      next;
    };

    my $str2time = str2time_sql( $dbh->{Driver}->{Name} );
    my $group = "UserName";
    $group .= ",Realm"
      if ( ref($part_export) =~ /withdomain/ );

    my $sth_alter = $dbh->prepare(
      "ALTER TABLE radacct ADD COLUMN FreesideStatus varchar(32) NULL"
    );
    if ( $sth_alter ) {
      if ( $sth_alter->execute ) {
        my $sth_update = $dbh->prepare(
         "UPDATE radacct SET FreesideStatus = 'done' WHERE FreesideStatus IS NULL"
        ) or die $errmsg.$dbh->errstr;
        $sth_update->execute or die $errmsg.$sth_update->errstr;
      } else {
        my $error = $sth_alter->errstr;
        warn $errmsg.$error unless $error =~ /Duplicate column name/i;
      }
    } else {
      my $error = $dbh->errstr;
      warn $errmsg.$error; #unless $error =~ /exists/i;
    }

    my $sth_index = $dbh->prepare(
      "CREATE INDEX FreesideStatus ON radacct ( FreesideStatus )"
    );
    if ( $sth_index ) {
      unless ( $sth_index->execute ) {
        my $error = $sth_index->errstr;
        warn $errmsg.$error unless $error =~ /Duplicate key name/i;
      }
    } else {
      my $error = $dbh->errstr;
      warn $errmsg.$error; #unless $error =~ /exists/i;
    }

    my $sth = $dbh->prepare("SELECT UserName,
                                    Realm,
                                    $str2time max(AcctStartTime)),
                                    $str2time max(AcctStopTime))
                              FROM radacct
                              WHERE FreesideStatus = 'done'
                                AND AcctStartTime != 0
                                AND AcctStopTime  != 0
                              GROUP BY $group
                            ")
      or die $errmsg.$dbh->errstr;
    $sth->execute() or die $errmsg.$sth->errstr;
  
    while (my $row = $sth->fetchrow_arrayref ) {
      my ($username, $realm, $start, $stop) = @$row;
  
      $username = lc($username) unless $conf->exists('username-uppercase');

      my $exportnum = $part_export->exportnum;
      my $extra_sql = " AND exportnum = $exportnum ".
                      " AND exportsvcnum IS NOT NULL ";

      if ( ref($part_export) =~ /withdomain/ ) {
        $extra_sql = " AND '$realm' = ( SELECT domain FROM svc_domain
                         WHERE svc_domain.svcnum = svc_acct.domsvc ) ";
      }
  
      my $svc_acct = qsearchs({
        'select'    => 'svc_acct.*',
        'table'     => 'svc_acct',
        'addl_from' => 'LEFT JOIN cust_svc   USING ( svcnum )'.
                       'LEFT JOIN export_svc USING ( svcpart )',
        'hashref'   => { 'username' => $username },
        'extra_sql' => $extra_sql,
      });

      if ($svc_acct) {
        $svc_acct->last_login($start)
          if $start && (!$svc_acct->last_login || $start > $svc_acct->last_login);
        $svc_acct->last_logout($stop)
          if $stop && (!$svc_acct->last_logout || $stop > $svc_acct->last_logout);
      }
    }
  }

}

=back

=head1 BUGS

Sure.

=head1 SEE ALSO

=cut

1;

