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

# $Id: HTML.pm,v 1.2 2010-12-30 07:25:30 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::ReportOutput::HTML;

use strict;
use Template;
use Date::Format;

use Torrus::Log;
use Torrus::ReportOutput;
use Torrus::SiteConfig;

use base qw( Torrus::ReportOutput::Freeside Torrus::ReportOutput );

our @monthNames = qw
    (January February March April May June
     July August September October November December);

sub init
{
    my $self = shift;

    Torrus::SiteConfig::loadStyling();
    
    my $htmldir = $self->{'outdir'} . '/html';
    if( not -d $htmldir )
    {
        Verbose('Creating directory: ' . $htmldir);
        if( not mkdir( $htmldir ) )
        {
            Error('Cannot create directory ' . $htmldir . ': ' . $!);
            return 0;
        }
    }
    $self->{'htmldir'} = $htmldir;
    
    $self->{'tt'} =
        new Template(INCLUDE_PATH => $Torrus::Global::templateDirs,
                     TRIM => 1);
    return 1;
}


# Print the head page and years reference
sub genIntroduction
{
    my $self = shift;
    my $allReports = shift;

    return $self->render({
        'filename' => $self->indexFilename(),
        'template' => 'index',
        'data' => $allReports });    
}


# Print monthly report for a given service ID
# The fields argument is a hash of hashes:
# serviceid => reportname => month => fieldname => {value, units}
sub genSrvIdOutput
{
    my $self = shift;
    my $year = shift;    
    my $fields = shift;

    my $ok = 1;
    while( my( $serviceid, $ref ) = each %{$fields} )
    {
        $ok = $self->render({
            'filename' => $self->srvIdFilename($year, $serviceid),
            'template' => 'serviceid',
            'data' => $ref,
            'serviceid' => $serviceid,
            'year' => $year }) ? $ok:0; 
    }
    return $ok;
}


# Print daily report -- NOT IMPLEMENTED YET
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

    my $ok = 1;
    my @months;
    while( my( $month, $ref ) = each %{$fields} )
    {
        if( $self->render({
            'filename' => $self->monthlyFilename($year, $month),
            'template' => 'monthly',
            'data'     => $ref,
            'year'     => $year,
            'month'    => $month }) )
        {
            push( @months, $month );
        }
        else
        {
            $ok = 0;
        }
    }

    my @sorted = sort {$a <=>$b} @months;
    $ok = $self->render({
        'filename' => $self->yearlyFilename($year),
        'template' => 'yearly',
        'data'     => {'months' => \@sorted},
        'year'     => $year }) ? $ok:0;
    return $ok;
}
    

sub indexFilename
{
    return 'index.html';
}


sub srvIdFilename
{
    my $self = shift;
    my $year = shift;
    my $serviceid = shift;

    return sprintf('%.4d_serviceid_%s.html', $year, $serviceid);
}

sub monthlyFilename
{
    my $self = shift;
    my $year = shift;
    my $month = shift;

    return sprintf('%.4d_monthly_%.2d.html', $year, $month);
}

sub yearlyFilename
{
    my $self = shift;
    my $year = shift;

    return sprintf('%.4d_yearly.html', $year);
}
    
    

sub render
{
    my $self = shift;
    my $opt = shift;

    my $outfile = $self->{'htmldir'} . '/' . $opt->{'filename'};
    my $tmplfile = $Torrus::ReportOutput::HTML::templates{$opt->{'template'}};
    Debug('Rendering ' . $outfile . ' from ' . $tmplfile);
    
    my $ttvars =
    {
        'plainURL'   => $Torrus::Renderer::plainURL,
        'style'      => sub { return $self->style($_[0]); },
        'treeName'   => $self->{'options'}->{'Tree'},
        'companyName'=> $Torrus::Renderer::companyName,
        'companyURL' => $Torrus::Renderer::companyURL,
        'siteInfo'   => $Torrus::Renderer::siteInfo,
        'version'    => $Torrus::Global::version,
        'xmlnorm'    => \&xmlnormalize,
        'data'       => $opt->{'data'},
        'year'       => $opt->{'year'},
        'month'      => $opt->{'month'},
        'serviceid'  => $opt->{'serviceid'},
        'indexUrl'   => sub {
            return $self->reportUrl($self->indexFilename());},
        'srvIdUrl'   => sub {
            return $self->reportUrl($self->srvIdFilename($opt->{'year'},
                                                         $_[0]));},
        'monthlyUrl' => sub {
            return $self->reportUrl($self->monthlyFilename($opt->{'year'},
                                                           $_[0]));},
        'yearlyUrl' => sub {
            return $self->reportUrl($self->yearlyFilename($_[0]));},
        'monthName' => sub {$self->monthName($_[0]);},
        'formatValue' => sub {
            if( ref($_[0]))
            {
                return sprintf('%.2f %s', $_[0]->{'value'}, $_[0]->{'units'});
            }
            else
            {
                return 'N/A';
            }},
        'timestamp'  => sub { return time2str($Torrus::Renderer::timeFormat,
                                              time()); },

        #Freeside
        'freesideHeader' => sub { return $self->freesideHeader(@_); },
        'freesideFooter' => sub { return $self->freesideFooter(); },
    };
    
    my $result = $self->{'tt'}->process( $tmplfile, $ttvars, $outfile );

    if( not $result )
    {
        Error("Error while rendering " . $outfile . ": " .
              $self->{'tt'}->error());
        return 0;
    }
    return 1;
}


sub style
{
    my $self = shift;
    my $object = shift;

    my $ret = $Torrus::Renderer::styling{'report'}{$object};
    if( not defined( $ret ) )
    {
        $ret = $Torrus::Renderer::styling{'default'}{$object};
    }

    return $ret;
}

sub monthName
{
    my $self = shift;
    my $month = shift;

    return $monthNames[ $month - 1 ];
}


sub reportUrl
{
    my $self = shift;
    my $filename = shift;

    return $Torrus::Renderer::rendererURL . '/' .
        $self->{'options'}->{'Tree'} . '?htmlreport=' . $filename;
}

sub xmlnormalize
{
    my( $txt )= @_;

    $txt =~ s/\&/\&amp\;/gm;
    $txt =~ s/\</\&lt\;/gm;
    $txt =~ s/\>/\&gt\;/gm;
    $txt =~ s/\'/\&apos\;/gm;
    $txt =~ s/\"/\&quot\;/gm;

    return $txt;
}

    

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
