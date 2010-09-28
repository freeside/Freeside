<?php

function freeside_admin() {
  return drupal_get_form('freeside_admin_form');
}

function freeside_admin_form() {
  $hostname = variable_get('freeside_hostname','');

  $form = array(
    'freeside_hostname'=> array(
      '#type'   => 'textfield',
      '#title'  => t('Freeside server address'),
      '#default_value'=>variable_get('freeside_hostname',''),
      '#required'=>1,
    ),
  );

  if($hostname) {
    $freeside = new FreesideSelfService();
    $signup_info = $freeside->signup_info(
      array(
        'keys' => array('agent')
      )
    ); // no agent in this request

    $agents = array();
    foreach((array)$signup_info['agent'] as $a) {
      $agents[$a['agentnum']] = $a['agent'];
    }

    $form['freeside_agentnum'] = array(
      '#type'   => 'select',
      '#title'  => t('Signup agent'),
      '#default_value'=>variable_get('freeside_agentnum',''),
      '#required'=>1,
      '#options'=> $agents,
    );

    $form['freeside_debug'] = array(
      '#type'   => 'checkbox',
      '#title'  => t('Enable debugging'),
      '#default_value'=>variable_get('freeside_debug',0),
    );

    $form['freeside_redirect_after_signup'] = array(
      '#type'   => 'textfield',
      '#title'  => t('Success page (URL or Drupal path)'),
      '#default_value'=>variable_get('freeside_redirect_after_signup','/'),
    );
  }

  return system_settings_form($form);
}

?>
