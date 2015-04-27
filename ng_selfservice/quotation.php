<STYLE>
td.amount {
    text-align: right;
}
td.amount:before {
    content: "$";
}
tr.total * {
    background-color: #ddf;
    font-weight: bold;
}
table.section {
    width: 100%;
    border-collapse: collapse;
}
table.section td {
    font-size: small;
    padding: 1ex 1ex;
}
table.section th {
    text-align: left;
    padding: 1ex;
}
.row0 td {
    background-color: #eee;
}
.row1 td {
    background-color: #fff;
}
</STYLE>

<? $title ='Plan a new service order'; include('elements/header.php'); ?>
<? $current_menu = 'services_new.php'; include('elements/menu.php'); ?>
<?

$quotation = $freeside->quotation_info(array(
  'session_id'  => $_COOKIE['session_id'],
));

$can_order = 0;

if ( isset($quotation['sections']) and count($quotation['sections']) > 0 ) {
  $can_order = 1;
  # there are other ways this could be formatted, yes.
  # if you want the HTML-formatted quotation, use quotation_print().
  print(
    '<INPUT STYLE="float: right" TYPE="button" onclick="window.location.href=\'quotation_print.php\'" value="Download a quotation" />'.
    '<H3>Order summary</H3>'.
    "\n"
  );
  foreach ( $quotation['sections'] as $section ) {
    print(
      '<TABLE CLASS="section">'.
      '<TR>'.
      '<TH COLSPAN=4>'.  htmlspecialchars($section['description']).'</TH>'.
      '</TR>'.
      "\n"
    );
    $row = 0;
    foreach ( $section['detail_items'] as $detail ) {
      if (isset($detail['description'])) {
        print(
          '<TR CLASS="row' . $row . '">'.
          '<TD>'
        );
        if ( $detail['pkgnum'] ) {
          print(
            '<A HREF="quotation_remove_pkg.php?pkgnum=' .
            $detail['pkgnum'] . '">'.
            '<IMG SRC="images/cross.png" /></A>'
          );
        }
        print(
          '</TD>'.
          '<TD>'. htmlspecialchars($detail['description']). '</TD>'.
          '<TD CLASS="amount">'. $detail['amount']. '</TD>'.
          '</TR>'. "\n"
        );
        $row = 1 - $row;
      } else {
        # total rows; a 3.x-ism
        print(
          '<TR CLASS="total">'.
          '<TD></TD>'.
          '<TD>'. htmlspecialchars($detail['total_item']). '</TD>'.
          '<TD CLASS="amount">'. $detail['total_amount']. '</TD>'.
          '</TR>'."\n"
        );
      }
    }
    if (isset($section['subtotal'])) {
      print(
        '<TR CLASS="total">'.
        '<TD></TD>'.
        '<TD>Total</TD>'.
        '<TD CLASS="amount">'. $section['subtotal']. '</TD>'.
        '</TR>'
      );
    }
    print "</TABLE>\n";
  } # foreach $section
}

$pkgselect = $freeside->mason_comp( array(
    'session_id' => $_COOKIE['session_id'],
    'comp'       => '/elements/select-part_pkg.html',
    'args'       => array( 'onchange'       , 'enable_order_pkg()',
                           'empty_label'    , 'Select package',
                           'form_name'      , 'AddPkgForm',
                         ),
));
if ( isset($pkgselect['error']) && $pkgselect['error'] ) {
  $error = $pkgselect['error'];
  header('Location:index.php?error='. urlencode($pkgselect));
  die();
}

?>
<SCRIPT TYPE="text/javascript">
function enable_order_pkg () {
    document.AddPkgForm.submit.disabled =
        (document.AddPkgForm.pkgpart.value == '');
}
</SCRIPT>

<DIV STYLE="border-top: 1px solid; padding: 1ex">
<? $error = $_REQUEST['error']; include('elements/error.php'); ?>

<FORM NAME="AddPkgForm" ACTION="quotation_add_pkg.php" METHOD=POST>
<? echo $pkgselect['output']; ?>
<INPUT NAME="submit" TYPE="submit" VALUE="Add package" <? if ( ! isset($_REQUEST['pkgpart']) ) { echo 'DISABLED'; } ?>>
</FORM>

<? if ( $can_order ) { ?>
<FORM NAME="OrderQuoteForm" ACTION="quotation_order.php" METHOD=POST>
<INPUT TYPE="submit" VALUE="Confirm this order" <? if ( !$can_order ) { echo 'DISABLED'; } ?>>
<? } ?>

</DIV>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>
