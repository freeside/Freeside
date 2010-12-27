#
#  Copyright (C) 2004-2005  Christian Schnidrig
#  Copyright (C) 2007  Stanislav Sinyagin
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
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

# $Id: CDef.pm,v 1.1 2010-12-27 00:03:57 ivan Exp $
# Christian Schnidrig <christian.schnidrig@bluewin.ch>


# Torrus collector module for combining multiple datasources into one

package Torrus::Collector::CDef;

use strict;

use Torrus::Collector::CDef_Params;
use Torrus::ConfigTree;
use Torrus::Log;
use Torrus::RPN;
use Torrus::DataAccess;
use Torrus::Collector::RRDStorage;

# Register the collector type
$Torrus::Collector::collectorTypes{'cdef'} = 1;

# List of needed parameters and default values
$Torrus::Collector::params{'cdef'} = \%Torrus::Collector::CDef_Params::params;
$Torrus::Collector::initTarget{'cdef'} = \&Torrus::Collector::CDef::initTarget;


# get access to the configTree;
$Torrus::Collector::needsConfigTree{'cdef'}{'runCollector'} = 1;

sub initTarget
{
    my $collector = shift;
    my $token = shift;
    
    my $cref = $collector->collectorData( 'cdef' );
    if( not defined( $cref->{'crefTokens'} ) )
    {
        $cref->{'crefTokens'} = [];
    }

    push( @{$cref->{'crefTokens'}}, $token );
    
    return 1;
}

# This is first executed per target
$Torrus::Collector::runCollector{'cdef'} =
    \&Torrus::Collector::CDef::runCollector;

sub runCollector
{
    my $collector = shift;
    my $cref = shift;
    my $config_tree = $collector->configTree();

    my $now = time();
    my $da = new Torrus::DataAccess;

    # By default, try to get the data from one period behind
    my $defaultAccessTime = $now -
        ( $now % $collector->period() ) + $collector->offset();
    
    foreach my $token ( @{$cref->{'crefTokens'}} )
    {
        &Torrus::DB::checkInterrupted();
        
        my $accessTime = $defaultAccessTime -
            ( $collector->period() *
              $collector->param( $token, 'cdef-collector-delay' ) );

        # The RRDtool is non-reentrant, and we need to be careful
        # when running multiple threads
        Torrus::Collector::RRDStorage::semaphoreDown();
        
        my ($value, $timestamp) =
            $da->read_RPN( $config_tree, $token,
                           $collector->param( $token, 'rpn-expr' ),
                           $accessTime );

        Torrus::Collector::RRDStorage::semaphoreUp();

        if( defined( $value ) )
        {
            if ( $timestamp <
                 ( $accessTime -
                   ( $collector->period() *
                     $collector->param( $token, 'cdef-collector-tolerance' ))))
            {
                Error( "CDEF: Data is " . ($accessTime-$timestamp) .
                       " seconds too old for " . $collector->path($token) );
            }
            else
            {
                $collector->setValue( $token, $value, $timestamp );
            }
        }
    }
}



1;

