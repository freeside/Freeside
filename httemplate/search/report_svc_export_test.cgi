<& /elements/header.html, $title &>

% #foreach my $group (keys(%$errors)) {
% foreach my $error (@$errors) {
% my $group = (keys %$error)[0];	
<TABLE>
  <TR><TH ALIGN="left" COLSPAN="3"><FONT SIZE="+1">
    Found <% $error->{$group}->{'count'} %> <% $error->{$group}->{'description'} %> attached to <% $export %> export.
% if ($error->{$group}->{'errors'}) {
    <FONT COLOR="red">(<% scalar(keys %{$error->{$group}->{'errors'}}) %>) error(s)</FONT>
% }
  </FONT></TH></TR>
% unless ($error->{$group}->{'errors'}) {
    <TR><TD>&nbsp;</TD><TD COLSPAN=2><FONT COLOR="green">No errors found</FONT></TD></TR>
%}
% foreach my $e (keys(%{$error->{$group}->{'errors'}})) {
    <TR><TD>&nbsp;</TD><TD COLSPAN=2>
      <% $error->{$group}->{'errors'}->{$e}->{'description'} %>
%     if ($error->{$group}->{'errors'}->{$e}->{'link'}) {
	   <A HREF="<% $error->{$group}->{'errors'}->{$e}->{'link'} %>">(edit)</A>
%     }
    </TD></TR>
%   foreach my $err (keys(%{$error->{$group}->{'errors'}->{$e}->{'errors'}})) {
      <TR><TD>&nbsp;</TD><TD>&nbsp;</TD><TD><FONT COLOR="red" SIZE="-1"><% $error->{$group}->{'errors'}->{$e}->{'errors'}->{$err} %></FONT></TD></TR>
%   }
% }  
</TABLE>
% }
<& /elements/footer.html &>

<%init>

my $DEBUG = $cgi->param('debug') || 0;
my $conf = new FS::Conf;
my $export = $cgi->param('export');
my $title = $export." export test";

my $opts = { 'fsurl' => $fsurl, };

my $exports = FS::part_export::export_info();
my $class = "FS::part_export::$export" if $exports->{$export};
my $errors = $class->test_export_report($opts);

</%init>