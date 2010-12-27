#  Copyright (C) 2003-2004  Stanislav Sinyagin, Shawn Ferry
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

# $Id: MicrosoftWindows.pm,v 1.1 2010-12-27 00:03:55 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>
# Shawn Ferry <sferry at sevenspace dot com> <lalartu at obscure dot org>

# MS Windows 2000/XP SNMP agent discovery.
# ifDescr does not give unique interace mapping, so MAC address mapping
# is used.

package Torrus::DevDiscover::MicrosoftWindows;

use strict;
use Torrus::Log;


$Torrus::DevDiscover::registry{'MicrosoftWindows'} = {
    'sequence'     => 500,
    'checkdevtype' => \&checkdevtype,
    'discover'     => \&discover,
    'buildConfig'  => \&buildConfig
    };


our %oiddef =
    (
     # MSFT-MIB
     'windowsNT'                    => '1.3.6.1.4.1.311.1.1.3.1',

     # FtpServer-MIB
     'ms_ftpStatistics'             => '1.3.6.1.4.1.311.1.7.2.1',

     # HttpServer-MIB
     'ms_httpStatistics'            => '1.3.6.1.4.1.311.1.7.3.1',
     );

# Not all interfaces are normally needed to monitor.
# You may override the interface filtering in devdiscover-siteconfig.pl:
# redefine $Torrus::DevDiscover::MicrosoftWindows::interfaceFilter
# or define $Torrus::DevDiscover::MicrosoftWindows::interfaceFilterOverlay

our $interfaceFilter;
our $interfaceFilterOverlay;
my %winNTInterfaceFilter;

if( not defined( $interfaceFilter ) )
{
    $interfaceFilter = \%winNTInterfaceFilter;
}


# Key is some unique symbolic name, does not mean anything
# ifType is the number to match the interface type
# ifDescr is the regexp to match the interface description
%winNTInterfaceFilter =
    (
     'MS TCP Loopback interface' => {
         'ifType'  => 24                        # softwareLoopback
         },
     );

sub checkdevtype
{
    my $dd = shift;
    my $devdetails = shift;

    if( not $dd->oidBaseMatch
        ( 'windowsNT',
          $devdetails->snmpVar( $dd->oiddef('sysObjectID') ) ) )
    {
        return 0;
    }

    my $data = $devdetails->data();

    &Torrus::DevDiscover::RFC2863_IF_MIB::addInterfaceFilter
        ($devdetails, $interfaceFilter);

    if( defined( $interfaceFilterOverlay ) )
    {
        &Torrus::DevDiscover::RFC2863_IF_MIB::addInterfaceFilter
            ($devdetails, $interfaceFilterOverlay);
    }

    $devdetails->setCap('interfaceIndexingManaged');
    
    return 1;
}


sub discover
{
    my $dd = shift;
    my $devdetails = shift;

    my $session = $dd->session();
    my $data = $devdetails->data();

    # In Windows SNMP agent, ifDescr is not unique per interface.
    # We use MAC address as a unique interface identifier.

    $data->{'nameref'}{'ifComment'} = ''; # suggest?

    $data->{'param'}{'ifindex-map'} = '$IFIDX_MAC';
    Torrus::DevDiscover::RFC2863_IF_MIB::retrieveMacAddresses( $dd,
                                                               $devdetails );

    $data->{'nameref'}{'ifNick'} = 'MAC';
    
    # FTP and HTTP servers, if present
    if( $dd->checkSnmpTable( 'ms_ftpStatistics' ) )
    {
        $devdetails->setCap( 'msIIS' );
        $devdetails->setCap( 'msFtpStats' );
    }

    if( $dd->checkSnmpTable( 'ms_httpStatistics' ) )
    {
        $devdetails->setCap( 'msIIS' );
        $devdetails->setCap( 'msHttpStats' );
    }

    return 1;
}


# Nothing really to do yet
sub buildConfig
{
    my $devdetails = shift;
    my $cb = shift;
    my $devNode = shift;

    if( $devdetails->hasCap( 'msIIS' ) )
    {
        my $iisParam = {
            'precedence'    =>  -100000,
            'comment'       => 'Microsoft Internet Information Server'
            };

        my @iisTemplates;
        if( $devdetails->hasCap( 'msFtpStats' ) )
        {
            push( @iisTemplates,
                  'MicrosoftWindows::microsoft-iis-ftp-stats' );
        }
        if( $devdetails->hasCap( 'msHttpStats' ) )
        {
            push( @iisTemplates,
                  'MicrosoftWindows::microsoft-iis-http-stats' );
        }


        my $iisNode = $cb->addSubtree( $devNode, 'MS_IIS', $iisParam,
                                       \@iisTemplates );
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
