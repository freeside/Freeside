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

# $Id: Validator.pm,v 1.1 2010-12-27 00:03:45 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


package Torrus::ConfigTree::Validator;

use Torrus::ConfigTree;
use Torrus::Log;
use Torrus::RPN;
use Torrus::SiteConfig;
use strict;

Torrus::SiteConfig::loadStyling();

%Torrus::ConfigTree::Validator::reportedErrors = ();

my %rrd_params =
    (
     'leaf-type' => {'rrd-def' => {'rrd-ds' => undef,
                                   'rrd-cf' => {'AVERAGE' => undef,
                                                'MIN'     => undef,
                                                'MAX'     => undef,
                                                'LAST'    => undef},
                                   'data-file' => undef,
                                   'data-dir'  => undef},
                     'rrd-cdef' => {'rpn-expr' => undef}},
     );

my %rrdmulti_params = ( 'ds-names' => undef );

# Plugins might need to add a new storage type
our %collector_params =
    (
     'collector-type'  => undef,
     '@storage-type'   => {
         'rrd' => {
             'data-file'              => undef,
             'data-dir'               => undef,
             'leaf-type'              => {
                 'rrd-def'  => {'rrd-ds' => undef,
                                'rrd-cf' => {'AVERAGE' => undef,
                                             'MIN'     => undef,
                                             'MAX'     => undef,
                                             'LAST'    => undef},
                                'rrd-create-dstype' => {'GAUGE' => undef,
                                                        'COUNTER' => undef,
                                                        'DERIVE'  => undef,
                                                        'ABSOLUTE' => undef },
                                'rrd-create-rra'         => undef,
                                'rrd-create-heartbeat'   => undef,
                                '+rrd-hwpredict'         => {
                                    'enabled' => {
                                        'rrd-create-hw-rralen' => undef},
                                    'disabled' => undef,
                                }}}},
         'ext' => {
             'ext-dstype' => {
                 'GAUGE' => undef,
                 'COUNTER32' => undef,
                 'COUNTER64' => undef },
             'ext-service-id' => undef,
             '+ext-service-units' => {
                 'bytes' => undef }}},
     'collector-period'      => undef,
     'collector-timeoffset'  => undef,
     '+collector-scale'      => undef,
     '+collector-dispersed-timeoffset' => {
         'no' => undef,
         'yes' => undef }
     # collector-timeoffset-min, max, step, and hashstring are validated
     # during post-processing
     );


# Plugins might in theory create new datasource types
our %leaf_params =
    ('ds-type' => {'rrd-file' => \%rrd_params,
                   'rrd-multigraph' => \%rrdmulti_params,
                   'collector' => \%collector_params},
     'rrgraph-views'             => undef,
     '+rrd-scaling-base'         => {'1000' => undef, '1024' => undef},
     '+graph-logarithmic'        => {'yes'  => undef, 'no' => undef},
     '+graph-rigid-boundaries'   => {'yes'  => undef, 'no' => undef},
     '+graph-ignore-decorations' => {'yes'  => undef, 'no' => undef});


my %monitor_params =
    ('monitor-type' => {'expression' => {'rpn-expr' => undef},
                        'failures' => undef},
     'action'       => undef,
     'expires'      => undef
     );

my %action_params =
    ('action-type' => {'tset' => {'tset-name' => undef},
                       'exec' => {'command' => undef} }
     );

my %view_params =
    ('expires' => undef,
     'view-type' => {'rrgraph' => {'width' => undef,
                                   'height' => undef,
                                   'start' => undef,
                                   'line-style' => undef,
                                   'line-color' => undef,
                                   '+ignore-limits' => {
                                       'yes'=>undef, 'no'=>undef },
                                   '+ignore-lower-limit' => {
                                       'yes'=>undef, 'no'=>undef },
                                   '+ignore-upper-limit' => {
                                       'yes'=>undef, 'no'=>undef }},
                     'rrprint' => {'start' => undef,
                                   'print-cf' => undef},
                     'html' => {'html-template' => undef},
                     'adminfo' => undef}
     );


# Load additional validation, configurable from
# torrus-config.pl and torrus-siteconfig.pl

foreach my $mod ( @Torrus::Validator::loadLeafValidators )
{
    eval( 'require ' . $mod );
    die( $@ ) if $@;
    eval( '&' . $mod . '::initValidatorLeafParams( \%leaf_params )' );
    die( $@ ) if $@;
}


