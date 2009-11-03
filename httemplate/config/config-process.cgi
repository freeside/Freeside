<%init>
die "access denied\n"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = new FS::Conf;
$FS::Conf::DEBUG = 1;
my @config_items = grep { $_->key != ~/^invoice_(html|latex|template)/ }
                        $conf->config_items;
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
  } elsif ( $type eq 'binary' || $type eq 'image' ) {
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
  } elsif (
    $type =~ /^(editlist|selectmultiple)$/
    or ( $type =~ /^select(-(sub|part_svc|part_pkg|pkg_class))?$/
         || $i->multiple )
  ) {
    if ( scalar(@{[ $cgi->param($i->key.$n) ]}) ) {
      $conf->set($i->key, join("\n", @{[ $cgi->param($i->key.$n) ]} ), $agentnum);
    } else {
      $conf->delete($i->key, $agentnum);
    }
  } elsif ( $type =~ /^(text|select(-(sub|part_svc|part_pkg|pkg_class))?)$/ ) {
    if ( $cgi->param($i->key.$n) ne '' ) {
      $conf->set($i->key, $cgi->param($i->key.$n), $agentnum);
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
%   my $n = 0;
%   foreach my $type ( ref($i->type) ? @{$i->type} : $i->type ) {
    var configCell = window.top.document.getElementById('<% $agentnum. $i->key. $n %>');
    if ( ! configCell ) {
      window.top.location.reload();
    }
    //alert('found cell ' + configCell);
%     if (    $type eq 'textarea'
%          || $type eq 'editlist'
%          || $type eq 'selectmultiple' ) {
        configCell.innerHTML =
          '<font size="-2"><pre>' + "\n" +
          <% encode_entities(join("\n",
               map { length($_) > 88 ? substr($_,0,88).'...' : $_ }
                   $conf->config($i->key, $agentnum)
             ) )
          |js_string %> +
          '</pre></font>';

%     } elsif ( $type eq 'checkbox' ) {
%       if ( $conf->exists($i->key, $agentnum) ) {
          configCell.style.backgroundColor = '#00ff00';
          configCell.innerHTML = 'YES';
%       } else {
          configCell.style.backgroundColor = '#ff0000';
          configCell.innerHTML = 'NO';
%       }
%     } elsif ( $type eq 'select' && $i->select_hash ) {
%       my %hash;
%       if ( ref($i->select_hash) eq 'ARRAY' ) {
%         tie %hash, 'Tie::IxHash', '' => '', @{ $i->select_hash };
%       } else {
%         tie %hash, 'Tie::IxHash', '' => '', %{ $i->select_hash };
%       }
        configCell.innerHTML = <% $conf->exists($i->key, $agentnum) ? $hash{ $conf->config($i->key, $agentnum) } : '' |js_string %>;

%     } elsif ( $type eq 'text' || $type eq 'select' ) {
        configCell.innerHTML = <% $conf->exists($i->key, $agentnum) ? $conf->config($i->key, $agentnum) : '' |js_string %>;
%     } elsif ( $type =~ /^select-(part_svc|part_pkg|pkg_class)$/ && ! $i->multiple ) {
        configCell.innerHTML =
          <% $conf->config($i->key, $agentnum) |js_string %>
%# + ': ' +
%#          <% &{ $i->option_sub }( $conf->config($i->key, $agentnum) ) |js_string %>;
%     } elsif ( $type eq 'select-sub' ) {
        configCell.innerHTML =
          <% $conf->config($i->key, $agentnum) |js_string %> + ': ' +
          <% &{ $i->option_sub }( $conf->config($i->key, $agentnum) ) |js_string %>;
%     } else {
        //alert('unknown type <% $type %>');
        window.top.location.reload();
%     }

%     $n++;
%   }
    parent.cClick();
  </SCRIPT>
  </BODY></HTML>
