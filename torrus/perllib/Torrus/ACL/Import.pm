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

# $Id: Import.pm,v 1.1 2010-12-27 00:03:59 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>


package Torrus::ACL::Import;

use Torrus::ACL;
use Torrus::ACL::Edit;
use Torrus::Log;

use XML::LibXML;
use strict;

my %formatsSupported = ('1.0' => 1,
                        '1.1' => 1);

sub importACL
{
    my $self = shift;
    my $filename = shift;

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
    if( $root->nodeName() ne 'aclexport' )
    {
        Error('XML root element is not "aclexport" in ' . $filename);
        return 0;
    }

    my $format_version =
        (($root->getElementsByTagName('file-info'))[0]->
         getElementsByTagName('format-version'))[0]->textContent();
    if( not $format_version or not $formatsSupported{$format_version} )
    {
        Error('Invalid format or format version not supported: ' . $filename);
        return 0;
    }

    foreach my $groupnode ( ($root->getElementsByTagName('groups'))[0]->
                            getElementsByTagName('group') )
    {
        my $group = $groupnode->getAttribute('name');
        Debug('Importing group: ' . $group);
        if( not $self->groupExists( $group ) )
        {
            $ok = $self->addGroups( $group ) ? $ok:0;
        }
        else
        {
            Debug('Group already exists: ' . $group);
        }

        foreach my $privnode ( $groupnode->getElementsByTagName('privilege') )
        {
            my $object = $privnode->getAttribute('object');
            my $priv = $privnode->getAttribute('name');
            Debug('Setting privilege ' . $priv . ' for ' . $object .
                  ' to group ' . $group);
            $ok = $self->setPrivilege( $group, $object, $priv ) ? $ok:0;
        }

        foreach my $attrnode ( $groupnode->getElementsByTagName('attribute') )
        {
            my $attr = $attrnode->getAttribute('name');
            if( $attr ne 'modified' )
            {
                my $value = $attrnode->getAttribute('value');
                Debug('Setting attribute ' . $attr . ' for group ' . $group .
                      ' to ' . $value);
                $ok = $self->setGroupAttribute( $group, $attr, $value )
                    ? $ok:0;
            }
        }
    }

    foreach my $usernode ( ($root->getElementsByTagName('users'))[0]->
                            getElementsByTagName('user') )
    {
        my $uid = $usernode->getAttribute('uid');
        Debug('Importing user: ' . $uid);

        if( not $self->userExists( $uid ) )
        {
            $ok = $self->addUser( $uid ) ? $ok:0;
        }
        else
        {
            Debug('User already exists: ' . $uid);
        }

        foreach my $membernode ( $usernode->getElementsByTagName('member-of') )
        {
            my $group = $membernode->getAttribute('group');
            Debug('Adding ' . $uid . ' to group ' . $group);

            if( not grep {$group eq $_} $self->memberOf( $uid ) )
            {
                $ok = $self->addUserToGroups( $uid, $group ) ? $ok:0;
            }
            else
            {
                Debug('User ' . $uid . ' is already in group ' . $group);
            }
        }

        foreach my $attrnode ( $usernode->getElementsByTagName('attribute') )
        {
            my $attr = $attrnode->getAttribute('name');
            if( $attr ne 'modified' )
            {
                my $value = $attrnode->getAttribute('value');
                Debug('Setting attribute ' . $attr . ' for user ' . $uid .
                      ' to ' . $value);
                $ok = $self->setUserAttribute( $uid, $attr, $value ) ? $ok:0;
            }
        }
    }
    Debug('Import finished');
    return $ok;
}




1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
