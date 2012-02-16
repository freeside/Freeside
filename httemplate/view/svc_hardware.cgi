<% include('elements/svc_Common.html',
            'table'        => 'svc_hardware',
            'labels'       => \%labels,
            'fields'       => \@fields,
          )
%>
<%init>

my $fields = FS::svc_hardware->table_info->{'fields'};
my %labels = map { $_ =>  ( ref($fields->{$_})
                             ? $fields->{$_}{'label'}
                             : $fields->{$_}
                         );
                 } keys %$fields;
my $model =  { field => 'typenum',
               type  => 'text',
               value => sub { $_[0]->hardware_type->description }
             };
my $status = { field => 'statusnum',
               type  => 'text',
               value => sub { $_[0]->status_label }
             };
my $note =   { field => 'note',
               type  => 'text',
               value => sub { encode_entities($_[0]->note) }
             };
my @fields = ($model, qw( serial hw_addr ip_addr smartcard ), $status, $note );
</%init>
