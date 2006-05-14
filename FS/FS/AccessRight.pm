package FS::AccessRight;

use strict;
user vars qw(@rights %rights);
use Tie::IxHash;

=head1 NAME

FS::AccessRight - Access control rights.

=head1 SYNOPSIS

  use FS::AccessRight;

=head1 DESCRIPTION

Access control rights - Permission to perform specific actions that can be
assigned to users and/or groups.

=cut

@rights = (
  'Reports' => [
    '_desc' => 'Access to high-level reporting',
  ],
  'Configuration' => [
    '_desc' => 'Access to configuration',

    'Settings' => {},

    'agent' => [
      '_desc' => 'Master access to reseller configuration',
      'agent_type'  => {},
      'agent'       => {},
    ],

    'export_svc_pkg' => [
      '_desc' => 'Access to export, service and package configuration',
      'part_export' => {},
      'part_svc'    => {},
      'part_pkg'    => {},
      'pkg_class'   => {},
    ],

    'billing' => [
      '_desc' => 'Access to billing configuration',
      'payment_gateway'  => {},
      'part_bill_event'  => {},
      'prepay_credit'    => {},
      'rate'             => {},
      'cust_main_county' => {},
    ],

    'dialup' => [
      '_desc' => 'Access to dialup configuraiton',
      'svc_acct_pop' => {},
    ],

    'broadband' => [
      '_desc' => 'Access to broadband configuration',
      'router'     => {},
      'addr_block' => {},
    ],

    'misc' => [
      'part_referral'      => {},
      'part_virtual_field' => {},
      'msgcat'             => {},
      'inventory_class'    => {},
    ],

  },

);

#turn it into a more hash-like structure, but ordered via IxHash

