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

# $Id: RRDtool.pm,v 1.1 2010-12-27 00:03:44 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::Renderer::RRDtool;

use strict;

use Torrus::ConfigTree;
use Torrus::RPN;
use Torrus::Log;

use RRDs;

# All our methods are imported by Torrus::Renderer;

my %rrd_graph_opts =
    (
     'start'  => '--start',
     'end'    => '--end',
     'width'  => '--width',
     'height' => '--height'
     );

my @arg_arrays = qw(opts defs bg hwtick hrule hwline line fg);


sub render_rrgraph
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $outfile = shift;

    if( not $config_tree->isLeaf($token) )
    {
        Error("Token $token is not a leaf");
        return undef;
    }

    my $obj = {'args' => {}, 'dname' => 'A'};

    foreach my $arrayName ( @arg_arrays )
    {
        $obj->{'args'}{$arrayName} = [];
    }

    push( @{$obj->{'args'}{'opts'}},
          $self->rrd_make_opts( $config_tree, $token, $view,
                                \%rrd_graph_opts, ) );

    push( @{$obj->{'args'}{'opts'}},
          $self->rrd_make_graph_opts( $config_tree, $token, $view ) );

    my $dstype = $config_tree->getNodeParam($token, 'ds-type');

    if( $dstype eq 'rrd-multigraph' )
    {
        $self->rrd_make_multigraph( $config_tree, $token, $view, $obj );
    }
    else
    {
        my $leaftype = $config_tree->getNodeParam($token, 'leaf-type');

        # Handle DEFs and CDEFs
        # At the moment, we call the DEF as 'A'. Could change in the future
        if( $leaftype eq 'rrd-def' )
        {
            push( @{$obj->{'args'}{'defs'}},
                  $self->rrd_make_def( $config_tree, $token,
                                       $obj->{'dname'} ) );

            if( $self->rrd_check_hw( $config_tree, $token, $view ) )
            {
                $self->rrd_make_holtwinters( $config_tree, $token,
                                             $view, $obj );
            }
        }
        elsif( $leaftype eq 'rrd-cdef' )
        {
            my $expr = $config_tree->getNodeParam($token, 'rpn-expr');
            push( @{$obj->{'args'}{'defs'}},
                  $self->rrd_make_cdef($config_tree, $token,
                                       $obj->{'dname'}, $expr) );
        }
        else
        {
            Error("Unsupported leaf-type: $leaftype");
            return undef;
        }

        $self->rrd_make_graphline( $config_tree, $token, $view, $obj );
    }

    $self->rrd_make_hrules( $config_tree, $token, $view, $obj );
    if( not $Torrus::Renderer::ignoreDecorations )
    {
        $self->rrd_make_decorations( $config_tree, $token, $view, $obj );
    }

    # We're all set


    my @args;
    foreach my $arrayName ( @arg_arrays )
    {
        push( @args, @{$obj->{'args'}{$arrayName}} );
    }
    Debug("RRDs::graph arguments: " . join(' ', @args));

    $self->tz_set();
    &RRDs::graph( $outfile, @args );
    $self->tz_restore();
    my $ERR=RRDs::error;
    if( $ERR )
    {
        my $path = $config_tree->path($token);
        Error("$path $view: Error during RRD graph: $ERR");
        return undef;
    }

    return( $config_tree->getParam($view, 'expires')+time(), 'image/png' );
}


my %rrd_print_opts =
    (
     'start'  => '--start',
     'end'    => '--end',
     );



