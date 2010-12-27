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

# $Id: Edit.pm,v 1.1 2010-12-27 00:03:59 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


package Torrus::ACL::Edit;

use Torrus::ACL;
use Torrus::Log;

use strict;

@Torrus::ACL::Edit::ISA = qw(Torrus::ACL);

sub new
{
    my $proto = shift;
    my %options = @_;
    my $class = ref($proto) || $proto;
    $options{'-WriteAccess'} = 1;
    my $self  = $class->SUPER::new( %options );
    bless $self, $class;
    return $self;
}


sub addGroups
{
    my $self = shift;
    my @groups = shift;

    my $ok = 1;
    foreach my $group ( @groups )
    {
        if( length( $group ) == 0 or $group =~ /\W/ )
        {
            Error('Invalid group name: ' . $group);
            $ok = 0;
        }
        elsif( $self->groupExists( $group ) )
        {
            Error('Cannot add group ' . $group . ': the group already exists');
            $ok = 0;
        }
        else
        {
            $self->{'db_users'}->addToList( 'G:', $group );
            $self->setGroupModified( $group );
            Info('Group added: ' . $group);
        }
    }
    return $ok;
}

sub deleteGroups
{
    my $self = shift;
    my @groups = shift;

    my $ok = 1;
    foreach my $group ( @groups )
    {
        if( $self->groupExists( $group ) )
        {
            my $members = $self->listGroupMembers( $group );
            foreach my $uid ( @{$members} )
            {
                $self->{'db_users'}->delFromList( 'gm:' . $uid, $group );
            }
            $self->{'db_users'}->delFromList( 'G:', $group );

            my $cursor = $self->{'db_acl'}->cursor( -Write => 1 );
            while( my ($key, $val) = $self->{'db_acl'}->next( $cursor ) )
            {
                my( $dbgroup, $object, $privilege ) = split( ':', $key );
                if( $dbgroup eq $group )
                {
                    $self->{'db_acl'}->c_del( $cursor );
                }
            }
            undef $cursor;

            Info('Group deleted: ' . $group);
        }
        else
        {
            Error('Cannot delete group ' . $group .
                  ': the group does not exist');
            $ok = 0;
        }
    }
    return $ok;
}

sub groupExists
{
    my $self = shift;
    my $group = shift;

    return $self->{'db_users'}->searchList( 'G:', $group );
}


sub listGroups
{
    my $self = shift;

    my $list = $self->{'db_users'}->get( 'G:' );

    return split( ',', $list );
}


sub listGroupMembers
{
    my $self = shift;
    my $group = shift;

    my $members = [];

    my $cursor = $self->{'db_users'}->cursor();
    while( my ($key, $val) = $self->{'db_users'}->next( $cursor ) )
    {
        my( $selector, $uid ) = split(':', $key);
        if( $selector eq 'gm' )
        {
            if( defined($val) and length($val) > 0 and
                grep {$group eq $_} split(',', $val) )
            {
                push( @{$members}, $uid );
            }
        }
    }
    undef $cursor;
    return $members;
}


sub addUserToGroups
{
    my $self = shift;
    my $uid = shift;
    my @groups = @_;

    my $ok = 1;
    if( $self->userExists( $uid ) )
    {
        foreach my $group ( @groups )
        {
            if( $self->groupExists( $group ) )
            {
                if( not grep {$group eq $_} $self->memberOf( $uid ) )
                {
                    $self->{'db_users'}->addToList( 'gm:' . $uid, $group );
                    $self->setGroupModified( $group );
                    Info('Added ' . $uid . ' to group ' . $group);
                }
                else
                {
                    Error('Cannot add ' . $uid . ' to group ' . $group .
                          ': user is already a member of this group');
                    $ok = 0;
                }
            }
            else
            {
                Error('Cannot add ' . $uid . ' to group ' . $group .
                      ': group does not exist');
                $ok = 0;
            }
        }
    }
    else
    {
        Error('Cannot add user ' . $uid .
              'to groups: user does not exist');
        $ok = 0;
    }
    return $ok;
}


