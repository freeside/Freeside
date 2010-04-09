<% include( '/elements/header.html', 'RADIUS Sessions') %>

% ###
% # and finally, display the thing
% ### 
%
% foreach my $part_export (
%   #grep $_->can('usage_sessions'), qsearch( 'part_export' )
%   qsearch( 'part_export', { 'exporttype' => 'sqlradius' } ),
%   qsearch( 'part_export', { 'exporttype' => 'sqlradius_withdomain' } )
% ) {
%   %user2svc_acct = ();
%
%   my $efields = tie my %efields, 'Tie::IxHash', %fields;
%   delete $efields{'framedipaddress'} if $part_export->option('hide_ip');
%   if ( $part_export->option('hide_data') ) {
%     delete $efields{$_} foreach qw(acctinputoctets acctoutputoctets);
%   }
%   if ( $part_export->option('show_called_station') ) {
%     $efields->Splice(1, 0,
%       'calledstationid' => {
%                              'name'   => 'Destination',
%                              'attrib' => 'Called-Station-ID',
%                              'fmt'    =>
%                                sub { length($_[0]) ? shift : '&nbsp'; },
%                              'align'  => 'left',
%                            },
%     );
%   }
%
%

    <% $part_export->exporttype %> to <% $part_export->machine %><BR>
    <% include( '/elements/table-grid.html' ) %>
%   my $bgcolor1 = '#eeeeee';
%   my $bgcolor2 = '#ffffff';
%   my $bgcolor;

    <TR>
%   foreach my $field ( keys %efields ) { 

      <TH CLASS="grid" BGCOLOR="#cccccc">
        <% $efields{$field}->{name} %><BR>
        <FONT SIZE=-2><% $efields{$field}->{attrib} %></FONT>
      </TH>

%   } 
  </TR>

%   foreach my $session (
%       @{ $part_export->usage_sessions( {
%            'stoptime_start'  => $beginning,
%            'stoptime_end'    => $ending,
%            'open_sessions'   => $open_sessions,
%            'starttime_start' => $starttime_beginning,
%            'starttime_end'   => $starttime_ending,
%            'svc_acct'        => $cgi_svc_acct,
%            'ip'              => $ip,
%            'prefix'          => $prefix, 
%          } )
%       }
%   ) {
%     if ( $bgcolor eq $bgcolor1 ) {
%       $bgcolor = $bgcolor2;
%     } else {
%       $bgcolor = $bgcolor1;
%     }

      <TR>
%     foreach my $field ( keys %efields ) { 
%       my $html = &{ $efields{$field}->{fmt} }( $session->{$field},
%                                                $session,
%                                                $part_export,
%                                              );
%       my $class = ( $html =~ /<TABLE/ ? 'inv' : 'grid' );

        <TD CLASS="<%$class%>" BGCOLOR="<% $bgcolor %>" ALIGN="<% $efields{$field}->{align} %>">
          <% $html %>
        </TD>
%     } 
  </TR>

%   } 

</TABLE>
<BR><BR>

% } 

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('List rating data');

###
# parse cgi params
###

#sort of false laziness w/cust_pay.cgi
my( $beginning, $ending ) = ( '', '' );
if ( $cgi->param('stoptime_beginning')
     && $cgi->param('stoptime_beginning') =~ /^([ 0-9\-\/\:\w]{0,54})$/ ) {
  $beginning = parse_datetime($1);
}
if ( $cgi->param('stoptime_ending')
     && $cgi->param('stoptime_ending') =~ /^([ 0-9\-\/\:\w]{0,54})$/ ) {
  $ending = parse_datetime($1); # + 86399;
}
if ( $cgi->param('begin') && $cgi->param('begin') =~ /^(\d+)$/ ) {
  $beginning = $1;
}
if ( $cgi->param('end') && $cgi->param('end') =~ /^(\d+)$/ ) {
  $ending = $1;
}

my $open_sessions = '';
if ( $cgi->param('open_sessions') =~ /^(\d*)$/ ) {
  $open_sessions = $1;
}

my( $starttime_beginning, $starttime_ending ) = ( '', '' );
if ( $cgi->param('starttime_beginning')
     && $cgi->param('starttime_beginning') =~ /^([ 0-9\-\/\:\w]{0,54})$/ ) {
  $starttime_beginning = parse_datetime($1);
}
if ( $cgi->param('starttime_ending')
     && $cgi->param('starttime_ending') =~ /^([ 0-9\-\/\:\w]{0,54})$/ ) {
  $starttime_ending = parse_datetime($1); # + 86399;
}

my $cgi_svc_acct = '';
if ( $cgi->param('svcnum') =~ /^(\d+)$/ ) {
  $cgi_svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $1 } );
} elsif ( $cgi->param('username') =~ /^([^@]+)\@([^@]+)$/ ) {
  my %search = { 'username' => $1 };
  my $svc_domain = qsearchs('svc_domain', { 'domain' => $2 } );
  if ( $svc_domain ) {
    $search{'domsvc'} = $svc_domain->svcnum;
  } else {
    delete $search{'username'};
  }
  $cgi_svc_acct = qsearchs( 'svc_acct', \%search )
    if keys %search;
} elsif ( $cgi->param('username') =~ /^(.+)$/ ) {
  $cgi_svc_acct = qsearchs( 'svc_acct', { 'username' => $1 } );
}

my $ip = '';
if ( $cgi->param('ip') =~ /^((\d+\.){3}\d+)$/ ) {
  $ip = $1;
}

my $prefix = $cgi->param('prefix');
$prefix =~ s/\D//g;
if ( $prefix =~ /^(\d+)$/ ) {
  $prefix = $1;
  $prefix = "011$prefix" unless $prefix =~ /^1/;
} else {
  $prefix = '';
}