sub validateNodes
{
    my $config_tree = shift;
    my $token = $config_tree->token('/');

    if( defined($token) )
    {
        return validateNode($config_tree, $token);
    }
    else
    {
        Error("The datasource tree is empty");
        return 0;
    }
}

sub validateNode
{
    my $config_tree = shift;
    my $token = shift;

    &Torrus::DB::checkInterrupted();

    my $ok = 1;

    if( $config_tree->isLeaf($token) )
    {
        # Verify the default view
        my $view = $config_tree->getNodeParam( $token, 'default-leaf-view' );
        if( not defined( $view ) )
        {
            my $path = $config_tree->path( $token );
            Error("Default view is not defined for leaf $path");
            $ok = 0;
        }
        elsif( not $config_tree->{'validator'}{'viewExists'}{$view} and
               not $config_tree->viewExists( $view ) )
        {
            my $path = $config_tree->path( $token );
            Error("Non-existent view is defined as default for leaf $path");
            $ok = 0;
        }
        else
        {
            # Cache the view name
            $config_tree->{'validator'}{'viewExists'}{$view} = 1;
        }

        # Verify parameters
        $ok = validateInstanceParams($config_tree, $token,
                                     'node', \%leaf_params);

        if( $ok )
        {
            my $rrviewslist =
                $config_tree->getNodeParam( $token, 'rrgraph-views' );

            # Check the cache first
            if( not $config_tree->{'validator'}{'graphviews'}{$rrviewslist} )
            {
                my @rrviews = split( ',', $rrviewslist );

                if( scalar(@rrviews) != 5 )
                {
                    my $path = $config_tree->path( $token );
                    Error('rrgraph-views sould refer 5 views in' . $path);
                    $ok = 0;
                }
                else
                {
                    foreach my $view ( @rrviews )
                    {
                        if( not $config_tree->viewExists( $view ) )
                        {
                            my $path = $config_tree->path( $token );
                            Error("Non-existent view ($view) is defined in " .
                                  "rrgraph-views for $path");
                            $ok = 0;
                        }
                        elsif( $config_tree->getParam($view, 'view-type') ne
                               'rrgraph' )
                        {
                            my $path = $config_tree->path( $token );
                            Error("View $view is not of type rrgraph in " .
                                  "rrgraph-views for $path");
                            $ok = 0;
                        }
                    }
                }

                if( $ok )
                {
                    # Store the cache
                    $config_tree->{'validator'}{'graphviews'}{$rrviewslist}=1;
                }
            }
        }

        # Verify monitor references
        my $mlist = $config_tree->getNodeParam( $token, 'monitor' );
        if( defined $mlist )
        {
            foreach my $param ( 'monitor-period', 'monitor-timeoffset' )
            {
                if( not defined( $config_tree->getNodeParam( $token,
                                                             $param ) ) )
                {
                    my $path = $config_tree->path( $token );
                    Error('Mandatory parameter ' . $param .
                          ' is not defined in ' . $path);
                    $ok = 0;
                }
            }
            
            foreach my $monitor ( split(',', $mlist) )
            {
                if( not $config_tree->{'validator'}{'monitorExists'}{$monitor}
                    and
                    not $config_tree->monitorExists( $monitor ) )
                {
                    my $path = $config_tree->path( $token );
                    Error("Non-existent monitor: $monitor in $path");
                    $ok = 0;
                }
                else
                {
                    $config_tree->{'validator'}{'monitorExists'}{$monitor} = 1;
                }
            }
            
            my $varstring =
                $config_tree->getNodeParam( $token, 'monitor-vars' );
            if( defined $varstring )
            {
                foreach my $pair ( split( '\s*;\s*', $varstring ) )
                {
                    if( $pair !~ /^\w+\s*\=\s*[0-9\-+.eU]+$/o )
                    {
                        Error("Syntax error in monitor variables: $pair");
                        $ok = 0;
                    }
                }
            }

            my $action_target =
                $config_tree->getNodeParam($token, 'monitor-action-target');
            if( defined( $action_target ) )
            {
                my $target = $config_tree->getRelative($token, $action_target);
                if( not defined( $target ) )
                {
                    my $path = $config_tree->path( $token );
                    Error('monitor-action-target points to an invalid path: ' .
                          $action_target . ' in ' . $path);
                    $ok = 0;
                }
                elsif( not $config_tree->isLeaf( $target ) )
                {
                    my $path = $config_tree->path( $token );
                    Error('monitor-action-target must point to a leaf: ' .
                          $action_target . ' in ' . $path);
                    $ok = 0;
                }
            }
        }

        # Verify if the data-dir exists
        my $datadir = $config_tree->getNodeParam( $token, 'data-dir' );
        if( defined $datadir )
        {
            if( not $config_tree->{'validator'}{'dirExists'}{$datadir} and
                not ( -d $datadir ) and
                not $Torrus::ConfigTree::Validator::reportedErrors{$datadir} )
            {
                my $path = $config_tree->path( $token );
                Error("Directory does not exist: $datadir in $path");
                $ok = 0;
                $Torrus::ConfigTree::Validator::reportedErrors{$datadir} = 1;
            }
            else
            {
                # Store the cache
                $config_tree->{'validator'}{'dirExists'}{$datadir} = 1;
            }
        }

        # Verify type-specific parameters
        my $dsType = $config_tree->getNodeParam( $token, 'ds-type' );
        if( not defined( $dsType ) )
        {
            # Writer has already complained
            return 0;
        }

        if( $dsType eq 'rrd-multigraph' )
        {
            my @dsNames =
                split(',', $config_tree->getNodeParam( $token, 'ds-names' ) );

            if( scalar(@dsNames) == 0 )
            {
                my $path = $config_tree->path( $token );
                Error("ds-names list is empty in $path");
                $ok = 0;
            }
            foreach my $dname ( @dsNames )
            {
                my $param = 'ds-expr-' . $dname;
                my $expr = $config_tree->getNodeParam( $token, $param );
                if( not defined( $expr ) )
                {
                    my $path = $config_tree->path( $token );
                    Error("Parameter $param is not defined in $path");
                    $ok = 0;
                }
                else
                {
                    $ok = validateRPN( $token, $expr, $config_tree ) ? $ok : 0;
                }

                foreach my $paramprefix ( 'graph-legend-', 'line-style-',
                                          'line-color-', 'line-order-' )
                {
                    my $param = $paramprefix.$dname;
                    my $value = $config_tree->getNodeParam($token, $param);
                    if( not defined( $value ) )
                    {
                        my $path = $config_tree->path( $token );
                        Error('Parameter ' . $param .
                              ' is not defined in ' . $path);
                        $ok = 0;
                    }
                    elsif( $param eq 'line-style-' and
                           not validateLine( $value ) )
                    {
                        my $path = $config_tree->path( $token );
                        Error('Parameter ' . $param .
                              ' is defined incorrectly in ' . $path);
                        $ok = 0;
                    }
                    elsif( $param eq 'line-color-' and
                           not validateColor( $value ) )
                    {
                        my $path = $config_tree->path( $token );
                        Error('Parameter ' . $param .
                              ' is defined incorrectly in ' . $path);
                        $ok = 0;
                    }
                }
            }
        }
        elsif( $dsType eq 'rrd-file' and
               $config_tree->getNodeParam( $token, 'leaf-type' ) eq 'rrd-cdef')
        {
            my $expr = $config_tree->getNodeParam( $token, 'rpn-expr' );
            if( defined( $expr ) )
            {
                $ok = validateRPN( $token, $expr, $config_tree ) ? $ok : 0;
            }
            # Otherwise already reported by  validateInstanceParams()
        }
        elsif($dsType eq 'collector' and
              $config_tree->getNodeParam( $token, 'collector-type' ) eq 'snmp')
        {
            # Check the OID syntax
            my $oid = $config_tree->getNodeParam( $token, 'snmp-object' );
            if( defined($oid) and $oid =~ /^\./o )
            {
                my $path = $config_tree->path( $token );
                Error("Invalid syntax for snmp-object in " .
                      $path . ": OID must not start with dot");
                $ok = 0;
            }
        }
    }
    else
    {
        # This is subtree
        my $view = $config_tree->getNodeParam( $token,
                                               'default-subtree-view' );

        if( not defined( $view ) )
        {
            my $path = $config_tree->path( $token );
            Error("Default view is not defined for subtree $path");
            $ok = 0;
        }
        elsif( not $config_tree->{'validator'}{'viewExists'}{$view} and
               not $config_tree->viewExists( $view ) )
        {
            my $path = $config_tree->path( $token );
            Error("Non-existent view is defined as default for subtree $path");
            $ok = 0;
        }
        else
        {
            # Store the cache
            $config_tree->{'validator'}{'viewExists'}{$view} = 1;
        }

        foreach my $ctoken ( $config_tree->getChildren($token) )
        {
            if( not $config_tree->isAlias($ctoken) )
            {
                $ok = validateNode($config_tree, $ctoken)
                    ? $ok:0;
            }
        }
    }
    return $ok;
}

