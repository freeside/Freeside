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

# $Id: XMLCompiler.pm,v 1.1 2010-12-27 00:03:45 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


package Torrus::ConfigTree::XMLCompiler;

use Torrus::ConfigTree::Writer;
our @ISA=qw(Torrus::ConfigTree::Writer);

use Torrus::ConfigTree;
use Torrus::ConfigTree::Validator;
use Torrus::SiteConfig;
use Torrus::Log;
use Torrus::TimeStamp;

use XML::LibXML;
use strict;

sub new
{
    my $proto = shift;
    my %options = @_;
    my $class = ref($proto) || $proto;

    $options{'-Rebuild'} = 1;

    my $self  = $class->SUPER::new( %options );
    if( not defined( $self ) )
    {
        return undef;
    }

    bless $self, $class;

    if( $options{'-NoDSRebuild'} )
    {
        $self->{'-NoDSRebuild'} = 1;
    }

    $self->{'files_processed'} = {};

    return $self;
}


sub compile
{
    my $self = shift;
    my $filename = shift;

    &Torrus::DB::checkInterrupted();
    
    $filename = Torrus::SiteConfig::findXMLFile($filename);
    if( not defined( $filename ) )
    {
        return 0;
    }
                    
    # Make sure we process each file only once
    if( $self->{'files_processed'}{$filename} )
    {
        return 1;
    }
    else
    {
        $self->{'files_processed'}{$filename} = 1;
    }

    Verbose('Compiling ' . $filename);

    my $ok = 1;
    my $parser = new XML::LibXML;
    my $doc;
    eval { $doc = $parser->parse_file( $filename );  };
    if( $@ )
    {
        Error("Failed to parse $filename: $@");
        return 0;
    }

    my $root = $doc->documentElement();

    # Initialize the '/' element
    $self->initRoot();

    my $node;

    # First of all process all pre-required files
    foreach $node ( $root->getElementsByTagName('include') )
    {
        my $incfile = $node->getAttribute('filename');
        if( not $incfile )
        {
            Error("No filename given in include statement in $filename");
            $ok = 0;
        }
        else
        {
            $ok = $self->compile( $incfile ) ? $ok:0;
        }
    }

    foreach $node ( $root->getElementsByTagName('param-properties') )
    {
        $ok = $self->compile_paramprops( $node ) ? $ok:0;
    }

    if( not $self->{'-NoDSRebuild'} )
    {
        foreach $node ( $root->getElementsByTagName('definitions') )
        {
            $ok = $self->compile_definitions( $node ) ? $ok:0;
        }

        foreach $node ( $root->getElementsByTagName('datasources') )
        {
            $ok = $self->compile_ds( $node ) ? $ok:0;
        }
    }

    foreach $node ( $root->getElementsByTagName('monitors') )
    {
        $ok = $self->compile_monitors( $node ) ? $ok:0;
    }

    foreach $node ( $root->getElementsByTagName('token-sets') )
    {
        $ok = $self->compile_tokensets( $node ) ? $ok:0;
    }

    foreach $node ( $root->getElementsByTagName('views') )
    {
        $ok = $self->compile_views( $node ) ? $ok:0;
    }

    return $ok;
}


sub compile_definitions
{
    my $self = shift;
    my $node = shift;
    my $ok = 1;

    foreach my $def ( $node->getChildrenByTagName('def') )
    {
        &Torrus::DB::checkInterrupted();
        
        my $name = $def->getAttribute('name');
        my $value = $def->getAttribute('value');
        if( not $name )
        {
            Error("Definition without a name"); $ok = 0;
        }
        elsif( not $value )
        {
            Error("Definition without value: $name"); $ok = 0;
        }
        elsif( defined $self->getDefinition($name) )
        {
            Error("Duplicate definition: $name"); $ok = 0;
        }
        else
        {
            $self->addDefinition($name, $value);
        }
    }
    return $ok;
}


sub compile_paramprops
{
    my $self = shift;
    my $node = shift;
    my $ok = 1;

    foreach my $def ( $node->getChildrenByTagName('prop') )
    {
        &Torrus::DB::checkInterrupted();
          
        my $param = $def->getAttribute('param'); 
        my $prop = $def->getAttribute('prop');
        my $value = $def->getAttribute('value');
        if( not $param or not $prop or not defined($value) )
        {
            Error("Property definition error"); $ok = 0;
        }
        else
        {
            $self->setParamProperty($param, $prop, $value);
        }
    }
    return $ok;
}



