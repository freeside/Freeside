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

# $Id: ConfigTree.pm,v 1.1 2010-12-27 00:03:41 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


package Torrus::ConfigTree;

use Torrus::DB;
use Torrus::Log;
use Torrus::TimeStamp;

use strict;



sub new
{
    my $self = {};
    my $class = shift;
    my %options = @_;
    bless $self, $class;

    $self->{'treename'} = $options{'-TreeName'};
    die('ERROR: TreeName is mandatory') if not $self->{'treename'};

    $self->{'db_config_instances'} =
        new Torrus::DB( 'config_instances', -WriteAccess => 1 );
    defined( $self->{'db_config_instances'} ) or return( undef );

    my $i = $self->{'db_config_instances'}->get('ds:' . $self->{'treename'});
    if( not defined($i) )
    {
        $i = 0;
        $self->{'first_time_created'} = 1;
    }

    my $dsConfInstance = sprintf( '%d', $i );

    $i = $self->{'db_config_instances'}->get('other:' . $self->{'treename'});
    $i = 0 unless defined( $i );

    my $otherConfInstance = sprintf( '%d', $i );

    if( $options{'-WriteAccess'} )
    {
        $self->{'is_writing'} = 1;
        
        # Acquire exlusive lock on the database and set the compiling flag
        {
            my $ok = 1;
            my $key = 'compiling:' . $self->{'treename'};
            my $cursor = $self->{'db_config_instances'}->cursor( -Write => 1 );
            my $compilingFlag =
                $self->{'db_config_instances'}->c_get( $cursor, $key );
            if( $compilingFlag )
            {
                if( $options{'-ForceWriter'} )
                {
                    Warn('Another compiler process is probably still ' .
                         'running. This may lead to an unusable ' .
                         'database state');
                }
                else
                {
                    Error('Another compiler is running for the tree ' .
                          $self->{'treename'});
                    $ok = 0;
                }
            }
            else
            {
                $self->{'db_config_instances'}->c_put( $cursor, $key, 1 );
            }
            undef $cursor;
            if( not $ok )
            {
                return undef;
            }
            $self->{'iam_writer'} = 1;
        }

        if( not $options{'-NoDSRebuild'} )
        {
            $dsConfInstance = sprintf( '%d', ( $dsConfInstance + 1 ) % 2 );
        }
        $otherConfInstance = sprintf( '%d', ( $otherConfInstance + 1 ) % 2 );
    }

    $self->{'ds_config_instance'} = $dsConfInstance;
    $self->{'other_config_instance'} = $otherConfInstance;

    $self->{'db_readers'} = new Torrus::DB('config_readers',
                                           -Subdir => $self->{'treename'},
                                           -WriteAccess => 1 );
    defined( $self->{'db_readers'} ) or return( undef );

    $self->{'db_dsconfig'} =
        new Torrus::DB('ds_config_' . $dsConfInstance,
                       -Subdir => $self->{'treename'},  -Btree => 1,
                       -WriteAccess => $options{'-WriteAccess'});
    defined( $self->{'db_dsconfig'} ) or return( undef );
    
    $self->{'db_otherconfig'} =
        new Torrus::DB('other_config_' . $otherConfInstance,
                       -Subdir => $self->{'treename'}, -Btree => 1,
                       -WriteAccess => $options{'-WriteAccess'});
    defined( $self->{'db_otherconfig'} ) or return( undef );
    
    $self->{'db_aliases'} =
        new Torrus::DB('aliases_' . $dsConfInstance,
                       -Subdir => $self->{'treename'},  -Btree => 1,
                       -WriteAccess => $options{'-WriteAccess'});
    defined( $self->{'db_aliases'} ) or return( undef );

    if( $options{'-WriteAccess'} )
    {
        $self->setReady(0);
        $self->waitReaders();

        if( $options{'-Rebuild'} )
        {
            $self->{'db_otherconfig'}->trunc();
            if( not $options{'-NoDSRebuild'} )
            {
                $self->{'db_dsconfig'}->trunc();
                $self->{'db_aliases'}->trunc();
            }
        }
    }
    else
    {
        $self->setReader();

        if( not $self->isReady() )
        {
            if( $options{'-Wait'} )
            {
                Warn('Configuration is not ready');

                my $waitingTimeout =
                    time() + $Torrus::Global::ConfigReadyTimeout;
                my $success = 0;

                while( not $success and time() < $waitingTimeout )
                {
                    $self->clearReader();

                    Info('Sleeping ' .
                         $Torrus::Global::ConfigReadyRetryPeriod .
                         ' seconds');
                    sleep $Torrus::Global::ConfigReadyRetryPeriod;

                    $self->setReader();

                    if( $self->isReady() )
                    {
                        $success = 1;
                        Info('Now configuration is ready');
                    }
                    else
                    {
                        Info('Configuration is still not ready');
                    }
                }
                if( not $success )
                {
                    Error('Configuration wait timed out');
                    $self->clearReader();
                    return undef;
                }
            }
            else
            {
                Error('Configuration is not ready');
                $self->clearReader();
                return undef;
            }
        }
    }

    # Read the parameter properties into memory
    $self->{'db_paramprops'} =
        new Torrus::DB('paramprops_' . $dsConfInstance,
                       -Subdir => $self->{'treename'},  -Btree => 1,
                       -WriteAccess => $options{'-WriteAccess'});
    defined( $self->{'db_paramprops'} ) or return( undef );
    
    if( $options{'-Rebuild'} )
    {
        $self->{'db_paramprops'}->trunc();
    }
    else
    {
        my $cursor = $self->{'db_paramprops'}->cursor();
        while( my ($key, $val) =
               $self->{'db_paramprops'}->next( $cursor ) )
        {
            my( $param, $prop ) = split( /:/o, $key );
            $self->{'paramprop'}{$prop}{$param} = $val;
        }
        undef $cursor;
        $self->{'db_paramprops'}->closeNow();
        delete $self->{'db_paramprops'};
    }

    
    $self->{'db_sets'} =
        new Torrus::DB('tokensets_' . $dsConfInstance,
                       -Subdir => $self->{'treename'}, -Btree => 0,
                       -WriteAccess => 1, -Truncate => $options{'-Rebuild'});
    defined( $self->{'db_sets'} ) or return( undef );


    $self->{'db_nodepcache'} =
        new Torrus::DB('nodepcache_' . $dsConfInstance,
                       -Subdir => $self->{'treename'}, -Btree => 1,
                       -WriteAccess => 1,
                       -Truncate => ($options{'-Rebuild'} and
                                     not $options{'-NoDSRebuild'}));
    defined( $self->{'db_nodepcache'} ) or return( undef );


    $self->{'db_nodeid'} =
        new Torrus::DB('nodeid_' . $dsConfInstance,
                       -Subdir => $self->{'treename'}, -Btree => 1,
                       -WriteAccess => 1,
                       -Truncate => ($options{'-Rebuild'} and
                                     not $options{'-NoDSRebuild'}));
    defined( $self->{'db_nodeid'} ) or return( undef );

    return $self;
}


