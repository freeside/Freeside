<%

my $rate;
if ( $cgi->keywords ) {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/;
  $rate = qsearchs( 'rate', { 'ratenum' => $1 } );
} else { #adding
  $rate = new FS::rate {};
}
my $action = $rate->ratenum ? 'Edit' : 'Add';

my $p1 = popurl(1);

my %granularity = (
  '6'  => '6 second',
  '60' => 'minute',
);

my $nous = <<END;
  WHERE 0 < ( SELECT COUNT(*) FROM rate_prefix
               WHERE rate_region.regionnum = rate_prefix.regionnum
                 AND countrycode != '1'
            )
END

%>

<%= header("$action Rate plan", menubar(
      'Main Menu' => $p,
      'View all rate plans' => "${p}browse/rate.cgi",
    ))
%>

<!-- <FORM ACTION="<%=$p1%>rate.cgi" NAME="OneTrueForm" METHOD=POST onSubmit="document.OneTrueForm.submit.disabled=true"> -->

<SCRIPT TYPE="text/javascript" SRC="../elements/jsrsClient.js"></SCRIPT>
<SCRIPT TYPE="text/javascript">
function process () {
  document.OneTrueForm.submit.disabled=true;

  var Hash = new Array();
  var x = 0;
  var fieldName;
  for (var i = 0; i<document.OneTrueForm.elements.length; i++) {
    fieldName = document.OneTrueForm.elements[i].name;
    if (    (fieldName.indexOf('rate') > -1)
         || (fieldName.indexOf('min_') > -1) 
         || (fieldName.indexOf('sec_') > -1) 
       )
    {
        Hash[x++] = fieldName;
        Hash[x++] = document.OneTrueForm.elements[i].value;
    }
  }

  jsrsPOST = true;
  //jsrsExecute( 'process/rate.cgi', myCallback, 'process_rate', Hash );
  jsrsExecute( 'process/rate.cgi', myCallback, 'start_job', Hash );

}

function myCallback( jobnum ) {
  var progressWindow = window.open('../../misc/progress.html?jobnum=' + jobnum + ';url=<%=$p%>browse/rate.cgi', 'progressWindow', 'toolbar=no,location=no,directories=no,scrollbars=no,menubar=no,status=no,width=420,height=128');
  progressWindow.opener = self;
  //progressWindow.opener = document;
}

</SCRIPT>

<FORM NAME="OneTrueForm">
<INPUT TYPE="hidden" NAME="ratenum" VALUE="<%= $rate->ratenum %>">

Rate plan
<INPUT TYPE="text" NAME="ratename" SIZE=32 VALUE="<%= $rate->ratename %>">
<BR><BR>

<%= table() %>
<TR>
  <TH>Region</TH>
  <TH>Prefix(es)</TH>
  <TH><FONT SIZE=-1>Included<BR>minutes</FONT></TH>
  <TH><FONT SIZE=-1>Charge per<BR>minute</FONT></TH>
  <TH><FONT SIZE=-1>Granularity</FONT></TH>
</TR>

<% foreach my $rate_region (
     qsearch( 'rate_region',
              {},
              '',
              "$nous ORDER BY regionname",
            )
   ) {
     my $n = $rate_region->regionnum;
     my $rate_detail =
       $rate->dest_detail($rate_region)
       || new FS::rate_detail { 'min_included'    => 0,
                                'min_charge'      => 0,
                                'sec_granularity' => '60'
                              };
%>
  <TR>
    <TD><A HREF="<%=$p%>edit/rate_region.cgi?<%= $rate_region->regionnum %>"><%= $rate_region->regionname %></A></TD>
    <TD><%= $rate_region->prefixes_short %></TD>
    <TD><INPUT TYPE="text" SIZE=5 NAME="min_included<%=$n%>" VALUE="<%= $cgi->param("min_included$n") || $rate_detail->min_included %>"></TD>
    <TD>$<INPUT TYPE="text" SIZE=4 NAME="min_charge<%=$n%>" VALUE="<%= sprintf('%.2f', $cgi->param("min_charge$n") || $rate_detail->min_charge ) %>"></TD>
    <TD>
      <SELECT NAME="sec_granularity<%=$n%>">
        <% foreach my $granularity ( keys %granularity ) { %>
          <OPTION VALUE="<%=$granularity%>"<%= $granularity == ( $cgi->param("sec_granularity$n") || $rate_detail->sec_granularity ) ? ' SELECTED' : '' %>><%=$granularity{$granularity}%>
        <% } %>
      </SELECT>
  </TR>
<% } %>

<TR>
  <TD COLSPAN=5 ALIGN="center">
    <A HREF="<%=$p%>edit/rate_region.cgi"><I>Add a region</I></A>
  </TD>
</TR>

</TABLE>

<BR><INPUT NAME="submit" TYPE="button" VALUE="<%= 
  $rate->ratenum ? "Apply changes" : "Add rate plan"
%>" onClick="document.OneTrueForm.submit.disabled=true; process();">
Please make sure to allow popups from this site in order to view the progress window.
<!-- Please be patient, <%= $rate->ratenum ? 'editing' : 'adding' %>
a rate plan can take a few minutes... -->

    </FORM>
  </BODY>
</HTML>

