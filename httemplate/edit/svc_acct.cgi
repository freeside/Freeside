<& /elements/header.html, mt("$action [_1] account",$svc) &>

<& /elements/error.html &>

% if ( $cust_main ) { 

  <& /elements/small_custview.html, $cust_main, '', 1,
              popurl(2) . "view/cust_main.cgi" &>
  <BR>
% } 

<SCRIPT TYPE="text/javascript">
function randomPass() {
  var i=0;
  var pw_set='<% join('', 'a'..'z', 'A'..'Z', '0'..'9' ) %>';
  var pass='';
  while(i < 8) {
    i++;
    pass += pw_set.charAt(Math.floor(Math.random() * pw_set.length));
  }
  document.OneTrueForm.clear_password.value = pass;
}
</SCRIPT>

<FORM NAME="OneTrueForm" ACTION="<% $p1 %>process/svc_acct.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="svcnum" VALUE="<% $svcnum %>">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">
<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $svcpart %>">

% if ( $svcnum ) {
% my $svclabel = emt("Service #[_1]",$svcnum);
% $svclabel =~ s/$svcnum/<B>$svcnum<\/B>/;
<% $svclabel %>
% } else {
<% mt("Service # (NEW)") |h %>
% }
<BR>

<% ntable("#cccccc",2) %>

<TR>
  <TD ALIGN="right"><% mt('Service') |h %></TD>
  <TD BGCOLOR="#eeeeee"><% $part_svc->svc %></TD>
</TR>

<TR>
  <TD ALIGN="right"><% mt('Username') |h %></TD>
% if ( $svcnum && $conf->exists('svc_acct-no_edit_username') ) {
    <TD BGCOLOR="#eeeeee"><% $svc_acct->username() %></TD>
    <INPUT TYPE="hidden" NAME="username" VALUE="<% $username %>">
% } else {
    <TD>
      <INPUT TYPE="text" NAME="username" VALUE="<% $username %>" SIZE=<% $ulen2 %> MAXLENGTH=<% $ulen %>>
    </TD>
% }
</TR>

%if ( $part_svc->part_svc_column('_password')->columnflag ne 'F' ) {
<TR>
  <TD ALIGN="right"><% mt('Password') |h %></TD>
  <TD>
    <INPUT TYPE="text" NAME="clear_password" VALUE="<% $password %>" SIZE=<% $pmax2 %> MAXLENGTH=<% $pmax %>>
    <INPUT TYPE="button" VALUE="<% mt('Generate') |h %>" onclick="randomPass();">
  </TD>
</TR>
%}else{
    <INPUT TYPE="hidden" NAME="clear_password" VALUE="<% $password %>">
%}
<INPUT TYPE="hidden" NAME="_password_encoding" VALUE="<% $svc_acct->_password_encoding %>">
%
%my $sec_phrase = $svc_acct->sec_phrase;
%if ( $conf->exists('security_phrase') 
%  && $part_svc->part_svc_column('sec_phrase')->columnflag ne 'F' ) {

  <TR>
    <TD ALIGN="right"><% mt('Security phrase') |h %></TD>
    <TD>
      <INPUT TYPE="text" NAME="sec_phrase" VALUE="<% $sec_phrase %>" SIZE=32>
      (<% mt('for forgotten passwords') |h %>)
    </TD>
  </TD>
% } else { 

  <INPUT TYPE="hidden" NAME="sec_phrase" VALUE="<% $sec_phrase %>">
% } 
%
%#domain
%my $domsvc = $svc_acct->domsvc || 0;
%if ( $part_svc->part_svc_column('domsvc')->columnflag eq 'F' ) {
%

  <INPUT TYPE="hidden" NAME="domsvc" VALUE="<% $domsvc %>">
% } else { 
%
%  my %svc_domain = ();
%
%  if ( $domsvc ) {
%    my $svc_domain = qsearchs('svc_domain', { 'svcnum' => $domsvc, } );
%    if ( $svc_domain ) {
%      $svc_domain{$svc_domain->svcnum} = $svc_domain;
%    } else {
%      warn "unknown svc_domain.svcnum for svc_acct.domsvc: $domsvc";
%    }
%  }
%
%  %svc_domain = (%svc_domain,
%                 domain_select_hash FS::svc_acct('svcpart' => $svcpart,
%                                                 'pkgnum'  => $pkgnum,
%                                                )
%                );

  <TR>
    <TD ALIGN="right"><% mt('Domain') |h %></TD>
    <TD>
      <SELECT NAME="domsvc" SIZE=1>
% foreach my $svcnum (
%             sort { $svc_domain{$a} cmp $svc_domain{$b} }
%                  keys %svc_domain
%           ) {
%             my $svc_domain = $svc_domain{$svcnum};
%        

             <OPTION VALUE="<% $svcnum %>" <% $svcnum == $domsvc ? ' SELECTED' : '' %>><% $svc_domain{$svcnum} %>
% } 

      </SELECT>
    </TD>
  </TR>
% } 


