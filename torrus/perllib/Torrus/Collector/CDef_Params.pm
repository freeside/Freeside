#
#  Copyright (C) 2004  Christian Schnidrig
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
#  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

# $Id: CDef_Params.pm,v 1.1 2010-12-27 00:03:57 ivan Exp $
# Christian Schnidrig <christian.schnidrig@bluewin.ch>


# Parameter definitions for CDef collector plugin

package Torrus::Collector::CDef_Params;

use strict;

###  Initialize the configuration validator with module-specific parameters
our %params =
    (
     'rpn-expr'                 => undef,
     'cdef-collector-delay'     => undef,
     'cdef-collector-tolerance' => undef,
     );


sub initValidatorLeafParams
{
    my $hashref = shift;
    $hashref->{'ds-type'}{'collector'}{'collector-type'}{'cdef'} =
        \%params;
}


my %admInfoParamCategories =
    (
     'cdef-collector-delay'        => 'CDef_Collector',
     'cdef-collector-tolerance'    => 'CDef_Collector',
     );     


sub initAdmInfo
{
    my $map = shift;
    my $categories = shift;
    
    $map->{'ds-type'}{'collector'}{'collector-type'}{'cdef'} =
        \%params;
    
    while( my ($pname, $category) = each %admInfoParamCategories )
    {
        $categories->{$pname} = $category;
    }
}



1;

