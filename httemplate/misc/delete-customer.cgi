<!-- mason kludge -->
<%

my $conf = new FS::Conf;
die "Customer deletions not enabled" unless $conf->exists('deletecustomers');

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
my $cust_main = qsearchs( 'cust_main', { 'custnum' => $custnum } )
  or die "Customer not found: $custnum";

print header('Delete customer');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print 
  qq!<form action="!, popurl(1), qq!process/delete-customer.cgi" method=post>!,
  qq!<input type="hidden" name="custnum" value="$custnum">!;

if ( qsearch('cust_pkg', { 'custnum' => $custnum, 'cancel' => '' } ) ) {
  print "Move uncancelled packages to customer number ",
        qq!<input type="text" name="new_custnum" value="$new_custnum"><br><br>!;
}

print <<END;
This will <b>completely remove</b> all traces of this customer record.  This
is <B>not</B> what you want if this is a real customer who has simply
canceled service with you.  For that, cancel all of the customer's packages.
(you can optionally hide cancelled customers with the <a href="../docs/config.html#hidecancelledcustomers">hidecancelledcustomers</a> configuration file)
<br>
<br>Are you <b>absolutely sure</b> you want to delete this customer?
<br><input type="submit" value="Yes">
</form></body></html>
END

%>
