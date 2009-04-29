<% include('/elements/header.html', "Web Hosting $action") %>

<% include('/elements/error.html') %>

<FORM ACTION="<%$p1%>process/svc_www.cgi" METHOD=POST>

<INPUT TYPE="hidden" NAME="svcnum" VALUE="<% $svcnum %>">
Service #<B><% $svcnum ? $svcnum : "(NEW)" %></B>
<BR><BR>

<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">

<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $svcpart %>">

% my $recnum  = $svc_www->recnum;
% my $usersvc = $svc_www->usersvc;

<% &ntable("#cccccc",2) %>

  <TR>
    <TD ALIGN="right">Zone</TD>
    <TD>
      <SELECT NAME="recnum" SIZE=1>
%       foreach $_ (keys %arec) {
          <OPTION<% $_ eq $recnum ? " SELECTED" : "" %> VALUE="<%$_%>"><%$arec{$_}%>
%       }
      </SELECT>
    </TD>
  </TR>

% if ( $part_svc->part_svc_column('usersvc')->columnflag ne 'F'
%     || $part_svc->part_svc_column('usersvc')->columnvalue !~ /^\s*$/) {
    <TR>
      <TD ALIGN="right">Username</TD>
      <TD>
        <SELECT NAME="usersvc" SIZE=1>
          <OPTION VALUE="">(none)
%         foreach $_ (keys %svc_acct) {
            <OPTION<% ($_ eq $usersvc) ? " SELECTED" : "" %> VALUE="<%$_%>"><% $svc_acct{$_} %>
%         }
        </SELECT>
      </TD>
    </TR>
% }

% if ( $part_svc->part_svc_column('config')->columnflag ne 'F' &&
%      $FS::CurrentUser::CurrentUser->access_right('Edit www config') ) {
    <TR>
      <TD ALIGN="right">Config lines</TD>
      <TD>
        <TEXTAREA NAME="config" rows="15" cols="80"><% $config |h %></TEXTAREA>
      </TD>
    </TR>
% } else {
    <INPUT TYPE="hidden" NAME="config" VALUE="<% $config |h %>">
%}