% if ( $communigate ) {

    <TR>
      <TD ALIGN="right"><% mt('Aliases') |h %></TD>
      <TD><INPUT TYPE="text" NAME="cgp_aliases" VALUE="<% $svc_acct->cgp_aliases %>"></TD>
    </TR>

% } else {
    <INPUT TYPE="hidden" NAME="cgp_aliases" VALUE="<% $svc_acct->cgp_aliases %>">
% }


<& /elements/tr-select-svc_pbx.html,
             'curr_value' => $svc_acct->pbxsvc,
             'part_svc'   => $part_svc,
             'cust_pkg'   => $cust_pkg,
&>

%#pop
%my $popnum = $svc_acct->popnum || 0;
%if ( $part_svc->part_svc_column('popnum')->columnflag eq 'F' ) {
%

  <INPUT TYPE="hidden" NAME="popnum" VALUE="<% $popnum %>">
% } else { 

  <TR>
    <TD ALIGN="right"><% mt('Access number') |h %></TD>
    <TD><% FS::svc_acct_pop::popselector($popnum) %></TD>
  </TR>
% } 
% #uid/gid 
% foreach my $xid (qw( uid gid )) { 
%
%  if ( $part_svc->part_svc_column($xid)->columnflag =~ /^[FA]$/
%       || ! $conf->exists("svc_acct-edit_$xid")
%     ) {
%  
% if ( length($svc_acct->$xid()) ) { 

      <TR>
        <TD ALIGN="right"><% uc($xid) %></TD>
          <TD BGCOLOR="#eeeeee"><% $svc_acct->$xid() %></TD>
        <TD>
        </TD>
      </TR>
% } 
  
    <INPUT TYPE="hidden" NAME="<% $xid %>" VALUE="<% $svc_acct->$xid() %>">
% } else { 
  
    <TR>
      <TD ALIGN="right"><% uc($xid) %></TD>
      <TD>
        <INPUT TYPE="text" NAME="<% $xid %>" SIZE=8 MAXLENGTH=6 VALUE="<% $svc_acct->$xid() %>">
      </TD>
    </TR>
% } 
% } 
%
%#finger
%if ( $part_svc->part_svc_column('uid')->columnflag eq 'F'
%     && ! $svc_acct->finger ) { 
%

  <INPUT TYPE="hidden" NAME="finger" VALUE="">
% } else { 


  <TR>
    <TD ALIGN="right"><% mt('Real Name') |h %></TD>
    <TD>
      <INPUT TYPE="text" NAME="finger" VALUE="<% $svc_acct->finger %>">
    </TD>
  </TR>
% } 
%
%#dir
%if ( $part_svc->part_svc_column('dir')->columnflag eq 'F'
%     || !$curuser->access_right('Edit home dir')
%   ) { 


<INPUT TYPE="hidden" NAME="dir" VALUE="<% $svc_acct->dir %>">
% } else {


  <TR>
    <TD ALIGN="right"><% mt('Home directory') |h %></TD>
    <TD><INPUT TYPE="text" NAME="dir" VALUE="<% $svc_acct->dir %>"></TD>
  </TR>
% } 
%
%#shell
%my $shell = $svc_acct->shell;
%if ( $part_svc->part_svc_column('shell')->columnflag eq 'F'
%     || ( !$shell && $part_svc->part_svc_column('uid')->columnflag eq 'F' )
%   ) {
%

  <INPUT TYPE="hidden" NAME="shell" VALUE="<% $shell %>">
% } else { 


  <TR>
    <TD ALIGN="right"><% mt('Shell') |h %></TD>
    <TD>
      <SELECT NAME="shell" SIZE=1>
%
%           my($etc_shell);
%           foreach $etc_shell (@shells) {
%        

          <OPTION<% $etc_shell eq $shell ? ' SELECTED' : '' %>><% $etc_shell %>
% } 


      </SELECT>
    </TD>
  </TR>
% } 

<& svc_acct/communigate.html,
             'svc_acct'    => $svc_acct,
             'part_svc'    => $part_svc,
             'communigate' => $communigate,
