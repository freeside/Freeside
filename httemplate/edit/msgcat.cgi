<% header(emt("Edit Message catalog")) %>
<BR>

<& /elements/error.html &>

<% $widget->html %>

    </TABLE>
  </BODY>
</HTML>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $widget = new HTML::Widgets::SelectLayers(
  'selected_layer' => 'en_US',
  'options'        => { 'en_US'=>'en_US' },
  'form_action'    => 'process/msgcat.cgi',
  'layer_callback' => sub {
    my $layer = shift;
    my $html = qq!<INPUT TYPE="hidden" NAME="locale" VALUE="$layer">!.
               "<BR>".emt("Messages for locale [_1]",$layer)."<BR>". table().
               "<TR><TH COLSPAN=2>".emt('Code')."</TH>".
               "<TH>".emt('Message')."</TH>";
    $html .= "<TH>en_US Message</TH>" unless $layer eq 'en_US';
    $html .= '</TR>';

    #foreach my $msgcat ( sort { $a->msgcode cmp $b->msgcode }
    #                       qsearch('msgcat', { 'locale' => $layer } ) ) {
    foreach my $msgcat ( qsearch('msgcat', { 'locale' => $layer } ) ) {
      $html .=
        '<TR><TD>'. $msgcat->msgnum. '</TD><TD>'. $msgcat->msgcode. '</TD>'.
        '<TD><INPUT TYPE="text" SIZE=32 '.
        qq! NAME="!. $msgcat->msgnum. '" '.
        qq!VALUE="!. ($cgi->param($msgcat->msgnum)||$msgcat->msg). qq!"></TD>!;
      unless ( $layer eq 'en_US' ) {
        my $en_msgcat = qsearchs('msgcat', {
          'locale'  => 'en_US',
          'msgcode' => $msgcat->msgcode,
        } );
        $html .= '<TD>'. $en_msgcat->msg. '</TD>';
      }
      $html .= '</TR>';
    }

    $html .= '</TABLE><BR><INPUT TYPE="submit" VALUE="'.emt('Apply changes').'">';

    $html;
  },

);

</%init>
