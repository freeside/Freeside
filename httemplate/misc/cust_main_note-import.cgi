<% include("/elements/header.html", 'Batch Customer Note Import') %>
%

<FORM ACTION="process/cust_main_note-import.cgi" METHOD="POST">


<SCRIPT TYPE="text/javascript">

  function clearhint_custnum() {

    if ( this.value == 'Not found' ) {
      this.value = '';
      this.style.color = '#000000';
    }

  }

  function search_custnum() {

    this.style.color = '#000000'

    var custnum_obj = this;
    var searchrow = this.getAttribute('rownum');
    var custnum = this.value;
    var name_obj = document.getElementById('name'+searchrow);

    if ( custnum == 'searching...' || custnum == 'Not found' )
      return;

    var customer_select = document.getElementById('cust_select'+searchrow);

    if ( custnum == '' ) {
      customer_select.selectedIndex = 0;
      return;
    }

    custnum_obj.value = 'searching...';
    custnum_obj.disabled = true;
    custnum_obj.style.backgroundColor = '#dddddd';


    function search_custnum_update(customers) {

      var customerArray = eval('(' + customers + ')');

      custnum_obj.disabled = false;
      custnum_obj.style.backgroundColor = '#ffffff';

      if ( customerArray.length == 0 )  {
        custnum_obj.value = 'Not found';
        custnum_obj.style.color = '#ff0000';
      } else if ( customerArray.length == 5 ) {
	    var name = customerArray[1];
        opt(customer_select,custnum,name,'#000000');
        customer_select.selectedIndex = customer_select.length - 1;
        custnum_obj.value = custnum;
        name_obj.value = name;
      }

    }

    custnum_search( custnum, search_custnum_update );

  }

  function select_customer() {

    var custnum = this.options[this.selectedIndex].value;
    var name = this.options[this.selectedIndex].text;

    var searchrow = this.getAttribute('rownum');
    var custnum_obj = document.getElementById('custnum'+searchrow);
    var name_obj = document.getElementById('name'+searchrow);

    custnum_obj.value = custnum;
    custnum_obj.style.color = '#000000';

    name_obj.value = name;

  }

  function opt(what,value,text,color) {
    var optionName = new Option(text, value, false, false);
    optionName.style.color = color;
    var length = what.length;
    what.options[length] = optionName;
  }

  function previewChanged(what) {
    var submit_obj = document.getElementById('importsubmit');
    if (what.checked) {
      submit_obj.value = 'Preview note import';
    }else{
      submit_obj.value = 'Import notes';
    }
  }

</SCRIPT>

<% include('/elements/xmlhttp.html',
              'url'  => $p. 'misc/xmlhttp-cust_main-search.cgi',
              'subs' => [qw( custnum_search )],
           )
%>

%  my $fh = $cgi->upload('csvfile');
%  my $csv = new Text::CSV_XS;
%  my $skip_fuzzies = $cgi->param('fuzzies') ? 0 : 1;
%  my $use_agent_custid = $cgi->param('use_agent_custid') ? 1 : 0;
%
%  if ( defined($fh) ) {
     <TABLE BGCOLOR="#cccccc" BORDER=0 CELLSPACING=0>
     <TR>
       <TH>Cust #</TH>
       <TH>Customer</TH>
       <TH>Last</TH>
       <TH>First</TH>
       <TH>Note to be added</TH>
     </TR>
%    my $agentnum = scalar($cgi->param('agentnum'));
%    my $line;
%    my $row = 0;
%    while ( defined($line=<$fh>) ) {
%      $line =~ s/(\S*)\s*$/$1/;
%      $line =~ s/^(.*)(#!).*/$1/;
%
%      $csv->parse($line) or die "can't parse line: " . $csv->error_input();
%      my $custnum = 0;
%      my @values = $csv->fields();
%      my $last  = shift @values;
%      if ($last =~ /^\s*(\d+)\s*$/ ) {
%        $custnum = $1;
%        $last = shift @values;
%      }
%      my $first = shift @values;
%      my $note  = join ' ', @values;
%      next unless ( $last || $first || $note );
%      my @cust_main = ();
%      warn "searching for: $last, $first" if ($first || $last);
%      if ($agentnum && $custnum && $use_agent_custid) {
%        @cust_main = qsearch('cust_main', { 'agent'        => $agentnum,
%                                             'agent_custid' => $custnum   } );
%      } elsif ($custnum) { # && !use_agent_custid
%        @cust_main = qsearch('cust_main', { 'custnum' => $custnum });
%      } else {
%        @cust_main = FS::cust_main::smart_search(
%                                          'search' => "$last, $first",
%                                          'no_fuzzy_on_exact' => $skip_fuzzies,
%                                                )
%          if ($first || $last);
%      }
%
       <TR>
         <TD>
           <INPUT TYPE="text" NAME="custnum<% $row %>" ID="custnum<% $row %>" SIZE=8 MAXLENGTH=12 VALUE="<% $cust_main[0] ? $cust_main[0]->custnum : '' %>" rownum="<% $row %>">
             <SCRIPT TYPE="text/javascript">
               var custnum_input<% $row %> = document.getElementById("custnum<% $row %>");
               custnum_input<% $row %>.onfocus = clearhint_custnum;
               custnum_input<% $row %>.onchange = search_custnum;
             </SCRIPT>
         </TD>
         <TD>
           <SELECT NAME="cust_select<% $row %>" ID="cust_select<% $row %>" rownum="<% $row %>">
             <OPTION VALUE="">---</OPTION>
%      my $i=0;
%      foreach (@cust_main) {
             <OPTION <% $i ? '' : 'SELECTED' %> VALUE="<% $_->custnum %>"><% $_->name %></OPTION>
%        $i++;
%      }
           </SELECT>
             <SCRIPT TYPE="text/javascript">
               var customer_select<% $row %> = document.getElementById("cust_select<% $row %>");
               customer_select<% $row %>.onchange = select_customer;
             </SCRIPT>
           <INPUT TYPE="hidden" NAME="name<% $row %>" ID="name<% $row %>" VALUE="<% $i ? $cust_main[0]->name : '' %>">
         </TD>
         <TD>
           <% $first %>
           <INPUT TYPE="hidden" NAME="first<% $row %>" VALUE="<% $first %>">
         </TD>
         <TD>
           <% $last %>
           <INPUT TYPE="hidden" NAME="last<% $row %>" VALUE="<% $last %>">
         </TD>
         <TD>
           <% $note %>
           <INPUT TYPE="hidden" NAME="note<% $row %>" VALUE="<% $note %>">
         </TD>
       </TR>
%      $row++;
%    }
     </TABLE>
     <INPUT TYPE="submit" NAME="submit" ID="importsubmit" VALUE="Import notes">
     <INPUT TYPE="checkbox" NAME="preview" onchange="previewChanged(this);">
     Preview mode
%  } else {
     No file supplied
%  }

</FORM>
</BODY>
</HTML>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

</%init>
