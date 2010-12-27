#  Copyright (C) 2010  Stanislav Sinyagin
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

# $Id: CGI.pm,v 1.1 2010-12-27 00:03:43 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Universal CGI handler for Apache mod_perl and FastCGI

package Torrus::CGI;

use strict;
use CGI;
use IO::File;

# This modue is not a part of mod_perl
use Apache::Session::File;


use Torrus::Log;
use Torrus::Renderer;
use Torrus::SiteConfig;
use Torrus::ACL;

## Torrus::CGI->process($q)
## Expects a CGI object as input

sub process
{
    my($class, $q) = @_;

    my $path_info = $q->url(-path => 1);

    # quickly give plaintext file contents
    {
        my $pos = index( $path_info, $Torrus::Renderer::plainURL );
        if( $pos >= 0 )
        {
            my $fname = $Torrus::Global::webPlainDir . '/' .
                substr( $path_info,
                        $pos + length($Torrus::Renderer::plainURL) );

            my $ok = 0;

            my $type;
            if( $path_info =~ /\.css$/o )
            {
                $type = 'text/css';
            }
            else
            {
                $type = 'text/html';
            }
            
            if( -r $fname )
            {
                my $fh = new IO::File( $fname );
                if( defined( $fh ) )
                {
                    print $q->header('-type' => $type,
                                     '-expires' => '+1h');
                    
                    $fh->binmode(':raw');
                    my $buffer;           
                    while( $fh->read( $buffer, 65536 ) )
                    {
                        print( $buffer );
                    }
                    $fh->close();
                    $ok = 1;
                }
            }

            if( not $ok )
            {
                print $q->header(-status=>400),
                $q->start_html('Error'),
                $q->h2('Error'),
                $q->strong('Cannot retrieve file: ' . $fname);
            }
            
            return;
        }
    }
    
    my @paramNames = $q->param();

    if( $q->param('DEBUG') and not $Torrus::Renderer::globalDebug ) 
    {
        &Torrus::Log::setLevel('debug');
    }

    my %options = ();
    foreach my $name ( @paramNames )
    {
        if( $name =~ /^[A-Z]/ and $name ne 'SESSION_ID' )
        {
            $options{'variables'}->{$name} = $q->param($name);
        }
    }

    my( $fname, $mimetype, $expires );
    my @cookies;

    my $renderer = new Torrus::Renderer();
    if( not defined( $renderer ) )
    {
        return report_error($q, 'Error initializing Renderer');
    }

    my $tree = $path_info;
    $tree =~ s/^.*\/(.*)$/$1/;

    if( $Torrus::CGI::authorizeUsers )
    {
        $options{'acl'} = new Torrus::ACL;
        
        my $hostauth = $q->param('hostauth');
        if( defined( $hostauth ) )
        {
            my $uid = $q->remote_addr();
            $uid =~ s/\W/_/go;
            my $password = $uid . '//' . $hostauth;

            Debug('Host-based authentication for ' . $uid);
            
            if( not $options{'acl'}->authenticateUser( $uid, $password ) )
            {
                print $q->header(-status=>'403 Forbidden',
                                 '-type' => 'text/plain');
                print('Host-based authentication failed for ' . $uid);
                Info('Host-based authentication failed for ' . $uid);
                return;
            }
            
            Info('Host authenticated: ' . $uid);
            $options{'uid'} = $uid;
        }
        else
        {
            
            my $ses_id = $q->cookie('SESSION_ID');

            my $needs_new_session = 1;
            my %session;

            if( $ses_id )
            {
                # create a session object based on the cookie we got from the
                # browser, or a new session if we got no cookie
                eval
                {
                    tie %session, 'Apache::Session::File', $ses_id, {
                        Directory     => $Torrus::Global::sesStoreDir,
                        LockDirectory => $Torrus::Global::sesLockDir }
                };
                if( not $@ )
                {
                    if( $options{'variables'}->{'LOGOUT'} )
                    {
                        tied( %session )->delete();
                    }
                    else
                    {
                        $needs_new_session = 0;
                    }
                }
            }

            if( $needs_new_session )
            {
                tie %session, 'Apache::Session::File', undef, {
                    Directory     => $Torrus::Global::sesStoreDir,
                    LockDirectory => $Torrus::Global::sesLockDir };
            }

            # might be a new session, so lets give them their cookie back

            my %cookie = (-name  => 'SESSION_ID',
                          -value => $session{'_session_id'});
            
            if( $session{'uid'} )
            {
                $options{'uid'} = $session{'uid'};
                if( $session{'remember_login'} )
                {
                    $cookie{'-expires'} = '+60d';
                }
            }
            else
            {
                my $needsLogin = 1;

                # POST form parameters

                my $uid = $q->param('uid');
                my $password = $q->param('password');
                if( defined( $uid ) and defined( $password ) )
                {
                    if( $options{'acl'}->authenticateUser( $uid, $password ) )
                    {
                        $session{'uid'} = $options{'uid'} = $uid;
                        $needsLogin = 0;
                        Info('User logged in: ' . $uid);
                        
                        if( $q->param('remember') )
                        {
                            $cookie{'-expires'} = '+60d';
                            $session{'remember_login'} = 1;
                        }
                    }
                    else
                    {
                        $options{'authFailed'} = 1;
                    }
                }

                if( $needsLogin )
                {
                    $options{'urlPassTree'} = $tree;
                    foreach my $param ( 'token', 'path', 'nodeid',
                                        'view', 'v' )
                    {
                        my $val = $q->param( $param );
                        if( defined( $val ) and length( $val ) > 0 )
                        {
                            $options{'urlPassParams'}{$param} = $val;
                        }
                    }
                    
                    ( $fname, $mimetype, $expires ) =
                        $renderer->renderUserLogin( %options );
                    
                    die('renderUserLogin returned undef') unless $fname;
                }
            }
            untie %session;
            
            push(@cookies, $q->cookie(%cookie));
        }
    }

    if( not $fname )
    {
        if( not $tree or not Torrus::SiteConfig::treeExists( $tree ) )
        {
            ( $fname, $mimetype, $expires ) =
                $renderer->renderTreeChooser( %options );
        }
        else
        {
            if( $Torrus::CGI::authorizeUsers and
                not $options{'acl'}->hasPrivilege( $options{'uid'}, $tree,
                                                   'DisplayTree' ) )
            {
                return report_error($q, 'Permission denied');
            }
            
            if( $Torrus::Renderer::displayReports and
                defined( $q->param('htmlreport') ) )
            {
                if( $Torrus::CGI::authorizeUsers and
                    not $options{'acl'}->hasPrivilege( $options{'uid'}, $tree,
                                                       'DisplayReports' ) )
                {
                    return report_error($q, 'Permission denied');
                }

                my $reportfname = $q->param('htmlreport');
                # strip off leading slashes for security
                $reportfname =~ s/^.*\///o;
                
                $fname = $Torrus::Global::reportsDir . '/' . $tree .
                    '/html/' . $reportfname;
                if( not -f $fname )
                {
                    return report_error($q, 'No such file: ' . $reportfname);
                }
                
                $mimetype = 'text/html';
                $expires = '3600';
            }
            else
            {
                my $config_tree = new Torrus::ConfigTree( -TreeName => $tree );
                if( not defined($config_tree) )
                {
                    return report_error($q, 'Configuration is not ready');
                }
                
                my $token = $q->param('token');
                if( not defined($token) )
                {
                    my $path = $q->param('path');
                    if( not defined($path) )
                    {
                        my $nodeid = $q->param('nodeid');
                        if( defined($nodeid) )
                        {
                            $token = $config_tree->getNodeByNodeid( $nodeid );
                            if( not defined($token) )
                            {
                                return report_error
                                    ($q, 'Cannot find nodeid:' . $nodeid);
                            }
                        }
                        else
                        {
                            $token = $config_tree->token('/');
                        }
                    }
                    else
                    {
                        $token = $config_tree->token($path);
                        if( not defined($token) )
                        {
                            return report_error($q, 'Invalid path');
                        }
                    }
                }
                elsif( $token !~ /^S/ and
                       not defined( $config_tree->path( $token ) ) )
                {
                    return report_error($q, 'Invalid token');
                }
                
                my $view = $q->param('view');
                if( not defined($view) )
                {
                    $view = $q->param('v');
                }

                ( $fname, $mimetype, $expires ) =
                    $renderer->render( $config_tree, $token, $view, %options );
                
                undef $config_tree;
            }
        }
    }

    undef $renderer;
    &Torrus::DB::cleanupEnvironment();

    if( defined( $options{'acl'} ) )
    {
        undef $options{'acl'};
    }

    if( defined($fname) )
    {
        if( not -e $fname )
        {
            return report_error($q, 'No such file or directory: ' . $fname);
        }
        
        Debug("Render returned $fname $mimetype $expires");

        my $fh = new IO::File( $fname );
        if( defined( $fh ) )
        {
            print $q->header('-type' => $mimetype,
                             '-expires' => '+'.$expires.'s',
                             '-cookie' => \@cookies);
            
            $fh->binmode(':raw');
            my $buffer;           
            while( $fh->read( $buffer, 65536 ) )
            {
                print( $buffer );
            }
            $fh->close();
        }
        else
        {
            return report_error($q, 'Cannot open file ' . $fname . ': ' . $!);
        }
    }
    else
    {
        return report_error($q, "Renderer returned error.\n" .
                            "Probably wrong directory permissions or " .
                            "directory missing:\n" .
                            $Torrus::Global::cacheDir);            
    }
    
    if( not $Torrus::Renderer::globalDebug )
    {
        &Torrus::Log::setLevel('info');
    }
}


sub report_error
{
    my $q = shift;
    my $msg = shift;

    print $q->header('-type' => 'text/plain',
                     '-expires' => 'now');

    print('Error: ' . $msg);
}


1;

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
