package RT::Template;

=item LoadByName

Takes Name and Queue arguments. Tries to load queue specific template
first, then global. If Queue argument is omitted then global template
is tried, not template with the name in any queue.

=cut

sub LoadByName {
    my $self = shift;
    my %args = (
        Queue => undef,
        Name  => undef,
        @_
    );
    my $queue = $args{'Queue'};
    if ( blessed $queue ) {
        $queue = $queue->id;
    } elsif ( defined $queue and $queue =~ /\D/ ) {
        my $tmp = RT::Queue->new( $self->CurrentUser );
        $tmp->Load($queue);
        $queue = $tmp->id;
    }

    return $self->LoadGlobalTemplate( $args{'Name'} ) unless $queue;

    $self->LoadQueueTemplate( Queue => $queue, Name => $args{'Name'} );
    return $self->id if $self->id;
    return $self->LoadGlobalTemplate( $args{'Name'} );
}

1;
