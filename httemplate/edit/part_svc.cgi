<!-- mason kludge -->
<% 
   my $part_svc;
   if ( $cgi->param('error') ) { #error
     $part_svc = new FS::part_svc ( {
       map { $_, scalar($cgi->param($_)) } fields('part_svc')
     } );
   } elsif ( $cgi->keywords ) { #edit
     my($query) = $cgi->keywords;
     $query =~ /^(\d+)$/ or die "malformed query: $query";
     $part_svc=qsearchs('part_svc', { 'svcpart'=>$1 } )
       or die "unknown svcpart: $1";
   } else { #adding
     $part_svc = new FS::part_svc {};
   }
   my $action = $part_svc->svcpart ? 'Edit' : 'Add';
   my $hashref = $part_svc->hashref;
   my $p_svcdb = $part_svc->svcdb || 'svc_acct';

%>

<SCRIPT>
function visualize(what) {
  if (document.getElementById) {
    document.getElementById('d<%= $p_svcdb %>').style.visibility = "visible";
  } else {
    document.l<%= $p_svcdb %>.visibility = "visible";
  }
}
</SCRIPT>

<%= header("$action Service Definition",
           menubar( 'Main Menu'         => $p,
                    'View all service definitions' => "${p}browse/part_svc.cgi"
                  ),
           " onLoad=\"visualize()\""
           )
%>

<% if ( $cgi->param('error') ) { %>
<FONT SIZE="+1" COLOR="#ff0000">Error: <%= $cgi->param('error') %></FONT>
<% } %>

<FORM NAME="dummy">

      Service Part #<%= $part_svc->svcpart ? $part_svc->svcpart : "(NEW)" %>
<BR><BR>
Service  <INPUT TYPE="text" NAME="svc" VALUE="<%= $hashref->{svc} %>"><BR>
Disable new orders <INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<%= $hashref->{disabled} eq 'Y' ? ' CHECKED' : '' %>><BR>
<BR>
Services are items you offer to your customers.
<UL><LI>svc_acct - Shell accounts, POP mailboxes, SLIP/PPP and ISDN accounts
    <LI>svc_domain - Domains
    <LI>svc_acct_sm - <B>deprecated</B> (use svc_forward for new installations) Virtual domain mail aliasing.
    <LI>svc_forward - mail forwarding
    <LI>svc_www - Virtual domain website
<!--   <LI>svc_charge - One-time charges (Partially unimplemented)
       <LI>svc_wo - Work orders (Partially unimplemented)
-->
</UL>
For the selected table, you can give fields default or fixed (unchangable)
values.  For example, a SLIP/PPP account may have a default (or perhaps fixed)
<B>slipip</B> of <B>0.0.0.0</B>, while a POP mailbox will probably have a fixed
blank <B>slipip</B> as well as a fixed shell something like <B>/bin/true</B> or
<B>/usr/bin/passwd</B>.
<BR><BR>
<SCRIPT>
var svcdb = null;
function changed(what) {
  svcdb = what.options[what.selectedIndex].value;
<% foreach my $svcdb ( qw( svc_acct svc_domain svc_acct_sm svc_forward svc_www ) ) { %>
  if (svcdb == "<%= $svcdb %>" ) {
    <% foreach my $not ( grep { $_ ne $svcdb } (
                           qw(svc_acct svc_domain svc_acct_sm svc_forward svc_www) ) ) { %>
      if (document.getElementById) {
        document.getElementById('d<%= $not %>').style.visibility = "hidden";
      } else {
        document.l<%= $not %>.visibility = "hidden";
      }
    <% } %>
    if (document.getElementById) {
      document.getElementById('d<%= $svcdb %>').style.visibility = "visible";
    } else {
      document.l<%= $svcdb %>.visibility = "visible";
    }
  }
<% } %>
}
</SCRIPT>
<% my @dbs = $hashref->{svcdb}
             ? ( $hashref->{svcdb} )
             : qw( svc_acct svc_domain svc_acct_sm svc_forward svc_www ); %>