# Process <param name="name" value="value"/> and put them into DB.
# Usage: $self->compile_params($node, $name);

sub compile_params
{
    my $self = shift;
    my $node = shift;
    my $name = shift;
    my $isDS = shift;

    &Torrus::DB::checkInterrupted();
          
    my $ok = 1;
    foreach my $p_node ( $node->getChildrenByTagName('param') )
    {
        my $param = $p_node->getAttribute('name');
        my $value = $p_node->getAttribute('value');
        if( not defined($value) )
        {
            $value = $p_node->textContent();
        }
        if( not $param )
        {
            Error("Parameter without name in $name"); $ok = 0;
        }
        else
        {
            # Remove spaces in the head and tail.
            $value =~ s/^\s+//om;
            $value =~ s/\s+$//om;

            if( $isDS )
            {
                $self->setNodeParam($name, $param, $value);
            }
            else
            {
                $self->setParam($name, $param, $value);
            }
        }
    }
    return $ok;
}


sub compile_ds
{
    my $self = shift;
    my $ds_node = shift;
    my $ok = 1;

    # First, process templates. We expect them to be direct children of
    # <datasources>

    foreach my $template ( $ds_node->getChildrenByTagName('template') )
    {
        my $name = $template->getAttribute('name');
        if( not $name )
        {
            Error("Template without a name"); $ok = 0;
        }
        elsif( defined $self->{'Templates'}->{$name} )
        {
            Error("Duplicate template names: $name"); $ok = 0;
        }
        else
        {
            $self->{'Templates'}->{$name} = $template;
        }
    }

    # Recursively traverse the tree
    $ok = $self->compile_subtrees( $ds_node, $self->token('/') ) ? $ok:0;

    return $ok;
}




sub validate_nodename
{
    my $self = shift;
    my $name = shift;

    return ( $name =~ /^[0-9A-Za-z_\-\.\:]+$/o and
             $name !~ /\.\./o );
}

