% if ( $error ) {
%   $cgi->param('error', $error);
<% $cgi->redirect(popurl(2). "cdr_type.cgi?". $cgi->query_string ) %>
% } else {
<% $cgi->redirect(popurl(2). "cdr_type.cgi" ) %>
% }
<%init>
my $error = '';
die "access denied" 
    unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my %vars = $cgi->Vars;
warn Dumper(\%vars)."\n";

my %old = map { $_->cdrtypenum => $_ } qsearch('cdr_type', {});

my @new;
foreach ( keys(%vars) ) {
  my ($i) = /^cdrtypenum(\d+)$/ or next;
  my $cdrtypenum = $vars{"cdrtypenum$i"} or next;
  my $cdrtypename = $vars{"cdrtypename$i"} or next;
  # don't delete unchanged records
  if ( $old{$i} and $old{$i}->cdrtypename eq $cdrtypename ) {
    delete $old{$i};
    next;
  }
  push @new, FS::cdr_type->new({ 
    'cdrtypenum'  => $cdrtypenum,
    'cdrtypename' => $cdrtypename,
  });
}
foreach (values(%old)) {
  $error = $_->delete;
  last if $error;
}
if(!$error) {
  foreach (@new) {
    $error = $_->insert;
    last if $error;
  }
}
</%init>
