<%

my $conf = new FS::Conf;
my $maxrecords = $conf->config('maxsearchrecordsperpage');

my $limit = '';
$limit .= "LIMIT $maxrecords" if $maxrecords;

my $offset = $cgi->param('offset') || 0;
$limit .= " OFFSET $offset" if $offset;

my $total;

my $sql = $cgi->param('sql');
$sql =~ s/^\s*SELECT//i;

my $count_sql = $sql;
$count_sql =~ s/^(.*)\s+FROM\s/COUNT(*) FROM /i;

my $sth = dbh->prepare("SELECT $count_sql")
  or eidiot dbh->errstr. " doing $count_sql\n";
$sth->execute or eidiot "Error executing \"$count_sql\": ". $sth->errstr;

$total = $sth->fetchrow_arrayref->[0];

my $sth = dbh->prepare("SELECT $sql $limit")
  or eidiot dbh->errstr. " doing $sql\n";
$sth->execute or eidiot "Error executing \"$sql\": ". $sth->errstr;
my $rows = $sth->fetchall_arrayref;

%>
<!-- mason kludge -->
<%

  #begin pager
  my $pager = '';
  if ( $total != scalar(@$rows) && $maxrecords ) {
    unless ( $offset == 0 ) {
      $cgi->param('offset', $offset - $maxrecords);
      $pager .= '<A HREF="'. $cgi->self_url.
                '"><B><FONT SIZE="+1">Previous</FONT></B></A> ';
    }
    my $poff;
    my $page;
    for ( $poff = 0; $poff < $total; $poff += $maxrecords ) {
      $page++;
      if ( $offset == $poff ) {
        $pager .= qq!<FONT SIZE="+2">$page</FONT> !;
      } else {
        $cgi->param('offset', $poff);
        $pager .= qq!<A HREF="!. $cgi->self_url. qq!">$page</A> !;
      }
    }
    unless ( $offset + $maxrecords > $total ) {
      $cgi->param('offset', $offset + $maxrecords);
      $pager .= '<A HREF="'. $cgi->self_url.
                '"><B><FONT SIZE="+1">Next</FONT></B></A> ';
    }
  }
  #end pager

  print header('Query Results', menubar('Main Menu'=>$p) ).
        "$total total rows<BR><BR>$pager". table().
        "<TR>";
  print "<TH>$_</TH>" foreach @{$sth->{NAME}};
  print "</TR>";

  foreach $row ( @$rows ) {
    print "<TR>";
    print "<TD>$_</TD>" foreach @$row;
    print "</TR>";
  }

  print "</TABLE>$pager</BODY></HTML>";

%>