sub render_rrprint
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $outfile = shift;

    if( not $config_tree->isLeaf($token) )
    {
        Error("Token $token is not a leaf");
        return undef;
    }

    my @arg_opts;
    my @arg_defs;
    my @arg_print;

    push( @arg_opts, $self->rrd_make_opts( $config_tree, $token, $view,
                                           \%rrd_print_opts, ) );

    my $dstype = $config_tree->getNodeParam($token, 'ds-type');

    if( $dstype eq 'rrd-multigraph' )
    {
        Error("View type rrprint is not supported ".
              "for DS type rrd-multigraph");
        return undef;
    }

    my $leaftype = $config_tree->getNodeParam($token, 'leaf-type');

    # Handle DEFs and CDEFs
    # At the moment, we call the DEF as 'A'. Could change in the future
    my $dname = 'A';
    if( $leaftype eq 'rrd-def' )
    {
        push( @arg_defs,
              $self->rrd_make_def( $config_tree, $token, $dname ) );
    }
    elsif( $leaftype eq 'rrd-cdef' )
    {
        my $expr = $config_tree->getNodeParam($token, 'rpn-expr');
        push( @arg_defs,
              $self->rrd_make_cdef($config_tree, $token, $dname, $expr) );
    }
    else
    {
        Error("Unsupported leaf-type: $leaftype");
        return undef;
    }

    foreach my $cf ( split(',', $config_tree->getParam($view, 'print-cf')) )
    {
        push( @arg_print, sprintf( 'PRINT:%s:%s:%%le', $dname, $cf ) );
    }

    # We're all set

    my @args = ( @arg_opts, @arg_defs, @arg_print );
    Debug("RRDs::graph arguments: " . join(' ', @args));

    my $printout;
    $self->tz_set();
    ($printout, undef, undef) = RRDs::graph('/dev/null', @args);
    $self->tz_restore();
    my $ERR=RRDs::error;
    if( $ERR )
    {
        my $path = $config_tree->path($token);
        Error("$path $view: Error during RRD graph: $ERR");
        return undef;
    }

    if( not open(OUT, ">$outfile") )
    {
        Error("Cannot open $outfile for writing: $!");
        return undef;
    }
    else
    {
        printf OUT ("%s\n", join(':', @{$printout}));
        close OUT;
    }

    return( $config_tree->getParam($view, 'expires')+time(), 'text/plain' );
}



sub rrd_make_multigraph
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $obj = shift;

    my @dsNames =
        split(',', $config_tree->getNodeParam($token, 'ds-names') );

    # We need this to refer to some existing variable name
    $obj->{'dname'} = $dsNames[0];

    # Analyze the drawing order
    my %dsOrder;
    foreach my $dname ( @dsNames )
    {
        my $order = $config_tree->getNodeParam($token, 'line-order-'.$dname);
        $dsOrder{$dname} = defined( $order ) ? $order : 100;
    }

    my $disable_legend = $config_tree->getParam($view, 'disable-legend');    
    $disable_legend =
        (defined($disable_legend) and $disable_legend eq 'yes') ? 1:0;
    
    # make DEFs and Line instructions

    my $do_gprint = 0;

    if( not $disable_legend )
    {
        $do_gprint = $self->rrd_if_gprint( $config_tree, $token );
        if( $do_gprint )
        {
            $self->rrd_make_gprint_header( $config_tree, $token, $view, $obj );
        }
    }

    foreach my $dname ( sort {$dsOrder{$a} <=> $dsOrder{$b}} @dsNames )
    {
        my $dograph = 1;
        my $ignoreViews =
            $config_tree->getNodeParam($token, 'ignore-views-'.$dname);
        if( defined( $ignoreViews ) and
            grep {$_ eq $view} split(',', $ignoreViews) )
        {
            $dograph = 0;
        }

        my $gprint_this = $do_gprint;
        if( $do_gprint )
        {
            my $ds_nogprint =
                $config_tree->getNodeParam($token, 'disable-gprint-'.$dname);
            if( defined( $ds_nogprint ) and $ds_nogprint eq 'yes' )
            {
                $gprint_this = 0;
            }
        }

        my $legend;
        
        if( $dograph or $gprint_this )
        {
            my $expr = $config_tree->getNodeParam($token, 'ds-expr-'.$dname);
            push( @{$obj->{'args'}{'defs'}},
                  $self->rrd_make_cdef($config_tree, $token, $dname, $expr) );

            $legend =
                $config_tree->getNodeParam($token, 'graph-legend-'.$dname);
            if( defined( $legend ) )
            {
                $legend =~ s/:/\\:/g;
            }
            else
            {
                $legend = '';
            }
        }
            
        if( $gprint_this )
        {
            $self->rrd_make_gprint( $dname, $legend,
                                    $config_tree, $token, $view, $obj );
            if( not $dograph )
            {
                push( @{$obj->{'args'}{'line'}},
                      'COMMENT:' . $legend . '\l');
            }
        }
        else
        {
            # For datasource that disables gprint, there's no reason
            # to print the label
            $legend = '';
        }
        
        if( $dograph )
        {
            my $linestyle =
                $self->mkline( $config_tree->getNodeParam
                               ($token, 'line-style-'.$dname) );
            
            my $linecolor =
                $self->mkcolor( $config_tree->getNodeParam
                                ($token, 'line-color-'.$dname) );
            
            my $alpha =
                $config_tree->getNodeParam($token, 'line-alpha-'.$dname);
            if( defined( $alpha ) )
            {
                $linecolor .= $alpha;
            }

            my $stack =
                $config_tree->getNodeParam($token, 'line-stack-'.$dname);
            if( defined( $stack ) and $stack eq 'yes' )
            {
                $stack = ':STACK';
            }
            else
            {
                $stack = '';
            }
                
            push( @{$obj->{'args'}{'line'}},
                  sprintf( '%s:%s%s%s%s', $linestyle, $dname,
                           $linecolor,
                           length($legend) > 0 ? ':'.$legend.'\l' : '',
                           $stack ) );
            
        }
    }
}


