<% include( 'elements/svc_Common.html',
            'table'   	=> 'svc_hardware',
            'html_foot' => $html_foot,
            'fields'    => \@fields,
    )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

my $html_foot = sub { };

my @fields = (
  {
    field => 'typenum',
    type  => 'select-hardware_type',
  },
  {
    field => 'serial',
    type  => 'text',
    label => 'Device serial #',
  },
  {
    field => 'hw_addr',
    type  => 'text',
    label => 'Hardware address',
  },
  {
    field => 'ip_addr',
    type  => 'text',
    label => 'IP address',
  },
  {
    field => 'statusnum',
    type  => 'select-table',
    table => 'hardware_status',
    label => 'Service status',
    name_col => 'label',
    disable_empty => 1,
  },
  {
    field => 'note',
    type  => 'textarea',
    rows  => 4,
    cols  => 30,
    label => 'Installation notes',
  },

);
    
</%init>
