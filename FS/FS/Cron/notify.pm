package FS::Cron::notify;

use strict;
use vars qw( @ISA @EXPORT_OK $DEBUG );
use Exporter;
use FS::UID qw( dbh driver_name );
use FS::Record qw(qsearch qsearchs);
use FS::cust_main;
use FS::cust_pkg;

@ISA = qw( Exporter );
@EXPORT_OK = qw ( notify_flat_delay );
$DEBUG = 0;

sub notify_flat_delay {

  my %opt = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  $DEBUG = 1 if $opt{'v'};
  
  #we're at now now (and later).
  my($time) = $^T;
  my $conf = new FS::Conf;
  my $error = '';

  my $integer = driver_name =~ /^mysql/ ? 'SIGNED' : 'INTEGER';

  # select * from cust_pkg where
  my $where_pkg = <<"END";
    WHERE ( cancel IS NULL OR cancel = 0 )
      AND ( bill > 0 )
      AND EXISTS (
        SELECT 1 FROM part_pkg
          WHERE cust_pkg.pkgpart = part_pkg.pkgpart
            AND part_pkg.plan = 'flat_delayed'
            AND EXISTS ( SELECT 1 from part_pkg_option
                           WHERE part_pkg.pkgpart = part_pkg_option.pkgpart
                             AND part_pkg_option.optionname = 'recur_notify'
                             AND CAST( part_pkg_option.optionvalue AS $integer ) > 0
                             AND 0 <= ( $time
                                        + CAST( part_pkg_option.optionvalue AS $integer )
                                          * 86400
                                        - cust_pkg.bill
                                      )
                             AND (    cust_pkg.expire is null
                                   OR cust_pkg.expire > ( $time
                                                          + CAST( part_pkg_option.optionvalue AS $integer )
                                                            * 86400
                                                        )
END

#/*                           and (     cust_pkg.adjourn is null
#                                    or cust_pkg.adjourn > $time
#-- Should notify suspended ones  + cast(part_pkg_option.optionvalue as $integer)
#                                          * 86400
#*/

  $where_pkg .= <<"END";
                                 )
                       )
      )
      AND NOT EXISTS (
        SELECT 1 from cust_pkg_option
          WHERE cust_pkg.pkgnum = cust_pkg_option.pkgnum
            AND cust_pkg_option.optionname = 'impending_recur_notification_sent'
            AND CAST( cust_pkg_option.optionvalue AS $integer ) = 1
      )
END
  
  if ($opt{a}) {
    $where_pkg .= <<END;
      AND EXISTS ( SELECT 1 from cust_main
                     WHERE cust_pkg.custnum = cust_main.custnum
                       AND cust_main.agentnum IN ( $opt{a} )
                 )
END
  }
  
  my @cust_pkg;
  if ( @ARGV ) {
    $where_pkg .= "and ( " . join( "OR ", map { "custnum = $_" } @ARGV) . " )";
  } 

  my $orderby = "order by custnum, bill";

  my $extra_sql = "$where_pkg $orderby";

  @cust_pkg = qsearch('cust_pkg', {}, '', $extra_sql );
  
  my @packages = ();
  my @recurdates = ();
  my @cust_pkgs = ();
  while ( scalar(@cust_pkg) ) {
    my $cust_main = $cust_pkg[0]->cust_main;
    my $custnum = $cust_pkg[0]->custnum;
    warn "working on $custnum" if $DEBUG;
    while (scalar(@cust_pkg)){
      last if ($cust_pkg[0]->custnum != $custnum);
      warn "storing information on " . $cust_pkg[0]->pkgnum if $DEBUG;
      push @packages, $cust_pkg[0]->part_pkg->pkg;
      push @recurdates, $cust_pkg[0]->bill;
      push @cust_pkgs, $cust_pkg[0];
      shift @cust_pkg;
    }
    my $msgnum = $conf->config('impending_recur_msgnum',$cust_main->agentnum);
    if ( $msgnum ) {
      my $msg_template = qsearchs('msg_template', { msgnum => $msgnum });
      $cust_main->setfield('packages', \\@packages);
      $cust_main->setfield('recurdates', \\@recurdates);
      $error = $msg_template->send('cust_main' => $cust_main,
                                   'object'    => $cust_main);
    }
    else {
      $error = $cust_main->notify( 'impending_recur_template',
                          'extra_fields' => { 'packages'   => \@packages,
                                              'recurdates' => \@recurdates,
                                              'package'    => $packages[0],
                                              'recurdate'  => $recurdates[0],
                                            },
                        );
    } #if $msgnum
    warn "Error notifying, custnum ". $cust_main->custnum. ": $error" if $error;

    unless ($error) { 
      local $SIG{HUP} = 'IGNORE';
      local $SIG{INT} = 'IGNORE';
      local $SIG{QUIT} = 'IGNORE';
      local $SIG{TERM} = 'IGNORE';
      local $SIG{TSTP} = 'IGNORE';

      my $oldAutoCommit = $FS::UID::AutoCommit;
      local $FS::UID::AutoCommit = 0;
      my $dbh = dbh;

      for (@cust_pkgs) {
        my %options = ($_->options,  'impending_recur_notification_sent' => 1 );
        $error = $_->replace( $_, options => \%options );
        if ($error){
          $dbh->rollback or die $dbh->errstr if $oldAutoCommit;
          die "Error updating package options for customer". $cust_main->custnum.
               ": $error" if $error;
        }
      }

      $dbh->commit or die $dbh->errstr if $oldAutoCommit;

    }

    @packages = ();
    @recurdates = ();
    @cust_pkgs = ();
  
  }

  dbh->commit or die dbh->errstr if $oldAutoCommit;

}

1;