# Check if Holt-Winters stuff is needed
sub rrd_check_hw
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;

    my $use_hw = 0;
    my $nodeHW = $config_tree->getNodeParam($token, 'rrd-hwpredict');
    if( defined($nodeHW) and $nodeHW eq 'enabled' )
    {
        my $viewHW = $config_tree->getParam($view, 'rrd-hwpredict');
        my $varNoHW = $self->{'options'}->{'variables'}->{'NOHW'};
        
        if( (not defined($viewHW) or $viewHW ne 'disabled') and
            (not $varNoHW) )
        {
            $use_hw = 1;
        }
    }
    return $use_hw;
}


sub rrd_make_holtwinters
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $obj = shift;

    my $dname = $obj->{'dname'};

    push( @{$obj->{'args'}{'defs'}},
          $self->rrd_make_def( $config_tree, $token,
                               $dname . 'pred', 'HWPREDICT' ) );
    push( @{$obj->{'args'}{'defs'}},
          $self->rrd_make_def( $config_tree, $token,
                               $dname . 'dev', 'DEVPREDICT' ) );
    # Upper boundary definition
    push( @{$obj->{'args'}{'defs'}},
          sprintf( 'CDEF:%supper=%spred,%sdev,2,*,+',
                   $dname, $dname, $dname  ) );

    # Lower boundary definition
    push( @{$obj->{'args'}{'defs'}},
          sprintf( 'CDEF:%slower=%spred,%sdev,2,*,-',
                   $dname, $dname, $dname  ) );

    # Failures definition
    push( @{$obj->{'args'}{'defs'}},
          $self->rrd_make_def( $config_tree, $token,
                               $dname . 'fail', 'FAILURES' ) );

    # Generate H-W Boundary Lines

    # Boundary style
    my $hw_bndr_style = $config_tree->getParam($view, 'hw-bndr-style');
    $hw_bndr_style = 'LINE1' unless defined $hw_bndr_style;
    $hw_bndr_style = $self->mkline( $hw_bndr_style );

    my $hw_bndr_color = $config_tree->getParam($view, 'hw-bndr-color');
    $hw_bndr_color = '#FF0000' unless defined $hw_bndr_color;
    $hw_bndr_color = $self->mkcolor( $hw_bndr_color );

    push( @{$obj->{'args'}{'hwline'}},
          sprintf( '%s:%supper%s:%s',
                   $hw_bndr_style, $dname, $hw_bndr_color,
                   $Torrus::Renderer::hwGraphLegend ? 'Boundaries\n':'' ) );
    push( @{$obj->{'args'}{'hwline'}},
          sprintf( '%s:%slower%s',
                   $hw_bndr_style, $dname, $hw_bndr_color ) );

    # Failures Tick

    my $hw_fail_color = $config_tree->getParam($view, 'hw-fail-color');
    $hw_fail_color = '#FFFFA0' unless defined $hw_fail_color;
    $hw_fail_color = $self->mkcolor( $hw_fail_color );

    push( @{$obj->{'args'}{'hwtick'}},
          sprintf( 'TICK:%sfail%s:1.0:%s',
                   $dname, $hw_fail_color,
                   $Torrus::Renderer::hwGraphLegend ? 'Failures':'') );
}

