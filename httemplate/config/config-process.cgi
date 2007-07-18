<%init>
die "access denied\n"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = new FS::Conf;
$FS::Conf::DEBUG = 1;
my @config_items = $conf->config_items;
my %confitems = map { $_->key => $_ } $conf->config_items;

my $agentnum = $cgi->param('agentnum');
my $key = $cgi->param('key');
my $i = $confitems{$key};

my @touch = ();
my @delete = ();
my $n = 0;
foreach my $type ( ref($i->type) ? @{$i->type} : $i->type ) {
  if ( $type eq '' ) {
  } elsif ( $type eq 'textarea' ) {
    if ( $cgi->param($i->key.$n) ne '' ) {
      my $value = $cgi->param($i->key.$n);
      $value =~ s/\r\n/\n/g; #browsers?
      $conf->set($i->key, $value, $agentnum);
    } else {
      $conf->delete($i->key, $agentnum);
    }
  } elsif ( $type eq 'binary' ) {
    if ( defined($cgi->param($i->key.$n)) && $cgi->param($i->key.$n) ) {
      my $fh = $cgi->upload($i->key.$n);
      if (defined($fh)) {
        local $/;
        $conf->set_binary($i->key, <$fh>, $agentnum);
      }
    }else{
      warn "Condition failed for " . $i->key;
    }
  } elsif ( $type eq 'checkbox' ) {
    if ( defined $cgi->param($i->key.$n) ) {
      push @touch, $i->key;
    } else {
      push @delete, $i->key;
    }
  } elsif ( $type eq 'text' || $type eq 'select' || $type eq 'select-sub' )  {
    if ( $cgi->param($i->key.$n) ne '' ) {
      $conf->set($i->key, $cgi->param($i->key.$n), $agentnum);
    } else {
      $conf->delete($i->key, $agentnum);
    }
  } elsif ( $type eq 'editlist' || $type eq 'selectmultiple' )  {
    if ( scalar(@{[ $cgi->param($i->key.$n) ]}) ) {
      $conf->set($i->key, join("\n", @{[ $cgi->param($i->key.$n) ]} ), $agentnum);
    } else {
      $conf->delete($i->key, $agentnum);
    }
  }
  $n++;
}
# warn @touch;
$conf->touch($_, $agentnum) foreach @touch;
$conf->delete($_, $agentnum) foreach @delete;

</%init>
<% header('Configuration set') %>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
  </BODY></HTML>
