#  Copyright (C) 2002  Stanislav Sinyagin
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

# $Id: RFC2737_ENTITY_MIB.pm,v 1.1 2010-12-27 00:03:56 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Discovery module for ENTITY-MIB (RFC 2737)
# This module does not generate any XML, but provides information
# for other discovery modules

package Torrus::DevDiscover::RFC2737_ENTITY_MIB;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'RFC2737_ENTITY_MIB'} = {
    'sequence'     => 100,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # ENTITY-MIB
     'entPhysicalDescr'        => '1.3.6.1.2.1.47.1.1.1.1.2',
     'entPhysicalContainedIn'  => '1.3.6.1.2.1.47.1.1.1.1.4',
     'entPhysicalName'         => '1.3.6.1.2.1.47.1.1.1.1.7'
     );



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    my $descrTable =
        $session->get_table( -baseoid =>
                             $dd->oiddef('entPhysicalDescr') );
    if( defined $descrTable )
    {
        $devdetails->storeSnmpVars( $descrTable );
    }

    my $nameTable =
        $session->get_table( -baseoid =>
                             $dd->oiddef('entPhysicalName') );
    if( defined $nameTable )
    {
        $devdetails->storeSnmpVars( $nameTable );
    }

    return( defined($descrTable) or defined($nameTable) );
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();
    my $session = $dd->session();

    $data->{'entityPhysical'} = {};

    my $chassisIndex = 0;
    my $oidContainedIn = $dd->oiddef('entPhysicalContainedIn');

    foreach my $phyIndex
        ( $devdetails->getSnmpIndices($dd->oiddef('entPhysicalDescr')) )
    {
        my $ref = {};
        $data->{'entityPhysical'}{$phyIndex} = $ref;

        # Find the chassis. It is not contained in anything.
        if( not $chassisIndex )
        {
            my $oid = $oidContainedIn . '.' . $phyIndex;
            my $result = $session->get_request( -varbindlist => [ $oid ] );
            if( $session->error_status() == 0 and $result->{$oid} == 0 )
            {
                $chassisIndex = $phyIndex;
            }
        }

        my $descr = $devdetails->snmpVar( $dd->oiddef('entPhysicalDescr') .
                                          '.' . $phyIndex );
        if( $descr )
        {
            $ref->{'descr'} = $descr;
        }

        my $name = $devdetails->snmpVar( $dd->oiddef('entPhysicalName') .
                                         '.' . $phyIndex );
        if( $name )
        {
            $ref->{'name'} = $name;
        }
    }

    if( $chassisIndex )
    {
        $data->{'entityChassisPhyIndex'} = $chassisIndex;
        my $chassisDescr = $data->{'entityPhysical'}{$chassisIndex}{'descr'};
        if( length( $chassisDescr ) > 0 and
            not defined( $data->{'param'}{'comment'} ) )
        {
            Debug('ENTITY-MIB: found chassis description: ' . $chassisDescr);
            $data->{'param'}{'comment'} = $chassisDescr;
        }
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
