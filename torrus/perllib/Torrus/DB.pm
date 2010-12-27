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

# $Id: DB.pm,v 1.1 2010-12-27 00:03:39 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

package Torrus::DB;

use Torrus::Log;
use BerkeleyDB;
use strict;


# This is an abstraction layer for BerkeleyDB database operations
#
# Database opening:
#    my $db = new Torrus::DB('db_name',
#                          [ -Btree => 1, ]
#                          [ -WriteAccess => 1, ]
#                          [ -Truncate    => 1, ]
#                          [ -Subdir      => 'dirname' ]);
#    Defaults: Hash, read-only, no truncate.
#
# Database closing:
#    undef $db;
#
# Database cleaning:
#    $status = $db->trunc();
#

END
{
    &Torrus::DB::cleanupEnvironment();
}

sub new
{
    my $self = {};
    my $class = shift;
    my $dbname = shift;
    my %options = @_;
    bless $self, $class;

    if( not defined($Torrus::DB::env) )
    {
        if( not defined $Torrus::Global::dbHome )
        {
            Error('$Torrus::Global::dbHome must be defined ' .
                  'in torrus_config.pl');
            return undef;
        }
        elsif( not -d $Torrus::Global::dbHome )
        {
            Error("No such directory: $Torrus::Global::dbHome" );
            return undef;
        }
        else
        {
            $Torrus::DB::dbEnvErrFile =
                $Torrus::Global::logDir . '/dbenv_errlog_' . $$;
            
            Debug("Creating BerkeleyDB::Env");
            umask 0002;
            $Torrus::DB::env =
                new BerkeleyDB::Env(-Home  => $Torrus::Global::dbHome,
                                    -Flags => (DB_CREATE |
                                               DB_INIT_CDB | DB_INIT_MPOOL),
                                    -Mode  => 0664,
                                    -ErrFile => $Torrus::DB::dbEnvErrFile);
            if( not defined($Torrus::DB::env) )
            {
                Error("Cannot create BerkeleyDB Environment: ".
                      $BerkeleyDB::Error);
                return undef;
            }
        }
    }

    my $filename = $dbname.'.db';

    if( $options{'-Subdir'} )
    {
        my $dirname = $Torrus::Global::dbHome . '/' . $Torrus::DB::dbSub;
        if( not -d $dirname and not mkdir( $dirname ) )
        {
            Error("Cannot create directory $dirname: $!");
            return undef;
        }
        $dirname .= '/' . $options{'-Subdir'};
        if( not -d $dirname and not mkdir( $dirname ) )
        {
            Error("Cannot create directory $dirname: $!");
            return undef;
        }
        $filename =
            $Torrus::DB::dbSub . '/' . $options{'-Subdir'} . '/' . $filename;
    }

    # we need this in DESTROY debug message
    $self->{'dbname'} = $filename;

    my %hash;

    my $accmethod = $options{'-Btree'} ?
        'BerkeleyDB::Btree':'BerkeleyDB::Hash';

    my $flags = DB_RDONLY;

    if( $options{'-WriteAccess'} )
    {
        $flags = DB_CREATE;
    }

    my $property = 0;
    if( $options{'-Duplicates'} )
    {
        $property = DB_DUP | DB_DUPSORT;
    }
        
    if( not exists( $Torrus::DB::dbPool{$filename} ) )
    {
        Debug('Opening ' . $self->{'dbname'});

        my $dbh = new $accmethod (
                                  -Filename => $filename,
                                  -Flags    => $flags,
                                  -Property => $property,
                                  -Mode     => 0664,
                                  -Env      => $Torrus::DB::env );
        if( not $dbh )
        {
            Error("Cannot open database $filename: $! $BerkeleyDB::Error");
            return undef;
        }

        $Torrus::DB::dbPool{$filename} = { 'dbh'        => $dbh,
                                           'accmethod'  => $accmethod,
                                           'flags'      => $flags };

        $self->{'dbh'} = $dbh;
    }
    else
    {
        my $ref = $Torrus::DB::dbPool{$filename};
        if( $ref->{'accmethod'} eq $accmethod and $ref->{'flags'} eq $flags )
        {
            $self->{'dbh'} = $ref->{'dbh'};
        }
        else
        {
            Error('Database in dbPool has different flags: ' .
                  $self->{'dbname'});
            return undef;
        }
    }

    if( $options{'-Truncate'} )
    {
        $self->trunc();
    }

    if( $options{'-Delayed'} )
    {
        $self->{'delay_list_commit'} = 1;
    }

    return $self;
}


# It is strongly inadvisable to do anything inside a signal handler when DB
# operation is in progress

our $interrupted = 0;

my $signalHandlersSet = 0;
my $safeSignals = 0;





