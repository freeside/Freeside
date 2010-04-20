<% include('/elements/header.html', "$action $svc", '') %>

<% include('/elements/error.html') %>

<FORM ACTION="<% $p1 %>process/svc_domain.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="svcnum" VALUE="<% $svcnum %>">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">
<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $svcpart %>">

<% ntable("#cccccc",2) %>

<TR>
  <TD ALIGN="right">Domain</TD>
  <TD>
%   if ( !$svcnum || $conf->exists('svc_domain-edit_domain') ) {
      <INPUT TYPE="text" NAME="domain" VALUE="<% $domain %>" SIZE=28 MAXLENGTH=63>
%   } else {
      <B><% $domain %></B>
%   }

% if ($export) {
<BR>
Available top-level domains: <% $export->option('tlds') %>
</TR>

<TR>
<INPUT TYPE="radio" NAME="action" VALUE="N"<% $kludge_action eq 'N' ? ' CHECKED' : '' %>>Register at <% $registrar->{'name'} %>
<BR>

<INPUT TYPE="radio" NAME="action" VALUE="M"<% $kludge_action eq 'M' ? ' CHECKED' : '' %>>Transfer to <% $registrar->{'name'} %>
<BR>

<INPUT TYPE="radio" NAME="action" VALUE="I"<% $kludge_action eq 'I' ? ' CHECKED' : '' %>>Registered elsewhere

</TR>

% }
  </TD>
</TR>

% if ( $communigate ) {
  <TR>
    <TD ALIGN="right">Administrator domain</TD>
    <TD>
      <% include('/elements/select-domain.html',
                   'element_name' => 'parent_svcnum',
                   'curr_value'   => $svc_domain->parent_svcnum,
                   'empty_label'  => '(none)',
                )
      %>
    </TD>
  </TR>
% } else {
  <INPUT TYPE="hidden" NAME="parent_svcnum" VALUE="<% $svc_domain->parent_svcnum %>">
% }

% if ( $communigate
%      && $part_svc->part_svc_column('cgp_aliases')->columnflag !~ /^[FA]$/ ) {

    <TR>
      <TD ALIGN="right">Aliases</TD>
      <TD><INPUT TYPE="text" NAME="cgp_aliases" VALUE="<% $svc_domain->cgp_aliases %>"></TD>
    </TR>

% } else {
    <INPUT TYPE="hidden" NAME="cgp_aliases" VALUE="<% $svc_domain->cgp_aliases %>">
% }

% if ( $part_svc->part_svc_column('max_accounts')->columnflag =~ /^[FA]$/ ) {
    <INPUT TYPE="hidden" NAME="max_accounts" VALUE="<% $svc_domain->max_accounts %>">
% } else {
    <TR>
      <TD ALIGN="right">Maximum number of accounts</TD>
      <TD>
        <INPUT TYPE="text" NAME="max_accounts" SIZE=5 MAXLENGTH=6 VALUE="<% $svc_domain->max_accounts %>">
      </TD>
    </TR>
% }

% if ( $communigate
%      && $part_svc->part_svc_column('cgp_accessmodes')->columnflag ne 'F' )
% {

  <TR>
    <TD ALIGN="right">Enabled services</TD>
    <TD>
      <% include( '/elements/communigate_pro-accessmodes.html',
                    'curr_value' => $svc_domain->cgp_accessmodes,
                )
      %>
    </TD>
  </TR>

% } else {
    <INPUT TYPE="hidden" NAME="cgp_accessmodes" VALUE="<% $svc_domain->cgp_accessmodes() |h %>">
% }

% if ( $communigate
%      && $part_svc->part_svc_column('trailer')->columnflag ne 'F' )
% {

  <TR>
    <TD ALIGN="right">Mail trailer</TD>
    <TD>
      <TEXTAREA NAME="trailer" ROWS=5 COLS=60><% $svc_domain->trailer() |h %></TEXTAREA>
    </TD>
  </TR>

% } else {
    <INPUT TYPE="hidden" NAME="trailer" VALUE="<% $svc_domain->trailer() |h %>">
% }


</TABLE>
<BR>