sub rrd_make_graphline
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $obj = shift;

    my $legend;
    
    my $disable_legend = $config_tree->getParam($view, 'disable-legend');
    if( not defined($disable_legend) or $disable_legend ne 'yes' )
    {
        $legend = $config_tree->getNodeParam($token, 'graph-legend');
        if( defined( $legend ) )
        {
            $legend =~ s/:/\\:/g;
        }
    }

    if( not defined( $legend ) )
    {
        $legend = '';
    }
    
    my $styleval = $config_tree->getNodeParam($token, 'line-style');
    if( not defined( $styleval ) or length( $styleval ) == 0 )
    {
        $styleval = $config_tree->getParam($view, 'line-style');
    }
    
    my $linestyle = $self->mkline( $styleval );

    my $colorval = $config_tree->getNodeParam($token, 'line-color');
    if( not defined( $colorval ) or length( $colorval ) == 0 )
    {
        $colorval = $config_tree->getParam($view, 'line-color');
    }
    
    my $linecolor = $self->mkcolor( $colorval );

    if( $self->rrd_if_gprint( $config_tree, $token ) )
    {
        $self->rrd_make_gprint_header( $config_tree, $token, $view, $obj );

        $self->rrd_make_gprint( $obj->{'dname'}, $legend,
                                $config_tree, $token, $view, $obj );
    }

    push( @{$obj->{'args'}{'line'}},
          sprintf( '%s:%s%s%s', $linestyle, $obj->{'dname'}, $linecolor,
                   length($legend) > 0 ? ':'.$legend.'\l' : '' ) );
}


# Generate RRDtool arguments for HRULE's

sub rrd_make_hrules
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $obj = shift;

    my $hrulesList = $config_tree->getParam($view, 'hrules');
    if( defined( $hrulesList ) )
    {
        foreach my $hruleName ( split(',', $hrulesList ) )
        {
            # The presence of this parameter is checked by Validator
            my $valueParam =
                $config_tree->getParam( $view, 'hrule-value-'.$hruleName );
            my $value = $config_tree->getNodeParam( $token, $valueParam );

            if( defined( $value ) )
            {
                my $color =
                    $config_tree->getParam($view, 'hrule-color-'.$hruleName);
                $color = $self->mkcolor( $color );

                my $legend =
                    $config_tree->getNodeParam($token,
                                               'hrule-legend-'.$hruleName);

                my $arg = sprintf( 'HRULE:%e%s', $value, $color );
                if( defined( $legend ) and $legend =~ /\S/ )
                {
                    $arg .= ':' . $legend . '\l';
                }
                push( @{$obj->{'args'}{'hrule'}}, $arg );
            }
        }
    }
}


sub rrd_make_decorations
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $obj = shift;

    my $decorList = $config_tree->getParam($view, 'decorations');
    my $ignore_decor =
        $config_tree->getNodeParam($token, 'graph-ignore-decorations');
    if( defined( $decorList ) and
        (not defined($ignore_decor) or $ignore_decor ne 'yes') )
    {
        my $decor = {};
        foreach my $decorName ( split(',', $decorList ) )
        {
            my $order =
                $config_tree->getParam($view, 'dec-order-' . $decorName);
            $decor->{$order} = {'def' => [], 'line' => ''};

            my $style =
                $self->mkline( $config_tree->
                               getParam($view, 'dec-style-' . $decorName) );
            my $color =
                $self->mkcolor( $config_tree->
                                getParam($view, 'dec-color-' . $decorName) );
            my $expr = $config_tree->
                getParam($view, 'dec-expr-' . $decorName);

            push( @{$decor->{$order}{'def'}},
                  $self->rrd_make_cdef( $config_tree, $token, $decorName,
                                        $obj->{'dname'} . ',POP,' . $expr ) );

            $decor->{$order}{'line'} =
                sprintf( '%s:%s%s', $style, $decorName, $color );
        }

        foreach my $order ( sort {$a<=>$b} keys %{$decor} )
        {
            my $array = $order < 0 ? 'bg':'fg';

            push( @{$obj->{'args'}{'defs'}}, @{$decor->{$order}{'def'}} );
            push( @{$obj->{'args'}{$array}}, $decor->{$order}{'line'} );
        }
    }
}

# Takes the parameters from the view, and composes the list of
# RRDtool arguments