Table<SELECT NAME="svcdb" SIZE=1 onChange="changed(this)">
<% foreach my $svcdb (@dbs) { %>
<OPTION VALUE="<%= $svcdb %>" <%= ' SELECTED'x($svcdb eq $hashref->{svcdb}) %>><%= $svcdb %>
<% } %>
</SELECT></FORM>

<%
#these might belong somewhere else for other user interfaces 
#pry need to eventually create stuff that's shared amount UIs
my %defs = (
  'svc_acct' => {
    'dir'       => 'Home directory',
    'uid'       => 'UID (set to fixed and blank for dial-only)',
    'slipip'    => 'IP address (Set to fixed and blank to disable dialin, or, set a value to be exported to RADIUS Framed-IP-Address.  Use the special value <code>0e0</code> [zero e zero] to enable export to RADIUS without a Framed-IP-Address.)',
#    'popnum'    => qq!<A HREF="$p/browse/svc_acct_pop.cgi/">POP number</A>!,
    'popnum'    => {
                     desc => 'Access number',
                     type => 'select',
                     select_table => 'svc_acct_pop',
                     select_key   => 'popnum',
                     select_label => 'city',
                   },
    'username'  => 'Username',
    'quota'     => '',
    '_password' => 'Password',
    'gid'       => 'GID (when blank, defaults to UID)',
    'shell'     => 'Shell (all service definitions should have a default or fixed shell that is present in the <b>shells</b> configuration file)',
    'finger'    => 'GECOS',
    'domsvc'    => {
                     desc =>'svcnum from svc_domain',
                     type =>'select',
                     select_table => 'svc_domain',
                     select_key   => 'svcnum',
                     select_label => 'domain',
                   },
  },
  'svc_domain' => {
    'domain'    => 'Domain',
  },
  'svc_acct_sm' => {
    'domuser'   => 'domuser@virtualdomain.com',
    'domuid'    => 'UID where domuser@virtualdomain.com mail is forwarded',
    'domsvc'    => 'svcnum from svc_domain for virtualdomain.com',
  },
  'svc_forward' => {
    'srcsvc'    => 'service from which mail is to be forwarded',
    'dstsvc'    => 'service to which mail is to be forwarded',
    'dst'       => 'someone@another.domain.com to use when dstsvc is 0',
  },
  'svc_charge' => {
    'amount'    => 'amount',
  },
  'svc_wo' => {
    'worker'    => 'Worker',
    '_date'      => 'Date',
  },
  'svc_www' => {
    #'recnum' => '',
    #'usersvc' => '',
  },
);

