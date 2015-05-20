<? $title ='Prepaid Card Account Recharge'; include('elements/header.php'); ?>
<? $current_menu = 'recharge.php'; include('elements/menu.php'); ?>

<?
// This page is currently only designed for packages that use prepaid pricing.
// Usage limits should be in seconds, and you currently cannot mix packages that have 
// usage limits with packages that don't.  Payments must be made by prepaid card.
// The account service must be flagged as primary service of package.
//
// You can't change packages if you have a positive balance, but you CAN use 
// this form to only change package or only use a prepaid card--doing both isn't
// required.

$prepaid_cardnum = isset($_POST['prepaid_cardnum']) ? $_POST['prepaid_cardnum'] : '';
$pkgpart = isset($_POST['pkgpart']) ? $_POST['pkgpart'] : '';
$pkgnum  = isset($_POST['pkgnum']) ? $_POST['pkgnum'] : '';
$success = '';
$error   = '';

if ($pkgnum || $pkgpart) {
  if ($pkgnum && $pkgpart) {
    $change_results = $freeside->change_pkg(array(
      'session_id'      => $_COOKIE['session_id'],
      'pkgpart'         => $pkgpart,
      'pkgnum'          => $pkgnum,
    ));
    if ( isset($change_results['error']) && $change_results['error'] ) {
      $error = $change_results['error'];
    } else {
      $success .= ' Package applied to your account.';
      $pkgnum = '';
      $pkgpart = '';
    }
  } else if ($pkgnum) {
    $error = 'No account selected';
  } else if ($pkgpart) {
    $error = 'No package selected';
  }
}

if ($prepaid_cardnum) {
  $payment_results = $freeside->process_prepay(array(
    'session_id'      => $_COOKIE['session_id'],
    'prepaid_cardnum' => $prepaid_cardnum,
  ));
  if ( isset($payment_results['error']) && $payment_results['error'] ) {
    $error = $payment_results['error'];
  } else {
    $success .= ' Prepaid card applied to your account.';
    $prepaid_cardnum = '';
  }
}

$customer_info = $freeside->customer_info_short( array(
  'session_id' => $_COOKIE['session_id'],
) );
if ( isset($customer_info['error']) && $customer_info['error'] ) {
  $error = $customer_info['error'];
}

$signup_info = $freeside->signup_info( array('customer_session_id' => $_COOKIE['session_id'], 'keys' => ['part_pkg']) );
if (isset($signup_info['error']) && $signup_info['error']) {
  $error = $signup_info['error'];
}

$list_pkgs = $freeside->list_pkgs( array(
  'session_id' => $_COOKIE['session_id'],
) );
if ( isset($list_pkgs['error']) && $list_pkgs['error'] ) {
  $error = $list_pkgs['error'];
}

extract($customer_info);
extract($signup_info);
extract($list_pkgs);

$actsvcs = array();
$expsvcs = array();
foreach ($cust_pkg as $pkg) {
  $thissvc = array();
  $thissvc['svcnum']    = $pkg['primary_cust_svc']['svcnum'];
  $thissvc['overlimit'] = $pkg['primary_cust_svc']['overlimit'];
  $thissvc['label']     = $pkg['primary_cust_svc']['label'][1];
  $thissvc['pkgnum'] = $pkg['pkgnum'];
  $thissvc['status'] = $pkg['status'];
  $actsvcs[$thissvc['svcnum']] = $thissvc;
  if ($thissvc['overlimit'] or ($thissvc['status'] != 'active')) {
    $expsvcs[$thissvc['svcnum']] = $thissvc;
  }
}

if (count($actsvcs) > 0) {
  $list_svcs = $freeside->list_svcs( array(
    'session_id' => $_COOKIE['session_id'],
  ) );
  if ( isset($list_svcs['error']) && $list_svcs['error'] ) {
    $error = $list_svcs['error'];
  }
  extract($list_svcs);
  foreach ($svcs as $svc) {
    if (isset($actsvcs[$svc['svcnum']])) {
      $actsvcs[$svc['svcnum']]['seconds'] = strlen($svc['seconds']) ? $svc['seconds'] : 'Unlimited';
    }
  }
}

if ($success) {
  echo '<P><B>' . $success . '</B></P>';
}
include('elements/error.php');

if (count($actsvcs) > 0) {
?>
<TABLE STYLE="text-align: left;">
<TR><TH>Account</TH><TH STYLE="text-align: right;">Seconds Remaining</TH></TR>
<? 
  foreach ($actsvcs as $svc) {
    if ($svc['status'] == 'active') {
      $slabel = $svc['seconds'];
    } else {
      $slabel = '<I>' . ucfirst($svc['status']) . '</I>';
    }  
?>
<TR>
<TD><? echo $svc['label'] ?></TD>
<TD STYLE="text-align: right;"><? echo $slabel ?></TD>
</TR>
<?
  }
?>
</TABLE>
<?
}
if ($balance != 0) {
  $blabel = ($balance < 0) ? 'Credit' : 'Balance';
?>

<P><B><? echo $blabel ?>:</B> <? echo $money_char . abs($balance) ?></P>

<?
}
?>

<FORM NAME="OneTrueForm" METHOD="POST" ACTION="recharge.php" onSubmit="document.OneTrueForm.process.disabled=true">

<?
if ($balance <= 0) {
  if (count($expsvcs) > 0) {
?>

<P>
<B>Select an account to recharge:</B><BR>
<SELECT NAME="pkgnum">
<OPTION VALUE=""></OPTION>
<? foreach ($expsvcs as $svc) { ?>
<OPTION VALUE="<? echo $svc['pkgnum'] ?>"<? echo $pkgnum == $svc['pkgnum'] ? ' CHECKED' : ''  ?>>
<?   echo $svc['label'] ?>
</OPTION>
<? } ?>
</SELECT>
</P>

<P>
<B>Select a package to add to account</B><BR>
<SELECT NAME="pkgpart">
<OPTION VALUE=""></OPTION>
<? foreach ($part_pkg as $pkg) { ?>
<OPTION VALUE="<? echo $pkg['pkgpart'] ?>"<? echo $pkgpart == $pkg['pkgpart'] ? ' CHECKED' : ''  ?>>
<?   echo $pkg['pkg'] . ' - ' . $money_char . $pkg['options']['recur_fee'] ?>
</OPTION>
<? } ?>
</SELECT>
</P>

<?
  } else {
?>

<P>You have no services to recharge at this time.</P>

<?
  }
}
if (($balance > 0) or (count($expsvcs) > 0)) {
?>

<P>
<B>Enter prepaid card number:</B><BR>
<INPUT TYPE="text" NAME="prepaid_cardnum" VALUE="<? echo $prepaid_cardnum ?>">
</P>

<INPUT TYPE="submit" NAME="submit" VALUE="Submit">

<?
}
?>

</FORM>

<? include('elements/menu_footer.php'); ?>
<? include('elements/footer.php'); ?>

