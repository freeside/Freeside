#  Copyright (C) 2002-2007  Stanislav Sinyagin
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

# $Id: Writer.pm,v 1.1 2010-12-27 00:03:45 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

#
# Write access for ConfigTree
#

package Torrus::ConfigTree::Writer;

use Torrus::ConfigTree;
our @ISA=qw(Torrus::ConfigTree);

use Torrus::Log;
use Torrus::TimeStamp;
use Torrus::SiteConfig;
use Torrus::ServiceID;
    
use strict;
use Digest::MD5 qw(md5); # needed as hash function


our %multigraph_remove_space =
    ('ds-expr-' => 1,
     'graph-legend-' => 0);


# instance of Torrus::ServiceID object, if needed
my $srvIdParams;

# tree names where we initialized service IDs
my %srvIdInitialized;


sub new
{
    my $proto = shift;
    my %options = @_;
    my $class = ref($proto) || $proto;
    $options{'-WriteAccess'} = 1;
    my $self  = $class->SUPER::new( %options );
    if( not defined( $self ) )
    {
        return undef;
    }
    
    bless $self, $class;

    $self->{'viewparent'} = {};
    $self->{'mayRunCollector'} =
        Torrus::SiteConfig::mayRunCollector( $self->treeName() );

    $self->{'collectorInstances'} =
        Torrus::SiteConfig::collectorInstances( $self->treeName() );

    $self->{'db_collectortokens'} = [];
    foreach my $instance ( 0 .. ($self->{'collectorInstances'} - 1) )
    {
        $self->{'db_collectortokens'}->[$instance] =
            new Torrus::DB( 'collector_tokens' . '_' .
                            $instance . '_' . $self->{'ds_config_instance'},
                            -Subdir => $self->treeName(),
                            -WriteAccess => 1,
                            -Truncate    => 1 );
    }

    # delay writing of frequently changed values
    $self->{'db_dsconfig'}->delay();
    $self->{'db_otherconfig'}->delay();    
    return $self;
}


sub newToken
{
    my $self = shift;
    my $token = $self->{'next_free_token'};
    $token = 1 unless defined( $token );
    $self->{'next_free_token'} = $token + 1;
    return sprintf('T%.4d', $token);
}


sub setParam
{
    my $self  = shift;
    my $name  = shift;
    my $param = shift;
    my $value = shift;

    if( $self->getParamProperty( $param, 'remspace' ) )
    {
        $value =~ s/\s+//go;
    }

    $self->{'paramcache'}{$name}{$param} = $value;
    $self->{'db_otherconfig'}->put( 'P:'.$name.':'.$param, $value );
    $self->{'db_otherconfig'}->addToList('Pl:'.$name, $param);
}

sub setNodeParam
{
    my $self  = shift;
    my $name  = shift;
    my $param = shift;
    my $value = shift;

    if( $self->getParamProperty( $param, 'remspace' ) )
    {
        $value =~ s/\s+//go;
    }

    $self->{'paramcache'}{$name}{$param} = $value;
    $self->{'db_dsconfig'}->put( 'P:'.$name.':'.$param, $value );
    $self->{'db_dsconfig'}->addToList('Pl:'.$name, $param);
}


sub setParamProperty
{
    my $self = shift;
    my $param = shift;
    my $prop = shift;
    my $value = shift;

    $self->{'paramprop'}{$prop}{$param} = $value;
    $self->{'db_paramprops'}->put( $param . ':' . $prop, $value );
}


sub initRoot
{
    my $self  = shift;
    if( not defined( $self->token('/') ) )
    {
        my $token = $self->newToken();
        $self->{'db_dsconfig'}->put( 'pt:/', $token );
        $self->{'db_dsconfig'}->put( 'tp:'.$token, '/' );
        $self->{'db_dsconfig'}->put( 'n:'.$token, 0 );
        $self->{'nodetype_cache'}{$token} = 0;
    }
}

sub addChild
{
    my $self = shift;
    my $token = shift;
    my $childname = shift;
    my $isAlias = shift;

    if( not $self->isSubtree( $token ) )
    {
        Error('Cannot add a child to a non-subtree node: ' .
              $self->path($token));
        return undef;
    }

    my $path = $self->path($token) . $childname;

    # If the child already exists, do nothing

    my $ctoken = $self->token($path);
    if( not defined($ctoken) )
    {
        $ctoken = $self->newToken();

        $self->{'db_dsconfig'}->put( 'pt:'.$path, $ctoken );
        $self->{'db_dsconfig'}->put( 'tp:'.$ctoken, $path );

        $self->{'db_dsconfig'}->addToList( 'c:'.$token, $ctoken );
        $self->{'db_dsconfig'}->put( 'p:'.$ctoken, $token );
        $self->{'parentcache'}{$ctoken} = $token;

        my $nodeType;
        if( $isAlias )
        {
            $nodeType = 2; # alias
        }
        elsif( $childname =~ /\/$/o )
        {
            $nodeType = 0; # subtree
        }
        else
        {
            $nodeType = 1; # leaf
        }
        $self->{'db_dsconfig'}->put( 'n:'.$ctoken, $nodeType );
        $self->{'nodetype_cache'}{$ctoken} = $nodeType;
    }
    return $ctoken;
}