&>

% if ( $part_svc->part_svc_column('slipip')->columnflag =~ /^[FA]$/ ) { 
  <INPUT TYPE="hidden" NAME="slipip" VALUE="<% $svc_acct->slipip %>">
% } else { 
  <TR>
    <TD ALIGN="right"><% mt('IP') |h %></TD>
    <TD><INPUT TYPE="text" NAME="slipip" VALUE="<% $svc_acct->slipip %>"></TD>
  </TR>
% } 

% my %label = ( seconds => 'Time',
%               upbytes => 'Upload bytes',
%               downbytes => 'Download bytes',
%               totalbytes => 'Total bytes',
%             );
% foreach my $uf (keys %label) {
%   my $tf = $uf . "_threshold";
%   if ( $curuser->access_right('Edit usage') ) { 
  <TR>
    <TD ALIGN="right"><% mt("[_1] remaining",$label{$uf}) |h %> </TD>
    <TD><INPUT TYPE="text" NAME="<% $uf %>" VALUE="<% $svc_acct->$uf %>">(<% mt('blank disables') |h %>)</TD>
  </TR>
  <TR>
    <TD ALIGN="right"><% mt("[_1] threshold",$label{$uf}) |h %> </TD>
    <TD><INPUT TYPE="text" NAME="<% $tf %>" VALUE="<% $svc_acct->$tf %>">(<% mt('blank disables') |h %>)</TD>
  </TR>
%   }else{
      <INPUT TYPE="hidden" NAME="<% $uf %>" VALUE="<% $svc_acct->$uf %>">
      <INPUT TYPE="hidden" NAME="<% $tf %>" VALUE="<% $svc_acct->$tf %>">
%   } 
% }
%
%foreach my $r ( grep { /^r(adius|[cr])_/ } fields('svc_acct') ) {
%  $r =~ /^^r(adius|[cr])_(.+)$/ or next; #?
%  my $a = $2;
%
% if ( $part_svc->part_svc_column($r)->columnflag =~ /^[FA]$/ ) { 

    <INPUT TYPE="hidden" NAME="<% $r %>" VALUE="<% $svc_acct->getfield($r) %>">
% } else { 

    <TR>
      <TD ALIGN="right"><% $FS::raddb::attrib{$a} %></TD>
      <TD><INPUT TYPE="text" NAME="<% $r %>" VALUE="<% $svc_acct->getfield($r) %>"></TD>
    </TR>
% } 
% } 


<TR>
  <TD ALIGN="right"><% mt('RADIUS groups') |h %></TD>
% if ( $part_svc_usergroup->columnflag eq 'F' ) { 
    <TD BGCOLOR="#eeeeee"><% join('<BR>', @groupnames) %></TD>
% } else { 
%   my $radius_group_selected = '';
%   if ( $svc_acct->svcnum ) {
%      $radius_group_selected = join(',',$svc_acct->radius_groups('NUMBERS'));
%   }
%   elsif ( !$svc_acct->svcnum && $part_svc_usergroup->columnflag eq 'D' ) {
%       $radius_group_selected = $part_svc_usergroup->columnvalue;
%   }
    <TD><& /elements/select-radius_group.html, 
                curr_value => $radius_group_selected,
                element_name => 'radius_usergroup',
        &>
    </TD>
% } 

</TR>
% foreach my $field ($svc_acct->virtual_fields) { 
% # If the flag is X, it won't even show up in $svc_acct->virtual_fields. 
% if ( $part_svc->part_svc_column($field)->columnflag ne 'F' ) { 

    <% $svc_acct->pvf($field)->widget('HTML', 'edit', $svc_acct->getfield($field)) %>
% } 
% } 
  
</TABLE>
<BR>

% if ( $captcha_url ) {
<IMG SRC="<% $captcha_url %>"><BR>
<% mt('Enter the word shown above:') |h %> <INPUT TYPE="text" NAME="captcha_response"><BR>
<BR>
% }

<INPUT TYPE="submit" VALUE="Submit">

</FORM>

<& /elements/footer.html &>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;
my @shells = $conf->config('shells');

my $curuser = $FS::CurrentUser::CurrentUser;

