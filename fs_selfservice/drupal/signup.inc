<?php
function freeside_signup() {
  return drupal_get_form('freeside_signup_form');
}

function dkpr($var) {
  /* "debug kpr": Krumo-print $var if debugging is on */
  static $debug;
  if(empty($debug)) $debug = variable_get('freeside_debug','');
  if($debug) {
    kpr($var);
  }
}

function signup_info($keys) {
  /* local cache, because transporting the entire signup_info
    through XML-RPC is incredibly slow.  If you change the config,
    you can flush the local cache with the "Clear cached data" 
    button on the Drupal "Performance" menu. */
  $cid = 'FS_signup_info';
  $info = cache_get($cid);
  if($info) {
    return($info->data);
  }
  else {
    $packet = array(
      'agentnum'    => variable_get('freeside_agentnum',''),
      'promo_code'  => '',
      'reg_code'    => '',
      'keys'        => $keys,
    );

    $freeside = new FreesideSelfService(); 
    $freeside->clear_signup_cache();
    $info = $freeside->signup_info($packet);
    cache_set($cid, $info, 'cache', CACHE_TEMPORARY);
    return($info);
  }
}

function subextract($array, $key) {
  // map { $_->{$key} } (...)
  $out = array();
  foreach ($array as $i) {
    $out[] = $i[$key];
  }
  return $out;
}

function freeside_signup_form($form_state) {
  dkpr($form_state);

  $agentnum = variable_get('freeside_agentnum','');
  if( !$agentnum || !(variable_get('freeside_hostname','')) ) {
    drupal_set_message(t('Freeside self-service is not yet configured.'),'error');
    return array();
  }

  $freeside = new FreesideSelfService();
  $keys = array(
    // all the signup_info that we need
    'part_referral',
    'refnum',
    'emailinvoiceonly',
    'payby',
    'payby_longname',
    'part_pkg',
    'default_pkgpart',
    'signup_service',
  );
  $signup_info = signup_info($keys);
  dkpr($signup_info);

  $form = array();

  $refs = $signup_info['part_referral'];
  $form['refnum'] = count($refs) > 1 ?
    array(
      '#type'   => 'select',
      '#title'  => t('How did you hear about us?'),
      '#options'=> array_combine(
        subextract($refs, 'refnum'), 
        subextract($refs, 'referral')
      ),
      '#default_value'=>$signup_info['refnum'],
    ) : array (
      '#type'   => 'hidden',
      '#value'  => $refs[0]['refnum'],
    );

  $form['contact'] = array(
    '#type'   => 'fieldset',
    '#title'  => t('Contact Information'),
    'last'    => array( 
      '#prefix' => '<div class="container-inline">',
      '#type'   => 'textfield',
      '#title'  => t('Contact name (last, first)'),
      '#size'   => 20,
      '#required' => 1,
    ),
    'first'   => array( 
      '#type'   => 'textfield',
      '#size'   => 20,
      '#required' => 1,
      '#suffix' => '</div>',
    ),
    'company' => array(
      '#type'   => 'textfield',
      '#title'  => t('Company'),
      '#size'   => 20,
    ),
    'address1'=> array(
      '#type'   => 'textfield',
      '#title'  => t('Address'),
      '#size'   => 30,
      '#required'=>1,
    ),
    'address2'=> array(
      '#type'   => 'textfield',
      '#size'   => 30,
    ),
    'city'    => array(
      '#prefix' => '<div class="container-inline">',
      '#type'   => 'textfield',
      '#title'  => t('City'),
      '#size'   => 15,
      '#required'=>1,
    ),
    'state'   => array(
      '#type'   => 'textfield',
      '#title'  => t('State'),
      '#size'   => 2,
      '#required'=>1,
      '#default_value'=>$info['statedefault'],
    ),
    'zip'     => array(
      '#type'   => 'textfield',
      '#title'  => t('Zip'),
      '#size'   => 10,
      '#required'=>1,
      '#suffix' => '</div>',
    ),
    'daytime' => array(
      '#type'   => 'textfield',
      '#title'  => t('Daytime Phone'),
      '#size'   => 18,
    ),
    'night'   => array(
      '#type'   => 'textfield',
      '#title'  => t('Night Phone'),
      '#size'   => 18,
    ),
  );

  $emailinvoiceonly = $signup_info['emailinvoiceonly'];

  $form['billing'] = array(
    'invoicing_list'  => array(
      '#type'   => 'textfield',
      '#title'  => t('Email invoice to'),
      '#size'   => '40',
      '#required'=>$emailinvoiceonly,
    ),
    '#type'   => 'fieldset',
    '#title'  => t('Billing Information'),
    'invoicing_list_POST' => array(
      '#type'   => $emailinvoiceonly ? 'hidden' : 'checkbox',
      '#title'  => t('Send a paper invoice'),
      '#default_value' => 0,
    ),
  );

  if( count($signup_info['payby']) > 1 ) {
    $form['billing']['payby'] = array(
      '#type'   => 'select',
      '#title'  => t('Payment method'),
      '#options'=> array_combine(
        $signup_info['payby'],
        $signup_info['payby_longname']
      ),
    );
  }
  else {
    $form['billing']['payby'] = array(
      '#type'   => 'hidden',
      '#value'  => $signup_info['payby'][0],
    );
  }
  $form['billing']['payby_CARD'] = array(
    '#type'   => 'fieldset',
    'cardnum' => array(
      '#prefix' => '<div class="container-inline">',
      '#type'   => 'textfield',
      '#title'  => t('Credit card number'),
      '#size'   => 20,
      '#maxlength'=>20,
      '#required'=>1,
      '#suffix' => '</div>',
    ),
    'expmonth' => array(
      '#prefix' => '<div class="container-inline">',
      '#type'   => 'textfield',
      '#title'  => t('Expiration date'),
      '#size'   => 2,
      '#required'=>1,
      '#maxlength' => 2,
    ),
    'expyear' => array(
      '#field_prefix' => '/',
      '#type'   => 'textfield',
      '#size'   => 2,
      '#maxlength' => 2,
      '#required'=>1,
      '#suffix' => '</div>',
    ),
    'paycvv'  => array(
      '#prefix' => '<div class="container-inline">',
      '#type'   => 'textfield',
      '#title'  => 'CVV',
      '#size'   => 3,
      '#maxlength'  => 3,
      '#required'=>1,
      '#suffix' => '</div>',
    ),
    'cardname'=> array(
      '#prefix' => '<div class="container-inline">',
      '#type'   => 'textfield',
      '#title'  => t('Exact name on card'),
      '#size'   => 40,
      '#maxlength'=>60,
      '#suffix' => '</div>',
    ),
  );

  $pkgs = $signup_info['part_pkg'];
  $form['package'] = array(
    '#type'   => 'fieldset',
    '#title'  => t('First Package'),
    'pkgpart' => (count($pkgs) > 1 ?
      array(
        '#type'   => 'select',
        '#title'  => '',
        '#options'=> array_combine(
          subextract($pkgs, 'pkgpart'),
          subextract($pkgs, 'pkg')
        ),
        '#default_value'=>$signup_info['default_pkgpart'],
      ) : array (
        '#type'   => 'hidden',
        '#value'  => $pkgs[0]['pkgpart'],
      )
    ),
  );

  switch($signup_info['signup_service']) {
  case 'svc_acct':
    $form['package'] += array(
      'username'=> array(
        '#type'   => 'textfield',
        '#title'  => t('Username'),
        '#size'   => 20,
        '#required'=>1,
      ),
      'password'=> array(
        '#type'   => 'password_confirm',
        '#size'   => 20,
        '#required'=>1,
        '#process'=> array('freeside_expand_password_confirm'),
      )
    );
    break;
  case 'svc_pbx':
    break; // nothing yet implemented
  }
  $form['package']['pkgpart']['#default_value'] = $signup_info['default_pkgpart'];

  $form['submit'] = array(
    '#type'   => 'submit',
    '#value'  => 'Sign me up!',
  );
  return $form;
}

