#
#  Discovery module for Arbor|e Series devices
#  Formerly Ellacoya Networks
#
#  Copyright (C) 2008 Jon Nistor
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.
#
# $Id: Arbor_E.pm,v 1.1.1.1.2.1 2011-12-16 22:43:56 ivan Exp $
# Jon Nistor <nistor at snickers.org>
#
# NOTE: This module has been tested against v7.5.x, v7.6.x, v9.0.x, v9.1.x
#
# -- Common
#      Arbor_E::disable-bundle-offer
#      Arbor_E::disable-bundle-offer-deny
#      Arbor_E::disable-bundle-offer-pktsize
#      Arbor_E::disable-bundle-offer-rate
#      Arbor_E::disable-bundle-offer-subcount
#      Arbor_E::enable-bundle-name-rrd
#      Arbor_E::disable-flowdev
#
# -- e30 specific
#      Arbor_E::disable-e30-buffers
#      Arbor_E::disable-e30-bundle
#      Arbor_E::disable-e30-cpu
#      Arbor_E::disable-e30-fwdTable
#      Arbor_E::disable-e30-fwdTable-login
#      Arbor_E::disable-e30-hdd
#      Arbor_E::enable-e30-hdd-errors
#      Arbor_E::disable-e30-hdd-logs
#      Arbor_E::disable-e30-l2tp
#      Arbor_E::disable-e30-mem
#      Arbor_E::enable-e30-mempool
#      Arbor_E::disable-e30-bundle
#      Arbor_E::disable-e30-bundle-deny
#      Arbor_E::disable-e30-bundle-rate
#      Arbor_E::disable-e30-slowpath 
#
# -- e100 specific
#      Arbor_E::disable-e100-cpu
#      Arbor_E::disable-e100-hdd
#      Arbor_E::disable-e100-mem
#      Arbor_E::disable-e100-policymgmt
#      Arbor_E::disable-e100-submgmt
#

# Arbor_E devices discovery
package Torrus::DevDiscover::Arbor_E;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'Arbor_E'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };

our %oiddef =
    (
     # ELLACOYA-MIB
     'eProducts'	     => '1.3.6.1.4.1.3813.2',
     'codeVer'               => '1.3.6.1.4.1.3813.1.4.1.1.0',
     'sysIdSerialNum'	     => '1.3.6.1.4.1.3813.1.4.1.5.2.0',
     'memPoolNameIndex'      => '1.3.6.1.4.1.3813.1.4.2.5.1.1',
     'hDriveErrModel'        => '1.3.6.1.4.1.3813.1.4.2.10.16.0',
     'hDriveErrSerialNum'    => '1.3.6.1.4.1.3813.1.4.2.10.17.0',
     'partitionName'         => '1.3.6.1.4.1.3813.1.4.2.11.1.2', # e100
     'cpuSdramIndex'         => '1.3.6.1.4.1.3813.1.4.2.12.1.1', # e100
     'hDriveDailyLogSize'    => '1.3.6.1.4.1.3813.1.4.2.13.0',
     'cpuUtilization'	     => '1.3.6.1.4.1.3813.1.4.4.1.0',
     'cpuUtilTable'          => '1.3.6.1.4.1.3813.1.4.4.2',      # e100
     'cpuIndex'		     => '1.3.6.1.4.1.3813.1.4.4.2.1.1',  # e100
     'cpuName'               => '1.3.6.1.4.1.3813.1.4.4.2.1.2',  # e100
     'loginRespOkStatsIndex' => '1.3.6.1.4.1.3813.1.4.3.15.1.1',

     # ELLACOYA-MIB::cpuCounters, e30 (available in 7.5.x -- slowpath counters)
     'cpuCounters'           => '1.3.6.1.4.1.3813.1.4.4.10',
     'slowpathCounters'      => '1.3.6.1.4.1.3813.1.4.4.10.1',
     'sigCounters'           => '1.3.6.1.4.1.3813.1.4.4.10.2',

     # ELLACOYA-MIB::flow
     'flowPoolNameD1'        => '1.3.6.1.4.1.3813.1.4.5.1.1.1.2',
     'flowPoolNameD2'        => '1.3.6.1.4.1.3813.1.4.5.2.1.1.2',

     # ELLACOYA-MIB::bundleStatsTable
     'bundleName'                    => '1.3.6.1.4.1.3813.1.4.12.1.1.2',
     'bundleBytesSentDenyPolicyDrop' => '1.3.6.1.4.1.3813.1.4.12.1.1.6',
     'bundleBytesSentRateLimitDrop'  => '1.3.6.1.4.1.3813.1.4.12.1.1.8',
     'boBundleID'                    => '1.3.6.1.4.1.3813.1.4.12.2.1.1',
     'boBundleName'                  => '1.3.6.1.4.1.3813.1.4.12.2.1.3',
     'boOfferName'                   => '1.3.6.1.4.1.3813.1.4.12.2.1.4',
     'boBundleSubCount'              => '1.3.6.1.4.1.3813.1.4.12.2.1.7',
     'boPacketsSent64'               => '1.3.6.1.4.1.3813.1.4.12.2.1.8',
     'boBundleBytesSentDenyPolicyDrop' => '1.3.6.1.4.1.3813.1.4.12.2.1.22',
     'boBundleBytesSentRateLimitDrop'  => '1.3.6.1.4.1.3813.1.4.12.2.1.24',

     # ELLACOYA-MIB::policyMgmt, e100
     'policyMgmt'                    => '1.3.6.1.4.1.3813.1.4.16',

     # ELLACOYA-MIB::subscriberMgmt, e100
     'subscriberMgmt'                => '1.3.6.1.4.1.3813.1.4.17',
     'subscriberStateName'           => '1.3.6.1.4.1.3813.1.4.17.7.1.2',

     # ELLACOYA-MIB::l2tp, e30 (available in 7.5.x)
     'l2tpConfigEnabled'             => '1.3.6.1.4.1.3813.1.4.18.1.1.0',
     'l2tpSecureEndpointIpAddress'   => '1.3.6.1.4.1.3813.1.4.18.3.2.1.1.1',
     'l2tpSecureEndpointOverlapping' => '1.3.6.1.4.1.3813.1.4.18.3.2.1.1.3',

     );

