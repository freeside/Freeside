<& /elements/header.html, "$action Service Definition" &>
<& /elements/menubar.html,
  'View all service definitions' => "${p}browse/part_svc.cgi"
           #" onLoad=\"visualize()\""
&>

<& /elements/init_overlib.html &>

<BR><BR>

<STYLE TYPE="text/css">
.disabled {
  background-color: #dddddd;
}
.hidden {
  display: none;
}
.enabled {
  background-color: #ffffff;
}
.row0 TD {
  background-color: #eeeeee;
}
.row1 TD {
  background-color: #ffffff;
}
.def_info {
  text-align: center;
  padding: 0px;
  border-top: none;
  font-size: smaller;
  font-style: italic;
}
</STYLE>
<SCRIPT TYPE="text/javascript">
function fixup_submit(layer) {
  document.forms[layer].submit.disabled = true;
  fixup(document.forms[layer]);
  window[layer+'process'].call();
}

function flag_changed(obj) {
  var newflag = obj.value;
  var a = obj.name.match(/(.*)__(.*)_flag/);
  var layer = a[1];
  var field = a[2];
  var input = document.getElementById(layer + '__' + field);
  // for fields that have both 'input' and 'select', 'select' is 'select from
  // inventory class'.
  var select = document.getElementById(layer + '__' + field + '_select');
  if (newflag == "" || newflag == "X") { // disable
    if ( input ) {
      input.disabled = true;
      input.className = 'disabled';
    }
    if ( select ) {
      select.disabled = true;
      select.className = 'hidden';
    }
  } else if ( newflag == 'D' || newflag == 'F' || newflag == 'S' ) {
    if ( input ) {
      // enable text box, disable inventory select
      input.disabled = false;
      input.className = 'enabled';
      if ( select ) {
        select.disabled = false;
        select.className = 'hidden';
      }
    } else if ( select ) {
      // enable select
      select.disabled = false;
      select.className = 'enabled';
      if ( newflag == 'S' || select.getAttribute('should_be_multiple') ) {
        select.multiple = true;
        var defaults = select.getAttribute('default');
        if ( defaults ) {
          defaults = defaults.split(',');
          for (var i = 0; i < defaults.length; i++) {
            for (j = 0; j < select.options.length; j++ ) {
              if ( defaults[i] == select.options[j].value ) {
                select.options[j].selected = true;
              }
            }
          }
        }
      } else {
        select.multiple = false;
      }
    }
  } else if ( newflag == 'M' || newflag == 'A' || newflag == 'H' ) {
    // these all require a class selection
    if ( select ) {
      select.disabled = false;
      select.className = 'enabled';
      if ( input ) {
        input.disabled = false;
        input.className = 'hidden';
      }
    }
  }
}

window.onload = function() {
  var selects = document.getElementsByTagName('SELECT');
  for(i = 0; i < selects.length; i++) {
    var obj = selects[i];
    if ( obj.multiple ) {
      obj.setAttribute('should_be_multiple', true);
    }
  }
  for(i = 0; i < selects.length; i++) {
    var obj = selects[i];
    if ( obj.name.match(/_flag$/) ) {
      flag_changed(obj);
    }
  }
};

</SCRIPT>

<FORM NAME="dummy">

<FONT CLASS="fsinnerbox-title">Service Part #<% $part_svc->svcpart ? $part_svc->svcpart : "(NEW)" %></FONT>
<TABLE CLASS="fsinnerbox">
<TR>
  <TD ALIGN="right">Service</TD>
  <TD><INPUT TYPE="text" NAME="svc" VALUE="<% $hashref->{svc} %>"></TD>
<TR>

<& /elements/tr-select-part_svc_class.html, curr_value=>$hashref->{classnum} &>

<TR>
  <TD ALIGN="right">Self-service access</TD>
  <TD>
    <SELECT NAME="selfservice_access">
% tie my %selfservice_access, 'Tie::IxHash', #false laziness w/browse/part_svc
%   ''         => 'Yes',
%   'hidden'   => 'Hidden',
%   'readonly' => 'Read-only',
% ;
% for (keys %selfservice_access) {
  <OPTION VALUE="<% $_ %>"
          <% $_ eq $hashref->{'selfservice_access'} ? 'SELECTED' : '' %>
  ><% $selfservice_access{$_} %>
% }
    </SELECT>
  </TD>
</TR>


<TR>
  <TD ALIGN="right">Disable new orders</TD>
  <TD><INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<% $hashref->{disabled} eq 'Y' ? ' CHECKED' : '' %>></TD>
</TR>

<TR>
  <TD ALIGN="right">Preserve this service on package cancellation</TD>
  <TD><INPUT TYPE="checkbox" NAME="preserve" VALUE="Y"<% $hashref->{'preserve'} eq 'Y' ? ' CHECKED' : '' %>>&nbsp;</TD>
</TR>

</TABLE>

<INPUT TYPE="hidden" NAME="svcpart" VALUE="<% $hashref->{svcpart} %>">

<BR>

<BR>
Table <% $widget->html %>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $conf = FS::Conf->new;
my $part_svc;
my $clone = '';
if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {#clone
  #$cgi->param('clone') =~ /^(\d+)$/ or die "malformed query: $query";
  $part_svc = qsearchs('part_svc', { 'svcpart'=>$1 } )
    or die "unknown svcpart: $1";
  $clone = $part_svc->svcpart;
  $part_svc->svcpart('');
} elsif ( $cgi->keywords ) { #edit
  my($query) = $cgi->keywords;
  $query =~ /^(\d+)$/ or die "malformed query: $query";
  $part_svc=qsearchs('part_svc', { 'svcpart'=>$1 } )
    or die "unknown svcpart: $1";
} else { #adding
  $part_svc = new FS::part_svc {};
}

my $action = $part_svc->svcpart ? 'Edit' : 'Add';
my $hashref = $part_svc->hashref;
#   my $p_svcdb = $part_svc->svcdb || 'svc_acct';


my @dbs = $hashref->{svcdb}
           ? ( $hashref->{svcdb} )
           : FS::part_svc->svc_tables();

my $help = '';
unless ( $hashref->{svcpart} ) {
  $help = '&nbsp;'.
          include('/elements/popup_link.html',
                    'action' => $p.'docs/part_svc-table.html',
                    'label'  => 'help',
                    'actionlabel' => 'Service table help',
                    'width'       => 763,
                    #'height'      => 400,
                  );
}

tie my %svcdb, 'Tie::IxHash', map { $_=>$_ } grep dbdef->table($_), @dbs;
my $widget = new HTML::Widgets::SelectLayers(
  #'selected_layer' => $p_svcdb,
  'selected_layer' => $hashref->{svcdb} || 'svc_acct',
  'options'        => \%svcdb,
  'form_name'      => 'dummy',
  #'form_action'    => 'process/part_svc.cgi',
  'form_action'    => 'part_svc.cgi', #self
  'form_elements'  => [qw( svc svcpart classnum selfservice_access
                           disabled preserve
                      )],
  'html_between'   => $help,
  'layer_callback' => sub {
    include('elements/part_svc_column.html',
              shift,
              'part_svc' => $part_svc,
              'clone' => $clone
    )
  }
);
</%init>