% if ( $communigate ) {

Account defaults
<% ntable("#cccccc",2) %>

  <% include('/elements/tr-checkbox.html',
               'label'      => 'Password modification',
               'field'      => 'acct_def_password_selfchange',
               'curr_value' => $svc_domain->acct_def_password_selfchange,
               'value'      => 'Y',
            )
  %>

  <% include('/elements/tr-checkbox.html',
               'label'      => 'Password recovery',
               'field'      => 'acct_def_password_recover',
               'curr_value' => $svc_domain->acct_def_password_recover,
               'value'      => 'Y',
            )
  %>

  <TR>
    <TD ALIGN="right">Enabled services
    </TD>
    <TD><% include('/elements/communigate_pro-accessmodes.html',
                     'element_name_prefix' => 'acct_def_cgp_accessmodes_',
                     'curr_value' => $svc_domain->acct_def_cgp_accessmodes,
                  )
        %>
    </TD>
  </TR>

  <% include('/elements/tr-input-text.html',
               'label'      => 'Mail storage limit',
               'field'      => 'acct_def_quota',
               'curr_value' => $svc_domain->acct_def_quota,
            )
  %>
  <% include('/elements/tr-input-text.html',
               'label'      => 'File storage limit',
               'field'      => 'acct_def_file_quota',
               'curr_value' => $svc_domain->acct_def_file_quota,
            )
  %>
  <% include('/elements/tr-input-text.html',
               'label'      => 'Files limit',
               'field'      => 'acct_def_file_maxnum',
               'curr_value' => $svc_domain->acct_def_file_maxnum,
            )
  %>
  <% include('/elements/tr-input-text.html',
               'label'      => 'File size limit',
               'field'      => 'acct_def_file_maxsize',
               'curr_value' => $svc_domain->acct_def_file_maxsize,
            )
  %>

  <% include('/elements/tr-select.html',
               'label'      => 'Allowed mail rules',
               'field'      => 'acct_def_cgp_rulesallowed',
               'options'    => [ '', 'No', 'Filter Only', 'All But Exec', 'Any' ],
               'labels'     => {
                                 '' => 'default (No)', #No always the default?
                               },
               'curr_value' => $svc_domain->acct_def_cgp_rulesallowed,
            )
  %>

  <% include('/elements/tr-checkbox.html',
               'label'      => 'RPOP modifications',
               'field'      => 'acct_def_cgp_rpopallowed',
               'curr_value' => $svc_domain->acct_def_cgp_rpopallowed,
               'value'      => 'Y',
            )
  %>

  <% include('/elements/tr-checkbox.html',
               'label'      => 'Accepts mail to "all"',
               'field'      => 'acct_def_cgp_mailtoall',
               'curr_value' => $svc_domain->acct_def_cgp_mailtoall,
               'value'      => 'Y',
            )
  %>

  <% include('/elements/tr-checkbox.html',
               'label'      => 'Add trailer to sent mail',
               'field'      => 'acct_def_cgp_addmailtrailer',
               'curr_value' => $svc_domain->acct_def_cgp_addmailtrailer,
               'value'      => 'Y',
            )
  %>

%# false laziness w/svc_acct acct_def
  <TR>
    <TD ALIGN="right">Message delete method</TD>
    <TD>
      <SELECT NAME="acct_def_cgp_deletemode">
%       for ( 'Move To Trash', 'Immediately', 'Mark' ) {
          <OPTION VALUE="<% $_ %>"
                  <% $_ eq $svc_domain->acct_def_cgp_deletemode ? 'SELECTED' : '' %>
          ><% $_ %>
%       }
      </SELECT>
    </TD>
  </TR>

  <% include('/elements/tr-input-text.html',
               'label'      => 'On logout remove trash',
               'curr_value' => $svc_domain->acct_def_cgp_emptytrash,
            )
  %>
  <% include('/elements/tr-select.html',
               'label'      => 'Language',
               'field'      => 'acct_def_cgp_language',
               'options'    => [ '', qw( English Arabic Chinese Dutch French German Hebrew Italian Japanese Portuguese Russian Slovak Spanish Thai ) ],
               'labels'     => {
                                 '' => 'default (English)',
                               },
               'curr_value' => $svc_domain->acct_def_cgp_language,
            )
  %>

  <% include('/elements/tr-select.html',
               'label'      => 'Time zone',
               'field'      => 'acct_def_cgp_timezone',
               'options'    => [
                                 'HostOS',
                                 '(+0100) Algeria/Congo',
                                 '(+0200) Egypt/South Africa',
                                 '(+0300) Saudi Arabia',
                                 '(+0400) Oman',
                                 '(+0500) Pakistan',
                                 '(+0600) Bangladesh',
                                 '(+0700) Thailand/Vietnam',
                                 '(+0800) China/Malaysia',
                                 '(+0900) Japan/Korea',
                                 '(+1000) Queensland',
                                 '(+1100) Micronesia',
                                 '(+1200) Fiji',
                                 '(+1300) Tonga/Kiribati',
                                 '(+1400) Christmas Islands',
                                 '(-0100) Azores/Cape Verde',
                                 '(-0200) Fernando de Noronha',
                                 '(-0300) Argentina/Uruguay',
                                 '(-0400) Venezuela/Guyana',
                                 '(-0500) Haiti/Peru',
                                 '(-0600) Central America',
                                 '(-0700) Arisona',
                                 '(-0800) Adamstown',
                                 '(-0900) Marquesas Islands',
                                 '(-1000) Hawaii/Tahiti',
                                 '(-1100) Samoa',
                                 'Asia/Afghanistan',
                                 'Asia/India',
                                 'Asia/Iran',
                                 'Asia/Iraq',
                                 'Asia/Israel',
                                 'Asia/Jordan',
                                 'Asia/Lebanon',
                                 'Asia/Syria',
                                 'Australia/Adelaide',
                                 'Australia/East',
                                 'Australia/NorthernTerritory',
                                 'Europe/Central',
                                 'Europe/Eastern',
                                 'Europe/Moscow',
                                 'Europe/Western',
                                 'GMT (+0000)',
                                 'Newfoundland',
                                 'NewZealand/Auckland',
                                 'NorthAmerica/Alaska',
                                 'NorthAmerica/Atlantic',
                                 'NorthAmerica/Central',
                                 'NorthAmerica/Eastern',
                                 'NorthAmerica/Mountain',
                                 'NorthAmerica/Pacific',
                                 'Russia/Ekaterinburg',
                                 'Russia/Irkutsk',
                                 'Russia/Kamchatka',
                                 'Russia/Krasnoyarsk',
                                 'Russia/Magadan',
                                 'Russia/Novosibirsk',
                                 'Russia/Vladivostok',
                                 'Russia/Yakutsk',
                                 'SouthAmerica/Brasil',
                                 'SouthAmerica/Chile',
                                 'SouthAmerica/Paraguay',
                               ],
               'labels'     => {
                                 '' => 'default (HostOS)',
                               },
               'curr_value' => $svc_domain->acct_def_cgp_timezone,
            )
  %>

  <% include('/elements/tr-select.html',
               'label'      => 'Layout',
               'field'      => 'acct_def_cgp_skinname',
               'options'    => [ '', '***', 'GoldFleece', 'Skin2' ],
               'labels'     => {
                                 '' => 'default (***)',
                               },
               'curr_value' => $svc_domain->acct_def_cgp_skinname,
            )
  %>

  <% include('/elements/tr-select.html',
               'label'      => 'Pronto style',
               'field'      => 'acct_def_cgp_prontoskinname',
               'options'    =>  [ '', 'Pronto', 'Pronto-darkflame', 'Pronto-steel', 'Pronto-twilight', ],
               'curr_value' => $svc_domain->acct_def_cgp_prontoskinname,
            )
  %>

  <% include('/elements/tr-select.html',
               'label'      => 'Send read receipts',
               'field'      => 'acct_def_cgp_sendmdnmode',
               'options'    => [ '', 'Never', 'Manually', 'Automatically' ],
               'labels'     => {
                                 '' => 'default (Automatically)',
                               },
               'curr_value' => $svc_domain->acct_def_cgp_language,
            )
  %>

%              #XXX rules, archive rule, spam foldering rule(s)

</TABLE>
<BR>

% } else {

%   foreach my $f (qw( password_selfchange password_recover cgp_accessmodes
%                      quota file_quota file_maxnum file_maxsize
%                      cgp_rulesallowed cgp_rpopallowed cgp_mailtoall
%                      cgp_addmailtrailer
%                      cgp_deletemode cgp_emptytrash cgp_language
%                      cgp_timezone cgp_skinname cgp_sendmdnmode
%                 )) {
      <INPUT TYPE="hidden" NAME="acct_def_<%$f%>" VALUE="<% $svc_domain->get("acct_def_$f") %>">
%   }

% }

