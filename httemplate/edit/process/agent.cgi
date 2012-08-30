<% include( 'elements/process.html',
              'table'            => 'agent',
              'viewall_dir'      => 'browse',
              'viewall_ext'      => 'cgi',
              'process_m2m'      => { 'link_table'   => 'access_groupagent',
                                      'target_table' => 'access_group',
                                    },
              'edit_ext'         => 'cgi',
              'noerror_callback' => $process_agent_pkg_class,
          )
%>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

if ( FS::Conf->new->exists('disable_acl_changes') ) {
  errorpage('ACL changes disabled in public demo.');
  die "shouldn't be reached";
}

my $process_agent_pkg_class = sub {
  my( $cgi, $agent ) = @_;

  #surprising amount of false laziness w/ edit/agent.cgi
  my @pkg_class = qsearch('pkg_class', { 'disabled'=>'' });
  foreach my $pkg_class ( '', @pkg_class ) {
    my %agent_pkg_class = ( 'agentnum' => $agent->agentnum,
                            'classnum' => $pkg_class ? $pkg_class->classnum : ''
                          );
    my $agent_pkg_class =
      qsearchs( 'agent_pkg_class', \%agent_pkg_class )
      || new FS::agent_pkg_class   \%agent_pkg_class;

    my $param = 'classnum'. $agent_pkg_class{classnum};

    $agent_pkg_class->commission_percent( $cgi->param($param) );

    my $method = $agent_pkg_class->agentpkgclassnum ? 'replace' : 'insert';

    my $error = $agent_pkg_class->$method;
    die $error if $error; #XXX push this down into agent.pm w/better/transactional error handling

  }

};

</%init>
