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

# $Id: CiscoVDSL.pm,v 1.1 2010-12-27 00:03:53 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Cisco VDSL Line statistics.
# Tested with Catalyst 2950 LRE

package Torrus::DevDiscover::CiscoVDSL;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'CiscoVDSL'} = {
    'sequence'     => 600,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # CISCO-IETF-VDSL-LINE-MIB
     'cvdslCurrSnrMgn'  => '1.3.6.1.4.1.9.10.87.1.1.2.1.5',
     );



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    if( $devdetails->isDevType('CiscoGeneric') )
    {
        my $snrTable =
            $session->get_table( -baseoid => $dd->oiddef('cvdslCurrSnrMgn') );
        if( defined $snrTable )
        {
            $devdetails->storeSnmpVars( $snrTable );
            return 1;
        }
    }

    return 0;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();

    $data->{'cvdsl'} = [];

    foreach my $ifIndex ( keys %{$data->{'interfaces'}} )
    {
        my $oid = $dd->oiddef('cvdslCurrSnrMgn') . '.' . $ifIndex;
        if( $devdetails->hasOID( $oid . '.1' ) and
            $devdetails->hasOID( $oid . '.2' ) )
        {
            push( @{$data->{'cvdsl'}}, $ifIndex );
        }
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    my $subtreeName = 'VDSL_Line_Stats';

    my $subtreeNode = $cb->addSubtree( $devNode, $subtreeName, {},
                                       ['CiscoVDSL::cvdsl-subtree']);

    my $data = $devdetails->data();

    foreach my $ifIndex ( sort {$a<=>$b} @{$data->{'cvdsl'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};

        my $ifSubtreeName = $interface->{$data->{'nameref'}{'ifSubtreeName'}};

        my $templates = ['CiscoVDSL::cvdsl-interface'];

        my $param = {
            'interface-name' => $interface->{'param'}{'interface-name'},
            'interface-nick' => $interface->{'param'}{'interface-nick'},
            'comment'        => $interface->{'param'}{'comment'}
        };

        $cb->addSubtree( $subtreeNode, $ifSubtreeName, $param, $templates );
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
