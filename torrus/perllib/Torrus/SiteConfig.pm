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

# $Id: SiteConfig.pm,v 1.1 2010-12-27 00:03:39 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

## %Torrus::Global::treeConfig manipulation

package Torrus::SiteConfig;

use Torrus::Log;
use strict;

our %validDaemonNames = ('collector' => 1,
                         'monitor'   => 1);

our %mandatoryGraphStyles =
    (
     'SingleGraph'     => {'color' => 1, 'line'  => 1},
     'HWBoundary'     => {'color' => 1, 'line'  => 1},
     'HWFailure'      => {'color' => 1},
     'HruleMin'       => {'color' => 1},
     'HruleNormal'    => {'color' => 1},
     'HruleMax'       => {'color' => 1},
     'BpsIn'          => {'color' => 1, 'line'  => 1},
     'BpsOut'         => {'color' => 1, 'line'  => 1}
     );

%Torrus::SiteConfig::validLineStyles =
    (
     'LINE1' => 1,
     'LINE2' => 1,
     'LINE3' => 1,
     'AREA'  => 1,
     'STACK' => 1
     );

## Verify the correctness of %Torrus::Global::treeConfig contents

sub verify
{
    my $ok = 1;
    if( not (scalar( keys %Torrus::Global::treeConfig )) )
    {
        Error('%Torrus::Global::treeConfig is not defined or empty');
        $ok = 0;
    }

    foreach my $tree ( keys %Torrus::Global::treeConfig )
    {
        if( $tree !~ /^[a-zA-Z][a-zA-Z0-9_\-]*$/o )
        {
            Error("Invalid tree name: " . $tree);
            $ok = 0;
            next;
        }

        if( not $Torrus::Global::treeConfig{$tree}{'description'} )
        {
            Error("Missing description for the tree named \"" . $tree . "\"");
            $ok = 0;
        }

        my $xmlfiles = $Torrus::Global::treeConfig{$tree}{'xmlfiles'};
        if( not ref( $xmlfiles ) or not scalar( @{$xmlfiles} ) )
        {
            Error("'xmlfiles' array is not defined for the tree named \"" .
                  $tree . "\"");
            $ok = 0;
        }
        else
        {
            foreach my $file ( @{$xmlfiles} )
            {
                $ok = findXMLFile( $file,
                                   "in the tree named \"" . $tree . "\"" ) ?
                                       $ok:0;
            }

            if( ref( $Torrus::Global::treeConfig{$tree}{'run'} ) )
            {
                foreach my $daemon
                    ( keys %{$Torrus::Global::treeConfig{$tree}{'run'}} )
                {
                    if( not $validDaemonNames{$daemon} )
                    {
                        Error("\"" . $daemon . "\" is not a correct daemon " .
                              "name in the tree named \"" . $tree . "\"");
                        $ok = 0;
                    }
                }
            }
        }
    }

    foreach my $file ( @Torrus::Global::xmlAlwaysIncludeFirst )
    {
        $ok = findXMLFile( $file,
                           'in @Torrus::Global::xmlAlwaysIncludeFirst' ) ?
                               $ok:0;
    }
    foreach my $file ( @Torrus::Global::xmlAlwaysIncludeLast )
    {
        $ok = findXMLFile( $file,
                           'in @Torrus::Global::xmlAlwaysIncludeLast' ) ?
                               $ok:0;
    }

    # Validate the styling profile

    my $file = $Torrus::Global::stylingDir . '/' .
        $Torrus::Renderer::stylingProfile . '.pl';
    if( -r $file )
    {
        require $file;

        #Color names are always there
        require $Torrus::Global::stylingDir . '/colornames.pl';

        if( defined($Torrus::Renderer::stylingProfileOverlay) )
        {
            my $overlay = $Torrus::Renderer::stylingProfileOverlay;
            if( -r $overlay )
            {
                require $overlay;
            }
            else
            {
                Error('Error reading styling profile overlay from ' .
                      $overlay . ': File is not readable');
                $ok = 0;
            }
        }

        my $profile = \%Torrus::Renderer::graphStyles;
        # Check if mandatory parameters present
        foreach my $element ( keys %mandatoryGraphStyles )
        {
            if( ref( $profile->{$element} ) )
            {
                if( $mandatoryGraphStyles{$element}{'color'}
                    and not defined( $profile->{$element}{'color'} ) )
                {
                    Error('Mandatory color for ' . $element .
                          ' is not defined in ' . $file);
                    $ok = 0;
                }
                if( $mandatoryGraphStyles{$element}{'line'}
                    and not defined( $profile->{$element}{'line'} ) )
                {
                    Error('Mandatory line style for ' . $element .
                          ' is not defined in ' . $file);
                    $ok = 0;
                }
            }
            else
            {
                Error('Mandatory styling for ' . $element .
                      ' is not defined in ' . $file);
                $ok = 0;
            }
        }
        # Check validity of all parameters
        foreach my $element ( keys %{$profile} )
        {
            if( defined( $profile->{$element}{'color'} ) )
            {
                my $color = $profile->{$element}{'color'};
                my $recursionLimit = 100;

                while( $color =~ /^\#\#(\S+)$/ )
                {
                    if( $recursionLimit-- <= 0 )
                    {
                        Error('Color recursion is too deep');
                        $ok = 0;
                    }
                    else
                    {
                        my $colorName = $1;
                        $color = $profile->{$colorName}{'color'};
                        if( not defined( $color ) )
                        {
                            Error('No color is defined for ' . $colorName);
                            $ok = 0;
                        }
                    }
                }

                if( $color !~ /^\#[0-9a-fA-F]{6}$/ )
                {
                    Error('Invalid color specification for ' . $element .
                          ' in ' . $file);
                    $ok = 0;
                }
            }
            if( defined( $profile->{$element}{'line'} ) )
            {
                if( not $Torrus::SiteConfig::validLineStyles{
                    $profile->{$element}{'line'}} )
                {
                    Error('Invalid line specification for ' . $element .
                          ' in ' . $file);
                    $ok = 0;
                }
            }
        }
    }
    else
    {
        Error('Error reading styling profile from ' . $file .
              ': File is not readable');
        $ok = 0;
    }

    return $ok;
}


sub findXMLFile
{
    my $file = shift;
    my $msg = shift;

    my $filename;
    if( defined( $file ) )
    {
        my $found = 0;
        foreach my $dir ( @Torrus::Global::xmlDirs )
        {
            $filename = $dir . '/' . $file;
            if( -r $filename )
            {
                $found = 1;
                last;
            }
        }
        
        if( not $found )
        {
            Error("Cannot find file: " . $file);
            $filename = undef;
        }
    }
    else
    {
        Error("File name undefined " . $msg);
    }
    return $filename;
}


sub treeExists
{
    my $tree = shift;
    return defined( $Torrus::Global::treeConfig{$tree} );
}


sub listTreeNames
{
    return( sort keys %Torrus::Global::treeConfig );
}


sub mayRunCollector
{
    my $tree = shift;
    my $run = $Torrus::Global::treeConfig{$tree}{'run'}{'collector'};
    return( defined($run) and $run > 0 );   
}

sub collectorInstances
{
    my $tree = shift;
    my $run = $Torrus::Global::treeConfig{$tree}{'run'}{'collector'};
    return( (defined($run) and $run > 1) ? int($run) : 1 ); 
}

sub mayRunMonitor
{
    my $tree = shift;
    return $Torrus::Global::treeConfig{$tree}{'run'}{'monitor'};
}


sub listXmlFiles
{
    my $tree = shift;
    return @{$Torrus::Global::treeConfig{$tree}{'xmlfiles'}};
}


sub treeDescription
{
    my $tree = shift;
    return $Torrus::Global::treeConfig{$tree}{'description'};
}


sub loadStyling
{
    require $Torrus::Global::stylingDir . '/' .
        $Torrus::Renderer::stylingProfile . '.pl';

    require $Torrus::Global::stylingDir . '/colornames.pl';

    if( defined($Torrus::Renderer::stylingProfileOverlay) )
    {
        require $Torrus::Renderer::stylingProfileOverlay;
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