sub setSignalHandlers
{
    if( $signalHandlersSet )
    {
        return;
    }
    
    $SIG{'TERM'} = sub {
        if( $safeSignals )
        {
            Warn('Received SIGTERM. Scheduling to exit.');
            $interrupted = 1;
        }
        else
        {
            Warn('Received SIGTERM. Stopping the process.');
            exit(1);
        }            
    };

    $SIG{'INT'} = sub {
        if( $safeSignals )
        {
            Warn('Received SIGINT. Scheduling to exit.');
            $interrupted = 1;
        }
        else
        {
            Warn('Received SIGINT. Stopping the process');
            exit(1);
        }            
    };
    

    $SIG{'PIPE'} = sub {
        if( $safeSignals )
        {
            Warn('Received SIGPIPE. Scheduling to exit.');
            $interrupted = 1;
        }
        else
        {
            Warn('Received SIGPIPE. Stopping the process');
            exit(1);
        }            
    };
    
    $SIG{'QUIT'} = sub {
        if( $safeSignals )
        {
            Warn('Received SIGQUIT. Scheduling to exit.');
            $interrupted = 1;
        }
        else
        {
            Warn('Received SIGQUIT. Stopping the process');
            exit(1);
        }            
    };

    $signalHandlersSet = 1;
}


sub setSafeSignalHandlers
{
    setSignalHandlers();
    $safeSignals = 1;
}


sub setUnsafeSignalHandlers
{
    setSignalHandlers();
    $safeSignals = 0;
}
    

# If we were previously interrupted, gracefully exit now

sub checkInterrupted
{
    if( $interrupted )
    {
        Warn('Stopping the process');
        exit(1);
    }
}



sub closeNow
{
    my $self = shift;

    my $filename = $self->{'dbname'};
    Debug('Explicitly closing ' . $filename);
    delete $Torrus::DB::dbPool{$filename};
    $self->{'dbh'}->db_close();
    delete $self->{'dbh'};
}

sub cleanupEnvironment
{
    if( defined( $Torrus::DB::env ) )
    {
        foreach my $filename ( sort keys %Torrus::DB::dbPool )
        {
            Debug('Closing ' . $filename);
            $Torrus::DB::dbPool{$filename}->{'dbh'}->db_close();
            delete $Torrus::DB::dbPool{$filename};
        }
        
        Debug("Destroying BerkeleyDB::Env");
        $Torrus::DB::env->close();
        $Torrus::DB::env = undef;

        if( -z $Torrus::DB::dbEnvErrFile )
        {
            unlink $Torrus::DB::dbEnvErrFile;
        }
    }
}


sub delay
{
    my $self = shift;
    $self->{'delay_list_commit'} = 1;
}

    

sub trunc
{
    my $self = shift;

    Debug('Truncating ' . $self->{'dbname'});
    my $count = 0;
    return $self->{'dbh'}->truncate($count) == 0;
}


sub put
{
    my $self = shift;
    my $key = shift;
    my $val = shift;

    ref( $self->{'dbh'} ) or die( 'Fatal error: ' . $self->{'dbname'} );
    return $self->{'dbh'}->db_put($key, $val) == 0;
}

sub get
{
    my $self = shift;
    my $key = shift;
    my $val = undef;

    $self->{'dbh'}->db_get($key, $val);
    return $val;
}


sub del
{
    my $self = shift;
    my $key = shift;
    my $val = undef;

    return $self->{'dbh'}->db_del($key) == 0;
}


sub cursor
{
    my $self = shift;
    my %options = @_;
    
    return $self->{'dbh'}->db_cursor( $options{'-Write'} ? DB_WRITECURSOR:0 );
}


sub next
{
    my $self = shift;
    my $cursor = shift;
    my $key = '';
    my $val = '';

    if( $cursor->c_get($key, $val, DB_NEXT) == 0 )
    {
        return ($key, $val);
    }
    else
    {
        return ();
    }
}

sub c_del
{
    my $self = shift;
    my $cursor = shift;

    my $cnt = 0;
    $cursor->c_del( $cnt );
}


sub c_get
{
    my $self = shift;
    my $cursor = shift;
    my $key = shift;
    my $val = undef;

    if( $cursor->c_get( $key, $val, DB_SET ) == 0 )
    {
        return $val;
    }
    else
    {
        return undef;
    }
}

sub c_put
{
    my $self = shift;
    my $cursor = shift;
    my $key = shift;
    my $val = shift;

    return ( $cursor->c_put( $key, $val, DB_KEYFIRST ) == 0 );
}



# Btree best match. We assume that the searchKey is longer or equal
# than the matched key in the database.
#
# If none found, returns undef.
# If found, returns a hash with keys
# "exact" => true when exact match found
# "key"   => key as is stored in the database
# "value" => value from the matched database entry
# The found key is shorter or equal than searchKey, and is a prefix
# of the searchKey

