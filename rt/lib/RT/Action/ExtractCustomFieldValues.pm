package RT::Action::ExtractCustomFieldValues;
require RT::Action;

use strict;
use warnings;

use base qw(RT::Action);

our $VERSION = 2.99_01;

sub Describe {
    my $self = shift;
    return ( ref $self );
}

sub Prepare {
    return (1);
}

sub FirstAttachment {
    my $self = shift;
    return $self->TransactionObj->Attachments->First;
}

sub Queue {
    my $self = shift;
    return $self->TicketObj->QueueObj->Id;
}

sub TemplateContent {
    my $self = shift;
    return $self->TemplateObj->Content;
}

sub TemplateConfig {
    my $self = shift;

    my ($content, $error) = $self->TemplateContent;
    if (!defined($content)) {
        return (undef, $error);
    }

    my $Separator = '\|';
    my @lines = split( /[\n\r]+/, $content);
    my @results;
    for (@lines) {
        chomp;
        next if /^#/;
        next if /^\s*$/;
        if (/^Separator=(.+)$/) {
            $Separator = $1;
            next;
        }
        my %line;
        @line{qw/CFName Field Match PostEdit Options/}
            = split(/$Separator/);
        $_ = '' for grep !defined, values %line;
        push @results, \%line;
    }
    return \@results;
}

sub Commit {
    my $self            = shift;
    return 1 unless $self->FirstAttachment;

    my ($config_lines, $error) = $self->TemplateConfig;

    return 0 if $error;

    for my $config (@$config_lines) {
        my %config = %{$config};
        $RT::Logger->debug( "Looking to extract: "
                . join( " ", map {"$_=$config{$_}"} sort keys %config ) );

        if ( $config{Options} =~ /\*/ ) {
            $self->FindContent(
                %config,
                Callback    => sub {
                    my $content = shift;
                    my $found = 0;
                    while ( $content =~ /$config{Match}/mg ) {
                        my ( $cf, $value ) = ( $1, $2 );
                        $cf = $self->LoadCF( Name => $cf, Quiet => 1 );
                        next unless $cf;
                        $found++;
                        $self->ProcessCF(
                            %config,
                            CustomField => $cf,
                            Value       => $value
                        );
                    }
                    return $found;
                },
            );
        } else {
            my $cf;
            $cf = $self->LoadCF( Name => $config{CFName} )
                if $config{CFName};

            $self->FindContent(
                %config,
                Callback    => sub {
                    my $content = shift;
                    return 0 unless $content =~ /($config{Match})/m;
                    $self->ProcessCF(
                        %config,
                        CustomField => $cf,
                        Value       => $2 || $1,
                    );
                    return 1;
                }
            );
        }
    }
    return (1);
}

sub LoadCF {
    my $self = shift;
    my %args            = @_;
    my $CustomFieldName = $args{Name};
    $RT::Logger->debug( "Looking for CF $CustomFieldName");

    # We do this by hand instead of using LoadByNameAndQueue because
    # that can find disabled queues
    my $cfs = RT::CustomFields->new($RT::SystemUser);
    $cfs->LimitToGlobalOrQueue($self->Queue);
    $cfs->Limit(
        FIELD         => 'Name',
        VALUE         => $CustomFieldName,
        CASESENSITIVE => 0
    );
    $cfs->RowsPerPage(1);

    my $cf = $cfs->First;
    if ( $cf && $cf->id ) {
        $RT::Logger->debug( "Found CF id " . $cf->id );
    } elsif ( not $args{Quiet} ) {
        $RT::Logger->error( "Couldn't load CF $CustomFieldName!");
    }

    return $cf;
}

sub FindContent {
    my $self = shift;
    my %args = @_;
    if ( lc $args{Field} eq "body" ) {
        my $Attachments  = $self->TransactionObj->Attachments;
        my $LastContent  = '';
        my $AttachmentCount = 0;

        my @list = @{ $Attachments->ItemsArrayRef };
        while ( my $Message = shift @list ) {
            $AttachmentCount++;
            $RT::Logger->debug( "Looking at attachment $AttachmentCount, content-type "
                                    . $Message->ContentType );
            my $ct = $Message->ContentType;
            unless ( $ct =~ m!^(text/plain|message|text$)!i ) {
                # don't skip one attachment that is text/*
                next if @list > 1 || $ct !~ m!^text/!;
            }

            my $content = $Message->Content;
            next unless $content;
            next if $LastContent eq $content;
            $RT::Logger->debug( "Examining content of body" );
            $LastContent = $content;
            $args{Callback}->( $content );
        }
    } elsif ( lc $args{Field} eq 'headers' ) {
        my $attachment = $self->FirstAttachment;
        $RT::Logger->debug( "Looking at the headers of the first attachment" );
        my $content = $attachment->Headers;
        return unless $content;
        $RT::Logger->debug( "Examining content of headers" );
        $args{Callback}->( $content );
    } else {
        my $attachment = $self->FirstAttachment;
        $RT::Logger->debug( "Looking at $args{Field} header of first attachment" );
        my $content = $attachment->GetHeader( $args{Field} );
        return unless defined $content;
        $RT::Logger->debug( "Examining content of header" );
        $args{Callback}->( $content );
    }
}

sub ProcessCF {
    my $self = shift;
    my %args = @_;

    return $self->PostEdit(%args)
        unless $args{CustomField};

    my @values = ();
    if ( $args{CustomField}->SingleValue() ) {
        push @values, $args{Value};
    } else {
        @values = split( ',', $args{Value} );
    }

    foreach my $value ( grep defined && length, @values ) {
        $value = $self->PostEdit(%args, Value => $value );
        next unless defined $value && length $value;

        $RT::Logger->debug( "Found value for CF: $value");
        my ( $id, $msg ) = $self->TicketObj->AddCustomFieldValue(
            Field             => $args{CustomField},
            Value             => $value,
            RecordTransaction => $args{Options} =~ /q/ ? 0 : 1
        );
        $RT::Logger->info( "CustomFieldValue ("
                . $args{CustomField}->Name
                . ",$value) added: $id $msg" );
    }
}

sub PostEdit {
    my $self = shift;
    my %args = @_;

    return $args{Value} unless $args{Value} && $args{PostEdit};

    $RT::Logger->debug( "Running PostEdit for '$args{Value}'");
    my $value = $args{Value};
    local $_  = $value;    # backwards compatibility
    local $@;
    eval( $args{PostEdit} );
    $RT::Logger->error("$@") if $@;
    return $value;
}

1;
