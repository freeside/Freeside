package FS::UI::agent;

use strict;
use vars qw ( @ISA );
use FS::UI::Base;
use FS::Record qw( qsearchs );
use FS::agent;
use FS::agent_type;

@ISA = qw ( FS::UI::Base );

sub db_table { 'agent' };

sub db_name { 'Agent' };

sub db_description { <<END;
Agents are resellers of your service. Agents may be limited to a subset of your
full offerings (via their type).
END
}

sub list_fields {
  'agentnum',
  'typenum',
#  'freq',
#  'prog',
; }

sub list_header {
  'Agent',
  'Type',
#  'Freq (n/a)',
#  'Prog (n/a)',
; }

sub db_callback { 
  'agentnum' =>
    sub {
      my ( $agentnum, $record ) = @_;
      my $agent = $record->agent;
      new FS::UI::_Link (
        'table'  => 'agent',
        'method' => 'edit',
        'arg'    => [ $agentnum ],
        'text'   => "$agentnum: $agent",
      );
    },
  'typenum' =>
    sub {
      my $typenum = shift;
      my $agent_type = qsearchs( 'agent_type', { 'typenum' => $typenum } );
      my $atype = $agent_type->atype;
      new FS::UI::_Link (
        'table'  => 'agent_type',
        'method' => 'edit',
        'arg'    => [ $typenum ],
        'text'   => "$typenum: $atype"
      );
    },
}

1;