sub rrd_make_opts
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $opthash = shift;

    my @args = ();
    foreach my $param ( keys %{$opthash} )
    {
        my $value =
            $self->{'options'}->{'variables'}->{'G' . $param};
        
        if( not defined( $value ) )
        {
            $value = $config_tree->getParam( $view, $param );
        }
        
        if( defined( $value ) )
        {
            if( ( $param eq 'start' or $param eq 'end' ) and
                defined( $self->{'options'}->{'variables'}->{'NOW'} ) )
            {
                my $now = $self->{'options'}->{'variables'}->{'NOW'};
                if( index( $value , 'now' ) >= 0 )
                {
                    $value =~ s/now/$now/;
                }
                elsif( $value =~ /^(\-|\+)/ )
                {
                    $value = $now . $value;
                }
            }
            push( @args, $opthash->{$param}, $value );
        }
    }

    my $params = $config_tree->getParam($view, 'rrd-params');
    if( defined( $params ) )
    {
        push( @args, split('\s+', $params) );
    }

    my $scalingbase = $config_tree->getNodeParam($token, 'rrd-scaling-base');
    if( defined($scalingbase) and $scalingbase == 1024 )
    {
        push( @args, '--base', '1024' );
    }

    return @args;
}


sub rrd_make_graph_opts
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;

    my @args = ( '--imgformat', 'PNG' );

    my $graph_log = $config_tree->getNodeParam($token, 'graph-logarithmic');
    if( defined($graph_log) and $graph_log eq 'yes' )
    {
        push( @args, '--logarithmic' );
    }

    my $disable_title =
        $config_tree->getParam($view, 'disable-title');
    if( not defined( $disable_title ) or $disable_title ne 'yes' )
    {
        my $title = $config_tree->getNodeParam($token, 'graph-title');
        if( not defined( $title ) or length( $title ) == 0 )
        {
            $title = ' ';
        }
        push( @args, '--title', $title );
    }

    my $disable_vlabel =
        $config_tree->getParam($view, 'disable-vertical-label');
    if( not defined( $disable_vlabel ) or $disable_vlabel ne 'yes' )
    {
        my $vertical_label =
            $config_tree->getNodeParam($token, 'vertical-label');
        if( defined( $vertical_label ) and length( $vertical_label ) > 0 )
        {
            push( @args, '--vertical-label', $vertical_label );
        }
    }

    my $ignore_limits = $config_tree->getParam($view, 'ignore-limits');
    if( not defined($ignore_limits) or $ignore_limits ne 'yes' )
    {
        my $ignore_lower = $config_tree->getParam($view, 'ignore-lower-limit');
        if( not defined($ignore_lower) or $ignore_lower ne 'yes' )
        {
            my $limit =
                $config_tree->getNodeParam($token, 'graph-lower-limit');
            if( defined($limit) and length( $limit ) > 0 )
            {
                push( @args, '--lower-limit', $limit );
            }
        }

        my $ignore_upper = $config_tree->getParam($view, 'ignore-upper-limit');
        if( not defined($ignore_upper) or $ignore_upper ne 'yes' )
        {
            my $limit =
                $config_tree->getNodeParam($token, 'graph-upper-limit');
            if( defined($limit) and length( $limit ) > 0 )
            {
                push( @args, '--upper-limit', $limit );
            }
        }

        my $rigid_boundaries =
            $config_tree->getNodeParam($token, 'graph-rigid-boundaries');
        if( defined($rigid_boundaries) and $rigid_boundaries eq 'yes' )
        {
            push( @args, '--rigid' );
        }
    }

    if( scalar( @Torrus::Renderer::graphExtraArgs ) > 0 )
    {
        push( @args, @Torrus::Renderer::graphExtraArgs );
    }

    return @args;
}


sub rrd_make_def
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $dname = shift;
    my $cf = shift;

    my $datafile = $config_tree->getNodeParam($token, 'data-file');
    my $dataddir = $config_tree->getNodeParam($token, 'data-dir');
    my $rrdfile = $dataddir.'/'.$datafile;
    if( not -r $rrdfile )
    {
        my $path = $config_tree->path($token);
        Error("$path: No such file or directory: $rrdfile");
        return undef;
    }

    my $ds = $config_tree->getNodeParam($token, 'rrd-ds');
    if( not defined $cf )
    {
        $cf = $config_tree->getNodeParam($token, 'rrd-cf');
    }
    return sprintf( 'DEF:%s=%s:%s:%s',
                    $dname, $rrdfile, $ds, $cf );
}



my %cfNames =
    ( 'AVERAGE' => 1,
      'MIN'     => 1,
      'MAX'     => 1,
      'LAST'    => 1 );

