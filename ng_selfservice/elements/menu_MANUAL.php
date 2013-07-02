<style type="text/css">
#menu_ul ul li {
	display: inline;
	width: 100%;
} 
</style>

<ul id="menu_ul">

  <li><a href="main.php" <? if ($current_menu == 'main') echo 'class="current_menu"' ?>><? echo _('Home') ?></a></li>

  <li><a href="services.php" <? if (preg_match('/^service/', $current_menu)) echo 'class="current_menu"' ?>><? echo _('Services') ?><img src="images/dropdown_arrow_white.gif" style="display:none;"><img src="images/dropdown_arrow_grey.gif"></a>
    <ul>
      <li><a href="services.php" <? if ($current_menu == 'services') echo 'class="current_menu"' ?>><? echo _('My Services') ?></a></li>
      <li><a href="service_new.php" <? if ($current_menu == 'service_new') echo 'class="current_menu"' ?>><? echo _('Order a new service') ?></a></li>
    </ul>
  </li>

  <li><a href="personal.php" <? if ($current_menu == 'personal' || $current_menu == 'password') echo 'class="current_menu"' ?>><? echo _('Profile') ?><img src="images/dropdown_arrow_white.gif" style="display:none;"><img src="images/dropdown_arrow_grey.gif"></a>
    <ul>
      <li><a href="personal.php" <? if ($current_menu == 'personal') echo 'class="current_menu"' ?>><? echo _('Personal Information') ?></a></li>
      <li><a href="password.php" <? if ($current_menu == 'password') echo 'class="current_menu"' ?>><? echo _('Password') ?></a></li>
    </ul>
  </li>

  <li><a href="payment.php" <? if (preg_match('/^payment/', $current_menu)) echo 'class="current_menu"' ?>><? echo _('Payments') ?><img src="images/dropdown_arrow_white.gif" style="display:none;"><img src="images/dropdown_arrow_grey.gif"></a>
    <ul>
  <!--    <li><a href="payment.php" <? if ($current_menu == 'payment') echo 'class="current_menu"' ?> ><? echo _('Make Payment') ?></a></li>-->
      <li><a href="payment_cc.php"  <? if ($current_menu == 'payment_cc') echo 'class="current_menu"' ?>><? echo _('Credit Card Payment') ?></a></li>
      <li><a href="payment_ach.php"  <? if ($current_menu == 'payment_ach') echo 'class="current_menu"' ?>><? echo _('Electronic Check Payment') ?></a></li>
      <li><a href="payment_paypal.php"  <? if ($current_menu == 'payment_paypal') echo 'class="current_menu"' ?>><? echo _('PayPal Payment') ?></a></li>
      <li><a href="payment_webpay.php"  <? if ($current_menu == 'payment_webpay') echo 'class="current_menu"' ?>><? echo _('Webpay Payment') ?></a></li>
    </ul>
  
  <li><a href="usage.php" <? if (preg_match('/^usage/', $current_menu)) echo 'class="current_menu"' ?>><? echo _('Usage') ?><img src="images/dropdown_arrow_white.gif" style="display:none;"><img src="images/dropdown_arrow_grey.gif"></a>
     <ul>
  <!--    <li><a href="usage.php" <? if ($current_menu == 'usage') echo 'class="current_menu"' ?> ><? echo _('Usage') ?></a></li>-->
      <li><a href="usage_data.php"  <? if ($current_menu == 'usage_data') echo 'class="current_menu"' ?>><? echo _('Data usage') ?></a></li>
      <li><a href="usage_cdr.php"  <? if ($current_menu == 'usage_cdr') echo 'class="current_menu"' ?>><? echo _('Call usage') ?></a></li>
    </ul>

  </li>

  <li><a href="tickets.php" <? if (preg_match('/^ticket/', $current_menu)) echo 'class="current_menu"' ?>><? echo _('Help Desk') ?><img src="images/dropdown_arrow_white.gif" style="display:none;"><img src="images/dropdown_arrow_grey.gif"></a>
     <ul>
      <li><a href="tickets.php" <? if ($current_menu == 'tickets') echo 'class="current_menu"' ?> ><? echo _('Open Tickets') ?></a></li>
      <li><a href="tickets_resolved.php"  <? if ($current_menu == 'tickets_resolved') echo 'class="current_menu"' ?>><? echo _('Resolved Tickets') ?></a></li>
      <li><a href="ticket_create.php"  <? if ($current_menu == 'ticket_create') echo 'class="current_menu"' ?>><? echo _('Create a new ticket') ?></a></li>
    </ul>

  </li>

  <li><!-- style="float:right;border-style:none;" --><a href="faqs.php"><? echo _('FAQs') ?></a></li>

  <li><!-- style="float:right;border-style:none;" --><a href="logout.php"><? echo _('Logout') ?></a></li>

</ul>

<div style="clear:both;"></div>
<table cellpadding="0" cellspacing="0" border="0">
<tr>
<td class="page">