my($svcnum, $pkgnum, $svcpart, $part_svc, $svc_acct, @groups);
if ( $cgi->param('error') ) {

  $svc_acct = new FS::svc_acct ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_acct')
  } );
  $svcnum = $svc_acct->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $part_svc = qsearchs( 'part_svc', { 'svcpart' => $svcpart } );
  die "No part_svc entry for svcpart $svcpart!" unless $part_svc;
  @groups = $cgi->param('radius_usergroup');

} elsif ( $cgi->param('pkgnum') && $cgi->param('svcpart') ) { #adding

  $cgi->param('pkgnum') =~ /^(\d+)$/ or die 'unparsable pkgnum';
  $pkgnum = $1;
  $cgi->param('svcpart') =~ /^(\d+)$/ or die 'unparsable svcpart';
  $svcpart = $1;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $svc_acct = new FS::svc_acct({svcpart => $svcpart}); 

  $svcnum='';

  $svc_acct->password_recover('Y'); #default. hmm.

} else { #editing

  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "unparsable svcnum";
  $svcnum=$1;
  $svc_acct=qsearchs('svc_acct',{'svcnum'=>$svcnum})
    or die "Unknown (svc_acct) svcnum!";

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
    or die "Unknown (cust_svc) svcnum!";

  $pkgnum=$cust_svc->pkgnum;
  $svcpart=$cust_svc->svcpart;

  $part_svc = qsearchs( 'part_svc', { 'svcpart' => $svcpart } );
  die "No part_svc entry for svcpart $svcpart!" unless $part_svc;

  @groups = $svc_acct->radius_groups;

}

my $communigate = scalar($part_svc->part_export('communigate_pro'));
                # || scalar($part_svc->part_export('communigate_pro_singledomain'));

my( $cust_pkg, $cust_main ) = ( '', '' );
if ( $pkgnum ) {
  $cust_pkg = qsearchs('cust_pkg', { 'pkgnum' => $pkgnum } );
  $cust_main = $cust_pkg->cust_main;
}

unless ( $svcnum || $cgi->param('error') ) { #adding

  #set gecos
  if ($cust_main) {
    unless ( $part_svc->part_svc_column('uid')->columnflag eq 'F' ) {
      $svc_acct->setfield('finger',
        $cust_main->getfield('first') . " " . $cust_main->getfield('last')
      );
    }
  }

  $svc_acct->set_default_and_fixed( {
    #false laziness w/svc-acct::_fieldhandlers
    'usergroup' => sub { 
                         my( $self, $groups ) = @_;
                         if ( ref($groups) eq 'ARRAY' ) {
                           @groups = @$groups;
                           $groups;
                         } elsif ( length($groups) ) {
                           @groups = split(/\s*,\s*/, $groups);
                           [ @groups ];
                         } else {
                           @groups = ();
                           [];
                         }
                       }
  } );

}

my $part_svc_usergroup = $part_svc->part_svc_column('usergroup');
#fixed radius groups always override & display
my @groupnames; # only used for display of Fixed RADIUS groups
if ( $part_svc_usergroup->columnflag eq 'F' ) {
  @groups = split(',',$part_svc_usergroup->columnvalue);
  @groupnames = map { $_->long_description } 
                    qsearch({ 'table'         => 'radius_group',
                           'extra_sql'     => "where groupnum in (".$part_svc_usergroup->columnvalue.")",
                        }) if length($part_svc_usergroup->columnvalue);
}

my $action = $svcnum ? 'Edit' : 'Add';

my $svc = $part_svc->getfield('svc');

my $otaker = getotaker;

my $username = $svc_acct->username;

my $password = '';
if ( $cgi->param('error') ) {
  $password = $cgi->param('clear_password');
} elsif ( $svcnum ) {
  my $password_encryption = $svc_acct->_password_encryption;
  if ( $password = $svc_acct->get_cleartext_password ) {
    $password = '*HIDDEN*' unless $conf->exists('showpasswords');
  } elsif( $svc_acct->_password and $password_encryption ne 'plain' ) {
    $password = "(".uc($password_encryption)." encrypted)";
  }
}

my $ulen = 
  $conf->exists('usernamemax')
  ? $conf->config('usernamemax')
  : dbdef->table('svc_acct')->column('username')->length;
my $ulen2 = $ulen+2;

my $pmax = max($conf->config('passwordmax') || 13);
my $pmax2 = $pmax+2;

my $p1 = popurl(1);

sub max {
  (sort(@_))[-1]
}

my $captcha_url;
my ($export_google) = $part_svc->part_export('acct_google');
if ( $export_google ) {
  my $error = $export_google->auth_error;
  if ( $error ) {
    if ( $error->{'captcha_url'} ) {
      $captcha_url = $error->{'captcha_url'};
    }
    else {
      $cgi->param('error', $error->{'message'});
    }
  } #if $error
}

</%init>