% foreach my $field ($svc_www->virtual_fields) {
%   if ( $part_svc->part_svc_column($field)->columnflag ne 'F' ) {
%     # If the flag is X, it won't even show up in $svc_acct->virtual_fields.
      <% $svc_www->pvf($field)->widget( 'HTML', 'edit',
                                        $svc_www->getfield($field)
                                      )
      %>
%   }
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

my( $svcnum,  $pkgnum, $svcpart, $part_svc, $svc_www, $config );

if ( $cgi->param('error') ) {

  $svc_www = new FS::svc_www ( {
    map { $_, scalar($cgi->param($_)) } fields('svc_www')
  } );
  $svcnum = $svc_www->svcnum;
  $pkgnum = $cgi->param('pkgnum');
  $svcpart = $cgi->param('svcpart');
  $config = $cgi->param('config');
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

} elsif ( $cgi->param('pkgnum') && $cgi->param('svcpart') ) { #adding

  $cgi->param('pkgnum') =~ /^(\d+)$/ or die 'unparsable pkgnum';
  $pkgnum = $1;
  $cgi->param('svcpart') =~ /^(\d+)$/ or die 'unparsable svcpart';
  $svcpart = $1;

  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

  $svc_www = new FS::svc_www { svcpart => $svcpart };

  $svcnum='';

  $svc_www->set_default_and_fixed;

} else { #editing

  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "unparsable svcnum";
  $svcnum=$1;
  $svc_www=qsearchs('svc_www',{'svcnum'=>$svcnum})
    or die "Unknown (svc_www) svcnum!";

  my($cust_svc)=qsearchs('cust_svc',{'svcnum'=>$svcnum})
    or die "Unknown (cust_svc) svcnum!";

  $pkgnum  = $cust_svc->pkgnum;
  $svcpart = $cust_svc->svcpart;
  $config  = $svc_www->config;
  
  $part_svc=qsearchs('part_svc',{'svcpart'=>$svcpart});
  die "No part_svc entry!" unless $part_svc;

}
my $action = $svc_www->svcnum ? 'Edit' : 'Add';

my( %svc_acct, %arec );
if ($pkgnum) {

  my @u_acct_svcparts;
  foreach my $svcpart (
    map { $_->svcpart } qsearch( 'part_svc', { 'svcdb' => 'svc_acct' } )
  ) {
    next if $conf->exists('svc_www-usersvc_svcpart')
            && ! grep { $svcpart == $_ }
                      $conf->config('svc_www-usersvc_svcpart');
    push @u_acct_svcparts, $svcpart;
  }

  my($cust_pkg)=qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  my($custnum)=$cust_pkg->getfield('custnum');
  my($i_cust_pkg);
  foreach $i_cust_pkg ( qsearch('cust_pkg',{'custnum'=>$custnum}) ) {
    my($cust_pkgnum)=$i_cust_pkg->getfield('pkgnum');
    my($acct_svcpart);
    foreach $acct_svcpart (@u_acct_svcparts) {   #now find the corresponding 
                                              #record(s) in cust_svc ( for this
                                              #pkgnum ! )
      my($i_cust_svc);
      foreach $i_cust_svc ( qsearch('cust_svc',{'pkgnum'=>$cust_pkgnum,'svcpart'=>$acct_svcpart}) ) {
        my($svc_acct)=qsearchs('svc_acct',{'svcnum'=>$i_cust_svc->getfield('svcnum')});
        $svc_acct{$svc_acct->getfield('svcnum')}=
          $svc_acct->cust_svc->part_svc->svc. ': '. $svc_acct->email;
      }  
    }
  }


  my($d_part_svc,@d_acct_svcparts);
  foreach $d_part_svc ( qsearch('part_svc',{'svcdb'=>'svc_domain'}) ) {
    push @d_acct_svcparts,$d_part_svc->getfield('svcpart');
  }

  foreach $i_cust_pkg ( qsearch( 'cust_pkg', { 'custnum' => $custnum } ) ) {
    my $cust_pkgnum = $i_cust_pkg->pkgnum;

    foreach my $acct_svcpart (@d_acct_svcparts) {

      foreach my $i_cust_svc (
        qsearch( 'cust_svc', { 'pkgnum'  => $cust_pkgnum,
                               'svcpart' => $acct_svcpart } )
      ) {
        my $svc_domain =
          qsearchs( 'svc_domain', { 'svcnum' => $i_cust_svc->svcnum } );

        my $extra_sql = "AND ( rectype = 'A' OR rectype = 'CNAME' )";
        unless ( $conf->exists('svc_www-enable_subdomains') ) {
          $extra_sql .= " AND ( reczone = '\@' OR reczone = '".
                        $svc_domain->domain. ".' )";
        }

        foreach my $domain_rec (
          qsearch( 'domain_record',
                   {
                     'svcnum' => $svc_domain->svcnum,
                   },
                   '',
                   $extra_sql,
          )
        ) {
          $arec{$domain_rec->recnum} = $domain_rec->zone;
        }

        if ( $conf->exists('svc_www-enable_subdomains') ) {
          $arec{'www.'. $svc_domain->domain} = 'www.'. $svc_domain->domain
            unless    qsearchs( 'domain_record', {
                                  svcnum  => $svc_domain->svcnum,
                                  reczone => 'www',
                      } )
                   || qsearchs( 'domain_record', {
                                  svcnum  => $svc_domain->svcnum,
                                  reczone => 'www.'.$svc_domain->domain.'.',
                    } );
        }

        $arec{'@.'. $svc_domain->domain} = $svc_domain->domain
          unless   qsearchs('domain_record', {
                              svcnum  => $svc_domain->svcnum,
                              reczone => '@',
                   } )
                || qsearchs('domain_record', {
                              svcnum  => $svc_domain->svcnum,
                              reczone => $svc_domain->domain.'.',
                   } );

      }

    }
  }

} elsif ( $action eq 'Edit' ) {

  my($domain_rec) = qsearchs('domain_record', { 'recnum'=>$svc_www->recnum });
  $arec{$svc_www->recnum} = join '.', $domain_rec->recdata, $domain_rec->reczone;

} else {
  die "\$action eq Add, but \$pkgnum is null!\n";
}

my $p1 = popurl(1);

</%init>