sub DESTROY
{
    my $self = shift;

    Debug('Destroying ConfigTree object');

    if( $self->{'iam_writer'} )
    {
        # Acquire exlusive lock on the database and clear the compiling flag
        my $cursor = $self->{'db_config_instances'}->cursor( -Write => 1 );
        $self->{'db_config_instances'}->c_put
            ( $cursor, 'compiling:' . $self->{'treename'}, 0 );
        undef $cursor;
    }
    else
    {
        $self->clearReader();
    }

    undef $self->{'db_dsconfig'};
    undef $self->{'db_otherconfig'};
    undef $self->{'db_aliases'};
    undef $self->{'db_sets'};
    undef $self->{'db_nodepcache'};
    undef $self->{'db_readers'};
}

# Manage the readinness flag

sub setReady
{
    my $self = shift;
    my $ready = shift;
    $self->{'db_otherconfig'}->put( 'ConfigurationReady', $ready ? 1:0 );
}

sub isReady
{
    my $self = shift;
    return $self->{'db_otherconfig'}->get( 'ConfigurationReady' );
}

# Manage the readers database

sub setReader
{
    my $self = shift;

    my $readerId = 'pid=' . $$ . ',rand=' . sprintf('%.10d', rand(1e9));
    Debug('Setting up reader: ' . $readerId);
    $self->{'reader_id'} = $readerId;
    $self->{'db_readers'}->put( $readerId,
                                sprintf('%d:%d:%d',
                                        time(),
                                        $self->{'ds_config_instance'},
                                        $self->{'other_config_instance'}) );
}