sub setAlias
{
    my $self = shift;
    my $token = shift;
    my $apath = shift;

    my $ok = 1;

    my $iamLeaf = $self->isLeaf($token);

    # TODO: Add more verification here
    if( not defined($apath) or $apath !~ /^\//o or
        ( not $iamLeaf and $apath !~ /\/$/o ) or
        ( $iamLeaf and $apath =~ /\/$/o ) )
    {
        my $path = $self->path($token);
        Error("Incorrect alias at $path: $apath"); $ok = 0;
    }
    elsif( $self->token( $apath ) )
    {
        my $path = $self->path($token);
        Error("Alias already exists: $apath at $path"); $ok = 0;
    }
    else
    {
        # Go through the alias and create subtrees if neccessary

        my @pathelements = $self->splitPath($apath);
        my $aliasChildName = pop @pathelements;

        my $nodepath = '';
        my $parent_token = $self->token('/');

        foreach my $nodename ( @pathelements )
        {
            $nodepath .= $nodename;
            my $child_token = $self->token( $nodepath );
            if( not defined( $child_token ) )
            {
                $child_token = $self->addChild( $parent_token, $nodename );
                if( not defined( $child_token ) )
                {
                    return 0;
                }
            }
            $parent_token = $child_token;
        }

        my $alias_token = $self->addChild( $parent_token, $aliasChildName, 1 );
        if( not defined( $alias_token ) )
        {
            return 0;
        }

        $self->{'db_dsconfig'}->put( 'a:'.$alias_token, $token );
        $self->{'db_dsconfig'}->addToList( 'ar:'.$token, $alias_token );
        $self->{'db_aliases'}->put( $apath, $token );
    }
    return $ok;
}

sub addView
{
    my $self = shift;
    my $vname = shift;
    my $parent = shift;
    $self->{'db_otherconfig'}->addToList('V:', $vname);
    if( defined( $parent ) )
    {
        $self->{'viewparent'}{$vname} = $parent;
    }
}


sub addMonitor
{
    my $self = shift;
    my $mname = shift;
    $self->{'db_otherconfig'}->addToList('M:', $mname);
}


sub addAction
{
    my $self = shift;
    my $aname = shift;
    $self->{'db_otherconfig'}->addToList('A:', $aname);
}


sub addDefinition
{
    my $self = shift;
    my $name = shift;
    my $value = shift;
    $self->{'db_dsconfig'}->put( 'd:'.$name, $value );
    $self->{'db_dsconfig'}->addToList('D:', $name);
}


sub setVar
{
    my $self = shift;
    my $token = shift;
    my $name = shift;
    my $value = shift;
    
    $self->{'setvar'}{$token}{$name} = $value;
}


sub isTrueVar
{
    my $self = shift;
    my $token = shift;
    my $name = shift;

    my $ret = 0;

    while( defined( $token ) and
           not defined( $self->{'setvar'}{$token}{$name} ) )
    {
        $token = $self->getParent( $token );
    }

    if( defined( $token ) )
    {
        my $value = $self->{'setvar'}{$token}{$name};
        if( defined( $value ) )
        {
            if( $value eq 'true' or
                $value =~ /^\d+$/o and $value )
            {
                $ret = 1;
            }
        }
    }
    
    return $ret;
}

sub finalize
{
    my $self = shift;
    my $status = shift;

    if( $status )
    {
        # write delayed data
        $self->{'db_dsconfig'}->commit();
        $self->{'db_otherconfig'}->commit();    
        
        Verbose('Configuration has compiled successfully. Switching over to ' .
             'DS config instance ' . $self->{'ds_config_instance'} .
             ' and Other config instance ' .
             $self->{'other_config_instance'} );

        $self->setReady(1);
        if( not $self->{'-NoDSRebuild'} )
        {
            $self->{'db_config_instances'}->
                put( 'ds:' . $self->treeName(),
                     $self->{'ds_config_instance'} );
        }

        $self->{'db_config_instances'}->
            put( 'other:' . $self->treeName(),
                 $self->{'other_config_instance'} );

        Torrus::TimeStamp::init();
        Torrus::TimeStamp::setNow($self->treeName() . ':configuration');
        Torrus::TimeStamp::release();
    }
}


