<!-- mason kludge -->
<%= header('Map tables') %>
<SCRIPT>
var gSafeOnload = new Array();
var gSafeOnsubmit = new Array();
window.onload = SafeOnload;
function SafeAddOnLoad(f) {
  gSafeOnload[gSafeOnload.length] = f;
}
function SafeOnload() {
  for (var i=0;i<gSafeOnload.length;i++)
    gSafeOnload[i]();
}
function SafeAddOnSubmit(f) {
  gSafeOnsubmit[gSafeOnsubmit.length] = f;
}
function SafeOnsubmit() {
  for (var i=0;i<gSafeOnsubmit.length;i++)
    gSafeOnsubmit[i]();
}
</SCRIPT>
<FORM NAME="OneTrueForm" METHOD="POST" ACTION="meta-import.cgi">
<%
  #one
  unless ( $cgi->param('magic') ) {

    #oops, silly
    #my $fh = $cgi->upload('csvfile');
    ##warn $cgi;
    ##warn $fh;
    #
    #use Archive::Tar;
    #$tar = Archive::Tar->new();
    #$tar->create_archive($fh); #or die $tar->error;

    #haha for now
    my @files = qw(
authserv  credtype  dunprev  invoice  pmtdet    product   taxplan
ccdet     customer  genlog   ledger   pops      pubvars   
cchist    discplan  glacct   origco   prodcat   recur     users
credcode  dundet    invline  payment  prodclas  repforms  webserv
    );

    %>
    <INPUT TYPE="hidden" NAME="magic" VALUE="process">
    <%= hashmaker('schema', \@files, [ grep { ! /^h_/ } dbdef->tables ] ) %>
    <br><INPUT TYPE="submit" VALUE="done">
    <%

  } elsif ( $cgi->param('magic') eq 'process' ) {

    %>
    <INPUT TYPE="hidden" NAME="magic" VALUE="process2">
    <%

    my $schema_string = $cgi->param('schema');
    %><INPUT TYPE="hidden" NAME="schema" VALUE="<%=$schema_string%>"><%
    my %schema = map { /^\s*(\w+)\s*=>\s*(\w+)\s*$/
                         or die "guru meditation #420: $_";
                       ( $1 => $2 );
                     }
                 split( /\n/, $schema_string );

    #*** should be in global.asa/handler.pl like the rest
    eval 'use Text::CSV_XS;';

    foreach my $table ( keys %schema ) {

      my $csv = Text::CSV_XS->new({ 'binary'=>1 });
      open(FILE,"</home/ivan/intergate/legacy/csvdir/$table")
        or die "can't /home/ivan/intergate/legacy/csvdir/$table: $!";
      my $header = lc(<FILE>);
      close FILE;
      $csv->parse($header) or die;
      my @from_columns = $csv->fields;

      my @fs_columns = dbdef->table($schema{$table})->columns;

      %>
      <%= hashmaker($table, \@from_columns, \@fs_columns, $table, $schema{$table} ) %>
      <br><hr><br>
      <%

    }

    %>
    <br><INPUT TYPE="submit" VALUE="done">
    <%

  } elsif ( $cgi->param('magic') eq 'process2' ) {

    print "<pre>\n";
    #false laziness with above
    my $schema_string = $cgi->param('schema');
    my %schema = map { /^\s*(\w+)\s*=>\s*(\w+)\s*$/
                         or die "guru meditation #420: $_";
                       ( $1 => $2 );
                     }
                 split( /\n/, $schema_string );
    foreach my $table ( keys %schema ) {
      ( my $spaces = $table ) =~ s/./ /g;
      print "'$table' => { 'table' => '$schema{$table}',\n".
            #(length($table) x ' '). "         'map'   => {\n";
            "$spaces        'map'   => {\n";
      my %map = map { /^\s*(\w+)\s*=>\s*(\w+)\s*$/
                         or die "guru meditation #420: $_";
                       ( $1 => $2 );
                     }
                 split( /\n/, $cgi->param($table) );
      foreach ( keys %map ) {
        print "$spaces                     '$_' => '$map{$_}',\n";
      }
      print "$spaces                   },\n";
      print "$spaces      },\n";

    }
    print "\n</pre>";

  } else {
    warn "unrecognized magic: ". $cgi->param('magic');
  }

  %>
</FORM>
</BODY>
</HTML>

  <%
  #hashmaker widget
  sub hashmaker {
    my($name, $from, $to, $labelfrom, $labelto) = @_;
    $fromsize = scalar(@$from);
    $tosize = scalar(@$to);
    "<TABLE><TR><TH>$labelfrom</TH><TH>$labelto</TH></TR><TR><TD>".
        qq!<SELECT NAME="${name}_from" SIZE=$fromsize>\n!.
        join("\n", map { qq!<OPTION VALUE="$_">$_</OPTION>! } sort { $a cmp $b } @$from ).
        "</SELECT>\n".
      '</TD><TD>'.
        qq!<SELECT NAME="${name}_to" SIZE=$tosize>\n!.
        join("\n", map { qq!<OPTION VALUE="$_">$_</OPTION>! } sort { $a cmp $b } @$to ).
        "</SELECT>\n".
      '</TD></TR>'.
      '<TR><TD COLSPAN=2>'.
        qq!<INPUT TYPE="button" VALUE="map" onClick="toke_$name(this.form)">!.
      '</TD></TR><TR><TD COLSPAN=2>'.
      qq!<TEXTAREA NAME="$name" COLS=80 ROWS=8></TEXTAREA>!.
      '</TD></TR></TABLE>'.
      "<script>
            function toke_$name() {
              fromObject = document.OneTrueForm.${name}_from;
              for (var i=fromObject.options.length-1;i>-1;i--) {
                if (fromObject.options[i].selected)
                  fromname = deleteOption_$name(fromObject,i);
              }
              toObject = document.OneTrueForm.${name}_to;
              for (var i=toObject.options.length-1;i>-1;i--) {
                if (toObject.options[i].selected)
                  toname = deleteOption_$name(toObject,i);
              }
              document.OneTrueForm.$name.value = document.OneTrueForm.$name.value + fromname + ' => ' + toname + '\\n';
            }
            function deleteOption_$name(object,index) {
              value = object.options[index].value;
              object.options[index] = null;
              return value;
            }
      </script>".
      '';
  }

%>