sub clearReader
{
    my $self = shift;

    if( defined( $self->{'reader_id'} ) )
    {
        Debug('Clearing reader: ' . $self->{'reader_id'});
        $self->{'db_readers'}->del( $self->{'reader_id'} );
        delete $self->{'reader_id'};
    }
}


sub waitReaders
{
    my $self = shift;

    # Let the active readers finish their job
    my $noReaders = 0;
    while( not $noReaders )
    {
        my @readers = ();
        my $cursor = $self->{'db_readers'}->cursor();
        while( my ($key, $val) = $self->{'db_readers'}->next( $cursor ) )
        {
            my( $timestamp, $dsInst, $otherInst ) = split( /:/o, $val );
            if( $dsInst == $self->{'ds_config_instance'} or
                $otherInst == $self->{'other_config_instance'} )
            {
                push( @readers, {
                    'reader' => $key,
                    'timestamp' => $timestamp } );
            }
        }
        undef $cursor;
        if( @readers > 0 )
        {
            Info('Waiting for ' . scalar(@readers) . ' readers:');
            my $recentTS = 0;
            foreach my $reader ( @readers )
            {
                Info($reader->{'reader'} . ', timestamp: ' .
                     localtime( $reader->{'timestamp'} ));
                if( $reader->{'timestamp'} > $recentTS )
                {
                    $recentTS = $reader->{'timestamp'};
                }
            }
            if( $recentTS + $Torrus::Global::ConfigReadersWaitTimeout >=
                time() )
            {
                Info('Sleeping ' . $Torrus::Global::ConfigReadersWaitPeriod  .
                     ' seconds');
                sleep( $Torrus::Global::ConfigReadersWaitPeriod );
            }
            else
            {
                # the readers are too long active. we ignore them now
                Warn('Readers wait timed out. Flushing the readers list for ' .
                     'DS config instance ' . $self->{'ds_config_instance'} .
                     ' and Other config instance ' .
                     $self->{'other_config_instance'});

                my $cursor = $self->{'db_readers'}->cursor( -Write => 1 );
                while( my ($key, $val) =
                       $self->{'db_readers'}->next( $cursor ) )
                {
                    my( $timestamp, $dsInst, $otherInst ) =
                        split( /:/o, $val );
                    if( $dsInst == $self->{'ds_config_instance'} or
                        $otherInst == $self->{'other_config_instance'} )
                    {
                        $self->{'db_readers'}->c_del( $cursor );
                    }
                }
                undef $cursor;
                $noReaders = 1;
            }
        }
        else
        {
            $noReaders = 1;
        }
    }
}



# This should be called after Torrus::TimeStamp::init();

sub getTimestamp
{
    my $self = shift;
    return Torrus::TimeStamp::get($self->{'treename'} . ':configuration');
}

sub treeName
{
    my $self = shift;
    return $self->{'treename'};
}


# Returns array with path components