# Moved the validation part to Torrus::ConfigTree::Validator
sub rrd_make_cdef
{
    my $self  = shift;
    my $config_tree = shift;
    my $token = shift;
    my $dname = shift;
    my $expr  = shift;

    my @args = ();

    # We will name the DEFs as $dname.sprintf('%.2d', $ds_couter++);
    my $ds_couter = 1;

    my $rpn = new Torrus::RPN;

    # The callback for RPN translation
    my $callback = sub
    {
        my ($noderef, $timeoffset) = @_;

        my $function;
        if( $noderef =~ s/^(.+)\@// )
        {
            $function = $1;
        }

        my $cf;
        if( defined( $function ) and $cfNames{$function} )
        {
            $cf = $function;
        }
        
        my $leaf = length($noderef) > 0 ?
            $config_tree->getRelative($token, $noderef) : $token;

        my $varname = $dname . sprintf('%.2d', $ds_couter++);
        push( @args,
              $self->rrd_make_def( $config_tree, $leaf, $varname, $cf ) );
        return $varname;
    };

    $expr = $rpn->translate( $expr, $callback );
    push( @args, sprintf( 'CDEF:%s=%s', $dname, $expr ) );
    return @args;
}


sub rrd_if_gprint
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;

    my $disable = $config_tree->getNodeParam($token, 'graph-disable-gprint');
    if( defined( $disable ) and $disable eq 'yes' )
    {
        return 0;
    }
    return 1;
}

sub rrd_make_gprint
{
    my $self = shift;
    my $vname = shift;
    my $legend = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $obj = shift;

    my @args = ();

    my $gprintValues = $config_tree->getParam($view, 'gprint-values');
    if( defined( $gprintValues ) and length( $gprintValues ) > 0 )
    {
        foreach my $gprintVal ( split(',', $gprintValues ) )
        {
            my $format =
                $config_tree->getParam($view, 'gprint-format-' . $gprintVal);
            push( @args, 'GPRINT:' . $vname . ':' . $format );
        }
    }

    push( @{$obj->{'args'}{'line'}}, @args );
}
            

sub rrd_make_gprint_header
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $obj = shift;

    my $gprintValues = $config_tree->getParam($view, 'gprint-values');
    if( defined( $gprintValues ) and length( $gprintValues ) > 0 )
    {
        my $gprintHeader = $config_tree->getParam($view, 'gprint-header');
        if( defined( $gprintHeader ) and length( $gprintHeader ) > 0 )
        {
            push( @{$obj->{'args'}{'line'}},
                  'COMMENT:' . $gprintHeader . '\l' );
        }
    }
}
       

sub mkcolor
{
    my $self = shift;
    my $color = shift;

    my $recursionLimit = 100;

    while( $color =~ /^\#\#(\S+)$/ )
    {
        if( $recursionLimit-- <= 0 )
        {
            Error('Color recursion is too deep');
            $color = '#000000';
        }
        else
        {
            my $colorName = $1;
            $color = $Torrus::Renderer::graphStyles{$colorName}{'color'};
            if( not defined( $color ) )
            {
                Error('No color is defined for ' . $colorName);
                $color = '#000000';
            }
        }
    }
    return $color;
}

sub mkline
{
    my $self = shift;
    my $line = shift;

    if( $line =~ /^\#\#(\S+)$/ )
    {
        my $lineName = $1;
        $line = $Torrus::Renderer::graphStyles{$lineName}{'line'};
        if( not defined( $line ) )
        {
            Error('No line style is defined for ' . $lineName);
            $line = 'LINE1';
        }
    }
    return $line;
}


sub tz_set
{
    my $self = shift;

    if( defined $ENV{'TZ'} )
    {
        Debug("Previous TZ value: " . $ENV{'TZ'});
        $self->{'tz_defined'} = 1;
    }
    else
    {
        $self->{'tz_defined'} = 0;
    }

    if( defined( my $newTZ = $self->{'options'}->{'variables'}->{'TZ'} ) )
    {
        Debug("Setting TZ to " . $newTZ);
        $self->{'tz_old'} = $ENV{'TZ'};
        $ENV{'TZ'} = $newTZ;
        $self->{'tz_changed'} = 1;
    }
    else
    {
        $self->{'tz_changed'} = 0;
    }
}

sub tz_restore
{
    my $self = shift;

    if( $self->{'tz_changed'} )
    {
        if( $self->{'tz_defined'} )
        {
            Debug("Restoring TZ back to " . $self->{'tz_old'});
            $ENV{'TZ'} = $self->{'tz_old'};
        }
        else
        {
            Debug("Restoring TZ back to undefined");
            delete $ENV{'TZ'};
        }
    }
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
