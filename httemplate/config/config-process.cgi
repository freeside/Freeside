<%
  my $conf = new FS::Conf;
  $FS::Conf::DEBUG = 1;
  my @config_items = $conf->config_items;

  foreach my $i ( @config_items ) {
    my @touch = ();
    my @delete = ();
    my $n = 0;
    foreach my $type ( ref($i->type) ? @{$i->type} : $i->type ) {
      if ( $type eq '' ) {
      } elsif ( $type eq 'textarea' ) {
        if ( $cgi->param($i->key. $n) ne '' ) {
          my $value = $cgi->param($i->key. $n);
          $value =~ s/\r\n/\n/g; #browsers?
          $conf->set($i->key, $value);
        } else {
          $conf->delete($i->key);
        }
      } elsif ( $type eq 'checkbox' ) {
#        if ( defined($cgi->param($i->key. $n)) && $cgi->param($i->key. $n) ) {
        if ( defined $cgi->param($i->key. $n) ) {
          #$conf->touch($i->key);
          push @touch, $i->key;
        } else {
          #$conf->delete($i->key);
          push @delete, $i->key;
        }
      } elsif ( $type eq 'text' || $type eq 'select' )  {
        if ( $cgi->param($i->key. $n) ne '' ) {
          $conf->set($i->key, $cgi->param($i->key. $n));
        } else {
          $conf->delete($i->key);
        }
      } elsif ( $type eq 'editlist' || $type eq 'selectmultiple' )  {
        if ( scalar(@{[ $cgi->param($i->key. $n) ]}) ) {
          $conf->set($i->key, join("\n", @{[ $cgi->param($i->key. $n) ]} ));
        } else {
          $conf->delete($i->key);
        }
      } else {
      }
      $n++;
    }
   # warn @touch;
    $conf->touch($_) foreach @touch;
    $conf->delete($_) foreach @delete;
  }

%>
<%= $cgi->redirect("config-view.cgi") %>
