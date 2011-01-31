package RT::Queue;

use strict;
use warnings;

# Adjust various saved settings that might have the old queue name in them.
# $changes{'AttributeName'} = sub (attribute, old queue name, new queue name)
# where the sub changes any reference to the old name to the new name
# returning a positive value on success,
# or (0, error string) if it fails somehow
# or -1 if the old name isn't found

my %changes = (
    'SavedSearch' => sub {
        my ($attr, $old, $new) = @_;
        # Deal with queue names containing single quotes.
        $old =~ s/'/\\'/g;
        $new =~ s/'/\\'/g;
        my $string = $attr->SubValue('Query');
        # Deal with queue names containing regex metacharacters.
        if ( $string =~ s/Queue\W+\K'\Q$old\E'/'$new'/ ) {
            return $attr->SetSubValues(Query => $string);
        }
        -1;
    },
    'Pref-QuickSearch' => sub {
        my ($attr, $old, $new) = @_;
        my $x = $attr->SubValue($old);
        return -1 if !defined($x);
        my @err = $attr->DeleteSubValue($old);
        return @err if !$err[0];
        return $attr->SetSubValues($new => $x);
    },
);

sub SetName {
    my $self = shift;
    my $new = shift;

    # We may potentially change anything at all.
    unless ( $self->CurrentUser->HasRight(
        Right => 'SuperUser', Object => 'RT::System' )
    ) {
        return ( 0, $self->loc("SuperUser access required to rename queues") );
    }

    $RT::Handle->BeginTransaction();
    my $old = $self->Name;
    my ($err, $msg) = $self->SUPER::SetName($new);
    unless ($err) {
        $RT::Handle->Rollback;
        return (0, "Unable to rename queue to '$new': $msg");
    }
    foreach my $attrname (keys %changes) {
        my $Attributes = RT::Attributes->new($self->CurrentUser);
        $Attributes->UnLimit;
        foreach my $attr ( $Attributes->Named($attrname) ) {
            ($err, $msg) = &{ $changes{$attrname} }($attr, $old, $new);
            unless ($err) {
                $RT::Handle->Rollback;
                return (0, "Unable to change attribute $attrname - ".
                    $attr->Description.  ": $msg");
            }
        }
    }
    RT->System->QueueCacheNeedsUpdate(1);
    $RT::Handle->Commit;
    return 1, "Name changed from '$old' to '$new'";
}


1;