<INPUT TYPE="submit" VALUE="Submit">

</FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Provision customer service'); #something else more specific?

my $conf = new FS::Conf;

my($svcnum, $pkgnum, $svcpart, $kludge_action, $part_svc,
   $svc_domain);
if ( $cgi->param('error') ) {

  $svc_domain = new FS::svc_domain ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_domain')
  } );
  $svcnum = $svc_domain->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $kludge_action = $cgi->param('action');
  $part_svc = qsearchs('part_svc', { 'svcpart' => $svcpart } );
  die "No part_svc entry!" unless $part_svc;

} elsif ( $cgi->param('pkgnum') && $cgi->param('svcpart') ) { #adding

  $cgi->param('pkgnum') =~ /^(\d+)$/ or die 'unparsable pkgnum';
  $pkgnum = $1;
  $cgi->param('svcpart') =~ /^(\d+)$/ or die 'unparsable svcpart';
  $svcpart = $1;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $svc_domain = new FS::svc_domain({});

  $svcnum='';

  $svc_domain->set_default_and_fixed;

} else { #editing

  $kludge_action = '';
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "unparsable svcnum";
  $svcnum=$1;
  $svc_domain=qsearchs('svc_domain',{'svcnum'=>$svcnum})
    or die "Unknown (svc_domain) svcnum!";

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
    or die "Unknown (cust_svc) svcnum!";

  $pkgnum=$cust_svc->pkgnum;
  $svcpart=$cust_svc->svcpart;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

}
my $action = $svcnum ? 'Edit' : 'Add';

my $svc = $part_svc->getfield('svc');

my $communigate = scalar($part_svc->part_export('communigate_pro'));
                # || scalar($part_svc->part_export('communigate_pro_singledomain'));

# Find the first export that does domain registration
my @exports = grep $_->can('registrar'), $part_svc->part_export;
my $export = $exports[0];
# If we have a domain registration export, get the registrar object
my $registrar = $export ? $export->registrar : '';

my $otaker = getotaker;

my $domain = $svc_domain->domain;

my $p1 = popurl(1);

</%init>
