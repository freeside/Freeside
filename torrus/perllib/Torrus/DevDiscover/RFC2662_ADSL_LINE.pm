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

# $Id: RFC2662_ADSL_LINE.pm,v 1.1 2010-12-27 00:03:53 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# ADSL Line statistics.

# We assume that adslAturPhysTable is always present when adslAtucPhysTable
# is there. Probably that's wrong, and needs to be redesigned.

package Torrus::DevDiscover::RFC2662_ADSL_LINE;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'RFC2662_ADSL_LINE'} = {
    'sequence'     => 100,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # ADSL-LINE-MIB
     'adslAtucPhysTable'  => '1.3.6.1.2.1.10.94.1.1.2',
     'adslAtucCurrSnrMgn' => '1.3.6.1.2.1.10.94.1.1.2.1.4',
     'adslAturPhysTable' => '1.3.6.1.2.1.10.94.1.1.3'
     );



sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    my $atucTable =
        $session->get_table( -baseoid => $dd->oiddef('adslAtucPhysTable') );
    if( not defined $atucTable )
    {
        return 0;
    }
    $devdetails->storeSnmpVars( $atucTable );

    ## Do we need to check adslAtucPhysTable ? ##

    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $data = $devdetails->data();

    $data->{'adslAtucPhysTable'} = [];

    foreach my $ifIndex ( keys %{$data->{'interfaces'}} )
    {
        if( $devdetails->hasOID( $dd->oiddef('adslAtucCurrSnrMgn') .
                                 '.' . $ifIndex ) )
        {
            push( @{$data->{'adslAtucPhysTable'}}, $ifIndex );
        }
    }

    return 1;
}


sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    # Build SNR subtree
    my $subtreeName = 'ADSL_Line_Stats';

    my $param = {
        'precedence'         => '-600',
        'comment'            => 'ADSL line statistics'
        };
    my $subtreeNode = $cb->addSubtree( $devNode, $subtreeName, $param );

    my $data = $devdetails->data();

    foreach my $ifIndex ( sort {$a<=>$b} @{$data->{'adslAtucPhysTable'}} )
    {
        my $interface = $data->{'interfaces'}{$ifIndex};

        my $ifSubtreeName = $interface->{$data->{'nameref'}{'ifSubtreeName'}};

        my $templates = ['RFC2662_ADSL_LINE::adsl-line-interface'];

        my $param = {
            'interface-name' => $interface->{'param'}{'interface-name'},
            'interface-nick' => $interface->{'param'}{'interface-nick'},
            'collector-timeoffset-hashstring' =>'%system-id%:%interface-nick%',
            'comment'        => $interface->{'param'}{'comment'}
        };
        
        $param->{'node-display-name'} =
            $interface->{$data->{'nameref'}{'ifReferenceName'}};
        
        $cb->addSubtree( $subtreeNode, $ifSubtreeName, $param, $templates );
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
