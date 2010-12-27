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

# $Id: ReportGenerator.pm,v 1.1 2010-12-27 00:03:37 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Package for reports generation
# Classes should inherit Torrus::ReportGenerator

package Torrus::ReportGenerator;

use strict;
use Date::Parse;

use Torrus::Log;
use Torrus::SQL::Reports;
use Torrus::SQL::SrvExport;

sub new
{
    my $class = shift;
    my $options = shift;

    if( not ref( $options ) or
        not defined( $options->{'Date'} ) or
        not defined( $options->{'Time'} ) or
        not defined( $options->{'Name'} ) )
    {
        Error('Missing options in Torrus::Report constructor');
        return undef;
    }
    
    my $self = {};
    bless ($self, $class);

    # For monthly reports, adjust date and time for the first day of the month
    if( $self->isMonthly() )
    {
        $options->{'Time'} = '00:00';
        my ($ss,$mm,$hh,$day,$month,$year,$zone) =
            strptime( $options->{'Date'} );
        $year += 1900;
        $month++;
        $self->{'StartDate'} = sprintf('%.4d-%.2d-01', $year, $month);
        $options->{'Date'} = $self->{'StartDate'};
        $self->{'StartUnixTime'} = str2time( $self->{'StartDate'} );
        $self->{'Year'} = $year;
        $self->{'Month'} = $month;

        # Count the number of seconds in the month and define the end date
        my $endyear = $year;
        my $endmonth = $month + 1;

        if( $endmonth > 12 )
        {
            $endmonth = 1;
            $endyear++;
        }

        my $enddate = sprintf('%.4d-%.2d-01', $endyear, $endmonth);
        $self->{'EndDate'} = $enddate;
        $self->{'EndUnixTime'} = str2time( $self->{'EndDate'} );
        
        $self->{'RangeSeconds'} =
            $self->{'EndUnixTime'} - $self->{'StartUnixTime'};
    }

    if( $self->usesSrvExport() )
    {
        my $srvExp =
            Torrus::SQL::SrvExport->new( $options->{'SrvExportSqlSubtype'} );
        if( not defined( $srvExp ) )
        {
            Error('Cannot connect to the database');
            return undef;
        }
        $self->{'srvexport'} = $srvExp;
    }
    
    $self->{'options'} = $options;

    my $sqlRep = Torrus::SQL::Reports->new( $options->{'ReportsSqlSubtype'} );
    if( not defined( $sqlRep ) )
    {
        Error('Cannot connect to the database');
        return undef;
    }
    $self->{'backend'} = $sqlRep;
    
    my $reportId = $sqlRep->reportId( $options->{'Date'},
                                      $options->{'Time'},
                                      $options->{'Name'} );
    $self->{'reportId'} = $reportId;
    
    if( $sqlRep->isComplete( $reportId ) )
    {
        Error('Report already exists');
        return undef;
    }
    
    return $self;    
}


sub generate
{
    die('Virtual method called');    
}


sub isMonthly
{
    return 0;
}

sub usesSrvExport
{
    return 0;
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
