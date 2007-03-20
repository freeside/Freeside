<% include("/elements/header.html", "Batch Customer Note Import $op") %>

The following items <% $op eq 'Preview' ? 'would not be' : 'were not' %> imported.  (See below for imported items)
<PRE>
%  foreach my $row (@uninserted) {
%    $csv->combine( (map{ $row->{$_} } qw(last first note) ),
%                   $row->{error} ? ('#!', $row->{error}) : (),
%                 );
<% $csv->string %>
%  }
</PRE>

The following items <% $op eq 'Preview' ? 'would be' : 'were' %> imported.  (See above for unimported items)

<PRE>
%  foreach my $row (@inserted) {
%    $csv->combine( (map{ $row->{$_} } qw(custnum last first note) ),
%                   ('#!', $row->{name}),
%                 );
<% $csv->string %>
%  }
</PRE>
  
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Import');

my $date = time;
my $otaker = $FS::CurrentUser::CurrentUser->username;
my $csv = new Text::CSV_XS;

my $param = $cgi->Vars;

my $op = $param->{preview} ? "Preview" : "Results";

my @inserted = ();
my @uninserted = ();
for ( my $row = 0; exists($param->{"custnum$row"}); $row++ ) {
  if ( $param->{"custnum$row"} ) {
    my $cust_main_note = new FS::cust_main_note {
                                          'custnum'  => $param->{"custnum$row"},
                                          '_date'    => $date,
                                          'otaker'   => $otaker,
                                          'comments' => $param->{"note$row"},
                                                };
    my $error = '';
    $error = $cust_main_note->insert unless ($op eq "Preview");
    my $result = { 'custnum' => $param->{"custnum$row"},
                   'last'    => $param->{"last$row"},
                   'first'   => $param->{"first$row"},
                   'note'    => $param->{"note$row"},
                   'name'    => $param->{"name$row"},
                   'error'   => $error,
                 };
    if ($error) {
      push @uninserted, $result;
    }else{
      push @inserted, $result;
    }
  }else{
    push @uninserted, { 'custnum' => '',
                        'last'    => $param->{"last$row"},
                        'first'   => $param->{"first$row"},
                        'note'    => $param->{"note$row"},
                        'error'   => '',
                      };
  }
}
</%init>
