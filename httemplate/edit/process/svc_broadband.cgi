<%

# If it's stupid but it works, it's not stupid.
# -- U.S. Army

local $FS::UID::AutoCommit = 0;
my $dbh = FS::UID::dbh;

$cgi->param('svcnum') =~ /^(\d*)$/ or die "Illegal svcnum!";
my $svcnum = $1;

my $old; my @old_sbf;
if ( $svcnum ) {
  $old = qsearchs('svc_broadband', { 'svcnum' => $svcnum } )
    or die "fatal: can't find broadband service (svcnum $svcnum)!";
  @old_sbf = $old->sb_field;
} else {
  $old = '';
}

my $new = new FS::svc_broadband ( {
  map {
    ($_, scalar($cgi->param($_)));
  } ( fields('svc_broadband'), qw( pkgnum svcpart ) )
} );

my $error;
if ( $svcnum ) {
  $error = $new->replace($old);
} else {
  $error = $new->insert;
  $svcnum = $new->svcnum;
}

unless ($error) {
  my $sb_field;

  foreach ($cgi->param) {
    #warn "\$cgi->param $_: " . $cgi->param($_);
    if(/^sbf_(\d+)/) {
      my $part = $1;
      #warn "\$part $part";
      $sb_field = new FS::sb_field 
        { svcnum      => $svcnum,
          value       => $cgi->param($_),
          sbfieldpart => $part };
      if (my @x = grep { $_->sbfieldpart eq $part } @old_sbf) {
      #if (my $old_sb_field = (grep { $_->sbfieldpart eq $part} @old_Sbf)[0]) {
        #warn "array: " . scalar(@x);
        if (length($sb_field->value) && ($sb_field->value ne $x[0]->value)) { 
          #warn "replacing " . $x[0]->value . " with " . $sb_field->value;
          $error = $sb_field->replace($x[0]);
          #$error = $sb_field->replace($old_sb_field);
        } elsif (length($sb_field->value) == 0) { 
          #warn "delete";
          $error = $x[0]->delete;
        }
      } else {
        if (length($sb_field->value) > 0) { 
          #warn "insert";
          $error = $sb_field->insert;
        }
        # else do nothing
      }
    }
  }
}

if ( $error ) {
  $cgi->param('error', $error);
  $cgi->param('ip_addr', $new->ip_addr);
  $dbh->rollback;
  print $cgi->redirect(popurl(2). "svc_broadband.cgi?". $cgi->query_string );
} else {
  $dbh->commit or die $dbh->errstr;
  print $cgi->redirect(popurl(3). "view/svc_broadband.cgi?" . $svcnum );
}

%>
