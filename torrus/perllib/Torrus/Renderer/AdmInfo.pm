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

# $Id: AdmInfo.pm,v 1.1 2010-12-27 00:03:44 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::Renderer::AdmInfo;

use strict;

use Torrus::ConfigTree;
use Torrus::Log;
use Torrus::ACL;

use Template;

my %rrd_params =
    (
     'leaf-type' => {'rrd-def' => {'rrd-ds' => undef,
                                   'rrd-cf' => undef,
                                   'data-file' => undef,
                                   'data-dir'  => undef},
                     'rrd-cdef' => {'rpn-expr' => undef}},
     );

my %rrdmulti_params = ( 'ds-names' => undef );

my %collector_params =
    (
     'storage-type'   => {'rrd' => {
         'data-file'              => undef,
         'data-dir'               => undef,
         'leaf-type'              => {
             'rrd-def'  => {'rrd-ds' => undef,
                            'rrd-cf' => undef,
                            'rrd-create-dstype' => undef,
                            'rrd-create-rra'         => undef,
                            'rrd-create-heartbeat'   => undef,
                            'rrd-hwpredict'         => {
                                'enabled' => {'rrd-create-hw-rralen' => undef},
                                'disabled' => undef
                                }}}}},
     'collector-type'        => undef,
     'collector-period'      => undef,
     'collector-timeoffset'  => undef,
     'collector-instance'    => undef,
     'collector-instance-hashstring' => undef,
     'collector-scale'      => undef,
     'collector-dispersed-timeoffset' => {
         'no' => undef,
         'yes' => {'collector-timeoffset-min' => undef,
                   'collector-timeoffset-max' => undef,
                   'collector-timeoffset-step' => undef,
                   'collector-timeoffset-hashstring' => undef}}
     );


my %leaf_params =
    ('ds-type' => {'rrd-file' => \%rrd_params,
                   'rrd-multigraph' => \%rrdmulti_params,
                   'collector' => \%collector_params},
     'rrgraph-views'             => undef,
     'rrd-scaling-base'         => undef,
     'graph-logarithmic'        => undef,
     'graph-rigid-boundaries'   => undef,
     'graph-ignore-decorations' => undef,
     'nodeid'                   => undef);


my %param_categories =
    (
     'collector-dispersed-timeoffset'    => 'Collector',
     'collector-period'                  => 'Collector',
     'collector-scale'                   => 'Collector',
     'collector-timeoffset'              => 'Collector',
     'collector-timeoffset-hashstring'   => 'Collector',
     'collector-timeoffset-max'          => 'Collector',
     'collector-timeoffset-min'          => 'Collector',
     'collector-timeoffset-step'         => 'Collector',
     'collector-type'                    => 'Collector',
     'collector-instance'                => 'Collector',
     'collector-instance-hashstring'     => 'Collector',
     'data-dir'                          => 'Storage',
     'data-file'                         => 'Storage',
     'ds-names'                          => 'Multigraph',
     'ds-type'                           => 'Common Parameters',
     'graph-ignore-decorations'          => 'Display',
     'graph-logarithmic'                 => 'Display',
     'graph-rigid-boundaries'            => 'Display',
     'leaf-type'                         => 'Common Parameters',
     'nodeid'                            => 'Common Parameters',
     'rpn-expr'                          => 'RRD CDEF Paramters',
     'rrd-cf'                            => 'RRD',
     'rrd-create-dstype'                 => 'RRD',
     'rrd-create-heartbeat'              => 'RRD',
     'rrd-create-hw-rralen'              => 'RRD',
     'rrd-create-rra'                    => 'RRD',
     'rrd-ds'                            => 'RRD',
     'rrd-hwpredict'                     => 'RRD',
     'rrd-scaling-base'                  => 'RRD',
     'rrgraph-views'                     => 'Display',
     'storage-type'                      => 'Storage'
     );
     

# Load additional validation, configurable from
# torrus-config.pl and torrus-siteconfig.pl

foreach my $mod ( @Torrus::Renderer::loadAdmInfo )
{
    eval( 'require ' . $mod );
    die( $@ ) if $@;
    eval( '&' . $mod . '::initAdmInfo( \%leaf_params, \%param_categories )' );
    die( $@ ) if $@;
}


# All our methods are imported by Torrus::Renderer;

sub render_adminfo
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my $outfile = shift;

    if( $self->may_display_adminfo( $config_tree, $token ) )
    {
        $self->{'adminfo'} = $self->retrieve_adminfo( $config_tree, $token );
        my @ret = $self->render_html( $config_tree, $token, $view, $outfile );
        delete $self->{'adminfo'};
        return @ret;
    }
    else
    {
        if( not open(OUT, ">$outfile") )
        {
            Error("Cannot open $outfile for writing: $!");
            return undef;
        }
        else
        {
            print OUT "Cannot display admin information\n";
            close OUT;
        }

        return (300+time(), 'text/plain');
    }
}


sub may_display_adminfo
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;

    if( $config_tree->isLeaf( $token ) )
    {
        # hasPrivilege is imported from Torrus::Renderer::HTML
        if( $self->hasPrivilege( $config_tree->treeName(),
                                 'DisplayAdmInfo' ) )
        {
            return 1;
        }
    }
    
    return 0;
}


sub retrieve_adminfo
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;

    my $ret = {};
    my @namemaps = ( \%leaf_params );

    while( scalar( @namemaps ) > 0 )
    {
        my @next_namemaps = ();

        foreach my $namemap ( @namemaps )
        {
            foreach my $paramkey ( keys %{$namemap} )
            {
                my $pname = $paramkey;

                my $pval = $config_tree->getNodeParam( $token, $pname );
                if( defined( $pval ) )
                {
                    if( ref( $namemap->{$paramkey} ) )
                    {
                        if( exists $namemap->{$paramkey}->{$pval} )
                        {
                            if( defined $namemap->{$paramkey}->{$pval} )
                            {
                                push( @next_namemaps,
                                      $namemap->{$paramkey}->{$pval} );
                            }
                        }
                    }

                    my $category = $param_categories{$pname};
                    if( not defined( $category ) )
                    {
                        $category = 'Other';
                    }                    
                    $ret->{$category}{$pname} = $pval;
                }
            }
        }
        @namemaps = @next_namemaps;
    }

    return $ret;
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