sub splitPath
{
    my $self = shift;
    my $path = shift;
    my @ret = ();
    while( length($path) > 0 )
    {
        my $node;
        $path =~ s/^([^\/]*\/?)//o; $node = $1;
        push(@ret, $node);
    }
    return @ret;
}

sub nodeName
{
    my $self = shift;
    my $path = shift;
    $path =~ s/.*\/([^\/]+)\/?$/$1/o;
    return $path;
}

sub token
{
    my $self = shift;
    my $path = shift;

    my $token = $self->{'db_dsconfig'}->get( 'pt:'.$path );
    if( not defined( $token ) )
    {
        my $prefixLen = 1; # the leading slash is anyway there
        my $pathLen = length( $path );
        while( not defined( $token ) and $prefixLen < $pathLen )
        {
            my $result = $self->{'db_aliases'}->getBestMatch( $path );
            if( not defined( $result ) )
            {
                $prefixLen = $pathLen; # exit the loop
            }
            else
            {
                # Found a partial match
                $prefixLen = length( $result->{'key'} );
                my $aliasTarget = $self->path( $result->{'value'} );
                $path = $aliasTarget . substr( $path, $prefixLen );
                $token = $self->{'db_dsconfig'}->get( 'pt:'.$path );
            }
        }
    }
    return $token;
}

sub path
{
    my $self = shift;
    my $token = shift;
    return $self->{'db_dsconfig'}->get( 'tp:'.$token );
}

sub nodeExists
{
    my $self = shift;
    my $path = shift;

    return defined( $self->{'db_dsconfig'}->get( 'pt:'.$path ) );
}


sub nodeType
{
    my $self = shift;
    my $token = shift;

    my $type = $self->{'nodetype_cache'}{$token};
    if( not defined( $type ) )
    {
        $type = $self->{'db_dsconfig'}->get( 'n:'.$token );
        $self->{'nodetype_cache'}{$token} = $type;
    }
    return $type;
}
    

sub isLeaf
{
    my $self = shift;
    my $token = shift;

    return ( $self->nodeType($token) == 1 );
}


sub isSubtree
{
    my $self = shift;
    my $token = shift;

    return( $self->nodeType($token) == 0 );
}

# Returns the real token or undef
sub isAlias
{
    my $self = shift;
    my $token = shift;

    return( ( $self->nodeType($token) == 2 ) ?
            $self->{'db_dsconfig'}->get( 'a:'.$token ) : undef );
}

# Returns the list of tokens pointing to this one as an alias
sub getAliases
{
    my $self = shift;
    my $token = shift;

    return $self->{'db_dsconfig'}->getListItems('ar:'.$token);
}


sub getParam
{
    my $self = shift;
    my $name = shift;
    my $param = shift;
    my $fromDS = shift;

    if( exists( $self->{'paramcache'}{$name}{$param} ) )
    {
        return $self->{'paramcache'}{$name}{$param};
    }
    else
    {
        my $db = $fromDS ? $self->{'db_dsconfig'} : $self->{'db_otherconfig'};
        my $val = $db->get( 'P:'.$name.':'.$param );
        $self->{'paramcache'}{$name}{$param} = $val;
        return $val;
    }
}

sub retrieveNodeParam
{
    my $self = shift;
    my $token = shift;
    my $param = shift;

    # walk up the tree and save the grandparent's value at parent's cache
    
    my $value;    
    my $currtoken = $token;
    my @ancestors;
    my $walked = 0;
    
    while( not defined($value) and defined($currtoken) )
    {
        $value = $self->getParam( $currtoken, $param, 1 );
        if( not defined $value )
        {
            if( $walked )
            {
                push( @ancestors, $currtoken );
            }
            else
            {
                $walked = 1;
            }
            # walk up to the parent
            $currtoken = $self->getParent($currtoken);
        }
    }

    foreach my $ancestor ( @ancestors )
    {
        $self->{'paramcache'}{$ancestor}{$param} = $value;
    }
    
    return $self->expandNodeParam( $token, $param, $value );
}