our %eChassisName =
    (
        '1'  => 'e16k',
        '2'  => 'e4k',
        '3'  => 'e30 Revision: R',
        '4'  => 'e30 Revision: S',
        '5'  => 'e30 Revision: T',
        '6'  => 'e30 Revision: U',
        '7'  => 'e30 Revision: V',
	'8'  => 'Ellacoya e100',
        '9'  => 'e100'
    );

our %eCpuName =
    (
        '1'  => 'Control Module',
        '3'  => 'DPI Module 1 CPU 1',
        '4'  => 'DPI Module 1 CPU 2',
        '5'  => 'DPI Module 2 CPU 1',
        '6'  => 'DPI Module 2 CPU 2',
        '7'  => 'I/O Module'
    );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'eProducts', $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        return 0;
    }
   
    $devdetails->setCap('interfaceIndexingPersistent');

    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    # PROG: Grab versions, serials and type of chassis.
    my $eInfo = $dd->retrieveSnmpOIDs
                   ( 'codeVer', 'sysIdSerialNum', 'sysObjectID' );
    $eInfo->{'modelNum'} = $eInfo->{'sysObjectID'};
    $eInfo->{'modelNum'} =~ s/.*(\d)$/$1/; # Last digit

    # SNMP: System comment
    $data->{'param'}{'comment'} =
            "Arbor " . $eChassisName{$eInfo->{'modelNum'}} .
            ", Hw Serial#: " . $eInfo->{'sysIdSerialNum'} .
            ", Version: " .  $eInfo->{'codeVer'};

    # ------------------------------------------------------------------------
    # Arbor_E e30 related material here
    if( $eInfo->{'modelNum'} < 8 )
    {
        Debug("Arbor_E: Found " . $eChassisName{$eInfo->{'modelNum'}} );

        # PROG: Set Capability to be the e30 device
        $devdetails->setCap('e30');

        # PROG: Check status oids
        if( $devdetails->param('Arbor_E::disable-e30-buffers') ne 'yes' )
	{
            $devdetails->setCap('e30-buffers');
        }

        if( $devdetails->param('Arbor_E::disable-e30-cpu') ne 'yes' )
        {
            $devdetails->setCap('e30-cpu');
        }

        if( $devdetails->param('Arbor_E::disable-e30-fwdTable') ne 'yes' )
        {
            $devdetails->setCap('e30-fwdTable');

            if( $devdetails->param('Arbor_E::disable-e30-fwdTable-login')
                ne 'yes' )
            {
                my $loginTable = $session->get_table(
                       -baseoid => $dd->oiddef('loginRespOkStatsIndex') );
                $devdetails->storeSnmpVars( $loginTable );

                if( defined( $loginTable ) )
                {
                    $devdetails->setCap('e30-fwdTable-login');

                    foreach my $statsIdx ( $devdetails->getSnmpIndices(
                                      $dd->oiddef('loginRespOkStatsIndex') ) )
                    {
                        push(@{$data->{'e30'}{'loginResp'}}, $statsIdx);
                    }
                }
            } # END hasCap disable-e30-fwdTable-login
        }

        if( $devdetails->param('Arbor_E::disable-e30-hdd') ne 'yes' )
        {
            $devdetails->setCap('e30-hdd');

            # SNMP: Add harddrive comment information
            $eInfo = $dd->retrieveSnmpOIDs( 'hDriveErrModel',
                                            'hDriveErrSerialNum' );

            $data->{'e30'}{'hddModel'}  = $eInfo->{'hDriveErrModel'};
            $data->{'e30'}{'hddSerial'} = $eInfo->{'hDriveErrSerialNum'};

            # PROG: Do we want errors as well?
            if( $devdetails->param('Arbor_E::enable-e30-hdd-errors') eq 'yes' )
            {
                $devdetails->setCap('e30-hdd-errors');
            }

            # PROG: Do we want to look at daily log files? (New in 7.6)
            if( $devdetails->param('Arbor_E::disable-e30-hdd-logs') ne 'yes' )
            {
                $eInfo = $dd->retrieveSnmpOIDs( 'hDriveDailyLogSize' );

                if( $eInfo->{'hDriveDailyLogSize'} )
                {
                    $devdetails->setCap('e30-hdd-logs');
                }
            }
        } # END: if disable-e30-hdd

        if( $devdetails->param('Arbor_E::disable-e30-l2tp') ne 'yes' )
        {
            # 1 - disabled, 2 - enabled, 3 - session aware
            $eInfo = $dd->retrieveSnmpOIDs('l2tpConfigEnabled');

            if( $eInfo->{'l2tpConfigEnabled'} > 1 )
            {
                $devdetails->setCap('e30-l2tp');

                my $l2tpSecEndTable = $session->get_table(
                       -baseoid => $dd->oiddef('l2tpSecureEndpointIpAddress') );
		$devdetails->storeSnmpVars( $l2tpSecEndTable );

                Debug("e30: L2TP secure endpoints found:");
                foreach my $SEP ( $devdetails->getSnmpIndices(
                                  $dd->oiddef('l2tpSecureEndpointIpAddress') ) )
		{
			next if( ! $SEP );
			$data->{'e30'}{'l2tpSEP'}{$SEP} = 0;
                        Debug("e30:    $SEP");
		}
            } # END: if l2tpConfigEnabled
        }

        # Memory usage on system
        if( $devdetails->param('Arbor_E::disable-e30-mem') ne 'yes' )
        {
            $devdetails->setCap('e30-mem');
        }

        # Memory usage / individual blocks
        if( $devdetails->param('Arbor_E::enable-e30-mempool') eq 'yes' )
        {
            my $mempoolTable = $session->get_table(
                                 -baseoid => $dd->oiddef('memPoolNameIndex') );
            $devdetails->storeSnmpVars( $mempoolTable );

            if( defined( $mempoolTable ) )
            {
                $devdetails->setCap('e30-mempool');

                foreach my $memOID (
                           $devdetails->getSnmpIndices(
                                $dd->oiddef('memPoolNameIndex') ) )
                {
                    my $memName = $mempoolTable->{
                               $dd->oiddef('memPoolNameIndex') . '.' . $memOID};

                    Debug("e30:  Mempool: $memName");
                    $data->{'e30'}{'mempool'}{$memOID} = $memName;
                }
            }
        }

        # Traffic statistics per Bundle
        if( $devdetails->param('Arbor_E::disable-e30-bundle') ne 'yes' )
        {
            # Set capability 
            $devdetails->setCap('e30-bundle');

            # Pull table information
            my $bundleTable = $session->get_table(
                                -baseoid => $dd->oiddef('bundleName') );
            $devdetails->storeSnmpVars( $bundleTable );

            Debug("e30: Bundle Information id:name");
            foreach my $bundleID (
                       $devdetails->getSnmpIndices( $dd->oiddef('bundleName') ))
            {
                    my $bundleName = $bundleTable->{$dd->oiddef('bundleName') .
                                        '.' . $bundleID};
                    $data->{'e30'}{'bundleID'}{$bundleID} = $bundleName;
	
                    Debug("e30:    $bundleID $bundleName");
            } # END foreache my $bundleID

            if( $devdetails->param('Arbor_E::disable-e30-bundle-deny') ne 'yes')
            {
                my $bundleDenyTable = $session->get_table(
                     -baseoid => $dd->oiddef('bundleBytesSentDenyPolicyDrop') );
                $devdetails->storeSnmpVars( $bundleDenyTable );

                if( $bundleDenyTable )
                {
                    $devdetails->setCap('e30-bundle-denyStats');
                }
            }

            if( $devdetails->param('Arbor_E::disable-e30-bundle-rate') ne 'yes')
            {
                my $bundleRateLimitTable = $session->get_table(
                     -baseoid => $dd->oiddef('bundleBytesSentRateLimitDrop') );
                $devdetails->storeSnmpVars( $bundleRateLimitTable );

                if( $bundleRateLimitTable )
                {
                    $devdetails->setCap('e30-bundle-rateLimitStats');
                }
            }

        } # END if Arbor_E::disable-e30-bundle

        # PROG: Counters
        if( $devdetails->param('Arbor_E::disable-e30-slowpath') ne 'yes' )
        {
            # Slowpath counters are available as of 7.5.x
            my $counters = $session->get_table(
                            -baseoid => $dd->oiddef('slowpathCounters') );
            $devdetails->storeSnmpVars( $counters );

            if( defined( $counters ) )
            {
                $devdetails->setCap('e30-slowpath');
            }
        }
    }


    # ------------------------------------------------------------------------
    #
    # Arbor E100 related material here

    if( $eInfo->{'modelNum'} >= 8 )
    {
        Debug("Arbor_E: Found " . $eChassisName{$eInfo->{'modelNum'}} );

        # PROG: Set Capability to be the e100 device
        $devdetails->setCap('e100');

        # CPU parameters ...
        if( $devdetails->param('Arbor_E::disable-e100-cpu') ne 'yes' )
        {
          my $cpuNameTable = $session->get_table(
                            -baseoid => $dd->oiddef('cpuName') );
          $devdetails->storeSnmpVars( $cpuNameTable );

          if( defined( $cpuNameTable ) )
          {
            $devdetails->setCap('e100-cpu');

            # PROG: Find all the CPU's ..
            foreach my $cpuIndex ( $devdetails->getSnmpIndices(
                                   $dd->oiddef('cpuName') ) )
            {
              my $cpuName = $cpuNameTable->{$dd->oiddef('cpuName') .
                                                   '.' . $cpuIndex};

              Debug("  CPU found: $cpuIndex, $cpuName");
              $data->{'e100'}{'cpu'}{$cpuIndex} = $cpuName;
            }
          }
        }

        # HDD Parameters
        if( $devdetails->param('Arbor_E::disable-e100-hdd') ne 'yes' )
        {
          my $hddTable = $session->get_table(
                           -baseoid => $dd->oiddef('partitionName') );
          $devdetails->storeSnmpVars( $hddTable );

          if( defined( $hddTable ) )
          {
            $devdetails->setCap('e100-hdd');

            # PROG: Find all the paritions and names ..
            foreach my $hddIndex ( $devdetails->getSnmpIndices(
                                   $dd->oiddef('partitionName') ) )
            {
              my $partitionName = $hddTable->{$dd->oiddef('partitionName') .
                                              '.' . $hddIndex};
              Debug("HDD Partition: $hddIndex, $partitionName");
              $data->{'e100'}{'hdd'}{$hddIndex} = $partitionName;
            }
          }
        }

        # MEM Parameters
        if( $devdetails->param('Arbor_E::disable-e100-mem') ne 'yes' )
        {
          my $cpuSdramTable = $session->get_table(
                             -baseoid => $dd->oiddef('cpuSdramIndex') );
          $devdetails->storeSnmpVars( $cpuSdramTable );

          if( defined( $cpuSdramTable ) )
          {
            $devdetails->setCap('e100-mem');

            # PROG: Find all memory indexes
            foreach my $memIndex ( $devdetails->getSnmpIndices(
                                   $dd->oiddef('cpuSdramIndex') ) )
            {
              my $memName = $data->{'e100'}{'cpu'}{$memIndex};
              Debug("MEM found: $memIndex, $memName");
              $data->{'e100'}{'mem'}{$memIndex} = $memName;
            }
          }
        }

        # Policy Mgmt parameters
        if( $devdetails->param('Arbor_E::disable-e100-policymgmt') ne 'yes' )
        {
          my $policyTable = $session->get_table(
                              -baseoid => $dd->oiddef('policyMgmt')
                            );
          $devdetails->storeSnmpVars( $policyTable );

          if( defined( $policyTable ) )
          {
            $devdetails->setCap('e100-policymgmt');
          }
        }

        # Subscriber Mgmt parameters
        if( $devdetails->param('Arbor_E::disable-e100-submgmt') ne 'yes' )
        {
          my $subTable = $session->get_table(
                            -baseoid => $dd->oiddef('subscriberStateName')
                         );
          $devdetails->storeSnmpVars( $subTable );

          if( defined( $subTable ) )
          {
            $devdetails->setCap('e100-submgmt');

            # Sub: Find state name entries
            foreach my $stateIDX ( $devdetails->getSnmpIndices( $dd->oiddef(
					'subscriberStateName') ) )
            {
               my $state = $subTable->{
                              $dd->oiddef('subscriberStateName') .
                              '.' .  $stateIDX
                           };
               
               Debug("  State index: $stateIDX, name: $state");
               $data->{'e100'}{'submgmt'}{$stateIDX} = $state;
            }
          }
        }
    }


    # ------------------------------------------------------------------------
    #
    # Common information between e30 and e100

    if( $devdetails->param('Arbor_E::disable-flowdev') ne 'yes' )
    {
        $devdetails->setCap('arbor-flowLookup');

        # Flow Lookup Device information
        # Figure out what pools exist for the 2 flow switching modules
        # ------------------------------------------------------------
        my $switchingModules = 2;

        foreach my $flowModule (1 .. $switchingModules) {
            Debug("common:  Flow Lookup Device " . $flowModule);

            my $flowPoolOid  = 'flowPoolNameD' . $flowModule;
            my $flowModTable = $session->get_table (
                              -baseoid => $dd->oiddef($flowPoolOid) );
            $devdetails->storeSnmpVars ( $flowModTable );

            # PROG: Look for pool names and indexes and store them.
            if( $flowModTable ) {
                foreach my $flowPoolIDX ( $devdetails->getSnmpIndices(
                                            $dd->oiddef($flowPoolOid) ) )
                {
                    my $flowPoolName = $flowModTable->{
                           $dd->oiddef($flowPoolOid) . '.' . $flowPoolIDX};

                    $data->{'arbor_e'}{'flowModule'}{$flowModule}{$flowPoolIDX}
                          = $flowPoolName;

                    Debug("common:    IDX: $flowPoolIDX  Pool: $flowPoolName");

                } # END: foreach my $flowPoolIDX
            } # END: if $flowModTable
        } # END: foreach my $flowModule
    }


    if( $devdetails->param('Arbor_E::disable-bundle-offer') ne 'yes' )
    {
        my $boOfferNameTable = $session->get_table(
                            -baseoid => $dd->oiddef('boOfferName') );
        $devdetails->storeSnmpVars( $boOfferNameTable );

        my $boBundleNameTable = $session->get_table(
                            -baseoid => $dd->oiddef('boBundleName') );
        $devdetails->storeSnmpVars( $boBundleNameTable );

        if( defined( $boOfferNameTable ) )
        {
            $devdetails->setCap('arbor-bundle');

            foreach my $boOfferNameID ( $devdetails->getSnmpIndices(
                                $dd->oiddef('boOfferName') ) )
            {
		my ($bundleID,$offerNameID) = split( /\./, $boOfferNameID );

                my $offerName = $boOfferNameTable->{
                                    $dd->oiddef('boOfferName')
                                    . '.' . $boOfferNameID };
                my $bundleName = $boBundleNameTable->{
                                    $dd->oiddef('boBundleName')
                                    . '.' . $boOfferNameID };

                $data->{'arbor_e'}{'offerName'}{$offerNameID} = $offerName;
                $data->{'arbor_e'}{'bundleName'}{$bundleID}   = $bundleName;

                push( @{$data->{'arbor_e'}{'boOfferBundle'}{$offerNameID}},
                      $bundleID );
            }
        }

        # PROG: Subscribers using the bundle
        if( $devdetails->param('Arbor_E::disable-bundle-offer-subcount')
            ne 'yes' )
        {
            my $oidSubcount = $dd->oiddef('boBundleSubCount');

            if( defined $session->get_table( -baseoid => $oidSubcount ) )
            {
                $devdetails->setCap('arbor-bundle-subcount');
            }
        }

        # PROG: Packets sent on this bundle with a size
        if( $devdetails->param('Arbor_E::disable-bundle-offer-pktsize')
            ne 'yes' )
        {
            my $oidPktsize = $dd->oiddef('boPacketsSent64');

            if( defined $session->get_table( -baseoid => $oidPktsize ) )
            {
                $devdetails->setCap('arbor-bundle-pktsize');
            }
        }

        # PROG: Bytes sent on this bundle for deny policy drop
        if( $devdetails->param('Arbor_E::disable-bundle-offer-deny')
            ne 'yes' )
        {
            my $oidDenypolicy = $dd->oiddef('boBundleBytesSentDenyPolicyDrop');

            if( defined $session->get_table( -baseoid => $oidDenypolicy ) )
            {
                $devdetails->setCap('arbor-bundle-deny');
            }
        }

        # PROG: Bytes sent on this bundle for rate limit drop
        if( $devdetails->param('Arbor_E::disable-bundle-offer-rate')
            ne 'yes' )
        {
            my $oidRatelimit = $dd->oiddef('boBundleBytesSentRateLimitDrop');

            if( defined $session->get_table( -baseoid => $oidRatelimit ) )
            {
                $devdetails->setCap('arbor-bundle-ratelimit');
            }
        }
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
    my $data = $devdetails->data();

    # PROG: Lets do e30 first ...
    if( $devdetails->hasCap('e30') )
    {
        # e30 buffer information
        if( $devdetails->hasCap('e30-buffers') )
        {
            $cb->addTemplateApplication($devNode, 'Arbor_E::e30-buffers');
        }

        if( $devdetails->hasCap('e30-bundle') )
        {
            # Create topLevel subtree
            my $bundleNode = $cb->addSubtree( $devNode, 'Bundle_Stats',
                                    { 'comment' => 'Bundle statistics' },
                                    [ 'Arbor_E::e30-bundle-subtree' ] );

            foreach my $bundleID
                ( sort {$a <=> $b} keys %{$data->{'e30'}{'bundleID'} } )
            {
                my $srvName     =  $data->{'e30'}{'bundleID'}{$bundleID};
                my $subtreeName =  $srvName;
                   $subtreeName =~ s/\W/_/g; 
                my $bundleRRD	= $bundleID;
                my @templates   = ( 'Arbor_E::e30-bundle' );

                if( $devdetails->param('Arbor_E::enable-e30-bundle-name-rrd')
                    eq 'yes' )
                {
                    # Filenames written out as the bundle name
                    $bundleRRD =  lc($srvName);
                    $bundleRRD =~ s/\W/_/g;
                }

                if( $devdetails->hasCap('e30-bundle-denyStats') )
                {
                    push( @templates, 'Arbor_E::e30-bundle-deny' );
                }

                if( $devdetails->hasCap('e30-bundle-rateLimitStats') )
                {
                    push( @templates, 'Arbor_E::e30-bundle-ratelimit' );
                }

                $cb->addSubtree( $bundleNode, $subtreeName,
                                 { 'comment'          => $srvName,
                                   'e30-bundle-index' => $bundleID,
                                   'e30-bundle-name'  => $srvName,
                                   'e30-bundle-rrd'   => $bundleRRD,
                                   'precedence'       => 1000 - $bundleID },
                                 \@templates );
            } # END foreach my $bundleID
        }

        # e30 cpu
        if( $devdetails->hasCap('e30-cpu') )
        {
            $cb->addTemplateApplication($devNode, 'Arbor_E::e30-cpu');
        }

        # e30 forwarding table
        if( $devdetails->hasCap('e30-fwdTable') )
        {
            $cb->addTemplateApplication($devNode, 'Arbor_E::e30-fwdTable');

            if( $devdetails->hasCap('e30-fwdTable-login') )
            {
                my $subtree  = "Forwarding_Table_Login_Stats";
                my $comment  = "Discovery attempts statistics";
                my $nodeTree = $cb->addSubtree( $devNode, $subtree, 
                                              { 'comment' => $comment },
                                                undef );

                my @colors =
                    ('##one', '##two', '##three', '##four', '##five',
                     '##six', '##seven', '##eight', '##nine', '##ten'
                    );

                my $multiParam = {
                    'precedence'        => 1000,
                    'comment'           => 'Summary of login attempt responses',
                    'graph-lower-limit' => 0,
                    'graph-title'       => 'Summary of login attempt responses',
                    'rrd-hwpredict'     => 'disabled',
                    'vertical-label'    => 'Responses',
                    'ds-type'           => 'rrd-multigraph'
                    };
                my $dsList;

                foreach my $sindex ( sort { $a <=> $b } 
                                     @{$data->{'e30'}{'loginResp'}} )
                {
		
                    $cb->addLeaf( $nodeTree, 'Login_' . $sindex,
                                { 'comment'    => 'Login attempt #' . $sindex,
                                  'login-idx'  => $sindex,
                                  'precedence' => 100 - $sindex },
                                [ 'Arbor_E::e30-fwdTable-login' ] );

                    # Addition for multi-graph
                    my $dsName  = "Login_$sindex";
                    my $color   = shift @colors;
                       $dsList .= $dsName . ',';

                    $multiParam->{"ds-expr-$dsName"}      = "{$dsName}";
                    $multiParam->{"graph-legend-$dsName"} = "Attempt $sindex";
                    $multiParam->{"line-style-$dsName"}   = "LINE1";
                    $multiParam->{"line-color-$dsName"}   = $color;
                    $multiParam->{"line-order-$dsName"}   = $sindex;

                    Debug("  loginReps: $sindex, color: $color");
                } # END: foreach $sindex

                $dsList =~ s/,$//o;	# Remove final comma
                $multiParam->{'ds-names'} = $dsList;

                $cb->addLeaf($nodeTree, 'Summary', $multiParam, undef );

            } # END: hasCap e30-fwdTable-login
        } # END: hasCap e30-fwdTable

        # e30 hard drive
        if( $devdetails->hasCap('e30-hdd') )
        {
            my $comment = "Model: "  . $data->{'e30'}{'hddModel'} . ", " .
                          "Serial: " . $data->{'e30'}{'hddSerial'};
            my $subtree = "Hard_Drive";
            my @templates;
            push( @templates, 'Arbor_E::e30-hdd-subtree' );
            push( @templates, 'Arbor_E::e30-hdd' );

            # PROG: Process hdd errors
            if( $devdetails->hasCap('e30-hdd-errors') )
            {
                push( @templates, 'Arbor_E::e30-hdd-errors' );
            }

            # PROG: Process hdd daily logs
            if( $devdetails->hasCap('e30-hdd-logs') )
            {
                push( @templates, 'Arbor_E::e30-hdd-logs' );
            }

            my $hdNode = $cb->addSubtree($devNode, $subtree,
                                        { 'comment' => $comment },
                                        \@templates);
        }

        # e30 L2TP tunnel information
        if( $devdetails->hasCap('e30-l2tp') )
        {
            # PROG: First add the appropriate template
            my $l2tpNode = $cb->addSubtree( $devNode, 'L2TP', undef,
                                          [ 'Arbor_E::e30-l2tp-subtree' ]);

            # PROG: Cycle through the SECURE EndPoint devices
            if( $data->{'e30'}{'l2tpSEP'} )
            {
                # PROG: Add the assisting template first
                my $l2tpEndNode = $cb->addSubtree( $l2tpNode, 'Secure_Endpoint',
                             { 'comment' => 'Secure endpoint parties' },
                             [ 'Arbor_E::e30-l2tp-secure-endpoints-subtree' ] );

                foreach my $SEP ( keys %{$data->{'e30'}{'l2tpSEP'}} )
                {
                  my $endPoint =  $SEP;
                     $endPoint =~ s/\W/_/g;

                  $cb->addSubtree($l2tpEndNode, $endPoint,
                              { 'e30-l2tp-ep'   => $SEP,
                                'e30-l2tp-file' => $endPoint },
                              [ 'Arbor_E::e30-l2tp-secure-endpoints-leaf' ]);
                } # END: foreach
            }
        }

        # e30 memory
        if( $devdetails->hasCap('e30-mem') )
        {
            $cb->addTemplateApplication($devNode, 'Arbor_E::e30-mem');
        }

        # e30 memory pool
        if( $devdetails->hasCap('e30-mempool') )
        {
            my $subtreeName = "Memory_Pool";
            my $param       = { 'comment' => 'Memory Pool Statistics' };
            my $templates   = [ 'Arbor_E::e30-mempool-subtree' ];
            my $memIndex    = $data->{'e30'}{'mempool'};

            my $nodeTop     = $cb->addSubtree( $devNode, $subtreeName,
                                               $param, $templates );

            foreach my $memIDX ( keys %{$memIndex} )
            {
                my $leafName = $memIndex->{$memIDX};
                my $dataFile = "%snmp-host%_mempool_" . $leafName . '.rrd';

                my $nodeMem = $cb->addSubtree( $nodeTop, $leafName, 
                                            { 'data-file'         => $dataFile,
                                              'e30-mempool-index' => $memIDX,
                                              'e30-mempool-name'  => $leafName
                                            },
                                            [ 'Arbor_E::e30-mempool' ] );
            }
        }

        # e30 slowpath counters
        if( $devdetails->hasCap('e30-slowpath') )
        {
            my $slowNode = $cb->addSubtree( $devNode, 'SlowPath', undef,
                                          [ 'Arbor_E::e30-slowpath' ] );
        }
    } # END: if e30 device


    # -----------------------------------------------------
    #
    # E100 series...

    if( $devdetails->hasCap('e100') )
    {
        # CPU: per-cpu information
        if( $devdetails->hasCap('e100-cpu') )
        {
            my @colors  = ( '##one', '##two', '##three', '##four', '##five',
                            '##six', '##seven', '##eight', '##nine', '##ten'
                          );
            my $subtree = "CPU_Usage";
            my $cpuTree = $cb->addSubtree( $devNode, $subtree, undef,
                                         [ 'Arbor_E::e100-cpu-subtree' ] );
            my $multiParam = {
                'precedence'        => 1000,
                'comment'           => 'Summary of all CPU utilization',
                'graph-lower-limit' => 0,
                'graph-title'       => 'Summary of all CPU utilization',
                'rrd-hwpredict'     => 'disabled',
                'vertical-label'    => 'Percent',
                'ds-type'           => 'rrd-multigraph'
                };
            my $dsList;

            foreach my $cpuIndex ( sort keys %{$data->{'e100'}{'cpu'}} )
            {
                my $cpuName = $data->{'e100'}{'cpu'}{$cpuIndex};
  
                # Is there proper desc for the CPU index?
                my $comment;
                if( $eCpuName{$cpuIndex} )
                {
                    $comment = $eCpuName{$cpuIndex};
                } else {
                    $comment = "CPU: $cpuName";
                }
  
                $cb->addLeaf( $cpuTree, $cpuName,
                            { 'comment'    => $comment,
                              'cpu-index'  => $cpuIndex,
                              'cpu-name'   => $cpuName,
                              'precedence' => 1000 - $cpuIndex },
                            [ 'Arbor_E::e100-cpu' ] );
  
                # Multi-graph additions
                my $color   = shift @colors;
                   $dsList .= $cpuName . ',';
                $multiParam->{"ds-expr-$cpuName"}      = "{$cpuName}";
                $multiParam->{"graph-legend-$cpuName"} = "$cpuName";
                $multiParam->{"line-style-$cpuName"}   = "LINE1";
                $multiParam->{"line-color-$cpuName"}   = $color;
                $multiParam->{"line-order-$cpuName"}   = $cpuIndex;
            } # END: foreach $cpuIndex

            $dsList =~ s/,$//o;     # Remove final comma
            $multiParam->{'ds-names'} = $dsList;
            $cb->addLeaf($cpuTree, 'Summary', $multiParam, undef );

        } # END: hasCap e100-cpu

        # HDD: Partition sizes / usage
        if( $devdetails->hasCap('e100-hdd') )
        {
            my $subtree = "HDD_Usage";
            my $hddTree = $cb->addSubtree( $devNode, $subtree, undef,
                                         [ 'Arbor_E::e100-hdd-subtree' ] );

            foreach my $hddIndex ( sort keys %{$data->{'e100'}{'hdd'}} )
            {
              my $hddName = $data->{'e100'}{'hdd'}{$hddIndex};
              $cb->addSubtree( $hddTree, $hddName,
                             { 'comment'    => 'HDD: ' . $hddName,
                               'hdd-index'  => $hddIndex,
                               'hdd-name'   => $hddName,
                               'precedence' => 1000 - $hddIndex },
                             [ 'Arbor_E::e100-hdd' ] );
            }
        }

        # MEM: per-cpu memory usage
        if( $devdetails->hasCap('e100-mem') )
        {
            my $subtree = "Memory_Usage";
            my $memTree = $cb->addSubtree( $devNode, $subtree, undef,
                                         [ 'Arbor_E::e100-mem-subtree' ] );
            foreach my $memIndex ( sort keys %{$data->{'e100'}{'mem'}} )
            {
              my $memName = $data->{'e100'}{'cpu'}{$memIndex};

              my $comment = "Memory for $memName CPU";
              $cb->addSubtree( $memTree, $memName,
                             { 'comment'    => $comment,
                               'mem-index'  => $memIndex,
                               'mem-name'   => $memName,
                               'precedence' => 1000 - $memIndex },
                             [ 'Arbor_E::e100-mem' ] );
            }
        }

        # PolicyMmgt: Information regarding delta, service bundles, subnets
        if( $devdetails->hasCap('e100-policymgmt') )
        {
            $cb->addTemplateApplication($devNode, 'Arbor_E::e100-policymgmt');
        }

        # SubscriberMgmt: Information regarding subscriber counts, states, etc.
        if( $devdetails->hasCap('e100-submgmt') )
        {
            my $subMgmtTree = $cb->addSubtree( $devNode, 'Subscribers', undef,
                                      [ 'Arbor_E::e100-submgmt-subtree' ]
                             );

            my $stateTree  = $cb->addSubtree( $subMgmtTree, 'Subscriber_State',
                                        undef,
                                      [ 'Arbor_E::e100-submgmt-state-subtree' ]
                             );

            # State: Multigraph display
            my @colors =
                ('##one', '##two', '##three', '##four', '##five',
                 '##six', '##seven', '##eight', '##nine', '##ten'
                );
            my $multiParam = {
                'precedence'        => 1000,
                'graph-lower-limit' => 0,
                'graph-title'       => 'Summary of subscriber states',
                'rrd-hwpredict'     => 'disabled',
                'vertical-label'    => 'Subscribers',
                'comment'           => 'Summary of all states',
                'ds-type'           => 'rrd-multigraph'
            };
            my $dsList;

            foreach my $stateIDX ( sort keys %{$data->{'e100'}{'submgmt'}} )
            {
                my $color        =  shift @colors;
                my $stateName    =  $data->{'e100'}{'submgmt'}{$stateIDX};
                my $stateNameRRD =  $stateName;
                   $stateNameRRD =~ s/[^a-zA-Z_]/_/o;

                my $stateNode = $cb->addLeaf( $stateTree, $stateName,
                                   { 'comment'    => "State: $stateName",
                                     'state-idx'  => $stateIDX,
                                     'state-name' => $stateName,
                                     'state-rrd'  => $stateNameRRD,
                                     'precedence' => 100 - $stateIDX },
                                   [ 'Arbor_E::e100-submgmt-state' ] );
                $dsList .= $stateName . ',';

                $multiParam->{"ds-expr-$stateName"}      = "{$stateName}";
                $multiParam->{"graph-legend-$stateName"} = "$stateName";
                $multiParam->{"line-style-$stateName"}   = "LINE1";
                $multiParam->{"line-color-$stateName"}   = $color,
                $multiParam->{"line-order-$stateName"}   = $stateIDX;
            }
            $dsList =~ s/,$//o;
            $multiParam->{'ds-names'} = $dsList;

            $cb->addLeaf($stateTree, 'Summary', $multiParam, undef );

        }
    }

    # -------------------------------------------------------------------------
    #
    # Common information between e30 and e100

    if( $devdetails->hasCap('arbor-bundle') )
    {
        my $subtreeName = "Bundle_Offer_Stats";
        my $param       = { 'comment'    => 'Byte counts for each bundle ' . 
                                            'per Offer' };
        my $templates   = [ ];
        my $nodeTop     = $cb->addSubtree( $devNode, $subtreeName,
                                           $param, $templates );

        foreach my $offerNameID ( keys %{$data->{'arbor_e'}{'offerName'}} )
        {
            my $offerName   =  $data->{'arbor_e'}{'offerName'}{$offerNameID};
               $offerName   =~ s/\W/_/g;
            my $offerBundle =  $data->{'arbor_e'}{'boOfferBundle'};
            my $offerRRD    =  $offerNameID;

            if( $devdetails->param('Arbor_E::enable-bundle-name-rrd')
                eq 'yes' )
            {
                # Filename will now be written as offer name
                $offerRRD = lc($offerName);
            }

            # Build tree
            my $oparam = { 'comment'   => 'Offer: ' . $offerName,
                           'offer-id'  => $offerNameID,
                           'offer-rrd' => $offerRRD };
            my $otemplates = [ 'Arbor_E::arbor-bundle-subtree' ];
            my $offerTop = $cb->addSubtree( $nodeTop, $offerName, $oparam,
                                            $otemplates );

            Debug("    Offer: $offerName");

            foreach my $bundleID ( @{$offerBundle->{$offerNameID}} )
            {
                my @btemplates;
                my $bundleName =  $data->{'arbor_e'}{'bundleName'}{$bundleID};
                   $bundleName =~ s/\W/_/g;
                my $bundleRRD  =  $bundleID;

                Debug("      $bundleID: $bundleName");

                if( $devdetails->param('Arbor_E::enable-bundle-name-rrd')
                    eq 'yes' )
                {
                    # Filename will now be written as bundle name
                    $bundleRRD = lc($bundleName);
                }

                my $bparam     = { 'comment'     => 'Bundle ID: ' . $bundleID,
                                   'data-file'   => '%system-id%_bo_' .
                                                    '%offer-rrd%_' .
                                                    '%bundle-rrd%.rrd',
                                   'bundle-id'   => $bundleID,
                                   'bundle-name' => $bundleName,
                                   'bundle-rrd'  => $bundleRRD };
                push( @btemplates, 'Arbor_E::arbor-bundle' );

                # PROG: Subscribers using the bundle
                if( $devdetails->hasCap('arbor-bundle-subcount') )
                {
                    push( @btemplates, 'Arbor_E::arbor-bundle-subcount' );
                }

                # PROG: Packets sent on this bundle per size
                if( $devdetails->hasCap('arbor-bundle-pktsize') )
                {
                    push( @btemplates, 'Arbor_E::arbor-bundle-pktsize' );
                }

                # PROG: Bytes sent on this bundle for deny policy drop
                if( $devdetails->hasCap('arbor-bundle-deny') )
                {
                    push( @btemplates, 'Arbor_E::arbor-bundle-deny' );
                }

                # PROG: Bytes sent on this bundle for rate limit drop
                if( $devdetails->hasCap('arbor-bundle-ratelimit') )
                {
                    push( @btemplates, 'Arbor_E::arbor-bundle-ratelimit' );
                }

                # Build tree
                $cb->addSubtree( $offerTop, $bundleName,
                                 $bparam, \@btemplates );
            } # END: foreach $bundleID
        } # END: foreach $offerNameID
    } # END: hasCap arbor-bundle

    # Flow device lookups
    if( $devdetails->hasCap('arbor-flowLookup') )
    {
        # PROG: Flow Lookup Device (pool names)
        my $flowNode = $cb->addSubtree( $devNode, 'Flow_Lookup',
                                      { 'comment' => 'Switching modules' },
                                        undef );

        my $flowLookup = $data->{'arbor_e'}{'flowModule'};

        foreach my $flowDevIdx ( keys %{$flowLookup} )
        {
            my $flowNodeDev = $cb->addSubtree( $flowNode,
                              'Flow_Lookup_' .  $flowDevIdx,
                              { 'comment' => 'Switching module '
                                              . $flowDevIdx },
                              [ 'Arbor_E::arbor-flowlkup-subtree' ] );

            # PROG: Find all the pool names and add Subtree
            foreach my $flowPoolIdx ( keys %{$flowLookup->{$flowDevIdx}} )
            {
                my $poolName = $flowLookup->{$flowDevIdx}{$flowPoolIdx};

                my $poolNode = $cb->addSubtree( $flowNodeDev, $poolName,
                               { 'comment'        => 'Flow Pool: ' . $poolName,
                                 'flowdev-index'  => $flowDevIdx,
                                 'flowpool-index' => $flowPoolIdx,
                                 'flowpool-name'  => $poolName,
                                 'precedence'     => 1000 - $flowPoolIdx},
                               [ 'Arbor_E::arbor-flowlkup-leaf' ] );
            } # END: foreach my $flowPoolIdx
        } # END: foreach my $flowDevIdx
    } # END: hasCap arbor-flowLookup

}

1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