#  svc_acct svc_domain svc_acct_sm svc_charge svc_wo
foreach my $svcdb ( qw(
  konq_kludge svc_acct svc_domain svc_acct_sm svc_forward svc_www
) ) {

#  my(@fields) = $svcdb eq 'konq_kludge'
#                  ? ()
#                  : grep { $_ ne 'svcnum' } fields($svcdb);
  #yucky kludge
  my(@fields) = defined( $FS::Record::dbdef->table($svcdb) )
                  ? grep { $_ ne 'svcnum' } fields($svcdb)
                  : ();
  #my($rowspan)=scalar(@rows);

  #my($ptmp)="<TD ROWSPAN=$rowspan>$svcdb</TD>";
#  $visibility = $svcdb eq $part_svc->svcdb ? "SHOW" : "HIDDEN";
#  $visibility = $svcdb eq $p_svcdb ? "visible" : "hidden";
  my $visibility = "hidden";
%>
<SCRIPT>
if (document.getElementById) {
    document.write("<DIV ID=\"d<%= $svcdb %>\" STYLE=\"visibility: <%= $visibility %>; position: absolute\">");
} else {
<% $visibility="show" if $visibility eq "visible"; %>
    document.write("<LAYER ID=\"l<%= $svcdb %>\" VISIBILITY=\"<%= $visibility %>\">");
}

function fixup(what) {
  what.svc.value = document.dummy.svc.value;
  what.svcdb.value = document.dummy.svcdb.options[document.dummy.svcdb.selectedIndex].value;
  if (document.dummy.disabled.checked)
    what.disabled.value = 'Y';
  else
    what.disabled.value = '';
}
</SCRIPT>
<FORM NAME="<%= $svcdb %>" ACTION="process/part_svc.cgi" METHOD=POST onSubmit="fixup(this)">
<INPUT TYPE="hidden" NAME="svcpart" VALUE="<%= $hashref->{svcpart} %>">
<INPUT TYPE="hidden" NAME="svc" VALUE="<%= $hashref->{svc} %>">
<INPUT TYPE="hidden" NAME="disabled" VALUE="<%= $hashref->{disabled} %>">
<INPUT TYPE="hidden" NAME="svcdb" VALUE="<%= $svcdb %>">
<%
  #print "$svcdb<BR>" unless $svcdb eq 'konq_kludge';
  print table(). "<TH>Field</TH><TH COLSPAN=2>Modifier</TH>" unless $svcdb eq 'konq_kludge';

  foreach my $field (@fields) {
    my $part_svc_column = $part_svc->part_svc_column($field);
    my $value = $cgi->param('error')
                  ? $cgi->param("${svcdb}__${field}")
                  : $part_svc_column->columnvalue;
    my $flag = $cgi->param('error')
                 ? $cgi->param("${svcdb}__${field}_flag")
                 : $part_svc_column->columnflag;
    #print "<TR>$ptmp<TD>$field";
    print "<TR><TD>$field";
    my $def = $defs{$svcdb}{$field};
    my $desc = ref($def) ? $def->{desc} : $def;
    
    print "- <FONT SIZE=-1>$desc</FONT>" if $desc;
    print "</TD>";
    print qq!<TD><INPUT TYPE="radio" NAME="${svcdb}__${field}_flag" VALUE=""!.
      ' CHECKED'x($flag eq ''). ">Off</TD>";
    print qq!<TD><INPUT TYPE="radio" NAME="${svcdb}__${field}_flag" VALUE="D"!.
      ' CHECKED'x($flag eq 'D'). ">Default ";
    print qq!<INPUT TYPE="radio" NAME="${svcdb}__${field}_flag" VALUE="F"!.
      ' CHECKED'x($flag eq 'F'). ">Fixed ";
    print '<BR>';
    if ( ref($def) ) {
      if ( $def->{type} eq 'select' ) {
        print qq!<SELECT NAME="${svcdb}__${field}">!;
        print '<OPTION> </OPTION>' unless $value;
        foreach my $record ( qsearch( $def->{select_table}, {} ) ) {
          warn $rvalue;
          my $rvalue = $record->getfield($def->{select_key});
          print qq!<OPTION VALUE="$rvalue"!.
                ( $rvalue==$value ? ' SELECTED>' : '>' ).
                $record->getfield($def->{select_label}). '</OPTION>';
        }
        print '</SELECT>';
      } else {
        print '<font color="#ff0000">unknown type'. $def->{type};
      }
    } else {
      print qq!<INPUT TYPE="text" NAME="${svcdb}__${field}" VALUE="$value">!;
    }
    print "</TD></TR>\n";
    #$ptmp='';
  }
  print "</TABLE>" unless $svcdb eq 'konq_kludge';

print qq!\n<BR><INPUT TYPE="submit" VALUE="!,
      $hashref->{svcpart} ? "Apply changes" : "Add service",
      qq!">! unless $svcdb eq 'konq_kludge';

  print "</FORM>";
  print <<END;
    <SCRIPT>
    if (document.getElementById) {
      document.write("</DIV>");
    } else {
      document.write("</LAYER>");
    }
    </SCRIPT>
END
}
#print "</TABLE>";
%>

<TAG onLoad="
    if (document.getElementById) {
      document.getElementById('d<%= $p_svcdb %>').style.visibility = 'visible';
    } else {
      document.l<%= $p_svcdb %>.visibility = 'visible';
    }
">

  </BODY>
</HTML>

