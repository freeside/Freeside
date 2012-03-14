<% include('elements/svc_Common.html',
            'table'        => 'svc_hardware',
            'labels'       => \%labels,
            'fields'       => \@fields,
          )
%>
<%init>

my $conf = new FS::Conf;
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
my $hw_addr ={ field => 'hw_addr',
               type  => 'text',
               value => sub { 
                my $hw_addr = $_[0]->hw_addr;
                $conf->exists('svc_hardware-check_mac_addr') ?
                  join(':', $hw_addr =~ /../g) : $hw_addr
                },
              };

my @fields = (
  $model,
  'serial',
  $hw_addr,
  'ip_addr',
  'smartcard',
  $status,
  $note,
);
</%init>