###
# field formatting subroutines
###

my %user2svc_acct = ();
my $user_format = sub {
  my ( $user, $session, $part_export ) = @_;

  my $svc_acct = '';
  if ( exists $user2svc_acct{$user} ) {
    $svc_acct = $user2svc_acct{$user};
  } else {
    my %search = ();
    if ( $part_export->exporttype eq 'sqlradius_withdomain' ) {
      my $domain;
      if ( $user =~ /^([^@]+)\@([^@]+)$/ ) {
       $search{'username'} = $1;
       $domain = $2;
     } else {
       $search{'username'} = $user;
       $domain = $session->{'realm'};
     }
     my $svc_domain = qsearchs('svc_domain', { 'domain' => $domain } );
     if ( $svc_domain ) {
       $search{'domsvc'} = $svc_domain->svcnum;
     } else {
       delete $search{'username'};
     }
    } elsif ( $part_export->exporttype eq 'sqlradius' ) {
      $search{'username'} = $user;
    } else {
      die 'unknown export type '. $part_export->exporttype.
          " for $part_export\n";
    }
    if ( keys %search ) {
      my @svc_acct =
        grep { qsearchs( 'export_svc', {
                 'exportnum' => $part_export->exportnum,
                 'svcpart'   => $_->cust_svc->svcpart,
               } )
             } qsearch( 'svc_acct', \%search );
      if ( @svc_acct ) {
        warn 'multiple svc_acct records for user $user found; '.
             'using first arbitrarily'
          if scalar(@svc_acct) > 1;
        $user2svc_acct{$user} = $svc_acct = shift @svc_acct;
      }
    } 
  }

  if ( $svc_acct ) { 
    my $svcnum = $svc_acct->svcnum;
    qq(<A HREF="${p}view/svc_acct.cgi?$svcnum"><B>$user</B></A>);
  } else {
    "<B>$user</B>";
  }

};

my $customer_format = sub {
  my( $unused, $session ) = @_;
  return '&nbsp;' unless exists $user2svc_acct{$session->{'username'}};
  my $svc_acct = $user2svc_acct{$session->{'username'}};
  my $cust_pkg = $svc_acct->cust_svc->cust_pkg;
  return '&nbsp;' unless $cust_pkg;
  my $cust_main = $cust_pkg->cust_main;

  qq!<A HREF="${p}view/cust_main.cgi?!. $cust_main->custnum. '">'.
    $cust_pkg->cust_main->name. '</A>';
};

my $time_format = sub {
  my $time = shift;
  return '&nbsp;' if $time == 0;
  my $pretty = time2str('%T%P %a&nbsp;%b&nbsp;%o&nbsp;%Y', $time );
  $pretty =~ s/ (\d)(st|dn|rd|th)/$1$2/;
  $pretty;
};

my $duration_format = sub {
  my $seconds = shift;
  my $hour = int($seconds/3600);
  my $min = int( ($seconds%3600) / 60 );
  my $sec = $seconds%60;
  '<TABLE CLASS="inv" BORDER=0 CELLSPACING=0 CELLPADDING=0>'.
  '<TR><TD CLASS="inv" ALIGN="right">'.
     ( $hour ? "<B>$hour</B>h" : '&nbsp;' ).
   '</TD><TD CLASS="inv" ALIGN="right">'.
     ( ( $hour || $min ) ? "<B>$min</B>m" : '&nbsp;' ).
   '</TD><TD CLASS="inv" ALIGN="right">'.
     "<B>$sec</B>s".
  '</TD></TR></TABLE>';
};

my $octets_format = sub {
  my $octets = shift;
  my $megs = $octets / 1048576;
  sprintf('<B>%.3f</B>&nbsp;megs', $megs);
  #my $gigs = $octets / 1073741824
  #sprintf('<B>%.3f</B> gigabytes', $gigs);
};

###
# the fields
###

tie my %fields, 'Tie::IxHash', 
  'username'          => {
                           name    => 'User',
                           attrib  => 'UserName',
                           fmt     => $user_format,
                           align   => 'left',
                         },
  'realm'             => {
                           name    => 'Realm',
                           attrib  => 'Realm',
                           align   => 'left',
                         },
  'dummy'             => {
                           name    => 'Customer',
                           attrib  => '',
                           fmt     => $customer_format,
                           align   => 'left',
                         },
  'framedipaddress'   => {
                           name    => 'IP&nbsp;Address',
                           attrib  => 'Framed-IP-Address',
                           fmt     => sub { my $ip = shift;
                                            length($ip) ? $ip : '&nbsp';
                                          },
                           align   => 'right',
                         },
  'acctstarttime'     => {
                           name    => 'Start&nbsp;time',
                           attrib  => 'Acct-Start-Time',
                           fmt     => $time_format,
                           align   => 'left',
                         },
  'acctstoptime'      => {
                           name    => 'End&nbsp;time',
                           attrib  => 'Acct-Stop-Time',
                           fmt     => $time_format,
                           align   => 'left',
                         },
  'acctsessiontime'   => {
                           name    => 'Duration',
                           attrib  => 'Acct-Session-Time',
                           fmt     => $duration_format,
                           align   => 'right',
                         },
  'acctinputoctets'   => {
                           name    => 'Upload', # (from user)',
                           attrib  => 'Acct-Input-Octets',
                           fmt     => $octets_format,
                           align   => 'right',
                         },
  'acctoutputoctets'  => {
                           name    => 'Download', # (to user)',
                           attrib  => 'Acct-Output-Octets',
                           fmt     => $octets_format,
                           align   => 'right',
                         },
;
$fields{$_}->{fmt} ||= sub { length($_[0]) ? shift : '&nbsp'; }
  foreach keys %fields;

</%init>
