package FS::Log::Output;

use base Log::Dispatch::Output;
use FS::Record qw( dbdef );

sub new { # exactly by the book
  my $proto = shift;
  my $class = ref $proto || $proto;

  my %p = @_;

  my $self = bless {}, $class;

  $self->_basic_init(%p);

  return $self;
}

sub log_message {
  my $self = shift;
  my %m = @_;

  my $object = $m{'object'};
  my ($tablename, $tablenum) = @m{'tablename', 'tablenum'};
  if ( $object and $object->isa('FS::Record') ) {
    $tablename = $object->table;
    $tablenum = $object->get( dbdef->table($tablename)->primary_key );

    # get the agentnum from the object if it has one
    $m{'agentnum'} ||= $object->get('agentnum');
    # maybe FS::cust_main_Mixin objects should use the customer's agentnum?
    # I'm trying not to do database lookups in here, though.
  }

  my $entry = FS::log->new({
      _date     => time,
      agentnum  => $m{'agentnum'},
      tablename => ($tablename || ''),
      tablenum  => ($tablenum || ''),
      level     => $self->_level_as_number($m{'level'}),
      message   => $m{'message'},
  });
  my $error = $entry->insert( FS::Log->context );
  if ( $error ) {
    # guh?
    warn "Error writing log entry: $error";
  }
}

1;
