#  Copyright (C) 2005  Stanislav Sinyagin
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

# $Id: MonthlySrvUsage.pm,v 1.1 2010-12-27 00:03:58 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# For all service IDs available, build monthly usage figures:
# Average, Maximum, and Percentile (default 95th percentile)
# 

package Torrus::ReportGenerator::MonthlySrvUsage;

use strict;
use POSIX qw(floor);
use Date::Parse;
use Math::BigFloat;

use Torrus::Log;
use Torrus::ReportGenerator;
use Torrus::ServiceID;

use base 'Torrus::ReportGenerator';

sub isMonthly
{
    return 1;
}

sub usesSrvExport
{
    return 1;
}


sub generate
{
    my $self = shift;

    my $percentile = $self->{'options'}->{'Percentile'};
    if( not defined( $percentile ) )
    {
        $percentile = 95;
    }

    my $step = $self->{'options'}->{'Step'};
    if( not defined( $step ) )
    {
        $step = 300;
    }

    my $srvIDParams = new Torrus::ServiceID();
    
    my $srvIDs = $self->{'srvexport'}->getServiceIDs();
    foreach my $serviceid ( @{$srvIDs} )
    {
        &Torrus::DB::checkInterrupted();
        
        my $data = $self->{'srvexport'}->getIntervalData
            ( $self->{'StartDate'}, $self->{'EndDate'}, $serviceid );

        &Torrus::DB::checkInterrupted();

        next if scalar( @{$data} ) == 0;
        Debug('MonthlySrvUsage: Generating report for ' . $serviceid);

        my $params = $srvIDParams->getParams( $serviceid );
        
        my @aligned = ();
        $#aligned = floor( $self->{'RangeSeconds'} / $step );
        my $nDatapoints = scalar( @aligned );
            
        # Fill in the aligned array. For each interval by modulo(step),
        # we take the maximum value from the available data

        my $maxVal = 0;
        
        foreach my $row ( @{$data} )
        {
            my $rowtime = str2time( $row->{'srv_date'} . 'T' .
                                    $row->{'srv_time'} );
            my $pos = floor( ($rowtime - $self->{'StartUnixTime'}) / $step );
            my $value = Math::BigFloat->new( $row->{'value'} );
            if( $value->is_nan() )
            {
                $value->bzero();
                $row->{'value'} = 0;
            }
            
            if( ( not defined( $aligned[$pos] ) ) or
                $aligned[$pos] < $value )
            {
                $aligned[$pos] = $value;
                if( $value > $maxVal )
                {
                    $maxVal = $value;
                }
            }
        }

        &Torrus::DB::checkInterrupted();

        # Set undefined values to zero and calculate the average

        my $sum = Math::BigFloat->new(0);
        my $unavailCount = 0;
        foreach my $pos ( 0 .. $#aligned )
        {
            if( not defined( $aligned[$pos] ) )
            {
                $aligned[$pos] = 0;
                $unavailCount++;
            }
            else
            {
                $sum += $aligned[$pos];
            }
        }

        &Torrus::DB::checkInterrupted();

        my $avgVal = $sum / $nDatapoints;

        # Calculate the percentile

        my @sorted = sort {$a <=> $b} @aligned;
        my $pcPos = floor( $nDatapoints * $percentile / 100 );
        my $pcVal = $sorted[$pcPos];

        # Calculate the total volume if it's a counter
        my $volume = Math::BigFloat->new(0);
        my $volumeDefined = 0;
        if( not defined( $params->{'dstype'} ) or
            $params->{'dstype'} =~ /^COUNTER/o )
        {
            $volumeDefined = 1;
            foreach my $row ( @{$data} )
            {
                $volume += $row->{'value'} * $row->{'intvl'};
            }
        }

        # Adjust units and scale

        my $usageUnits = '';
        my $volumeUnits = '';
        if( not defined( $params->{'units'} ) or
            $params->{'units'} eq 'bytes' )
        {
            # Adjust bytes into megabit per second
            $usageUnits = 'Mbps';
            $maxVal *= 8e-6;
            $avgVal *= 8e-6;
            $pcVal  *= 8e-6;

            # Adjust volume bytes into megabytes
            $volumeUnits = 'GB';
            $volume /= 1073741824;
        }
        
        $self->{'backend'}->addField( $self->{'reportId'}, {
            'name'      => 'MAX',
            'serviceid' => $serviceid,
            'value'     => $maxVal,
            'units'     => $usageUnits });
        
        $self->{'backend'}->addField( $self->{'reportId'}, {
            'name'      => 'AVG',
            'serviceid' => $serviceid,
            'value'     => $avgVal,
            'units'     => $usageUnits });
                                      
        $self->{'backend'}->addField( $self->{'reportId'}, {
            'name'      => sprintf('%s%s', $percentile, 'TH_PERCENTILE'),
            'serviceid' => $serviceid,
            'value'     => $pcVal,
            'units'     => $usageUnits });
        
        $self->{'backend'}->addField( $self->{'reportId'}, {
            'name'      => 'UNAVAIL',
            'serviceid' => $serviceid,
            'value'     => ($unavailCount*100)/$nDatapoints,
            'units'     => '%' });

        if( $volumeDefined )
        {
            $self->{'backend'}->addField( $self->{'reportId'}, {
                'name'      => 'VOLUME',
                'serviceid' => $serviceid,
                'value'     => $volume,
                'units'     => $volumeUnits });
        }
    }

    &Torrus::DB::checkInterrupted();

    $self->{'backend'}->finalize( $self->{'reportId'} );
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
