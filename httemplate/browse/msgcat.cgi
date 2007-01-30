<% include('/elements/header.html', "View Message catalog", menubar(
  'Edit message catalog' => $p. "edit/msgcat.cgi",
)) %>
<%  $widget->html %>
<% include('/elements/footer.html') %>
<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

my $widget = new HTML::Widgets::SelectLayers(
  'selected_layer' => 'en_US',
  'options'        => { 'en_US'=>'en_US' },
  'layer_callback' => sub {
    my $layer = shift;
    my $html = "<BR>Messages for locale $layer<BR>". table().
               "<TR><TH COLSPAN=2>Code</TH>".
               "<TH>Message</TH>";
    $html .= "<TH>en_US Message</TH>" unless $layer eq 'en_US';
    $html .= '</TR>';

    #foreach my $msgcat ( sort { $a->msgcode cmp $b->msgcode }
    #                       qsearch('msgcat', { 'locale' => $layer } ) ) {
    foreach my $msgcat ( qsearch('msgcat', { 'locale' => $layer } ) ) {
      $html .= '<TR><TD>'. $msgcat->msgnum. '</TD>'.
               '<TD>'. $msgcat->msgcode. '</TD>'.
               '<TD>'. $msgcat->msg. '</TD>';
      unless ( $layer eq 'en_US' ) {
        my $en_msgcat = qsearchs('msgcat', {
          'locale'  => 'en_US',
          'msgcode' => $msgcat->msgcode,
        } );
        $html .= '<TD>'. $en_msgcat->msg. '</TD>';
      }
      $html .= '</TR>';
    }

    $html .= '</TABLE>';
    $html;
  },

);

</%init>