sub delUserFromGroups
{
    my $self = shift;
    my $uid = shift;
    my @groups = shift;

    my $ok = 1;
    if( $self->userExists( $uid ) )
    {
        foreach my $group ( @groups )
        {
            if( $self->groupExists( $group ) )
            {
                if( grep {$group eq $_} $self->memberOf( $uid ) )
                {
                    $self->{'db_users'}->delFromList( 'gm:' . $uid, $group );
                    $self->setGroupModified( $group );
                    Info('Deleted ' . $uid . ' from group ' . $group);
                }
                else
                {
                    Error('Cannot delete ' . $uid . ' from group ' . $group .
                          ': user is not a member of this group');
                    $ok = 0;
                }
            }
            else
            {
                Error('Cannot detete ' . $uid . ' from group ' . $group .
                      ': group does not exist');
                $ok = 0;
            }
        }
    }
    else
    {
        Error('Cannot delete user ' . $uid .
              'from groups: user does not exist');
        $ok = 0;
    }
    return $ok;
}


sub addUser
{
    my $self = shift;
    my $uid = shift;
    my $attrValues = shift;

    my $ok = 1;
    if( length( $uid ) == 0 or $uid =~ /\W/ )
    {
        Error('Invalid user ID: ' . $uid);
        $ok = 0;
    }
    elsif( $self->userExists( $uid ) )
    {
        Error('Cannot add user ' . $uid . ': the user already exists');
        $ok = 0;
    }
    else
    {
        $self->setUserAttribute( $uid, 'uid', $uid );
        if( defined( $attrValues ) )
        {
            $self->setUserAttributes( $uid, $attrValues );
        }
        Info('User added: ' . $uid);
    }
    return $ok;
}


sub userExists
{
    my $self = shift;
    my $uid = shift;

    my $dbuid = $self->userAttribute( $uid, 'uid' );
    return( defined( $dbuid ) and ( $dbuid eq $uid ) );
}

sub listUsers
{
    my $self = shift;

    my @ret;

    my $cursor = $self->{'db_users'}->cursor();
    while( my ($key, $val) = $self->{'db_users'}->next( $cursor ) )
    {
        my( $selector, $uid, $attr ) = split(':', $key);
        if( $selector eq 'ua' and $attr eq 'uid' )
        {
            push( @ret, $uid );
        }
    }
    undef $cursor;
    return @ret;
}

sub setUserAttribute
{
    my $self = shift;
    my $uid = shift;
    my $attr = shift;
    my $val = shift;

    my $ok = 1;
    if( length( $attr ) == 0 or $attr =~ /\W/ )
    {
        Error('Invalid attribute name: ' . $attr);
        $ok = 0;
    }
    else
    {
        $self->{'db_users'}->put( 'ua:' . $uid . ':' . $attr, $val );
        $self->{'db_users'}->addToList( 'uA:' . $uid, $attr );
        if( $attr ne 'modified' )
        {
            $self->setUserModified( $uid );
        }
        Debug('Set ' . $attr . ' for ' . $uid . ': ' . $val);
    }
    return $ok;
}


sub delUserAttribute
{
    my $self = shift;
    my $uid = shift;
    my @attrs = @_;

    foreach my $attr ( @attrs )
    {
        $self->{'db_users'}->del( 'ua:' . $uid . ':' . $attr );
        $self->{'db_users'}->delFromList( 'uA:' . $uid, $attr );
        $self->setUserModified( $uid );
        Debug('Deleted ' . $attr . ' from ' . $uid);
    }
}


sub setUserAttributes
{
    my $self = shift;
    my $uid = shift;
    my $attrValues = shift;

    my $ok = 1;
    
    foreach my $attr ( keys %{$attrValues} )
    {
        $ok = $self->setUserAttribute( $uid, $attr, $attrValues->{$attr} )
            ? $ok:0;
    }
    
    return $ok;
}


sub setUserModified
{
    my $self = shift;
    my $uid = shift;

    $self->setUserAttribute( $uid, 'modified', scalar( localtime( time() ) ) );
}

sub listUserAttributes
{
    my $self = shift;
    my $uid = shift;

    my $list = $self->{'db_users'}->get( 'uA:' . $uid );

    return split( ',', $list );
}


sub setPassword
{
    my $self = shift;
    my $uid = shift;
    my $password = shift;

    my $ok = 1;
    if( $self->userExists( $uid ) )
    {
        if( length( $password ) < $Torrus::ACL::minPasswordLength )
        {
            Error('Password too short: must be ' .
                  $Torrus::ACL::minPasswordLength . ' characters long');
            $ok = 0;
        }
        else
        {
            my $attrValues = $self->{'auth'}->setPassword( $uid, $password );
            $self->setUserAttributes( $uid, $attrValues );
            Info('Password set for ' . $uid);
        }
    }
    else
    {
        Error('Cannot change password for user ' . $uid .
              ': user does not exist');
        $ok = 0;
    }
    return $ok;
}


