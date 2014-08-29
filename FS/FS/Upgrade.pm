package FS::Upgrade;

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG );
use Exporter;
use Tie::IxHash;
use File::Slurp;
use FS::UID qw( dbh driver_name );
use FS::Conf;
use FS::Record qw(qsearchs qsearch str2time_sql);
use FS::queue;
use FS::upgrade_journal;

use FS::svc_domain;
$FS::svc_domain::whois_hack = 1;

@ISA = qw( Exporter );
@EXPORT_OK = qw( upgrade_schema upgrade_config upgrade upgrade_sqlradius );

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

=item upgrade_config

=cut

#config upgrades
sub upgrade_config {
  my %opt = @_;

  my $conf = new FS::Conf;

  $conf->touch('payment_receipt')
    if $conf->exists('payment_receipt_email')
    || $conf->config('payment_receipt_msgnum');

  $conf->touch('geocode-require_nw_coordinates')
    if $conf->exists('svc_broadband-require-nw-coordinates');

  unless ( $conf->config('echeck-country') ) {
    if ( $conf->exists('cust_main-require-bank-branch') ) {
      $conf->set('echeck-country', 'CA');
    } elsif ( $conf->exists('echeck-nonus') ) {
      $conf->set('echeck-country', 'XX');
    } else {
      $conf->set('echeck-country', 'US');
    }
  }

  upgrade_overlimit_groups($conf);
  map { upgrade_overlimit_groups($conf,$_->agentnum) } qsearch('agent', {});

  my $DIST_CONF = '/usr/local/etc/freeside/default_conf/';#DIST_CONF in Makefile
  $conf->set($_, scalar(read_file( "$DIST_CONF/$_" )) )
    foreach grep { ! $conf->exists($_) && -s "$DIST_CONF/$_" }
      qw( quotation_html quotation_latex quotation_latexnotes );

  # change 'fslongtable' to 'longtable'
  # in invoice and quotation main templates, and also in all secondary 
  # invoice templates
  my @latex_confs =
    qsearch('conf', { 'name' => {op=>'LIKE', value=>'%latex%'} });

  foreach my $c (@latex_confs) {
    my $value = $c->value;
    if (length($value) and $value =~ /fslongtable/) {
      $value =~ s/fslongtable/longtable/g;
      $conf->set($c->name, $value, $c->agentnum);
    }
  }

  # if there's a USPS tools login, assume that's the standardization method
  # you want to use
  $conf->set('address_standardize_method', 'usps')
    if $conf->exists('usps_webtools-userid')
    && length($conf->config('usps_webtools-userid')) > 0
    && ! $conf->exists('address_standardize_method');

  # this option has been renamed/expanded
  if ( $conf->exists('cust_main-enable_spouse_birthdate') ) {
    $conf->touch('cust_main-enable_spouse');
    $conf->delete('cust_main-enable_spouse_birthdate');
  }

  # renamed/repurposed
  if ( $conf->exists('cust_pkg-show_fcc_voice_grade_equivalent') ) {
    $conf->touch('part_pkg-show_fcc_options');
    $conf->delete('cust_pkg-show_fcc_voice_grade_equivalent');
    warn "
You have FCC Form 477 package options enabled.

Starting with the October 2014 filing date, the FCC has redesigned 
Form 477 and introduced new service categories.  See bin/convert-477-options
to update your package configuration for the new report.

If you need to continue using the old Form 477 report, turn on the
'old_fcc_report' configuration option.
";
  }

  # boolean invoice_sections_by_location option is now
  # invoice_sections_method = 'location'
  my @invoice_sections_confs =
    qsearch('conf', { 'name' => { op=>'LIKE', value=>'%sections_by_location' } });
  foreach my $c (@invoice_sections_confs) {
    $c->name =~ /^(\w+)sections_by_location$/;
    $conf->delete($c->name);
    my $newname = $1.'sections_method';
    $conf->set($newname, 'location');
  }

}

sub upgrade_overlimit_groups {
    my $conf = shift;
    my $agentnum = shift;
    my @groups = $conf->config('overlimit_groups',$agentnum); 
    if(scalar(@groups)) {
        my $groups = join(',',@groups);
        my @groupnums;
        my $error = '';
        if ( $groups !~ /^[\d,]+$/ ) {
            foreach my $groupname ( @groups ) {
                my $g = qsearchs('radius_group', { 'groupname' => $groupname } );
                unless ( $g ) {
                    $g = new FS::radius_group {
                                    'groupname' => $groupname,
                                    'description' => $groupname,
                                    };
                    $error = $g->insert;
                    die $error if $error;
                }
                push @groupnums, $g->groupnum;
            }
            $conf->set('overlimit_groups',join("\n",@groupnums),$agentnum);
        }
    }
}

=item upgrade

=cut