my %validFuntcionNames =
    ( 'AVERAGE' => 1,
      'MIN'     => 1,
      'MAX'     => 1,
      'LAST'    => 1,
      'T'       => 1 );


sub validateRPN
{
    my $token = shift;
    my $expr  = shift;
    my $config_tree = shift;
    my $timeoffset_supported = shift;

    &Torrus::DB::checkInterrupted();
    
    my $ok = 1;

    # There must be at least one DS reference
    my $ds_couter = 0;

    my $rpn = new Torrus::RPN;

    # The callback for RPN translation
    my $callback = sub
    {
        my ($noderef, $timeoffset) = @_;

        my $function;
        if( $noderef =~ s/^(.+)\@//o )
        {
            $function = $1;
        }

        if( defined( $function ) and not $validFuntcionNames{$function} )
        {
            my $path = $config_tree->path($token);
            Error('Invalid function name ' . $function .
                  ' in node reference at ' . $path);
            $ok = 0;
            return undef;
        }            
        
        my $leaf = length($noderef) > 0 ?
            $config_tree->getRelative($token, $noderef) : $token;

        if( not defined $leaf )
        {
            my $path = $config_tree->path($token);
            Error("Cannot find relative reference $noderef at $path");
            $ok = 0;
            return undef;
        }
        if( not $config_tree->isLeaf( $leaf ) )
        {
            my $path = $config_tree->path($token);
            Error("Relative reference $noderef at $path is not a leaf");
            $ok = 0;
            return undef;
        }
        if( $config_tree->getNodeParam($leaf, 'leaf-type') ne 'rrd-def' )
        {
            my $path = $config_tree->path($token);
            Error("Relative reference $noderef at $path must point to a ".
                  "leaf of type rrd-def");
            $ok = 0;
            return undef;
        }
        if( defined( $timeoffset ) and not $timeoffset_supported )
        {
            my $path = $config_tree->path($token);
            Error("Time offsets are not supported at $path");
            $ok = 0;
            return undef;
        }

        $ds_couter++;
        return 'TESTED';
    };

    $rpn->translate( $expr, $callback );
    if( $ok and $ds_couter == 0 )
    {
        my $path = $config_tree->path($token);
        Error("RPN must contain at least one DS reference at $path");
        $ok = 0;
    }
    return $ok;
}



sub validateViews
{
    my $config_tree = shift;
    my $ok = 1;

    foreach my $view ($config_tree->getViewNames())
    {
        &Torrus::DB::checkInterrupted();
        
        $ok = validateInstanceParams($config_tree, $view,
                                     'view', \%view_params) ? $ok:0;
        if( $ok and $config_tree->getParam($view, 'view-type') eq 'rrgraph' )
        {
            my $hrulesList = $config_tree->getParam($view, 'hrules');
            if( defined( $hrulesList ) )
            {
                foreach my $hrule ( split(',', $hrulesList ) )
                {
                    my $valueParam =
                        $config_tree->getParam($view, 'hrule-value-' . $hrule);
                    if( not defined( $valueParam ) or $valueParam !~ /^\S+$/o )
                    {
                        Error('Mandatory parameter hrule-value-' . $hrule .
                              ' is not defined or incorrect for view ' .
                              $view);
                        $ok = 0;
                    }
                    my $color =
                        $config_tree->getParam($view, 'hrule-color-'.$hrule);
                    if( not defined( $color ) )
                    {
                        Error('Mandatory parameter hrule-color-' . $hrule .
                              ' is not defined for view ' . $view);
                        $ok = 0;
                    }
                    else
                    {
                        $ok = validateColor( $color ) ? $ok:0;
                    }
                }
            }

            my $decorList = $config_tree->getParam($view, 'decorations');
            if( defined( $decorList ) )
            {
                foreach my $decorName ( split(',', $decorList ) )
                {
                    foreach my $paramName ( qw(order style color expr) )
                    {
                        my $param = 'dec-' . $paramName . '-' . $decorName;
                        if( not defined( $config_tree->
                                         getParam($view, $param) ) )
                        {
                            Error('Missing parameter: ' . $param .
                                  ' in view ' . $view);
                            $ok = 0;
                        }
                    }

                    $ok = validateLine( $config_tree->
                                        getParam($view,
                                                 'dec-style-' . $decorName) )
                        ? $ok:0;
                    $ok = validateColor( $config_tree->
                                         getParam($view,
                                                  'dec-color-' . $decorName) )
                        ? $ok:0;
                }
            }

            $ok = validateColor( $config_tree->getParam($view, 'line-color') )
                ? $ok:0;
            $ok = validateLine( $config_tree->getParam($view, 'line-style') )
                ? $ok:0;

            my $gprintValues = $config_tree->getParam($view, 'gprint-values');
            if( defined( $gprintValues ) and length( $gprintValues ) > 0 )
            {
                foreach my $gprintVal ( split(',', $gprintValues ) )
                {
                    my $format =
                        $config_tree->getParam($view,
                                               'gprint-format-' . $gprintVal);
                    if( not defined( $format ) or length( $format ) == 0 )
                    {
                        Error('GPRINT format for ' . $gprintVal .
                              ' is not defined for view ' .  $view);
                        $ok = 0;
                    }
                }
            }
        }
    }
    return $ok;
}


sub validateColor
{
    my $color = shift;
    my $ok = 1;

    if( $color !~ /^\#[0-9a-fA-F]{6}$/o )
    {
        if( $color =~ /^\#\#(\S+)$/o )
        {
            if( not $Torrus::Renderer::graphStyles{$1}{'color'} )
            {
                Error('Incorrect color reference: ' . $color);
                $ok = 0;
            }
        }
        else
        {
            Error('Incorrect color syntax: ' . $color);
            $ok = 0;
        }
    }

    return $ok;
}


sub validateLine
{
    my $line = shift;
    my $ok = 1;

    if( $line =~ /^\#\#(\S+)$/o )
    {
        if( not $Torrus::Renderer::graphStyles{$1}{'line'} )
        {
            Error('Incorrect line style reference: ' . $line);
            $ok = 0;
        }
    }
    elsif( not $Torrus::SiteConfig::validLineStyles{$line} )
    {
        Error('Incorrect line syntax: ' . $line);
        $ok = 0;
    }

    return $ok;
}


sub validateMonitors
{
    my $config_tree = shift;
    my $ok = 1;

    foreach my $action ($config_tree->getActionNames())
    {        
        $ok = validateInstanceParams($config_tree, $action,
                                     'action', \%action_params) ? $ok:0;
        my $atype = $config_tree->getParam($action, 'action-type');
        if( $atype eq 'tset' )
        {
            my $tset = $config_tree->getParam($action, 'tset-name');
            if( defined $tset )
            {
                $tset = 'S'.$tset;
                if( not $config_tree->tsetExists( $tset ) )
                {
                    Error("Token-set does not exist: $tset in action $action");
                    $ok = 0;
                }
            }
            # Otherwise the error is already reported by validateInstanceParams
        }
        elsif( $atype eq 'exec' )
        {
            my $launch_when = $config_tree->getParam($action, 'launch-when');
            if( defined $launch_when )
            {
                foreach my $when ( split(',', $launch_when) )
                {
                    my $matched = 0;
                    foreach my $event ('set', 'repeat', 'clear', 'forget')
                    {
                        if( $when eq $event )
                        {
                            $matched = 1;
                        }
                    }
                    if( not $matched )
                    {
                        if( $when eq 'throw' )
                        {
                            Error('Event type "throw" is no longer ' .
                                  'supported. Replace with "set".');
                        }
                        else
                        {
                            Error("Invalid value in parameter launch-when " .
                                  "in action $action: $when");
                        }
                        $ok = 0;
                    }
                }
            }

            my $setenv_dataexpr =
                $config_tree->getParam( $action, 'setenv-dataexpr' );

            if( defined( $setenv_dataexpr ) )
            {
                # <param name="setenv_dataexpr"
                #        value="ENV1=expr1, ENV2=expr2"/>

                foreach my $pair ( split( ',', $setenv_dataexpr ) )
                {
                    my ($env, $param) = split( '=', $pair );
                    if( not $param )
                    {
                        Error("Syntax error in setenv-dataexpr in action " .
                              $action . ": \"" . $pair . "\"");
                        $ok = 0;
                    }
                    elsif( $env =~ /\W/o )
                    {
                        Error("Illegal characters in environment variable ".
                              "name in setenv-dataexpr in action " . $action .
                              ": \"" . $env . "\"");
                        $ok = 0;
                    }
                    elsif( not defined ($config_tree->getParam( $action,
                                                                $param ) ) )
                    {
                        Error("Parameter referenced in setenv-dataexpr is " .
                              "not defined in action " .
                              $action . ": " . $param);
                        $ok = 0;
                    }
                }
            }
        }
    }

    foreach my $monitor ($config_tree->getMonitorNames())
    {
        $ok = validateInstanceParams($config_tree, $monitor,
                                     'monitor', \%monitor_params) ? $ok:0;
        my $alist = $config_tree->getParam( $monitor, 'action' );
        foreach my $action ( split(',', $alist ) )
        {
            if( not $config_tree->actionExists( $action ) )
            {
                Error("Non-existent action: $action in monitor $monitor");
                $ok = 0;
            }
        }
    }
    return $ok;
}


sub validateTokensets
{
    my $config_tree = shift;
    my $ok = 1;

    my $view = $config_tree->getParam( 'SS', 'default-tsetlist-view' );
    if( not defined( $view ) )
    {
        Error("View is not defined for tokensets list");
        $ok = 0;
    }
    elsif( not $config_tree->viewExists( $view ) )
    {
        Error("Non-existent view is defined for tokensets list");
        $ok = 0;
    }

    foreach my $tset ($config_tree->getTsets())
    {
        &Torrus::DB::checkInterrupted();
        
        $view = $config_tree->getParam($tset, 'default-tset-view');
        if( not defined( $view ) )
        {
            $view = $config_tree->getParam('SS', 'default-tset-view');
        }

        if( not defined( $view ) )
        {
            Error("Default view is not defined for tokenset $tset");
            $ok = 0;
        }
        elsif( not $config_tree->viewExists( $view ) )
        {
            Error("Non-existent view is defined for tokenset $tset");
            $ok = 0;
        }
    }
    return $ok;
}




sub validateInstanceParams
{
    my $config_tree = shift;
    my $inst_name = shift;
    my $inst_type = shift;
    my $mapref = shift;

    &Torrus::DB::checkInterrupted();
    
    # Debug("Validating $inst_type $inst_name");

    my $ok = 1;
    my @namemaps = ($mapref);

    while( $ok and scalar(@namemaps) > 0 )
    {
        my @next_namemaps = ();

        foreach my $namemap (@namemaps)
        {
            foreach my $paramkey (keys %{$namemap})
            {
                # Debug("Checking param: $pname");

                my $pname = $paramkey;
                my $mandatory = 1;
                if( $pname =~ s/^\+//o )
                {
                    $mandatory = 0;
                }

                my $listval = 0;
                if( $pname =~ s/^\@//o )
                {
                    $listval = 1;
                }
                
                my $pvalue =
                    $config_tree->getInstanceParam($inst_type,
                                                   $inst_name, $pname);

                my @pvalues;
                if( $listval )
                {
                    @pvalues = split(',', $pvalue);
                }
                else
                {
                    @pvalues = ( $pvalue );
                }
                
                if( not defined( $pvalue ) )
                {
                    if( $mandatory )
                    {
                        my $msg;
                        if( $inst_type eq 'node' )
                        {
                            $msg = $config_tree->path( $inst_name );
                        }
                        else
                        {
                            $msg = "$inst_type $inst_name";
                        }
                        Error("Mandatory parameter $pname is not ".
                              "defined for $msg");
                        $ok = 0;
                    }
                }
                else
                {
                    if( ref( $namemap->{$paramkey} ) )
                    {
                        foreach my $pval ( @pvalues )
                        {
                            if( exists $namemap->{$paramkey}->{$pval} )
                            {
                                if( defined $namemap->{$paramkey}->{$pval} )
                                {
                                    push( @next_namemaps,
                                          $namemap->{$paramkey}->{$pval} );
                                }
                            }
                            else
                            {
                                my $msg;
                                if( $inst_type eq 'node' )
                                {
                                    $msg = $config_tree->path( $inst_name );
                                }
                                else
                                {
                                    $msg = "$inst_type $inst_name";
                                }
                                Error("Parameter $pname has ".
                                      "unknown value: $pval for $msg");
                                $ok = 0;
                            }
                        }
                    }
                }
            }
        }
        @namemaps = @next_namemaps;
    }
    return $ok;
}



1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
