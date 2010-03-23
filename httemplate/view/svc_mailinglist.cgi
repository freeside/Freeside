<% include('elements/svc_Common.html',
             'table' => 'svc_mailinglist',
             %opt,
          )
%>
<%init>

my %opt = ();

my $info = FS::svc_mailinglist->table_info;

$opt{'name'} = $info->{'name'};

my $fields = $info->{'fields'};
my %labels = map { $_ =>  ( ref($fields->{$_})
                             ? $fields->{$_}{'label'}
                             : $fields->{$_}
                         );
                 }
             keys %$fields;

#$opt{'fields'} = [ keys %$fields ];
$opt{'fields'} = [
  'username',
  'domain',
  'listname',
  'reply_to',
  'remove_from',
  'reject_auto',
  'remove_to_and_cc',
];

$opt{'labels'} = \%labels;

$opt{'html_foot'} = sub {
  my $svc_mailinglist = shift;
  my $listnum = $svc_mailinglist->listnum;

  my $sql = 'SELECT COUNT(*) FROM mailinglistmember WHERE listnum = ?';
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute($listnum) or die $sth->errstr;
  my $num = $sth->fetchrow_arrayref->[0];

  my $add_url = $p."edit/mailinglistmember.html?listnum=$listnum";

  my $add_link = include('/elements/init_overlib.html').
                 include('/elements/popup_link.html',
                           'action' => $add_url,
                           'label'  => 'add',
                           'actionlabel' => 'Add list member',
                           'width'  => 392,
                           'height' => 192,
                        );

  ntable('#cccccc').'<TR><TD>'.ntable('#cccccc',2). qq[
    <TR>
      <TD>List members</TD>
      <TD BGCOLOR="#ffffff">
        $num members
        ( <A HREF="${p}search/mailinglistmember.html?listnum=$listnum">view</A>
        | $add_link )
      </TD>
    </TR>
    </TABLE></TD></TR></TABLE>

    <BR><BR>
  ]. include('svc_export_settings.html', $svc_mailinglist);

};

</%init>
