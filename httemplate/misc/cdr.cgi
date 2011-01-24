%# <% $cgi->redirect(popurl(2). "search/cdr.html") %>
%# i should be a popup and reload my parent... until then, this will do
<% include('/elements/header.html','CDR update successful') %> 
<% include('/elements/footer.html') %> 
<%init> 
die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Edit rating data');

$cgi->param('action') =~ /^(new|del|(reprocess|delete) selected)$/
  or die "Illegal action";
my $action = $1;

my $cdr;
if ( $action eq 'new' || $action eq 'del' ) {
  $cgi->param('acctid') =~ /^(\d+)$/ or die "Illegal acctid";
  my $acctid = $1;
  $cdr = qsearchs('cdr', { 'acctid' => $1 })
    or die "unknown acctid $acctid";
}

if ( $action eq 'new' ) {
  my %hash = $cdr->hash;
  $hash{'freesidestatus'} = '';
  my $new = new FS::cdr \%hash;
  my $error = $new->replace($cdr);
  die $error if $error;
} elsif ( $action eq 'del' ) {
  my $error = $cdr->delete;
  die $error if $error;
} elsif ( $action =~ /^(reprocess|delete) selected$/ ) {
  foreach my $acctid (
    map { /^acctid(\d+)$/; $1; } grep /^acctid\d+$/, $cgi->param
  ) {
    my $cdr = qsearchs('cdr', { 'acctid' => $acctid });
    if ( $action eq 'reprocess selected' && $cdr ) { #new
      my $error = $cdr->clear_status;
      die $error if $error;
    } elsif ( $action eq 'delete selected' && $cdr ) { #del
      my $error = $cdr->delete;
      die $error if $error;
    }
  }
}

</%init>
