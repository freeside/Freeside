<% include( 'elements/svc_Common.html',
              'table'  => 'svc_mailinglist',
              'fields' => \@fields,
          )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my @fields = (
  'username',
  { field=>'domsvc',           type=>'select-svc-domain',
    #label => 'List address domain',
  },
  { field=>'listnum',          type=>'hidden', },
  { field=>'listname',         type=>'text', },
  { field=>'reply_to',         type=>'checkbox', value=>'Y' },
  { field=>'remove_from',      type=>'checkbox', value=>'Y' },
  { field=>'reject_auto',      type=>'checkbox', value=>'Y' },
  { field=>'remove_to_and_cc', type=>'checkbox', value=>'Y' },

);

</%init>
