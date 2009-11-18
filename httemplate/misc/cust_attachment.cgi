<% '',$cgi->redirect(popurl(2). "browse/cust_attachment.html?$browse_opts") %>
<%init>

$cgi->param('action') =~ /^(Delete|Undelete|Purge) selected$/
  or die "Illegal action";
my $action = $1;

my $browse_opts = join(';', map { $_.'='.$cgi->param($_) } 
    qw( orderby show_deleted )
    );

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right("$action attachment");

foreach my $attachnum (
    map { /^attachnum(\d+)$/; $1; } grep /^attachnum\d+$/, $cgi->param
  ) {
  my $attach = qsearchs('cust_attachment', { 'attachnum' => $attachnum });
  my $error;
  if ( $action eq 'Delete' and !$attach->disabled ) {
    $attach->disabled(time);
    $error = $attach->replace;
  }
  elsif ( $action eq 'Undelete' and $attach->disabled ) {
    $attach->disabled('');
    $error = $attach->replace;
  }
  elsif ( $action eq 'Purge' and $attach->disabled ) {
    $error = $attach->delete;
  }
  die $error if $error;
}

</%init>