sub deleteUser
{
    my $self = shift;
    my $uid = shift;

    my $ok = 1;
    if( $self->userExists( $uid ) )
    {
        my $cursor = $self->{'db_users'}->cursor( -Write => 1 );
        while( my ($key, $val) = $self->{'db_users'}->next( $cursor ) )
        {
            my( $selector, $dbuid ) = split(':', $key);
            if( ( $selector eq 'gm' or $selector eq 'ua' ) and
                $dbuid eq $uid )
            {
                $self->{'db_users'}->c_del( $cursor );
            }
        }
        undef $cursor;

        Info('User deleted: ' . $uid);
    }
    else
    {
        Error('Cannot delete user ' . $uid . ': user does not exist');
        $ok = 0;
    }
    return $ok;
}


sub setGroupAttribute
{
    my $self = shift;
    my $group = shift;
    my $attr = shift;
    my $val = shift;

    my $ok = 1;
    if( length( $attr ) == 0 or $attr =~ /\W/ )
    {
        Error('Invalid attribute name: ' . $attr);
        $ok = 0;
    }
    else
    {
        $self->{'db_users'}->put( 'ga:' . $group . ':' . $attr, $val );
        $self->{'db_users'}->addToList( 'gA:' . $group, $attr );
        if( $attr ne 'modified' )
        {
            $self->setGroupModified( $group );
        }
        Debug('Set ' . $attr . ' for ' . $group . ': ' . $val);
    }
    return $ok;
}


sub listGroupAttributes
{
    my $self = shift;
    my $group = shift;

    my $list = $self->{'db_users'}->get( 'gA:' . $group );

    return split( ',', $list );
}



sub setGroupModified
{
    my $self = shift;
    my $group = shift;

    $self->setGroupAttribute( $group, 'modified',
                              scalar( localtime( time() ) ) );
}


sub setPrivilege
{
    my $self = shift;
    my $group = shift;
    my $object = shift;
    my $privilege = shift;

    my $ok = 1;
    if( $self->groupExists( $group ) )
    {
        $self->{'db_acl'}->put( $group.':'.$object.':'.$privilege, 1 );
        $self->setGroupModified( $group );
        Info('Privilege ' . $privilege . ' for object ' . $object .
             ' set for group ' . $group);
    }
    else
    {
        Error('Cannot set privilege for group ' . $group .
              ': group does not exist');
        $ok = 0;
    }
    return $ok;
}


sub clearPrivilege
{
    my $self = shift;
    my $group = shift;
    my $object = shift;
    my $privilege = shift;

    my $ok = 1;
    if( $self->groupExists( $group ) )
    {
        my $key = $group.':'.$object.':'.$privilege;
        if( $self->{'db_acl'}->get( $key ) )
        {
            $self->{'db_acl'}->del( $key );
            $self->setGroupModified( $group );
            Info('Privilege ' . $privilege . ' for object ' . $object .
                 ' revoked from group ' . $group);
        }
    }
    else
    {
        Error('Cannot revoke privilege from group ' . $group .
              ': group does not exist');
        $ok = 0;
    }
    return $ok;
}


sub listPrivileges
{
    my $self = shift;
    my $group = shift;

    my $ret = {};

    my $cursor = $self->{'db_acl'}->cursor();
    while( my ($key, $val) = $self->{'db_acl'}->next( $cursor ) )
    {
        my( $dbgroup, $object, $privilege ) = split( ':', $key );
        if( $dbgroup eq $group )
        {
            $ret->{$object}{$privilege} = 1;
        }
    }
    undef $cursor;

    return $ret;
}


sub clearConfig
{
    my $self = shift;

    $self->{'db_acl'}->trunc();
    $self->{'db_users'}->trunc();

    Info('Cleared the ACL configuration');
    return 1;
}

sub exportACL
{
    my $self = shift;
    my $exportfile = shift;
    my $exporttemplate = shift;

    my $ok;
    eval 'require Torrus::ACL::Export;
          $ok = Torrus::ACL::Export::exportACL( $self, $exportfile,
                                              $exporttemplate );';
    if( $@ )
    {
        Error($@);
        return 0;
    }
    else
    {
        return $ok;
    }
}

sub importACL
{
    my $self = shift;
    my $importfile = shift;

    my $ok;
    eval 'require Torrus::ACL::Import;
          $ok = Torrus::ACL::Import::importACL( $self, $importfile );';

    if( $@ )
    {
        Error($@);
        return 0;
    }
    else
    {
        return $ok;
    }
}

1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