sub compile_subtrees
{
    my $self = shift;
    my $node = shift;
    my $token = shift;
    my $iamLeaf = shift;
    
    my $ok = 1;

    # Apply templates

    foreach my $templateapp ( $node->getChildrenByTagName('apply-template') )
    {
        my $name = $templateapp->getAttribute('name');
        if( not $name )
        {
            my $path = $self->path($token);
            Error("Template application without a name at $path"); $ok = 0;
        }
        else
        {
            my $template = $self->{'Templates'}->{$name};
            if( not defined $template )
            {
                my $path = $self->path($token);
                Error("Cannot find template named $name at $path"); $ok = 0;
            }
            else
            {
                $ok = $self->compile_subtrees
                    ($template, $token, $iamLeaf) ? $ok:0;
            }
        }
    }

    $ok = $self->compile_params($node, $token, 1);

    # Handle aliases -- we are still in compile_subtrees()

    foreach my $alias ( $node->getChildrenByTagName('alias') )
    {
        my $apath = $alias->textContent();
        $apath =~ s/\s+//mgo;
        $ok = $self->setAlias($token, $apath) ? $ok:0;
    }

    foreach my $setvar ( $node->getChildrenByTagName('setvar') )        
    {
        my $name = $setvar->getAttribute('name');
        my $value = $setvar->getAttribute('value');
        if( not defined( $name ) or not defined( $value ) )
        {
            my $path = $self->path($token);
            Error("Setvar statement without name or value in $path"); $ok = 0;
        }
        else
        {
            $self->setVar( $token, $name, $value );
        }
    }

    # Compile-time variables
    
    foreach my $iftrue ( $node->getChildrenByTagName('iftrue') )        
    {
        my $var = $iftrue->getAttribute('var');
        if( not defined( $var ) )
        {
            my $path = $self->path($token);
            Error("Iftrue statement without variable name in $path"); $ok = 0;
        }
        elsif( $self->isTrueVar( $token, $var ) )
        {
            $ok = $self->compile_subtrees( $iftrue, $token, $iamLeaf ) ? $ok:0;
        }
    }

    foreach my $iffalse ( $node->getChildrenByTagName('iffalse') )        
    {
        my $var = $iffalse->getAttribute('var');
        if( not defined( $var ) )
        {
            my $path = $self->path($token);
            Error("Iffalse statement without variable name in $path"); $ok = 0;
        }
        elsif( not $self->isTrueVar( $token, $var ) )
        {
            $ok = $self->compile_subtrees
                ( $iffalse, $token, $iamLeaf ) ? $ok:0;
        }
    }

    
    # Compile child nodes -- the last part of compile_subtrees()

    if( not $iamLeaf )
    {
        foreach my $subtree ( $node->getChildrenByTagName('subtree') )
        {
            my $name = $subtree->getAttribute('name');
            if( not defined( $name ) or length( $name ) == 0 )
            {
                my $path = $self->path($token);
                Error("Subtree without a name at $path"); $ok = 0;
            }
            else
            {
                if( $self->validate_nodename( $name ) )
                {
                    my $stoken = $self->addChild($token, $name.'/');
                    $ok = $self->compile_subtrees( $subtree, $stoken ) ? $ok:0;
                }
                else
                {
                    my $path = $self->path($token);
                    Error("Invalid subtree name: $name at $path"); $ok = 0;
                }
            }
        }

        foreach my $leaf ( $node->getChildrenByTagName('leaf') )
        {
            my $name = $leaf->getAttribute('name');
            if( not defined( $name ) or length( $name ) == 0 )
            {
                my $path = $self->path($token);
                Error("Leaf without a name at $path"); $ok = 0;
            }
            else
            {
                if( $self->validate_nodename( $name ) )
                {
                    my $ltoken = $self->addChild($token, $name);
                    $ok = $self->compile_subtrees( $leaf, $ltoken, 1 ) ? $ok:0;
                }
                else
                {
                    my $path = $self->path($token);
                    Error("Invalid leaf name: $name at $path"); $ok = 0;
                }
            }
        }
    }
    return $ok;
}


sub compile_monitors
{
    my $self = shift;
    my $mon_node = shift;
    my $ok = 1;

    foreach my $monitor ( $mon_node->getChildrenByTagName('monitor') )
    {
        my $mname = $monitor->getAttribute('name');
        if( not $mname )
        {
            Error("Monitor without a name"); $ok = 0;
        }
        else
        {
            $ok = $self->addMonitor( $mname );
            $ok = $self->compile_params($monitor, $mname) ? $ok:0;
        }
    }

    foreach my $action ( $mon_node->getChildrenByTagName('action') )
    {
        my $aname = $action->getAttribute('name');
        if( not $aname )
        {
            Error("Action without a name"); $ok = 0;
        }
        else
        {
            $self->addAction( $aname );
            $ok = $self->compile_params($action, $aname);
        }
    }
    return $ok;
}


sub compile_tokensets
{
    my $self = shift;
    my $tsets_node = shift;
    my $ok = 1;

    $ok = $self->compile_params($tsets_node, 'SS') ? $ok:0;

    foreach my $tokenset ( $tsets_node->getChildrenByTagName('token-set') )
    {
        my $sname = $tokenset->getAttribute('name');
        if( not $sname )
        {
            Error("Token-set without a name"); $ok = 0;
        }
        else
        {
            $sname = 'S'. $sname;
            $ok = $self->addTset( $sname );
            $ok = $self->compile_params($tokenset, $sname) ? $ok:0;
        }
    }
    return $ok;
}


sub compile_views
{
    my $self = shift;
    my $vw_node = shift;
    my $parentname = shift;
    my $ok = 1;

    foreach my $view ( $vw_node->getChildrenByTagName('view') )
    {
        my $vname = $view->getAttribute('name');
        if( not $vname )
        {
            Error("View without a name"); $ok = 0;
        }
        else
        {
            $self->addView( $vname, $parentname );
            $ok = $self->compile_params( $view, $vname ) ? $ok:0;
            # Process child views
            $ok = $self->compile_views( $view, $vname ) ? $ok:0;
        }
    }
    return $ok;
}



1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
