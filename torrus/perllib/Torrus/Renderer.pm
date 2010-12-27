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

# $Id: Renderer.pm,v 1.2 2010-12-27 08:40:19 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::Renderer;

use strict;
use Digest::MD5 qw(md5_hex);

use Torrus::DB;
use Torrus::ConfigTree;
use Torrus::TimeStamp;
use Torrus::RPN;
use Torrus::Log;
use Torrus::SiteConfig;

use Torrus::Renderer::HTML;
use Torrus::Renderer::RRDtool;

# Inherit methods from these modules
use base qw(Torrus::Renderer::HTML
            Torrus::Renderer::RRDtool
            Torrus::Renderer::Frontpage
            Torrus::Renderer::AdmInfo
            Torrus::Renderer::Freeside
           );

sub new
{
    my $self = {};
    my $class = shift;
    bless $self, $class;

    if( not defined $Torrus::Global::cacheDir )
    {
        Error('$Torrus::Global::cacheDir must be defined');
        return undef;
    }
    elsif( not -d $Torrus::Global::cacheDir )
    {
        Error("No such directory: $Torrus::Global::cacheDir");
        return undef;
    }

    $self->{'db'} = new Torrus::DB('render_cache', -WriteAccess => 1);
    if( not defined( $self->{'db'} ) )
    {
        return undef;
    }

    srand( time() * $$ );
    
    return $self;
}


# Returns the absolute filename and MIME type:
#
# my($fname, $mimetype) = $renderer->render($config_tree, $token, $view);
#

sub render
{
    my $self = shift;
    my $config_tree = shift;
    my $token = shift;
    my $view = shift;
    my %new_options = @_;

    # If no options given, preserve the existing ones
    if( %new_options )
    {
        $self->{'options'} = \%new_options;
    }

    $self->checkAndClearCache( $config_tree );

    my($t_render, $t_expires, $filename, $mime_type);

    my $tree = $config_tree->treeName();

    if( not $config_tree->isTset($token) )
    {
        if( my $alias = $config_tree->isAlias($token) )
        {
            $token = $alias;
        }
        if( not defined( $config_tree->path($token) ) )
        {
            Error("No such token: $token");
            return undef;
        }
    }

    $view = $config_tree->getDefaultView($token) unless defined $view;

    my $uid = '';
    if( $self->{'options'}->{'uid'} )
    {
        $uid = $self->{'options'}->{'uid'};
    }

    my $cachekey = $self->cacheKey( $uid . ':' . $tree . ':' .
                                    $token . ':' . $view );

    ($t_render, $t_expires, $filename, $mime_type) =
        $self->getCache( $cachekey );

    my $not_in_cache = 0;
    
    if( not defined( $filename ) )
    {
        $filename = Torrus::Renderer::newCacheFileName( $cachekey );
        $not_in_cache = 1;
    }

    my $cachefile = $Torrus::Global::cacheDir.'/'.$filename;

    if( ( not $not_in_cache ) and
        -f $cachefile and
        $t_expires >= time() )
    {
        return ($cachefile, $mime_type, $t_expires - time());
    }

    my $method = 'render_' . $config_tree->getParam($view, 'view-type');

    ($t_expires, $mime_type) =
        $self->$method( $config_tree, $token, $view, $cachefile );

    if( %new_options )
    {
        $self->{'options'} = undef;
    }

    my @ret;
    if( defined($t_expires) and defined($mime_type) )
    {
        $self->setCache($cachekey, time(), $t_expires, $filename, $mime_type);
        @ret = ($cachefile, $mime_type, $t_expires - time());
    }

    return @ret;
}


sub cacheKey
{
    my $self = shift;
    my $keystring = shift;

    if( ref( $self->{'options'}->{'variables'} ) )
    {
        foreach my $name ( sort keys %{$self->{'options'}->{'variables'}} )
        {
            my $val = $self->{'options'}->{'variables'}->{$name};
            $keystring .= ':' . $name . '=' . $val;
        }
    }
    return $keystring;
}


sub getCache
{
    my $self = shift;
    my $keystring = shift;

    my $cacheval = $self->{'db'}->get( $keystring );

    if( defined($cacheval) )
    {
        return split(':', $cacheval);
    }
    else
    {
        return undef;
    }
}


sub setCache
{
    my $self = shift;
    my $keystring = shift;
    my $t_render = shift;
    my $t_expires = shift;
    my $filename = shift;
    my $mime_type = shift;

    $self->{'db'}->put( $keystring,
                        join(':',
                             ($t_render, $t_expires, $filename, $mime_type)));
}



sub checkAndClearCache
{
    my $self = shift;
    my $config_tree = shift;

    my $tree = $config_tree->treeName();

    Torrus::TimeStamp::init();
    my $known_ts = Torrus::TimeStamp::get($tree . ':renderer_cache');
    my $actual_ts = $config_tree->getTimestamp();
    if( $actual_ts >= $known_ts or
        time() >= $known_ts + $Torrus::Renderer::cacheMaxAge )
    {
        $self->clearcache();
        Torrus::TimeStamp::setNow($tree . ':renderer_cache');
    }
    Torrus::TimeStamp::release();
}


sub clearcache
{
    my $self = shift;

    Debug('Clearing renderer cache');
    my $cursor = $self->{'db'}->cursor( -Write => 1 );
    while( my ($key, $val) = $self->{'db'}->next( $cursor ) )
    {
        my($t_render, $t_expires, $filename, $mime_type) =  split(':', $val);

        unlink $Torrus::Global::cacheDir.'/'.$filename;
        $self->{'db'}->c_del( $cursor );
    }
    undef $cursor;
    Debug('Renderer cache cleared');
}


sub newCacheFileName
{
    my $cachekey = shift;
    return sprintf('%s_%.5d', md5_hex($cachekey), rand(1e5));
}

sub xmlnormalize
{
    my( $txt )= @_;

    # Remove spaces in the head and tail.
    $txt =~ s/^\s+//om;
    $txt =~ s/\s+$//om;

    # Unscreen special characters
    $txt =~ s/{COLON}/:/ogm;
    $txt =~ s/{SEMICOL}/;/ogm;
    $txt =~ s/{PERCENT}/%/ogm;

    $txt =~ s/\&/\&amp\;/ogm;
    $txt =~ s/\</\&lt\;/ogm;
    $txt =~ s/\>/\&gt\;/ogm;
    $txt =~ s/\'/\&apos\;/ogm;
    $txt =~ s/\"/\&quot\;/ogm;

    return $txt;
}



1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
