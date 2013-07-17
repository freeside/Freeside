package RT::Action::ExtractCustomFieldValuesWithCodeInTemplate;
use strict;
use warnings;

use base qw(RT::Action::ExtractCustomFieldValues);

sub TemplateContent {
    my $self = shift;
    my $is_broken = 0;

    my $content = $self->TemplateObj->Content;

    my $template = Text::Template->new(TYPE => 'STRING', SOURCE => $content);
    my $new_content = $template->fill_in(
        BROKEN => sub {
            my (%args) = @_;
            $RT::Logger->error("Template parsing error: $args{error}")
                unless $args{error} =~ /^Died at /; # ignore intentional die()
            $is_broken++;
            return undef;
        },
    );

    return (undef, $self->loc('Template parsing error')) if $is_broken;

    return $new_content;
}

1;

