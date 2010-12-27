#  Copyright (C) 2005  Stanislav Sinyagin
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

# $Id: Reports.pm,v 1.1 2010-12-27 00:03:59 ivan Exp $
# Stanislav Sinyagin <ssinyagin@yahoo.com>

# Class for Reporter data manipulation
package Torrus::SQL::ReportFields;

package Torrus::SQL::Reports;

use strict;

use Torrus::SQL;
use base 'Torrus::SQL';

use Torrus::Log;
# use Torrus::SQL::ReportFields;

# The name of the table and columns 
# defaults configured in torrus-config.pl
our $tableName;
our %columns;


sub new
{
    my $class = shift;
    my $subtype = shift;

    my $self  = $class->SUPER::new( $subtype );

    $self->{'fields'} = Torrus::SQL::ReportFields->new( $subtype );
    
    bless ($self, $class);
    return $self;
}
    

# Find or create a new row in reports table
# 
sub reportId
{
    my $self = shift;
    my $repdate = shift;
    my $reptime = shift;
    my $repname = shift;

    my $result = $self->{'sql'}->select_one_to_arrayref({
        'fields' => [ $columns{'id'}, $columns{'iscomplete'} ],
        'table' => $tableName,
        'where' => { $columns{'rep_date'}   => $repdate,
                     $columns{'rep_time'}   => $reptime,
                     $columns{'reportname'} => $repname } });
    
    if( defined( $result ) )
    {
        if( not $result->[1] ) 
        {
            # iscomplete is zero - the report is unfinished
            Warn('Found unfinished report ' . $repname . ' for ' .
                 $repdate . ' ' . $reptime .
                 '. Deleting the previous report data');
            $self->{'fields'}->removeAll( $result->[0] );
        }
            
        return $result->[0];
    }
    else
    {
        my $id = $self->sequenceNext();

        $self->{'sql'}->insert({
            'table' => $tableName,
            'fields' => { $columns{'id'} => $id,
                          $columns{'rep_date'}   => $repdate,
                          $columns{'rep_time'}   => $reptime,
                          $columns{'reportname'} => $repname,
                          $columns{'iscomplete'} => 0 } });
        
        return $id;
    }
}



# Add a new field to a report. The field is a hash array reference
# with keys: 'name', 'serviceid', 'value', 'units'

sub addField
{
    my $self = shift;
    my $reportId = shift;
    my $field = shift;

    if( isDebug() )
    {
        Debug('Adding report field: ' . $field->{'name'} .
              ':' . $field->{'serviceid'} . ' = ' . $field->{'value'} .
              ' ' . $field->{'units'});
    }
    $self->{'fields'}->add( $reportId, $field );
}


sub getFields
{
    my $self = shift;
    my $reportId = shift;

    return $self->{'fields'}->getAll( $reportId );
}


sub isComplete
{
    my $self = shift;
    my $reportId = shift;
    
    my $result = $self->{'sql'}->select_one_to_arrayref({
        'fields' => [ $columns{'iscomplete'} ],
        'table' => $tableName,
        'where' => { $columns{'id'}   => $reportId } });
    
    if( defined( $result ) )
    {
        return $result->[0];
    }
    else
    {
        Error('Cannot find the report record for ID=' . $reportId);
    }

    return 0;
}


sub finalize
{
    my $self = shift;
    my $reportId = shift;

    $self->{'sql'}->update({
        'table' => $tableName,
        'where' => { $columns{'id'}   => $reportId },
        'fields' => { $columns{'iscomplete'} => 1 } });

    $self->{'sql'}->commit();
}


sub getAllReports
{
    my $self = shift;
    my $srvIdList = shift;
    my $limitDate = shift;

    my $where = { $columns{'iscomplete'} => 1 };
    
    if( defined( $limitDate ) )
    {
        $where->{$columns{'rep_date'}} = ['>=', $limitDate];
    }
    
    $self->{'sql'}->select({
        'table' => $tableName,
        'where' => $where,
        'fields' => [ $columns{'id'},
                      $columns{'rep_date'},
                      $columns{'rep_time'},
                      $columns{'reportname'} ] });
    
    my $reports =
        $self->fetchall([ 'id', 'rep_date', 'rep_time', 'reportname' ]);

    my $ret = {};
    foreach my $report ( @{$reports} )
    {
        my($year, $month, $day) = split('-', $report->{'rep_date'});

        my $fields = $self->getFields( $report->{'id'} );
        my $fieldsref = {};
        
        foreach my $field ( @{$fields} )
        {
            if( not ref( $srvIdList ) or
                grep {$field->{'serviceid'} eq $_} @{$srvIdList} )
            {
                $fieldsref->{$field->{'serviceid'}}->{$field->{'name'}} = {
                    'value' => $field->{'value'},
                    'units' => $field->{'units'} };
            }
        }
        
        $ret->{$year}{$month}{$day}{$report->{'reportname'}} = $fieldsref;
    }
    return $ret;    
}

        
        
    
    

        
################################################
## Class for report fields table

package Torrus::SQL::ReportFields;
use strict;

use Torrus::SQL;
use base 'Torrus::SQL';

use Torrus::Log;

# The name of the table and columns 
# defaults configured in torrus-config.pl
our $tableName;
our %columns;

sub add
{
    my $self = shift;
    my $reportId = shift;
    my $attrs = shift;
    
    my $id = $self->sequenceNext();
    
    $self->{'sql'}->insert({
        'table' => $tableName,
        'fields' => { $columns{'id'}         => $id,
                      $columns{'rep_id'}     => $reportId,
                      $columns{'name'}       => $attrs->{'name'},
                      $columns{'serviceid'}  => $attrs->{'serviceid'},
                      $columns{'value'}      => $attrs->{'value'},
                      $columns{'units'}      => $attrs->{'units'} } });
}


sub getAll
{
    my $self = shift;
    my $reportId = shift;
       
    $self->{'sql'}->select({
        'table' => $tableName,
        'where' => { $columns{'rep_id'} => $reportId },
        'fields' => [ $columns{'name'},
                      $columns{'serviceid'},
                      $columns{'value'},
                      $columns{'units'}] });

    return $self->fetchall([ 'name', 'serviceid', 'value', 'units' ]);
}


sub removeAll
{
    my $self = shift;
    my $reportId = shift;
       
    $self->{'sql'}->delete({
        'table' => $tableName,
        'where' => { $columns{'rep_id'} => $reportId }});
}    
    
    
    
    
1;


# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# perl-indent-level: 4
# End:
