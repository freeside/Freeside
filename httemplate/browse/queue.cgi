<%

print header("Job Queue", menubar(
  'Main Menu' => $p,
#  'Add new referral' => "../edit/part_referral.cgi",
)), &table(), <<END;
      <TR>
        <TH COLSPAN=2>Job</TH>
        <TH>Args</TH>
        <TH>Date</TH>
        <TH>Status</TH>
      </TR>
END

foreach my $queue ( sort { 
  $a->getfield('jobnum') <=> $b->getfield('jobnum')
} qsearch('queue',{}) ) {
  my($hashref)=$queue->hashref;
  my $jobnum = $hashref->{jobnum};
  my $args = join(' ', $queue->args);
  my $date = time2str( "%a %b %e %T %Y", $queue->_date );
  my $status = $hashref->{status};
  if ( $status eq 'failed' || $status eq 'locked' ) {
    $status .=
      qq! ( <A HREF="$p/edit/queue.cgi?jobnum=$jobnum&action=new">retry</A> |!.
      qq! <A HREF="$p/edit/queue.cgi?jobnum$jobnum&action=del">remove </A> )!;
  }
  print <<END;
      <TR>
        <TD>$jobnum</TD>
        <TD>$hashref->{job}</TD>
        <TD>$args</TD>
        <TD>$date</TD>
        <TD>$status</TD>
      </TR>
END

}

print <<END;
    </TABLE>
  </BODY>
</HTML>
END

%>