/* workaround for silly Drupal behavior */
function freeside_expand_password_confirm($element) {
  $element = expand_password_confirm($element);
  $element['pass1']['#attributes']['value'] = $element['#value']['pass1'];
  $element['pass2']['#attributes']['value'] = $element['#value']['pass2'];
  return $element;
}

function freeside_signup_form_submit($form, &$form_state) {
  $freeside = new FreesideSelfService();
  $values = $form_state['values'];
  dkpr($values);

  $customer = array();
  $customer['agentnum'] = variable_get('freeside_agentnum','');
  foreach( array( 'first',
                 'last',
                 'address1',
                 'address2',
                 'city',
                 'state',
                 'zip',
                 'daytime',
                 'night',
                 'fax',
                 'payby',
                 'refnum',
                 'invoicing_list',
                 'pkgpart',
                 'username'
               ) 
    as $field ) {
    $customer[$field] = $values[$field];
    }
  if($values['invoicing_list_POST']) {
    $customer['invoicing_list'] = 
      implode(',', array($customer['invoicing_list'], 'POST'));
  }
  $customer['_password']  = $values['password'];
  $customer['country']    = 'US';
  if($customer['payby'] == 'CARD') {
    $customer['payinfo'] = preg_replace('/\D/','',$values['cardnum']);
    $customer['paydate'] = $values['expmonth'] . '/' . $values['expyear'];
    $customer['payname'] = isset($values['cardname']) ? 
      $values['cardname'] :
      ($values['first'] . ' ' . $values['last']);
    $customer['paycvv'] = $values['paycvv'];
  }
  /* other paybys not implemented */

  dkpr($customer);
  $response = $freeside->new_customer($customer);
  dkpr($response);
  error_log("[new_customer] received response from Freeside: $response");
  $error = $response['error'];

  if ( $error ) {
    drupal_set_message(t("Signup error: $error"), 'error');
    $form_state['redirect'] = FALSE;
  }
  else {
    drupal_set_message(t("Signup successful!"),'status');
    $form_state['redirect'] = array(
      variable_get('freeside_redirect_after_signup','/'),
      //query string would go here
      //'custnum='.$response['custnum'].'&svcnum='.$response['svcnum'],
    );
  }
}

?>
