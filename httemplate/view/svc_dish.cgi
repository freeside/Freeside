<% include('elements/svc_Common.html',
            'table'        => 'svc_dish',
            'labels'       => \%labels,
            'fields'       => \@fields,
          )
%>
<%init>

my $fields = FS::svc_dish->table_info->{'fields'};
my %labels = map { $_ =>  ( ref($fields->{$_})
                             ? $fields->{$_}{'label'}
                             : $fields->{$_}
                         );
                 } keys %$fields;
my @fields = ('acctnum',
              { field => 'installdate', type => 'date' },
              'note'
              );
</%init>
