<& /elements/header.html, emt("View Message catalog"), menubar(
  emt('Edit message catalog') => $p. "edit/msgcat.cgi",
) &>
<%  $widget->html %>
<& /elements/footer.html &>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $widget = new HTML::Widgets::SelectLayers(
  'selected_layer' => 'en_US',
  'options'        => { 'en_US'=>'en_US', 'iw_IL' => 'iw_IL', },
  'layer_callback' => sub {
    my $layer = shift;
    my $html = "<BR>".emt("Messages for locale [_1]",$layer)."<BR>". table().
               "<TR><TH COLSPAN=2>".emt('Code')."</TH>".
               "<TH>".emt('Message')."</TH>";
    $html .= "<TH>en_US Message</TH>" unless $layer eq 'en_US';
    $html .= '</TR>';

    foreach my $msgcat ( qsearch('msgcat', { 'locale' => $layer } ) ) {
      $html .= '<TR><TD>'. $msgcat->msgnum. '</TD>'.
               '<TD>'. $msgcat->msgcode. '</TD>'.
               '<TD>'. $msgcat->msg. '</TD>';
      unless ( $layer eq 'en_US' ) {
        my $en_msgcat = qsearchs('msgcat', {
          'locale'  => 'en_US',
          'msgcode' => $msgcat->msgcode,
        } );
        $html .= '<TD>'. $en_msgcat->msg. '</TD>' if $en_msgcat;
      }
      $html .= '</TR>';
    }

    $html .= '</TABLE>';
    $html;
  },

);

</%init>
