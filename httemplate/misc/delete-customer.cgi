<% include('/elements/header.html', 'Delete customer') %>

<% include('/elements/error.html') %>

<FORM ACTION="<% popurl(1) %>process/delete-customer.cgi" METHOD=POST>
<INPUT TYPE="hidden" NAME="custnum" VALUE="<% $custnum |h %>">

%if ( qsearch('cust_pkg', { 'custnum' => $custnum, 'cancel' => '' } ) ) {
  Move uncancelled packages to customer number 
  <INPUT TYPE="text" NAME="new_custnum" VALUE="<% $new_custnum |h %>"><BR><BR>
%}

This will <B>completely remove</B> all traces of this customer record.  This
is <B>not</B> what you want if this is a real customer who has simply
canceled service with you.  For that, cancel all of the customer's packages.
(you can optionally hide cancelled customers with the <A HREF="../config/config-view.cgi#hidecancelledcustomers">hidecancelledcustomers</A> configuration option)
<BR>
<BR>Are you <B>absolutely sure</B> you want to delete this customer?
<BR><INPUT TYPE="submit" VALUE="Yes">
</FORM>

<% include('/elements/footer.html') %>

%#Deleting a customer you have financial records on (i.e. credits) is
%#typically considered fraudulant bookkeeping.  Remember, deleting   
%#customers should ONLY be used for completely bogus records.  You should
%#NOT delete real customers who simply discontinue service.
%#
%#For real customers who simply discontinue service, cancel all of the
%#customer's packages.  Customers with all cancelled packages are not  
%#billed.  There is no need to take further action to prevent billing on
%#customers with all cancelled packages.
%#
%#Also see the "hidecancelledcustomers" and "hidecancelledpackages"
%#configuration options, which will allow you to surpress the display of
%#cancelled customers and packages, respectively.

<%init>

my $conf = new FS::Conf;
die "Customer deletions not enabled in configuration"
  unless $conf->exists('deletecustomers');

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Delete customer');

my($custnum, $new_custnum);
if ( $cgi->param('error') ) {
  $custnum = $cgi->param('custnum');
  $new_custnum = $cgi->param('new_custnum');
} else {
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "Illegal query: $query";
  $custnum = $1;
  $new_custnum = '';
}
my $cust_main = qsearchs( {
  'table'     => 'cust_main',
  'hashref'   => { 'custnum' => $custnum },
  'extra_sql' => ' AND '. $FS::CurrentUser::CurrentUser->agentnums_sql,
} )
  or die 'Unknown custnum';

</%init>