sub postProcess
{
    my $self = shift;

    my $ok = $self->postProcessNodes();

    # Propagate view inherited parameters
    $self->{'viewParamsProcessed'} = {};
    foreach my $vname ( $self->getViewNames() )
    {
        &Torrus::DB::checkInterrupted();
        
        $self->propagateViewParams( $vname );
    }
    return $ok;
}



sub postProcessNodes
{
    my $self = shift;
    my $token = shift;

    &Torrus::DB::checkInterrupted();

    my $ok = 1;

    if( not defined( $token ) )
    {
        $token = $self->token('/');
    }

    my $nodeid = $self->getNodeParam( $token, 'nodeid', 1 );
    if( defined( $nodeid ) )
    {
        # verify the uniqueness of nodeid
        
        my $oldToken = $self->{'db_nodeid'}->get($nodeid);
        if( defined($oldToken) )
        {
            Error('Non-unique nodeid ' . $nodeid .
                  ' in ' . $self->path($token) .
                  ' and ' . $self->path($oldToken));
            $ok = 0;
        }
        else
        {
            $self->{'db_nodeid'}->put($nodeid, $token);
        }
    }

    
    if( $self->isLeaf($token) )
    {
        # Process static tokenset members

        my $tsets = $self->getNodeParam( $token, 'tokenset-member' );
        if( defined( $tsets ) )
        {
            foreach my $tset ( split(/,/o, $tsets) )
            {
                my $tsetName = 'S'.$tset;
                if( not $self->tsetExists( $tsetName ) )
                {
                    my $path = $self->path( $token );
                    Error("Referenced undefined token set $tset in $path");
                    $ok = 0;
                }
                else
                {
                    $self->tsetAddMember( $tsetName, $token, 'static' );
                }
            }
        }

        my $dsType = $self->getNodeParam( $token, 'ds-type' );
        if( defined( $dsType ) )
        {
            if( $dsType eq 'rrd-multigraph' )
            {
                # Expand parameter substitutions in multigraph leaves
                
                my @dsNames =
                    split(/,/o, $self->getNodeParam($token, 'ds-names') );
                
                foreach my $dname ( @dsNames )
                {
                    foreach my $param ( 'ds-expr-', 'graph-legend-' )
                    {
                        my $dsParam = $param . $dname;
                        my $value = $self->getNodeParam( $token, $dsParam );
                        if( defined( $value ) )
                        {
                            my $newValue = $value;
                            if( $multigraph_remove_space{$param} )
                            {
                                $newValue =~ s/\s+//go;
                            }
                            $newValue =
                                $self->expandSubstitutions( $token, $dsParam,
                                                            $newValue );
                            if( $newValue ne $value )
                            {
                                $self->setNodeParam( $token, $dsParam,
                                                     $newValue );
                            }
                        }
                    }
                }
            }
            elsif( $dsType eq 'collector' and $self->{'mayRunCollector'} )
            {
                # Split the collecting job between collector instances
                my $instance = 0;
                my $nInstances = $self->{'collectorInstances'};

                my $oldOffset =
                    $self->getNodeParam($token, 'collector-timeoffset');
                my $newOffset = $oldOffset;
                
                my $period =
                    $self->getNodeParam($token, 'collector-period');
                
                if( $nInstances > 1 )
                {
                    my $hashString =
                        $self->getNodeParam($token,
                                            'collector-instance-hashstring');
                    if( not defined( $hashString ) )
                    {
                        Error('collector-instance-hashstring is not defined ' .
                              'in ' . $self->path( $token ));
                        $hashString = '';
                    }
                    
                    $instance =
                        unpack( 'N', md5( $hashString ) ) % $nInstances;
                }          

                $self->setNodeParam( $token,
                                     'collector-instance',
                                     $instance );
                
                my $dispersed =
                    $self->getNodeParam($token,
                                        'collector-dispersed-timeoffset');
                if( defined( $dispersed ) and $dispersed eq 'yes' )
                {
                    # Process dispersed collector offsets
                    
                    my %p;
                    foreach my $param ( 'collector-timeoffset-min',
                                        'collector-timeoffset-max',
                                        'collector-timeoffset-step',
                                        'collector-timeoffset-hashstring' )
                    {
                        my $val = $self->getNodeParam( $token, $param );
                        if( not defined( $val ) )
                        {
                            Error('Mandatory parameter ' . $param . ' is not '.
                                  ' defined in ' . $self->path( $token ));
                            $ok = 0;
                        }
                        else
                        {
                            $p{$param} = $val;
                        }
                    }

                    if( $ok )
                    {
                        my $min = $p{'collector-timeoffset-min'};
                        my $max = $p{'collector-timeoffset-max'};
                        if( $max < $min )
                        {
                            Error('collector-timeoffset-max is less than ' .
                                  'collector-timeoffset-min in ' .
                                  $self->path( $token ));
                            $ok = 0;
                        }
                        else
                        {
                            my $step = $p{'collector-timeoffset-step'};
                            my $hashString =
                                $p{'collector-timeoffset-hashstring'};
                            
                            my $bucketSize = int( ($max - $min) / $step );
                            $newOffset =
                                $min
                                +
                                $step * ( unpack( 'N', md5( $hashString ) ) %
                                          $bucketSize )
                                +
                                $instance * int( $step / $nInstances );
                        }
                    }
                }
                else
                {
                    $newOffset += $instance * int( $period / $nInstances ); 
                } 

                $newOffset %= $period;
                
                if( $newOffset != $oldOffset )
                {
                    $self->setNodeParam( $token,
                                         'collector-timeoffset',
                                         $newOffset );
                }

                $self->{'db_collectortokens'}->[$instance]->put
                    ( $token, sprintf('%d:%d', $period, $newOffset) );

                my $storagetypes =
                    $self->getNodeParam( $token, 'storage-type' );
                foreach my $stype ( split(/,/o, $storagetypes) )
                {
                    if( $stype eq 'ext' )
                    {
                        if( not defined( $srvIdParams ) )
                        {
                            $srvIdParams =
                                new Torrus::ServiceID( -WriteAccess => 1 );
                        }

                        my $srvTrees =
                            $self->getNodeParam($token, 'ext-service-trees');

                        if( not defined( $srvTrees ) or
                            length( $srvTrees ) == 0 )
                        {
                            $srvTrees = $self->treeName();
                        }
                                                
                        my $serviceid =
                            $self->getNodeParam($token, 'ext-service-id');

                        foreach my $srvTree (split(/\s*,\s*/o, $srvTrees))
                        {
                            if( not Torrus::SiteConfig::treeExists($srvTree) )
                            {
                                Error
                                    ('Error processing ext-service-trees' .
                                     'for ' . $self->path( $token ) .
                                     ': tree ' . $srvTree .
                                     ' does not exist');
                                $ok = 0;
                            }
                            else
                            {
                                if( not $srvIdInitialized{$srvTree} )
                                {
                                    $srvIdParams->cleanAllForTree
                                        ( $srvTree );
                                    $srvIdInitialized{$srvTree} = 1;
                                }
                                else
                                {
                                    if( $srvIdParams->idExists( $serviceid,
                                                                $srvTree ) )
                                    {
                                        Error('Duplicate ServiceID: ' .
                                              $serviceid . ' in tree ' .
                                              $srvTree);
                                        $ok = 0;
                                    }
                                }
                            }
                        }

                        if( $ok )
                        {
                            # sorry for ackward Emacs auto-indent
                            my $params = {
                                'trees' => $srvTrees,
                                'token' => $token,
                                'dstype' =>
                                    $self->getNodeParam($token,
                                                        'ext-dstype'),
                                    'units' =>
                                    $self->getNodeParam
                                    ($token, 'ext-service-units')
                                };
                            
                            $srvIdParams->add( $serviceid, $params );
                        }
                    }
                }
            }
        }
        else
        {
            my $path = $self->path( $token );
            Error("Mandatory parameter 'ds-type' is not defined for $path");
            $ok = 0;
        }            
    }
    else
    {
        foreach my $ctoken ( $self->getChildren( $token ) )
        {
            if( not $self->isAlias( $ctoken ) )
            {
                $ok = $self->postProcessNodes( $ctoken ) ? $ok:0;
            }
        }
    }
    return $ok;
}


