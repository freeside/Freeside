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

# $Id: ReportOutput.pm,v 1.1 2010-12-27 00:03:40 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Package for generating report output to HTML, PDF, whatever
# Media-specific classes should inherit from this package
# and 

package Torrus::ReportOutput;

use strict;

use Torrus::Log;
use Torrus::SQL::Reports;
use Torrus::ServiceID;


sub new
{
    my $class = shift;
    my $options = shift;
    
    my $self = {};
    bless ($self, $class);
    
    $self->{'options'} = $options;    
    defined( $self->{'options'}->{'Tree'} ) or die;
    
    my $sqlRep = Torrus::SQL::Reports->new( $options->{'ReportsSqlSubtype'} );
    if( not defined( $sqlRep ) )
    {
        Error('Cannot connect to the database');
        return undef;
    }
    $self->{'backend'} = $sqlRep;

    my $outdir = $Torrus::Global::reportsDir . '/' .
        $self->{'options'}->{'Tree'};
    $self->{'outdir'} = $outdir;

    if( not -d $outdir )
    {
        if( not mkdir( $outdir ) )
        {
            Error('Cannot create directory ' . $outdir . ': ' . $!);
            return undef;
        }
    }

    return $self;    
}

# initialize the subclasses' internals
sub init
{
    my $self = shift;
    
    return 1;
}


sub generate
{
    my $self = shift;

    my $ok = 1;
    
    my %monthlyReportNames;

    my $srvIdList;
    if( not $self->{'options'}->{'All_Service_IDs'} )
    {
        my $srvId = new Torrus::ServiceID;
        $srvIdList = $srvId->getAllForTree( $self->{'options'}->{'Tree'} );
    }
    
    my $allReports = $self->{'backend'}->getAllReports( $srvIdList );

    # frontpage, title, list of years, etc.
    $self->genIntroduction( $allReports );

    while( my( $year, $yearRef ) = each %{$allReports} )
    {
        my $monthlyReportFields = {};
        my $srvidMonthlyFields = {};
        
        while( my( $month, $monthRef ) = each %{$yearRef} )
        {
            my $dailyReportFields = {};
            
            while( my( $day, $dayRef ) = each %{$monthRef} )
            {
                while( my( $reportName, $fieldsRef ) = each %{$dayRef} )
                {
                    # Check if the report is monthly
                    if( not defined( $monthlyReportNames{$reportName} ) )
                    {
                        my $class =
                            $Torrus::ReportGenerator::modules{$reportName};
                        eval( 'require ' . $class );
                        die( $@ ) if $@;

                        $monthlyReportNames{$reportName} =
                            $class->isMonthly() ? 1:0;
                    }

                    # This report is monthly -- do not include it in daily
                    # list.
                    if( $monthlyReportNames{$reportName} )
                    {
                        $monthlyReportFields->{$month}{$reportName} =
                            $fieldsRef;
                        while( my( $serviceid, $fref ) = each %{$fieldsRef} )
                        {
                            $srvidMonthlyFields->{$serviceid}{$reportName}->{
                                $month} = $fref;
                        }
                    }
                    else
                    {
                        $dailyReportFields->{$day} = $dayRef;
                    }
                }
            }

            $ok = $self->genDailyOutput( $year, $month, $dailyReportFields )?
                $ok:0;
        }

        $ok = $self->genSrvIdOutput( $year, $srvidMonthlyFields ) ? $ok:0;
        $ok = $self->genMonthlyOutput( $year, $monthlyReportFields ) ? $ok:0;;
    }

    return $ok;
}


# Print the head page and years reference
sub genIntroduction
{
    my $self = shift;
    my $allReports = shift;

    return 1;
}


# Print monthly report for a given service ID
# The fields argument is a hash of hashes:
# serviceid => reportname => month => fieldname => {value, units}
sub genSrvIdOutput
{
    my $self = shift;
    my $year = shift;    
    my $fields = shift;

    return 1;
}
    
# Print daily report
# Fields structure:
# day => reportname => serviceid => fieldname => {value, units}
sub genDailyOutput
{
    my $self = shift;
    my $year = shift;    
    my $month = shift;    
    my $fields = shift;

    return 1;
}

# Print monthly report
# fields:
# month => reportname => serviceid => fieldname => {value, units}
sub genMonthlyOutput
{
    my $self = shift;
    my $year = shift;    
    my $fields = shift;

    return 1;
}    
    
        
    

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
