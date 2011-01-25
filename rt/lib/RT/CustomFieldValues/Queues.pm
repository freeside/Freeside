package RT::CustomFieldValues::Queues;

use strict;
use warnings;

use base qw(RT::CustomFieldValues::External);

sub SourceDescription {
    return 'RT ticket queues';
}

sub ExternalValues {
    my $self = shift;

    my @res;
    my $i = 0;
    my $queues = RT::Queues->new( $self->CurrentUser );
    $queues->UnLimit;
    $queues->OrderByCols( { FIELD => 'Name' } );
    while( my $queue = $queues->Next ) {
        push @res, {
            name        => $queue->Name,
            description => $queue->Description,
            sortorder   => $i++,
        };
    }
    return \@res;
}

1;