sub expandNodeParam
{
    my $self = shift;
    my $token = shift;
    my $param = shift;
    my $value = shift;

    # %parameter_substitutions% in ds-path-* in multigraph leaves
    # are expanded by the Writer post-processing
    if( defined $value and $self->getParamProperty( $param, 'expand' ) )
    {
        $value = $self->expandSubstitutions( $token, $param, $value );
    }
    return $value;
}


sub expandSubstitutions
{
    my $self = shift;
    my $token = shift;
    my $param = shift;
    my $value = shift;

    my $ok = 1;
    my $changed = 1;

    while( $changed and $ok )
    {
        $changed = 0;

        # Substitute definitions
        if( index($value, '$') >= 0 )
        {
            if( not $value =~ /\$(\w+)/o )
            {
                my $path = $self->path($token);
                Error("Incorrect definition reference: $value in $path");
                $ok = 0;
            }
            else
            {
                my $dname = $1;
                my $dvalue = $self->getDefinition($dname);
                if( not defined( $dvalue ) )
                {
                    my $path = $self->path($token);
                    Error("Cannot find definition $dname in $path");
                    $ok = 0;
                }
                else
                {
                    $value =~ s/\$$dname/$dvalue/g;
                    $changed = 1;
                }
            }
        }

        # Substitute parameter references
        if( index($value, '%') >= 0 and $ok )
        {
            if( not $value =~ /\%([a-zA-Z0-9\-_]+)\%/o )
            {
                Error("Incorrect parameter reference: $value");
                $ok = 0;
            }
            else
            {
                my $pname = $1;
                my $pval = $self->getNodeParam( $token, $pname );

                if( not defined( $pval ) )
                {
                    my $path = $self->path($token);
                    Error("Cannot expand parameter reference %".
                          $pname."% in ".$path);
                    $ok = 0;
                }
                else
                {
                    $value =~ s/\%$pname\%/$pval/g;
                    $changed = 1;
                }
            }
        }
    }

    if( ref( $Torrus::ConfigTree::nodeParamHook ) )
    {
        $value = &{$Torrus::ConfigTree::nodeParamHook}( $self, $token,
                                                        $param, $value );
    }

    return $value;
}


sub getNodeParam
{
    my $self = shift;
    my $token = shift;
    my $param = shift;
    my $noclimb = shift;

    my $value;
    if( $noclimb )
    {
        $value = $self->getParam( $token, $param, 1 );
        return $self->expandNodeParam( $token, $param, $value );
    }

    if( $self->{'is_writing'} )
    {
        return $self->retrieveNodeParam( $token, $param );
    }

    my $cachekey = $token.':'.$param;
    my $cacheval = $self->{'db_nodepcache'}->get( $cachekey );
    if( defined( $cacheval ) )
    {
        my $status = substr( $cacheval, 0, 1 );
        if( $status eq 'U' )
        {
            return undef;
        }
        else
        {
            return substr( $cacheval, 1 );
        }
    }

    $value = $self->retrieveNodeParam( $token, $param );

    if( defined( $value ) )
    {
        $self->{'db_nodepcache'}->put( $cachekey, 'D'.$value );
    }
    else
    {
        $self->{'db_nodepcache'}->put( $cachekey, 'U' );
    }

    return $value;
}


sub getParamNames
{
    my $self = shift;
    my $name = shift;
    my $fromDS = shift;

    my $db = $fromDS ? $self->{'db_dsconfig'} : $self->{'db_otherconfig'};

    return $db->getListItems('Pl:'.$name);
}


sub getParams
{
    my $self = shift;
    my $name = shift;
    my $fromDS = shift;

    my $ret = {};
    foreach my $param ( $self->getParamNames( $name, $fromDS ) )
    {
        $ret->{$param} = $self->getParam( $name, $param, $fromDS );
    }
    return $ret;
}