sub propagateViewParams
{
    my $self = shift;
    my $vname = shift;

    # Avoid processing the same view twice
    if( $self->{'viewParamsProcessed'}{$vname} )
    {
        return;
    }

    # First we do the same for parent
    my $parent = $self->{'viewparent'}{$vname};
    if( defined( $parent ) )
    {
        $self->propagateViewParams( $parent );

        my $parentParams = $self->getParams( $parent );
        foreach my $param ( keys %{$parentParams} )
        {
            if( not defined( $self->getParam( $vname, $param ) ) )
            {
                $self->setParam( $vname, $param, $parentParams->{$param} );
            }
        }
    }

    # mark this view as processed
    $self->{'viewParamsProcessed'}{$vname} = 1;
}


sub validate
{
    my $self = shift;

    my $ok = 1;

    $self->{'is_writing'} = undef;

    if( not $self->{'-NoDSRebuild'} )
    {
        $ok = Torrus::ConfigTree::Validator::validateNodes($self);
    }
    $ok = Torrus::ConfigTree::Validator::validateViews($self) ? $ok:0;
    $ok = Torrus::ConfigTree::Validator::validateMonitors($self) ? $ok:0;
    $ok = Torrus::ConfigTree::Validator::validateTokensets($self) ? $ok:0;

    return $ok;
}


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
