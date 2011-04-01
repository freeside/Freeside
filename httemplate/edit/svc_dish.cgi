<% include( 'elements/svc_Common.html',
            'table'   	=> 'svc_dish',
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
    field => 'acctnum',
    type  => 'text',
    label => 'DISH Account #',
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
