<% include("/elements/header.html",'Customer package - Edit dates') %>

%#, menubar(
%#  "View this customer (#$custnum)" => popurl(2). "view/cust_main.cgi?$custnum",
%#));

<LINK REL="stylesheet" TYPE="text/css" HREF="../elements/calendar-win2k-2.css" TITLE="win2k-2">
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar_stripped.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-en.js"></SCRIPT>
<SCRIPT TYPE="text/javascript" SRC="../elements/calendar-setup.js"></SCRIPT>

<FORM NAME="formname" ACTION="process/REAL_cust_pkg.cgi" METHOD="POST">
<INPUT TYPE="hidden" NAME="pkgnum" VALUE="<% $pkgnum %>">

% # raw error from below
% if ( $error ) { 
  <FONT SIZE="+1" COLOR="#ff0000">Error: <% $error %></FONT>
% } 
% #or, regular error handler
<% include('/elements/error.html') %>

<% ntable("#cccccc",2) %>

  <TR>
    <TD ALIGN="right">Package number</TD>
    <TD BGCOLOR="#ffffff"><% $cust_pkg->pkgnum %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Package</TD>
    <TD BGCOLOR="#ffffff"><% $part_pkg->pkg %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Custom</TD>
    <TD BGCOLOR="#ffffff"><% $part_pkg->custom %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Comment</TD>
    <TD BGCOLOR="#ffffff"><% $part_pkg->comment %></TD>
  </TR>

  <TR>
    <TD ALIGN="right">Order taker</TD>
    <TD BGCOLOR="#ffffff"><% $cust_pkg->otaker %></TD>
  </TR>

% if ( $cust_pkg->setup && ! $cust_pkg->start_date ) {
  <& .row_display, cust_pkg=>$cust_pkg, column=>'start_date',   label=>'Start' &>
% } else {
  <& .row_edit, cust_pkg=>$cust_pkg, column=>'start_date', label=>'Start' &>
% }

  <& .row_edit, cust_pkg=>$cust_pkg, column=>'setup',     label=>'Setup' &>
  <& .row_edit, cust_pkg=>$cust_pkg, column=>'last_bill', label=>$last_bill_or_renewed &>
  <& .row_edit, cust_pkg=>$cust_pkg, column=>'bill',      label=>$next_bill_or_prepaid_until &>
  <& .row_display, cust_pkg=>$cust_pkg, column=>'contract_end',label=>'Contract end' &>
  <& .row_display, cust_pkg=>$cust_pkg, column=>'adjourn',  label=>'Adjournment', note=>'(will <b>suspend</b> this package when the date is reached)' &>
  <& .row_display, cust_pkg=>$cust_pkg, column=>'susp',     label=>'Suspension' &>

  <& .row_display, cust_pkg=>$cust_pkg, column=>'expire',   label=>'Expiration', note=>'(will <b>cancel</b> this package when the date is reached)' &>
  <& .row_display, cust_pkg=>$cust_pkg, column=>'cancel',   label=>'Cancellation' &>


<%def .row_edit>
<%args>
  $cust_pkg
  $column
  $label
  $note => ''
</%args>
% my $value = $cust_pkg->get($column);
% $value = $value ? time2str($format, $value) : "";

  <TR>
    <TD ALIGN="right"><% $label %> date</TD>
    <TD>
      <INPUT TYPE  = "text"
             NAME  = "<% $column %>"
             SIZE  = 32
             ID    = "<% $column %>_text"
             VALUE = "<% $value %>"
      >
      <IMG SRC   = "../images/calendar.png"
           ID    = "<% $column %>_button"
           STYLE = "cursor: pointer"
           TITLE = "Select date"
      >
%     if ( $note ) {
        <BR><FONT SIZE=-1><% $note %></FONT>
%     }
    </TD>
  </TR>

  <SCRIPT TYPE="text/javascript">
    Calendar.setup({
      inputField: "<% $column %>_text",
      ifFormat:   "<% $date_format %>",
      button:     "<% $column %>_button",
      align:      "BR"
    });
  </SCRIPT>

</%def>

<%def .row_display>
<%args>
  $cust_pkg
  $column
  $label
  $note => ''
</%args>
% if ( $cust_pkg->get($column) ) { 
    <TR>
      <TD ALIGN="right"><% $label %> date</TD>
      <TD BGCOLOR="#ffffff"><% time2str($format,$cust_pkg->get($column)) %>
%       if ( $note ) {
          <BR><FONT SIZE=-1><% $note %></FONT>
%       }
      </TD>
    </TR>
% } 
</%def>

</TABLE>

<BR>
<INPUT TYPE="submit" VALUE="Apply Changes">
</FORM>

<% include('/elements/footer.html') %>
<%shared>

my $conf = new FS::Conf;
my $date_format = $conf->config('date_format') || '%m/%d/%Y';

my $format = $date_format. ' %T'; # %z (%Z)';

</%shared>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Edit customer package dates');


my $error = '';
my( $pkgnum, $cust_pkg );

if ( $cgi->param('error') ) {

  $pkgnum = $cgi->param('pkgnum');

  if ( $cgi->param('error') =~ /^_/ ) {

    my @errors = ();
    my %errors = map { $_=>1 } split(',', $cgi->param('error'));
    $cgi->param('error', '');

    if ( $errors{'_bill_areyousure'} ) {
      if ( $cgi->param('bill') =~ /^([\s\d\/\:\-\(\w\)]*)$/ ) {
        my $bill = $1;
        push @errors,
          "You are attempting to set the next bill date to $bill, which is
           in the past.  This will charge the customer for the interval
           from $bill until now.  Are you sure you want to do this? ".
          '<INPUT TYPE="checkbox" NAME="bill_areyousure" VALUE="1">';
      }
    }

    if ( $errors{'_setup_areyousure'} ) {
      push @errors,
        "You are attempting to remove the setup date.  This will re-charge the
         customer for the setup fee. Are you sure you want to do this? ".
        '<INPUT TYPE="checkbox" NAME="setup_areyousure" VALUE="1">';
    }

    if ( $errors{'_start'} ) {
      push @errors,
        "You are attempting to add a start date to a package that has already
         started billing.";
    }

    $error = join('<BR><BR>', @errors );

  }

  #get package record
  $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  die "No package!" unless $cust_pkg;

  foreach my $col (qw( start_date setup last_bill bill adjourn expire )) {
    my $value = $cgi->param($col);
    $cust_pkg->set( $col, $value ? parse_datetime($value) : '' );
  }

} else {

  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "no pkgnum";
  $pkgnum = $1;

  #get package record
  $cust_pkg = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
  die "No package!" unless $cust_pkg;

}

my $part_pkg = qsearchs( 'part_pkg', { 'pkgpart' => $cust_pkg->pkgpart } );

my( $last_bill_or_renewed, $next_bill_or_prepaid_until );
unless ( $part_pkg->is_prepaid ) {
  #$billed_or_prepaid = 'billed';
  $last_bill_or_renewed = 'Last bill';
  $next_bill_or_prepaid_until = 'Next bill';
} else {
  #$billed_or_prepaid = 'prepaid';
  $last_bill_or_renewed = 'Renewed';
  $next_bill_or_prepaid_until = 'Prepaid until';
}

</%init>
