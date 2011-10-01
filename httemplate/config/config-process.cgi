%if ( scalar(@error) ) {
%
%  my $url = popurl(1)."config.cgi";
%  if ( length($cgi->query_string) > 1920 ) { #stupid IE 2083 URL limit
%
%    my $session = int(rand(4294967296)); #XXX
%    my $pref = new FS::access_user_pref({
%      'usernum'    => $FS::CurrentUser::CurrentUser->usernum,
%      'prefname'   => "redirect$session",
%      'prefvalue'  => $cgi->query_string,
%      'expiration' => time + 3600, #1h?  1m?
%    });
%    my $pref_error = $pref->insert;
%    if ( $pref_error ) {
%      die "FATAL: couldn't even set redirect cookie: $pref_error".
%          " attempting to set redirect$session to ". $cgi->query_string."\n";
%    }
%
<% $cgi->redirect("$url?redirect=$session") %>
%
%  } else {
%
<% $cgi->redirect("$url?". $cgi->query_string ) %>
%
%  }
%
%} else {
<& /elements/header-popup.html, 'Configuration set' &>
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
%     } elsif ( $type =~ /^select-(part_svc|part_pkg|pkg_class|agent)$/ && ! $i->multiple ) {
%       my $table = $1;
%       my $namecol = $namecol{$table};
%       my $pkey = dbdef->table($table)->primary_key;
%       my $key = $conf->config($i->key, $agentnum);
%       my $record = qsearchs($table, { $pkey => $key });
%       my $value = $record ? "$key: ".$record->$namecol() : $key;
        configCell.innerHTML = <% $value |js_string %>;
%     } elsif ( $type eq 'select-sub' && ! $i->multiple ) {
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
</BODY>
</HTML>
%}
<%once>
#false laziness w/config-view.cgi
my %namecol = (
  'part_svc'  => 'svc',
  'part_pkg'  => 'pkg',
  'pkg_class' => 'classname',
  'agent'     => 'agent',
);
</%once>
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
die "access denied\n" unless $curuser->access_right('Configuration');

my $locale = $cgi->param('locale') || '';

my $conf = new FS::Conf { 'locale' => $locale };

if ( $conf->exists('disable_settings_changes') ) {
  my @changers = split(/\s*,\s*/, $conf->config('disable_settings_changes'));
  my %changers = map { $_=>1 } @changers;
  unless ( $changers{$curuser->username} ) {
    errorpage_popup("Disabled in web demo");
    die "shouldn't be reached";
  }
}

$FS::Conf::DEBUG = 1;
my @config_items = grep { $_->key != ~/^invoice_(html|latex|template)/ }
                        $conf->config_items;
my %confitems = map { $_->key => $_ } $conf->config_items;

my $agentnum = $cgi->param('agentnum');
my $key = $cgi->param('key');
my $i = $confitems{$key};

my @error = ();
my @touch = ();
my @delete = ();
my $n = 0;
foreach my $type ( ref($i->type) ? @{$i->type} : $i->type ) {
  if ( $type eq '' ) {
  } elsif ( $type eq 'textarea' ) {
    if ( $cgi->param($i->key.$n) ne '' ) {
      my $value = $cgi->param($i->key.$n);
      $value =~ s/\r\n/\n/g; #browsers?
      my $error = &{$i->validate}($value, $n) if $i->validate;
      push @error, $error if $error;
      $conf->set($i->key, $value, $agentnum);
    } else {
      $conf->delete($i->key, $agentnum);
    }
  } elsif ( $type eq 'binary' || $type eq 'image' ) {
    if ( defined($cgi->param($i->key.$n)) && $cgi->param($i->key.$n) ) {
      my $fh = $cgi->upload($i->key.$n);
      my $error = &{$i->validate}($fh, $n) if $i->validate;
      push @error, $error if $error;
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
    or ( $type =~ /^select(-(sub|part_svc|part_pkg|pkg_class|agent))?$/
         || $i->multiple )
  ) {
    if ( scalar(@{[ $cgi->param($i->key.$n) ]}) ) {
      my $error = &{$i->validate}([ $cgi->param($i->key.$n) ], $n) if $i->validate;
      push @error, $error if $error;
      $conf->set($i->key, join("\n", @{[ $cgi->param($i->key.$n) ]} ), $agentnum);
    } else {
      $conf->delete($i->key, $agentnum);
    }
  } elsif ( $type =~ /^(text|select(-(sub|part_svc|part_pkg|pkg_class|agent))?)$/ ) {
    if ( $cgi->param($i->key.$n) ne '' ) {
      my $error = &{$i->validate}($cgi->param($i->key.$n), $n) if $i->validate;
      push @error, $error if $error;
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

if (scalar(@error)) {
  $cgi->param('error', join(' ', @error));
}

</%init>