sub getParent
{
    my $self = shift;
    my $token = shift;
    if( exists( $self->{'parentcache'}{$token} ) )
    {
        return $self->{'parentcache'}{$token};
    }
    else
    {
        my $parent = $self->{'db_dsconfig'}->get( 'p:'.$token );
        $self->{'parentcache'}{$token} = $parent;
        return $parent;
    }
}


sub getChildren
{
    my $self = shift;
    my $token = shift;

    if( (my $alias = $self->isAlias($token)) )
    {
        return $self->getChildren($alias);
    }
    else
    {
        return $self->{'db_dsconfig'}->getListItems( 'c:'.$token );
    }
}

sub getParamProperty
{
    my $self = shift;
    my $param = shift;
    my $prop = shift;

    return $self->{'paramprop'}{$prop}{$param};
}


sub getParamProperties
{
    my $self = shift;

    return $self->{'paramprop'};
}

# Recognize the regexp patterns within a path,
# like /Netflow/Exporters/.*/.*/bps.
# Each pattern is applied against direct child names only.
#
sub getNodesByPattern
{
    my $self = shift;
    my $pattern = shift;

    if( $pattern !~ /^\//o )
    {
        Error("Incorrect pattern: $pattern");
        return undef;
    }

    my @retlist = ();
    foreach my $nodepattern ( $self->splitPath($pattern) )
    {
        my @next_retlist = ();

        # Cut the trailing slash, if any
        my $patternname = $nodepattern;
        $patternname =~ s/\/$//o;

        if( $patternname =~ /\W/o )
        {
            foreach my $candidate ( @retlist )
            {
                # This is a pattern, let's get all matching children
                foreach my $child ( $self->getChildren( $candidate ) )
                {
                    # Cut the trailing slash and leading path
                    my $childname = $self->path($child);
                    $childname =~ s/\/$//o;
                    $childname =~ s/.*\/([^\/]+)$/$1/o;
                    if( $childname =~ $patternname )
                    {
                        push( @next_retlist, $child );
                    }
                }
            }

        }
        elsif( length($patternname) == 0 )
        {
            @next_retlist = ( $self->token('/') );
        }
        else
        {
            foreach my $candidate ( @retlist )
            {
                my $proposal = $self->path($candidate).$nodepattern;
                if( defined( my $proptoken = $self->token($proposal) ) )
                {
                    push( @next_retlist, $proptoken );
                }
            }
        }
        @retlist = @next_retlist;
    }
    return @retlist;
}

#
# Recognizes absolute or relative path, '..' as the parent subtree
#
sub getRelative
{
    my $self = shift;
    my $token = shift;
    my $relPath = shift;

    if( $relPath =~ /^\//o )
    {
        return $self->token( $relPath );
    }
    else
    {
        if( length( $relPath ) > 0 )
        {
            $token = $self->getParent( $token );
        }

        while( length( $relPath ) > 0 )
        {
            if( $relPath =~ /^\.\.\//o )
            {
                $relPath =~ s/^\.\.\///o;
                if( $token ne $self->token('/') )
                {
                    $token = $self->getParent( $token );
                }
            }
            else
            {
                my $childName;
                $relPath =~ s/^([^\/]*\/?)//o; $childName = $1;
                my $path = $self->path( $token );
                $token = $self->token( $path . $childName );
                if( not defined $token )
                {
                    return undef;
                }
            }
        }
        return $token;
    }
}


sub getNodeByNodeid
{
    my $self = shift;
    my $nodeid = shift;

    return $self->{'db_nodeid'}->get( $nodeid );
}

# Returns arrayref or undef.
# Each element is an arrayref to [nodeid, token] pair
sub searchNodeidPrefix
{
    my $self = shift;
    my $prefix = shift;

    return $self->{'db_nodeid'}->searchPrefix( $prefix );
}


# Returns arrayref or undef.
# Each element is an arrayref to [nodeid, token] pair
sub searchNodeidSubstring
{
    my $self = shift;
    my $substring = shift;

    return $self->{'db_nodeid'}->searchSubstring( $substring );
}



sub getDefaultView
{
    my $self = shift;
    my $token = shift;

    my $view;
    if( $self->isTset($token) )
    {
        if( $token eq 'SS' )
        {
            $view = $self->getParam('SS', 'default-tsetlist-view');
        }
        else
        {
            $view = $self->getParam($token, 'default-tset-view');
            if( not defined( $view ) )
            {
                $view = $self->getParam('SS', 'default-tset-view');
            }
        }
    }
    elsif( $self->isSubtree($token) )
    {
        $view = $self->getNodeParam($token, 'default-subtree-view');
    }
    else
    {
        # This must be leaf
        $view = $self->getNodeParam($token, 'default-leaf-view');
    }

    if( not defined( $view ) )
    {
        Error("Cannot find default view for $token");
    }
    return $view;
}


sub getInstanceParam
{
    my $self = shift;
    my $type = shift;
    my $name = shift;
    my $param = shift;

    if( $type eq 'node' )
    {
        return $self->getNodeParam($name, $param);
    }
    else
    {
        return $self->getParam($name, $param);
    }
}


sub getViewNames
{
    my $self = shift;
    return $self->{'db_otherconfig'}->getListItems( 'V:' );
}


sub viewExists
{
    my $self = shift;
    my $vname = shift;
    return $self->searchOtherList('V:', $vname);
}


sub getMonitorNames
{
    my $self = shift;
    return $self->{'db_otherconfig'}->getListItems( 'M:' );
}

sub monitorExists
{
    my $self = shift;
    my $mname = shift;
    return $self->searchOtherList('M:', $mname);
}


sub getActionNames
{
    my $self = shift;
    return $self->{'db_otherconfig'}->getListItems( 'A:' );
}


sub actionExists
{
    my $self = shift;
    my $mname = shift;
    return $self->searchOtherList('A:', $mname);
}


# Search for a value in comma-separated list
sub searchOtherList
{
    my $self = shift;
    my $key = shift;
    my $name = shift;

    return $self->{'db_otherconfig'}->searchList($key, $name);
}

# Token sets manipulation

sub isTset
{
    my $self = shift;
    my $token = shift;
    return substr($token, 0, 1) eq 'S';
}

sub addTset
{
    my $self = shift;
    my $tset = shift;
    $self->{'db_sets'}->addToList('S:', $tset);
}


sub tsetExists
{
    my $self = shift;
    my $tset = shift;
    return $self->{'db_sets'}->searchList('S:', $tset);
}

sub getTsets
{
    my $self = shift;
    return $self->{'db_sets'}->getListItems('S:');
}

sub tsetMembers
{
    my $self = shift;
    my $tset = shift;

    return $self->{'db_sets'}->getListItems('s:'.$tset);
}

sub tsetMemberOrigin
{
    my $self = shift;
    my $tset = shift;
    my $token = shift;
    
    return $self->{'db_sets'}->get('o:'.$tset.':'.$token);
}

sub tsetAddMember
{
    my $self = shift;
    my $tset = shift;
    my $token = shift;
    my $origin = shift;

    $self->{'db_sets'}->addToList('s:'.$tset, $token);
    $self->{'db_sets'}->put('o:'.$tset.':'.$token, $origin);
}


sub tsetDelMember
{
    my $self = shift;
    my $tset = shift;
    my $token = shift;

    $self->{'db_sets'}->delFromList('s:'.$tset, $token);
    $self->{'db_sets'}->del('o:'.$tset.':'.$token);
}

# Definitions manipulation

sub getDefinition
{
    my $self = shift;
    my $name = shift;
    return $self->{'db_dsconfig'}->get( 'd:'.$name );
}

sub getDefinitionNames
{
    my $self = shift;
    return $self->{'db_dsconfig'}->getListItems( 'D:' );
}


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
