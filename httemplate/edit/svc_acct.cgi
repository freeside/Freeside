<% include('/elements/header.html', "$action $svc account") %>

<% include('/elements/error.html') %>

% if ( $cust_main ) { 

  <% include( '/elements/small_custview.html', $cust_main, '', 1,
              popurl(2) . "view/cust_main.cgi") %>
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

Service # <% $svcnum ? "<B>$svcnum</B>" : " (NEW)" %><BR>

<% ntable("#cccccc",2) %>

<TR>
  <TD ALIGN="right">Service</TD>
  <TD BGCOLOR="#eeeeee"><% $part_svc->svc %></TD>
</TR>

<TR>
  <TD ALIGN="right">Username</TD>
  <TD>
    <INPUT TYPE="text" NAME="username" VALUE="<% $username %>" SIZE=<% $ulen2 %> MAXLENGTH=<% $ulen %>>
  </TD>
</TR>

%if ( $part_svc->part_svc_column('_password')->columnflag ne 'F' ) {
<TR>
  <TD ALIGN="right">Password</TD>
  <TD>
    <INPUT TYPE="text" NAME="clear_password" VALUE="<% $password %>" SIZE=<% $pmax2 %> MAXLENGTH=<% $pmax %>>
    <INPUT TYPE="button" VALUE="Generate" onclick="randomPass();">
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
%


  <TR>
    <TD ALIGN="right">Security phrase</TD>
    <TD>
      <INPUT TYPE="text" NAME="sec_phrase" VALUE="<% $sec_phrase %>" SIZE=32>
      (for forgotten passwords)
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
%


  <TR>
    <TD ALIGN="right">Domain</TD>
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
      <TD ALIGN="right">Aliases</TD>
      <TD><INPUT TYPE="text" NAME="cgp_aliases" VALUE="<% $svc_acct->cgp_aliases %>"></TD>
    </TR>

% } else {
    <INPUT TYPE="hidden" NAME="cgp_aliases" VALUE="<% $svc_acct->cgp_aliases %>">
% }


<% include('/elements/tr-select-svc_pbx.html',
             'curr_value' => $svc_acct->pbxsvc,
             'part_svc'   => $part_svc,
             'cust_pkg'   => $cust_pkg,
          )
%>

%#pop
%my $popnum = $svc_acct->popnum || 0;
%if ( $part_svc->part_svc_column('popnum')->columnflag eq 'F' ) {
%


  <INPUT TYPE="hidden" NAME="popnum" VALUE="<% $popnum %>">
% } else { 


  <TR>
    <TD ALIGN="right">Access number</TD>
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
    <TD ALIGN="right">Real Name</TD>
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
    <TD ALIGN="right">Home directory</TD>
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
    <TD ALIGN="right">Shell</TD>
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


% if ( $communigate
%      && $part_svc->part_svc_column('cgp_type')->columnflag ne 'F' )
% {

% # settings

  <TR>
    <TD ALIGN="right">Mailbox type</TD>
    <TD>
      <SELECT NAME="cgp_type">
%       foreach my $option (qw( MultiMailbox TextMailbox MailDirMailbox
%                               AGrade BGrade CGrade                    )) {
          <OPTION VALUE="<% $option %>"
                  <% $option eq $svc_acct->cgp_type() ? 'SELECTED' : '' %>
          ><% $option %>
%       }
      </SELECT>
    </TD>
  </TR>

% } else {
    <INPUT TYPE="hidden" NAME="cgp_type" VALUE="<% $svc_acct->cgp_type() %>">
% }


% #false laziness w/svc_domain
% if ( $communigate
%      && $part_svc->part_svc_column('cgp_accessmodes')->columnflag ne 'F' )
% {

  <TR>
    <TD ALIGN="right">Enabled services</TD>
    <TD>
      <% include( '/elements/communigate_pro-accessmodes.html',
                    'curr_value' => $svc_acct->cgp_accessmodes,
                )
      %>
    </TD>
  </TR>

% } else {
    <INPUT TYPE="hidden" NAME="cgp_accessmodes" VALUE="<% $svc_acct->cgp_accessmodes() |h %>">
% }


% if ( $part_svc->part_svc_column('quota')->columnflag eq 'F' ) { 
  <INPUT TYPE="hidden" NAME="quota" VALUE="<% $svc_acct->quota %>">
% } else {
%   my $quota_label = $communigate ? 'Mail storage limit' : 'Quota';
    <TR>
      <TD ALIGN="right"><% $quota_label %></TD>
      <TD><INPUT TYPE="text" NAME="quota" VALUE="<% $svc_acct->quota %>"></TD>
    </TR>
% }

% tie my %cgp_label, 'Tie::IxHash',
%   'file_quota'   => 'File storage limit',
%   'file_maxnum'  => 'Number of files limit',
%   'file_maxsize' => 'File size limit',
% ;
%
% foreach my $key (keys %cgp_label) {
%
%   if ( !$communigate || $part_svc->part_svc_column($key)->columnflag eq 'F' ){
      <INPUT TYPE="hidden" NAME="<%$key%>" VALUE="<% $svc_acct->$key() |h %>">
%   } else {

      <TR>
        <TD ALIGN="right"><% $cgp_label{$key} %></TD>
        <TD><INPUT TYPE="text" NAME="<% $key %>" VALUE="<% $svc_acct->$key() |h %>"></TD>
      </TR>

%   }
% }

% if ( $communigate ) {

%  #preferences

  <% include('/elements/tr-checkbox.html',
               'label'      => 'Password recovery',
               'field'      => 'password_recover',
               'curr_value' => $svc_acct->password_recover,
               'value'      => 'Y',
            )
  %>

  <% include('/elements/tr-select.html',
               'label'      => 'Allowed mail rules',
               'field'      => 'cgp_rulesallowed',
               'options'    => [ '', 'No', 'Filter Only', 'All But Exec', 'Any' ],
               'labels'     => {
                                 '' => 'default (No)', #No always the default?
                               },
               'curr_value' => $svc_acct->cgp_rulesallowed,
            )
  %>

  <% include('/elements/tr-checkbox.html',
               'label'      => 'RPOP modifications',
               'field'      => 'cgp_rpopallowed',
               'curr_value' => $svc_acct->cgp_rpopallowed,
               'value'      => 'Y',
            )
  %>

  <% include('/elements/tr-checkbox.html',
               'label'      => 'Accepts mail to "all"',
               'field'      => 'cgp_mailtoall',
               'curr_value' => $svc_acct->cgp_mailtoall,
               'value'      => 'Y',
            )
  %>

  <% include('/elements/tr-checkbox.html',
               'label'      => 'Add trailer to sent mail',
               'field'      => 'cgp_addmailtrailer',
               'curr_value' => $svc_acct->cgp_addmailtrailer,
               'value'      => 'Y',
            )
  %>

%# false laziness w/svc_domain acct_def
  <TR>
    <TD ALIGN="right">Message delete method</TD>
    <TD>
      <SELECT NAME="cgp_deletemode">
%       for ( 'Move To Trash', 'Immediately', 'Mark' ) {
          <OPTION VALUE="<% $_ %>"
                  <% $_ eq $svc_acct->cgp_deletemode ? 'SELECTED' : '' %>
          ><% $_ %>
%       }
      </SELECT>
    </TD>
  </TR>

  <TR>
    <TD ALIGN="right">On logout remove trash</TD>
    <TD><INPUT TYPE="text" NAME="cgp_emptytrash" VALUE="<% $svc_acct->cgp_emptytrash %>"></TD>
  </TR>

%#XXX language, time zone, layout, printo style, send read receipts
%#XXX vacation message, redirect all mail, mail rules

% } else {

  <INPUT TYPE="hidden" NAME="cgp_deletemode" VALUE="<% $svc_acct->cgp_deletemode %>">
  <INPUT TYPE="hidden" NAME="cgp_emptytrash" VALUE="<% $svc_acct->cgp_emptytrash %>">

% }


% if ( $part_svc->part_svc_column('slipip')->columnflag =~ /^[FA]$/ ) { 
  <INPUT TYPE="hidden" NAME="slipip" VALUE="<% $svc_acct->slipip %>">
% } else { 
  <TR>
    <TD ALIGN="right">IP</TD>
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
    <TD ALIGN="right"><% $label{$uf} %> remaining</TD>
    <TD><INPUT TYPE="text" NAME="<% $uf %>" VALUE="<% $svc_acct->$uf %>">(blank disables)</TD>
  </TR>
  <TR>
    <TD ALIGN="right"><% $label{$uf} %> threshold</TD>
    <TD><INPUT TYPE="text" NAME="<% $tf %>" VALUE="<% $svc_acct->$tf %>">(blank disables)</TD>
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
  <TD ALIGN="right">RADIUS groups</TD>
% if ( $part_svc->part_svc_column('usergroup')->columnflag eq 'F' ) { 


    <TD BGCOLOR="#eeeeee"><% join('<BR>', @groups) %></TD>
% } else { 


    <TD><% FS::svc_acct::radius_usergroup_selector( \@groups ) %></TD>
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

<INPUT TYPE="submit" VALUE="Submit">

</FORM>

<% include('/elements/footer.html') %>

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

#fixed radius groups always override & display
if ( $part_svc->part_svc_column('usergroup')->columnflag eq 'F' ) {
  @groups = split(',', $part_svc->part_svc_column('usergroup')->columnvalue);
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

</%init>