sub upgrade {
  my %opt = @_;

  my $data = upgrade_data(%opt);

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  local $FS::UID::AutoCommit = 0;

  local $FS::cust_pkg::upgrade = 1; #go away after setup+start dates cleaned up for old customers


  foreach my $table ( keys %$data ) {

    my $class = "FS::$table";
    eval "use $class;";
    die $@ if $@;

    if ( $class->can('_upgrade_data') ) {
      warn "Upgrading $table...\n";

      my $start = time;

      $class->_upgrade_data(%opt);

      # New interface for async upgrades: a class can declare a 
      # "queueable_upgrade" method, which will run as part of the normal 
      # upgrade, but if the -j option is passed, will instead be run from 
      # the job queue.
      if ( $class->can('queueable_upgrade') ) {
        my $jobname = $class . '::queueable_upgrade';
        my $num_jobs = FS::queue->count("job = '$jobname' and status != 'failed'");
        if ($num_jobs > 0) {
          warn "$class upgrade already scheduled.\n";
        } else {
          if ( $opt{'queue'} ) {
            warn "Scheduling $class upgrade.\n";
            my $job = FS::queue->new({ job => $jobname });
            $job->insert($class, %opt);
          } else {
            $class->queueable_upgrade(%opt);
          }
        } #$num_jobs == 0
      }

      if ( $oldAutoCommit ) {
        warn "  committing\n";
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

  local($FS::cust_main::ignore_expired_card) = 1;
  local($FS::cust_main::ignore_illegal_zip) = 1;
  local($FS::cust_main::ignore_banned_card) = 1;
  local($FS::cust_main::skip_fuzzyfiles) = 1;

  local($FS::cust_payby::ignore_expired_card) = 1;
  local($FS::cust_payby::ignore_banned_card) = 1;

  # decrypt inadvertantly-encrypted payinfo where payby != CARD,DCRD,CHEK,DCHK
  # kind of a weird spot for this, but it's better than duplicating
  # all this code in each class...
  my @decrypt_tables = qw( cust_main cust_pay_void cust_pay cust_refund cust_pay_pending );
  foreach my $table ( @decrypt_tables ) {
      my @objects = qsearch({
        'table'     => $table,
        'hashref'   => {},
        'extra_sql' => "WHERE payby NOT IN ( 'CARD', 'DCRD', 'CHEK', 'DCHK' ) ".
                       " AND LENGTH(payinfo) > 100",
      });
      foreach my $object ( @objects ) {
          my $payinfo = $object->decrypt($object->payinfo);
          die "error decrypting payinfo" if $payinfo eq $object->payinfo;
          $object->payinfo($payinfo);
          my $error = $object->replace;
          die $error if $error;
      }
  }

}

=item upgrade_data

=cut

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

    #default namespace
    'payment_gateway' => [],

    #migrate to templates
    'msg_template' => [],

    #return unprovisioned numbers to availability
    'phone_avail' => [],

    #insert scripcondition
    'TicketSystem' => [],
    
    #insert LATA data if not already present
    'lata' => [],
    
    #insert MSA data if not already present
    'msa' => [],

    # migrate to radius_group and groupnum instead of groupname
    'radius_usergroup' => [],
    'part_svc'         => [],
    'part_export'      => [],

    #insert default tower_sector if not present
    'tower' => [],

    #repair improperly deleted services
    'cust_svc' => [],

    #routernum/blocknum
    'svc_broadband' => [],

    #set up payment gateways if needed
    'pay_batch' => [],

    #flag monthly tax exemptions
    'cust_tax_exempt_pkg' => [],

    #kick off tax location history upgrade
    'cust_bill_pkg' => [],

    #fix taxable line item links
    'cust_bill_pkg_tax_location' => [],

    #populate state FIPS codes if not already done
    'state' => [],
  ;

  \%hash;

}

=item upgrade_schema

=cut

sub upgrade_schema {
  my %opt = @_;

  my $data = upgrade_schema_data(%opt);

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  local $FS::UID::AutoCommit = 0;

  foreach my $table ( keys %$data ) {

    my $class = "FS::$table";
    eval "use $class;";
    die $@ if $@;

    if ( $class->can('_upgrade_schema') ) {
      warn "Upgrading $table schema...\n";

      my $start = time;

      $class->_upgrade_schema(%opt);

      if ( $oldAutoCommit ) {
        warn "  committing\n";
        dbh->commit or die dbh->errstr;
      }
      
      #warn "\e[1K\rUpgrading $table... done in ". (time-$start). " seconds\n";
      warn "  done in ". (time-$start). " seconds\n";

    } else {
      warn "WARNING: asked for schema upgrade of $table,".
           " but FS::$table has no _upgrade_schema method\n";
    }

  }

}

=item upgrade_schema_data

=cut

sub upgrade_schema_data {
  my %opt = @_;

  tie my %hash, 'Tie::IxHash', 

    #fix classnum character(1)
    'cust_bill_pkg_detail' => [],
    #add necessary columns to RT schema
    'TicketSystem' => [],

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
      if ref($part_export) =~ /withdomain/
      || $dbh->{Driver}->{Name} =~ /^Pg/; #hmm

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
        warn $errmsg.$error
          unless $error =~ /Duplicate column name/i  #mysql
              || $error =~ /already exists/i;        #Pg
;
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
        warn $errmsg.$error
          unless $error =~ /Duplicate key name/i #mysql
              || $error =~ /already exists/i;    #Pg
      }
    } else {
      my $error = $dbh->errstr;
      warn $errmsg.$error. ' (preparing statement)';#unless $error =~ /exists/i;
    }

    my $times = ($dbh->{Driver}->{Name} =~ /^mysql/)
      ? ' AcctStartTime != 0 AND AcctStopTime != 0 '
      : ' AcctStartTime IS NOT NULL AND AcctStopTime IS NOT NULL ';

    my $sth = $dbh->prepare("SELECT UserName,
                                    Realm,
                                    $str2time max(AcctStartTime)),
                                    $str2time max(AcctStopTime))
                              FROM radacct
                              WHERE FreesideStatus = 'done'
                                AND $times
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

