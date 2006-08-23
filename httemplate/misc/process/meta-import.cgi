<!-- mason kludge -->
<% include("/elements/header.html",'Map tables') %>

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
%
%  #use DBIx::DBSchema;
%  my $schema = new_native DBIx::DBSchema
%                 map { $cgi->param($_) } qw( data_source username password );
%  foreach my $field (qw( data_source username password )) { 

    <INPUT TYPE="hidden" NAME=<% $field %> VALUE="<% $cgi->param($field) %>">
% }
%
%  my %schema;
%  use Tie::DxHash;
%  tie %schema, 'Tie::DxHash';
%  if ( $cgi->param('schema') ) {
%    my $schema_string = $cgi->param('schema');
%    
 <INPUT TYPE="hidden" NAME="schema" VALUE="<%$schema_string%>"> 
%
%    %schema = map { /^\s*(\w+)\s*=>\s*(\w+)\s*$/
%                      or die "guru meditation #420: $_";
%                    ( $1 => $2 );
%                  }
%              split( /\n/, $schema_string );
%  }
%
%  #first page
%  unless ( $cgi->param('magic') ) { 


    <INPUT TYPE="hidden" NAME="magic" VALUE="process">
    <% hashmaker('schema', [ $schema->tables ],
                            [ grep !/^h_/, dbdef->tables ],  ) %>
    <br><INPUT TYPE="submit" VALUE="done">
%
%
%  #second page
%  } elsif ( $cgi->param('magic') eq 'process' ) { 


    <INPUT TYPE="hidden" NAME="magic" VALUE="process2">
%
%
%    my %unique;
%    foreach my $table ( keys %schema ) {
%
%      my @from_columns = $schema->table($table)->columns;
%      my @fs_columns = dbdef->table($schema{$table})->columns;
%
%      

      <% hashmaker( $table.'__'.$unique{$table}++,
                     \@from_columns => \@fs_columns,
                     $table         =>  $schema{$table}, ) %>
      <br><hr><br>
%
%
%    }
%
%    

    <br><INPUT TYPE="submit" VALUE="done">
%
%
%  #third (results)
%  } elsif ( $cgi->param('magic') eq 'process2' ) {
%
%    print "<pre>\n";
%
%    my %unique;
%    foreach my $table ( keys %schema ) {
%      ( my $spaces = $table ) =~ s/./ /g;
%      print "'$table' => { 'table' => '$schema{$table}',\n".
%            #(length($table) x ' '). "         'map'   => {\n";
%            "$spaces        'map'   => {\n";
%      my %map = map { /^\s*(\w+)\s*=>\s*(\w+)\s*$/
%                         or die "guru meditation #420: $_";
%                       ( $1 => $2 );
%                     }
%                 split( /\n/, $cgi->param($table.'__'.$unique{$table}++) );
%      foreach ( keys %map ) {
%        print "$spaces                     '$_' => '$map{$_}',\n";
%      }
%      print "$spaces                   },\n";
%      print "$spaces      },\n";
%
%    }
%    print "\n</pre>";
%
%  } else {
%    warn "unrecognized magic: ". $cgi->param('magic');
%  }
%
%  

</FORM>
</BODY>
</HTML>
%
%  #hashmaker widget
%  sub hashmaker {
%    my($name, $from, $to, $labelfrom, $labelto) = @_;
%    my $fromsize = scalar(@$from);
%    my $tosize = scalar(@$to);
%    "<TABLE><TR><TH>$labelfrom</TH><TH>$labelto</TH></TR><TR><TD>".
%        qq!<SELECT NAME="${name}_from" SIZE=$fromsize>\n!.
%        join("\n", map { qq!<OPTION VALUE="$_">$_</OPTION>! } sort { $a cmp $b } @$from ).
%        "</SELECT>\n<BR>".
%      qq!<INPUT TYPE="button" VALUE="refill" onClick="repack_${name}_from()">!.
%      '</TD><TD>'.
%        qq!<SELECT NAME="${name}_to" SIZE=$tosize>\n!.
%        join("\n", map { qq!<OPTION VALUE="$_">$_</OPTION>! } sort { $a cmp $b } @$to ).
%        "</SELECT>\n<BR>".
%      qq!<INPUT TYPE="button" VALUE="refill" onClick="repack_${name}_to()">!.
%      '</TD></TR>'.
%      '<TR><TD COLSPAN=2>'.
%        qq!<INPUT TYPE="button" VALUE="map" onClick="toke_$name(this.form)">!.
%      '</TD></TR><TR><TD COLSPAN=2>'.
%      qq!<TEXTAREA NAME="$name" COLS=80 ROWS=8></TEXTAREA>!.
%      '</TD></TR></TABLE>'.
%      "<script>
%            function toke_$name() {
%              fromObject = document.OneTrueForm.${name}_from;
%              for (var i=fromObject.options.length-1;i>-1;i--) {
%                if (fromObject.options[i].selected)
%                  fromname = deleteOption_$name(fromObject,i);
%              }
%              toObject = document.OneTrueForm.${name}_to;
%              for (var i=toObject.options.length-1;i>-1;i--) {
%                if (toObject.options[i].selected)
%                  toname = deleteOption_$name(toObject,i);
%              }
%              document.OneTrueForm.$name.value = document.OneTrueForm.$name.value + fromname + ' => ' + toname + '\\n';
%            }
%            function deleteOption_$name(object,index) {
%              value = object.options[index].value;
%              object.options[index] = null;
%              return value;
%            }
%            function repack_${name}_from() {
%              var object = document.OneTrueForm.${name}_from;
%              object.options.length = 0;
%              ". join("\n", 
%                   map { "addOption_$name(object, '$_');\n" }
%                       ( sort { $a cmp $b } @$from )           ). "
%            }
%            function repack_${name}_to() {
%              var object = document.OneTrueForm.${name}_to;
%              object.options.length = 0;
%              ". join("\n", 
%                   map { "addOption_$name(object, '$_');\n" }
%                       ( sort { $a cmp $b } @$to )           ). "
%            }
%            function addOption_$name(object,value) {
%              var length = object.length;
%              object.options[length] = new Option(value, value, false, false);
%            }
%      </script>".
%      '';
%  }
%
%