sub getBestMatch
{
    my $self = shift;
    my $searchKey = shift;

    my $key = $searchKey;
    my $searchLen = length( $searchKey );
    my $val = '';
    my $ret = {};
    my $ok = 0;

    my $cursor = $self->{'dbh'}->db_cursor();

    if( $cursor->c_get( $key, $val, DB_SET_RANGE ) == 0 )
    {
        if( $key eq $searchKey )
        {
            $ok = 1;
            $ret->{'exact'} = 1;
        }
        else
        {
            # the returned key/data pair is the smallest data item greater
            # than or equal to the specified data item.
            # The previous entry should be what we search for.
            if( $cursor->c_get( $key, $val, DB_PREV ) == 0 )
            {
                if( length( $key ) < $searchLen and
                    index( $searchKey, $key ) == 0 )
                {
                    $ok = 1;
                    $ret->{'key'} = $key;
                    $ret->{'value'} = $val;
                }
            }
        }
    }
    else
    {
        if ( $cursor->c_get( $key, $val, DB_LAST ) == 0 )
        {
            if( length( $key ) < $searchLen and
                index( $searchKey, $key ) == 0 )
            {
                $ok = 1;
                $ret->{'key'} = $key;
                $ret->{'value'} = $val;
            }
        }
    }

    return( $ok ? $ret : undef );
}


# Search the keys that match the specified prefix.
# Return value is an array of [key,val] pairs or undef
# Returned keys may be duplicated if the DB is created with -Duplicates

sub searchPrefix
{
    my $self = shift;
    my $prefix = shift;

    my $ret = [];
    my $ok = 0;

    my $key = $prefix;
    my $val = '';

    my $cursor = $self->{'dbh'}->db_cursor();

    if( $cursor->c_get( $key, $val, DB_SET_RANGE ) == 0 )
    {
        # the returned key/data pair is the smallest data item greater
        # than or equal to the specified data item.
        my $finished = 0;
        while( not $finished )
        {
            if( index( $key, $prefix ) == 0 )
            {
                $ok = 1;
                push( @{$ret}, [ $key, $val ] );

                if( $cursor->c_get($key, $val, DB_NEXT) != 0 )
                {
                    $finished = 1;
                }
            }
            else
            {
                $finished = 1;
            }
        }
    }

    undef $cursor;

    return( $ok ? $ret : undef );    
}
    

# Search the keys that match the specified substring.
# Return value is an array of [key,val] pairs or undef
# Returned keys may be duplicated if the DB is created with -Duplicates

sub searchSubstring
{
    my $self = shift;
    my $substring = shift;

    my $ret = [];
    my $ok = 0;

    my $key = '';
    my $val = '';

    my $cursor = $self->{'dbh'}->db_cursor();

    while( $cursor->c_get($key, $val, DB_NEXT) == 0 )
    {
        if( index( $key, $substring ) >= 0 )
        {
            $ok = 1;
            push( @{$ret}, [ $key, $val ] );
        }
    }
    
    undef $cursor;
    
    return( $ok ? $ret : undef );    
}
    




# Comma-separated list manipulation

sub _populateListCache
{
    my $self = shift;
    my $key = shift;

    if( not exists( $self->{'listcache'}{$key} ) )
    {
        my $ref = {};        
        my $values = $self->get($key);
        if( defined( $values ) )
        {
            foreach my $val (split(/,/o, $values))
            {
                $ref->{$val} = 1;
            }
        }
        $self->{'listcache'}{$key} = $ref;
    }
}


sub _storeListCache
{
    my $self = shift;
    my $key = shift;

    if( not $self->{'delay_list_commit'} )
    {
        $self->put($key, join(',', keys %{$self->{'listcache'}{$key}}));
    }
}

    
sub addToList
{
    my $self = shift;
    my $key = shift;
    my $newval = shift;

    $self->_populateListCache($key);
    
    $self->{'listcache'}{$key}{$newval} = 1;
    
    $self->_storeListCache($key);
}


sub searchList
{
    my $self = shift;
    my $key = shift;
    my $name = shift;

    $self->_populateListCache($key);
    return $self->{'listcache'}{$key}{$name};
}


sub delFromList
{
    my $self = shift;
    my $key = shift;
    my $name = shift;

    $self->_populateListCache($key);
    if( $self->{'listcache'}{$key}{$name} )
    {
        delete $self->{'listcache'}{$key}{$name};
    }
    
    $self->_storeListCache($key);
}


sub getListItems
{
    my $self = shift;
    my $key = shift;

    $self->_populateListCache($key);
    return keys %{$self->{'listcache'}{$key}};
}

    

sub deleteList
{
    my $self = shift;
    my $key = shift;

    delete $self->{'listcache'}{$key};
    $self->del($key);
}


sub commit
{
    my $self = shift;
    
    if( $self->{'delay_list_commit'} and
        defined( $self->{'listcache'} ) )
    {
        while( my($key, $list) = each %{$self->{'listcache'}} )
        {
            $self->put($key, join(',', keys %{$list}));
        }
    }
}
            


1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
